Import-Module VMware.VimAutomation.Core
Import-Module VMware.VimAutomation.VDS

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore
Connect-VIServer "test"
clear

############
# Settings #
############
$vmName = "vmName"
$files = @"
File/Path1
File/Path2
"@ -split "`r`n"


##########
# Script #
##########
# Get Credential
$Cred = Get-Credential -Message "Please enter your domain credentials" -UserName $env:USERNAME

Write-Host ("[[Collecting VM]] VM: $comp")
$vm = Get-VM -Name $vmName

$fCount = $files.Count
$fCur = -1
foreach($file in $files){
  $fCur++
  $fPer = [Math]::Round( $fCur/$fCount*100 , 2 )
  Write-Progress -Activity "Processing File" -CurrentOperation ("{0,4}/{1} {2}" -f $fCur, $fCount, $file) -Status "$fPer % Done" -PercentComplete $fPer -Id 1
  
  # Encode and split file script
  $scriptEncode = @"
    `$content = Get-Content -Path `"$file`" | Out-String
    `$encoded = [System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes(`$content))
    
    `$count = 0
    while(`$encoded){
      `$count++
      `$encodedTemp, `$encoded = ([Char[]]`$encoded).Where({`$_},"Split",2500)
      Set-Content -Path `"$file.`$count`" -Value `$encodedTemp | Out-Null
    }
    `$count
"@
  
  $encodedCheck = $true
  try{
    $scriptEncodedResults = Invoke-VMScript -ScriptText $scriptEncode -GuestCredential $cred -VM $vm -ErrorAction Stop
    Write-Host $scriptEncodedResults
    $count = [int32] $scriptEncodedResults.ScriptOutput
    Write-Host ("[[Encoding/Splitting File]] Processing Success")
  }
  catch{
    Write-Host ("[[Encoding/Splitting File]] Processing Failure")
    $encodedCheck = $false
  }
  
  if($encodedCheck){
    # Decode script
    $extractionCheck = $true
    $encodedContent = ""
    foreach($chunk in 1..$count){
      $fileChunk = "$file.$chunk"
      $scriptDecode = @"
        `$contentEncoded = Get-Content -Path `"$fileChunk`"
        Remove-Item -Path `"$fileChunk`" | Out-Null
        `$contentEncoded
"@
      try{
        $scriptDecodeResults = Invoke-VMScript -ScriptText $scriptDecode -GuestCredential $cred -VM $vm -ErrorAction Stop
        Write-Host ("[[Extracting File]] Processing Chunk {0,3}/{1}" -f $chunk, $count)
        $encodedContent += $scriptDecodeResults.ScriptOutput -join ""
      }
      catch{
        $extractionCheck = $false
        Write-Host ("[[Extracting File]] Failure Chunk {0,3}/{1}" -f $chunk, $count)
      }
    }
  }
  
  if($extractionCheck){
    $contentDecoded = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($encodeContent))
    $pathFinal = "C:\Temp\test.txt"
    Set-Content -Path $pathFinal -Value $contentDecoded | Out-Null
    Write-Host ("[[Extracting File]] Output File: $pathFinal")
  }
}
