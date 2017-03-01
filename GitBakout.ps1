# Save
#$folders = @(Get-ChildItem -Path 'F:\Script Repository' -Directory)
$folders = @(Get-Item -Path 'F:\Script Repository\TestGitBackout2')

$folderCur   = -1
$folderCount = $folders.Count
foreach($folder in $folders){
    # Build Progress Bar
    $folderCur++
    $folderI  = [Math]::Round($folderCur/$folderCount * 100, 2)
    Write-Progress -Activity "Processing current Script Folder" -CurrentOperation $Folder.Name -Status "$folderI % Done" -PercentComplete $folderI -Id 1

    if(Test-Path -Path (Join-Path -Path $folder.FullName -ChildPath ".git")){
        # Previous File size
        $preSize = (Get-ChildItem -Path $folder.FullName -Recurse -Force | Measure-Object -Property Length -Sum).Sum/1MB

        # Move to folder
        cd $folder.FullName

        # Get a list of hashes
        $LogInfos = @(git log --pretty=format:%H";"%cn";"%ct";"%s)
        [Array]::Reverse($LogInfos)

        # Build object from Log Info
        Write-Host "Building log objects"
        $LogArr = @()
        foreach($LogInfo in $LogInfos){
            $LogObj = New-Object -TypeName PSObject
            $LogItems = $LogInfo -split ";"
            $TimeStamp = [TimeZone]::CurrentTimeZone.ToLocalTime(([DateTime]'1/1/1970').AddSeconds($LogItems[2]))
            $TimeStamp = Get-Date $TimeStamp -Format "yyyy.MM.ddTHH.mm.ss"
            Add-Member -InputObject $LogObj -MemberType NoteProperty -Name Hash      -Value $LogItems[0]
            Add-Member -InputObject $LogObj -MemberType NoteProperty -Name TimeStamp -Value $TimeStamp
            Add-Member -InputObject $LogObj -MemberType NoteProperty -Name Author    -Value $LogItems[1]
            Add-Member -InputObject $LogObj -MemberType NoteProperty -Name Message   -Value $LogItems[3]
            $LogArr += $LogObj
        }
        Write-Host "Built the following array for $($folder.Name)"
        $LogArr | Format-Table -AutoSize

        
        $listOfArchives = @()
        $logCur   = -1
        $logCount = $LogArr.Count
        foreach($Log in $LogArr){
            # Build Progress Bar
            $logCur++
            $logI  = [Math]::Round($logCur/$logCount * 100, 2)
            Write-Progress -Activity "Processing current Log Entry" -CurrentOperation $Log.TimeStamp -Status "$logI % Done" -PercentComplete $logI -Id 2

            # Make new folder
            $ArchiveFolder = New-Item -ItemType Directory -Path "$($folder.PSParentPath)\Archive of $($folder.Name) - $($Log.TimeStamp) - $($Log.Author)" -Force
            $listOfArchives += $ArchiveFolder

            # Clear Git Folder
            Get-ChildItem -Path $folder.FullName -Exclude @(".git") -Force | ForEach-Object -Process {Remove-Item -Path $_.FullName -Force -Recurse} | Out-Null

            # Pull Out Each Hash to new folder.
            git checkout $Log.Hash *
            #Start-Sleep -Seconds 5
            Copy-Item "$($folder.FullName)\*" $ArchiveFolder.FullName -Recurse
            #git checkout *

            # Add a text file with information on commit.
            git show $Log.Hash | Out-File -FilePath "$($ArchiveFolder.FullName)\Commit.log"
        }
        Write-Progress -Activity "Processing current Log Entry" -Status "Done" -Id 2 -Completed
        
        # Move new archives
        foreach($Archive in $listOfArchives){
            if(!(Test-Path -Path "$($folder.FullName)\Archives")){
                New-Item -ItemType Directory -Path "$($folder.FullName)\Archives" -Force
            }
            Move-Item $Archive.FullName -Destination "$($folder.FullName)\Archives" -Force
        }

        <#
        # Clear up artifacts
        $artifacts = Get-ChildItem -Path "$($folder.FullName)\Archives" -File
        foreach($artifact in $artifacts){
            Remove-Item -Path $artifact.FullName
        }
        #>

        # Post File size
        $postSize = (Get-ChildItem -Path $folder.FullName -Recurse -Force -Exclude .git | Measure-Object -Property Length -Sum).Sum/1MB

        # Report filesize
        Write-Host ("Pre is  {0:N3} MB" -f $preSize)
        Write-Host ("Post is {0:N3} MB" -f $postSize)
        #>
    }
    else{
        Write-Host "$($folder.Name) is not a .git"
    }
}
Write-Progress -Activity "Processing current Script Folder" -Status "Done" -Id 1 -Completed
