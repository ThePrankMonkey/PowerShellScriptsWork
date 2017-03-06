<#
    .SYNOPSIS
    This script extracts git commits.
    .DESCRIPTION
    This script will proceed through the desired folder and build archives of each commit for the subfolders.
    These archives will be 
    .NOTES
    Version:  1.0
    Ticket:   CHG0031543
    Requires: PowerShell v4
    Creator:  Matthew Hellmer
    History:  Version...Date.........User.....................Comment
              v1.0      2017.03.02   Matthew.Hellmer          Initial Creation
#>

#Requires -Version 4
Import-Module '\\S01a-GitServer\F$\Script Repository\APSTools-Module\APSTools.psm1' -Force

############
# Settings #
############
#$WorkPath  = 'F:\Script Repository\TestGitBackout - Copy'
$WorkPath  = 'F:\Script Repository\'
$RemoveGit = $false
$global:ErrorLogPath = 'F:\Script Repository\log.log'

Clear-Content -Path $global:ErrorLogPath
#Get-ChildItem -Path $WorkPath -Directory | ForEach-Object {try{$folder = $_; Remove-Item -Path (Join-Path -Path $folder.FullName -ChildPath "Git Archives") -Recurse -Force -ErrorAction Stop}catch{"No Archive for $($folder.Name)"}}



#############
# Functions #
#############
Function PassesGitCheck
{
<#
    .SYNOPSIS
    Checks to see if provided folder is a git repository
    .DESCRIPTION
    Checks to see if provided folder is a git repository. This is done by seeing if a .git folder is present and then if the repository can be queried.
    .NOTES
    Version:  1.1
    Ticket:   None
    Requires: PowerShell v4
    Creator:  Matthew Hellmer
    History:  Version...Date.........User.....................Comment
              v1.0      2017.02.28   Matthew.Hellmer          Initial Creation
              v1.1      2017.03.02   Matthew.Hellmer          Fixed issue with CheckGit reports
    .PARAMETER Folder
    The folder that is processed.
    .EXAMPLE
    PassesGitCheck -Folder "C:\Temp"
    C:\Temp is checked if it is a git folder.
#>
    Param(
        [Parameter(Position=0, Mandatory=$true)]
        [System.IO.DirectoryInfo]
        $Folder
    )
    Process{
        # Check if folder has a .git
        try{
            $CheckGit = Test-Path -Path (Join-Path -Path $Folder.FullName -ChildPath ".git")
            if($CheckGit){
                Log -Object $Folder -CustomMessage "Folder has a .git folder." -Type Info
            }
            else{
                Log -Object $Folder -CustomMessage "Folder does not have a .git folder." -Type Fail
            }
        }
        catch{
            $CheckGit = $false
            Log -Object $Folder -NewError $_ -CustomMessage "Error when checking for .git folder" -Type Error
        }

        # Check if Git is initialized
        try{
            $CheckInit = git rev-parse --is-inside-work-tree 2>$null
        }
        catch{
            Log -Object $Folder -NewError $_ -CustomMessage "Error when checking if initialized" -Type Error 
            $CheckInit = $false
        }

        $checkResults = $CheckGit -and $CheckInit
        if($checkResults){
            Log -Object $Folder -CustomMessage "Folder is a git repository." -Type Info
            return $true
        }
        else{
            Log -Object $Folder -CustomMessage "Folder is not a git repository." -Type Fail
            return $false
        }
    }
}


Function Main
{
    Begin{
        $folders = @(Get-ChildItem -Path $WorkPath -Directory)
        #$folders = @(Get-Item -Path $WorkPath)
    }
    Process{
        $folderCur   = -1
        $folderCount = $folders.Count
        foreach($folder in $folders){
            # Build Progress Bar
            $folderCur++
            $folderI  = [Math]::Round($folderCur/$folderCount * 100, 2)
            Write-Progress -Activity "Processing current Script Folder" -CurrentOperation $Folder.Name -Status "$folderI % Done" -PercentComplete $folderI -Id 1

            if(PassesGitCheck -Folder $folder){
                # Previous File size
                $preSize = (Get-ChildItem -Path $folder.FullName -Recurse -Force | Measure-Object -Property Length -Sum).Sum/1MB

                # Move to folder
                cd $folder.FullName

                # Back up current version if needed.
                git reset head --quiet
                $addedFiles = @(git add * --verbose)
                if($addedFiles){
                    git commit -m "Final backup" --quiet
                    Log -Object $Folder -CustomMessage "Needed to commit unstaged changes." -Type Warn
                }

                # Get a list of commits
                $LogInfos = @(git log --pretty=format:%H";"%cn";"%ct";"%s";"%h)
                [Array]::Reverse($LogInfos)
                Log -Object $Folder -CustomMessage ("Found {0} commits to process." -f $LogInfos.Count) -Type Info

                # Build object from commits
                Log -Object $Folder -CustomMessage "Building log objects." -Type Info
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
                    Add-Member -InputObject $LogObj -MemberType NoteProperty -Name Short     -Value $LogItems[4]
                    $LogArr += $LogObj
                }
                Log -Object $Folder -CustomMessage "Built the following array." -Type Info
                (($LogArr | Format-Table -AutoSize | Out-String) -split "`n") | Add-Content -Path $ErrorLogPath
                $LogArr | Format-Table -AutoSize

                # Build archives
                try{
                    Log -Object $Folder -CustomMessage "Building archives from commits." -Type Info
                    $listOfArchives = @()
                    $logCur   = -1
                    $logCount = $LogArr.Count
                    foreach($Log in $LogArr){
                        # Build Progress Bar
                        $logCur++
                        $logI  = [Math]::Round($logCur/$logCount * 100, 2)
                        Write-Progress -Activity "Processing current Log Entry" -CurrentOperation $Log.TimeStamp -Status "$logI % Done" -PercentComplete $logI -Id 2

                        # Make new folder
                        $ArchiveFolderName = "$($folder.PSParentPath)\Archive of $($folder.Name) - $($Log.TimeStamp) - $($Log.Author)"
                        $ArchiveFolder     = New-Item -ItemType Directory -Path $ArchiveFolderName -Force
                        $listOfArchives   += $ArchiveFolder

                        # Clear Git Folder
                        try{
                            $clearFiles = Get-ChildItem -Path $folder.FullName -Exclude ".git*" -Force -ErrorAction Stop
                            foreach($clearFile in $clearFiles){
                                try{
                                    Remove-Item -Path $clearFile.FullName -Force -Recurse -ErrorAction Stop | Out-Null
                                }
                                catch{
                                    Log -Object $Folder -NewError $_ -CustomMessage "Unexpected error removing $($clearFile.Name)" -Type Error
                                }
                            }
                        }
                        catch{
                            Log -Object $Folder -NewError $_ -CustomMessage "Unexpected error clearing git folder." -Type Error
                        }

                        # Pull Out Each Hash to new folder.
                        git checkout $Log.Hash *
                        Copy-Item "$($folder.FullName)\*" $ArchiveFolder.FullName -Recurse

                        # Add a text file with information on commit.
                        git show $Log.Hash | Out-File -FilePath "$($ArchiveFolder.FullName)\CommitRecord-$($Log.Short).log"
                    }
                    Write-Progress -Activity "Processing current Log Entry" -Status "Done" -Id 2 -Completed
                }
                catch{
                    Log -Object $Folder -NewError $_ -CustomMessage "Unexpected building archives." -Type Error
                }
        
                # Move new archives
                Log -Object $Folder -CustomMessage "Moving new archives." -Type Info
                $destination = "$($folder.FullName)\Git Archives"
                foreach($Archive in $listOfArchives){
                    if(!(Test-Path -Path $destination)){
                        New-Item -ItemType Directory -Path $destination -Force | Out-Null
                    }
                    try{
                        Move-Item $Archive.FullName -Destination $destination -Force
                    }
                    catch{
                        Log -Object $Archive -NewError $_ -CustomMessage "Unexpected error moving folder." -Type Error
                    }
                }

                # Remove git
                try{
                    if($RemoveGit){
                        $RemoveFiles = @(Get-ChildItem -Path $folder.FullName -Force | Where-Object {$_.Name -like ".git*"})
                        if($RemoveFiles){
                            $RemoveFiles | ForEach-Object -Process {Remove-Item -Path $_.FullName -Recurse -Force} | Out-Null
                            Log -Object $Folder -NewError $_ -CustomMessage "Removing old git files." -Type Info
                        }
                        else{
                            Log -Object $Folder -NewError $_ -CustomMessage "No old git files to remove." -Type Info
                        }
                    }
                    else{
                        Log -Object $Folder -CustomMessage "Not removing old git files." -Type Warn
                    }
                }
                catch{
                    Log -Object $Folder -NewError $_ -CustomMessage "Unexpected error when removing old git files." -Type Error
                }

                # Post File size
                $postSize = (Get-ChildItem -Path $folder.FullName -Recurse -Force -Exclude ".git" | Measure-Object -Property Length -Sum).Sum/1MB

                # Report filesize
                Log -Object $Folder -CustomMessage ("     Size for Git is {0,10:N3} MB" -f $preSize) -Type Info
                Log -Object $Folder -CustomMessage ("Size for Archives is {0,10:N3} MB" -f $postSize) -Type Info
                Log -Object $Folder -CustomMessage ("         Increase of {0,10:N2} %" -f ($postSize/$preSize * 100)) -Type Info
            }
        }
        Write-Progress -Activity "Processing current Script Folder" -Status "Done" -Id 1 -Completed
    }
}




########
# Main #
########
Main
Start-Process $global:ErrorLogPath
