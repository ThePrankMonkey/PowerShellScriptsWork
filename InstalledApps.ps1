$companies = @("mcafee", "network solutions", "microsoft")

$AppKeys = @()
$AppKeys += Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\"
$AppKeys += Get-ChildItem -Path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\"

$AppObjs = @()
foreach($AppKey in $AppKeys){
    $Publisher = $AppKey.GetValue("Publisher")
    foreach($company in $companies){
        if($Publisher -like "*$($company)*"){
            $appObj = [ordered]@{}
            $props  = $AppKey.GetValueNames() | Sort
            foreach($prop in $props){
                if($prop -ne ""){
                    $appObj[$prop] = $AppKey.GetValue($prop)
                }
                else{
                    Write-Host $AppKey, $prop -ForegroundColor Yellow
                }
            }
            if($appObj){
                $AppObjs += New-Object -TypeName PSObject -Property $appObj
            }
        }
    }
}

#$AppObjs
