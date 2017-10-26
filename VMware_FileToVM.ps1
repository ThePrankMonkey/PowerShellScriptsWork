
Add-PSSnapin VMware.VimAutomation.Core
Add-PSSnapin VMware.VimAutomation.VDS

Connect-VIServer "VCenter"
clear

$pathSource = "File\Path\You\Want\To\Push"
$pathFinal  = "Destination\File\Path\On\VM"
$pathInterim = $pathFinal + ".BAK"

$VMNames = @"
VM1
VM2
"@ -split "`r`n"

# Get Credential for VM (assumes same cred for all VM)
$Cred = Get-Credential -Message "Please enter your domain credentials" -UserName $env:USERNAME

# Grab and encode the content for the file
$content = Get-Content -Path $pathSource | Out-String
Write-Host ("[[Encoding File]]")
$encoded = [System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($content))

# Make array of encoded text chunks
Write-Host ("[[Chunking Encoded File]]")
$encodedArray = @()
while($encoded){
  $encodedTemp, $encoded = ([Char[]]$encoded).Where({$_},"Split",2500) # 2500 is a good size to get around limitations
  $encodedArray += $encodedTemp -join ''
}

# Decode Script
$scriptDecode = @"
  `$contentEncoded = Get-Content -Path `"$pathInterim`"
  `$contentDecoded = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String(`$contentEncoded))
  Set-Content -Path `"$pathFinal`" -Value `$contentDecoded
  Remove-Item -Path `"$pathInterim`"
"@

# Loop over computers
$cCount = $comps.Count
$cCur = -1
foreach($comp in $comps){
  $cCur++
  $cPer = [Math]::Round( $cCur/$cCount*100 , 2 )
  Write-Progress -Activity "Processing Computer" -CurrentOperation ("{0,4}/{1} {2}" -f $cCur, $cCount, $comp) -Status "$cPer % Done" -PercentComplete $cPer -Id 1
  
  Write-Host ("[[Collecting VM]] VM: $comp")
  $vm = Get-VM -Name $comp
  
  $lCount = $encodedArray.Count
  $lCur = 0
  foreach($line in $encodedArray){
    $lCur++
    $scriptImport = "Add-Content -Path `"$pathInterim`" -Value `"$line`""
    try{
      $scriptImportResults = Invoke-VMScript -ScriptText $scriptImport -GuestCredential $cred -VM $vm -ErrorAction Stop
      Write-Host ("[[Adding Encoded File]] Processing line {0,3}/{1}" -f $lCur, $lCount)
    }
    catch{
      Write-Host ("[[Adding Encoded File]] Failure line {0,3}/{1}" -f $lCur, $lCount)
    }
  }
  try{
    $scriptDecodeResults = Invoke-VMScript -ScriptText $scriptDecode -GuestCredential $cred -VM $vm -ErrorAction Stop
    Write-Host ("[[Decoding File]] Success")
  }
  catch{
    Write-Host ("[[Decoding File]] Failure")
  }
}
