<#
    .SYNOPSIS
    This script scans and commits changes to script folders.
    .DESCRIPTION
    This script is ran weekly to scan the script repository folder for any changes.
    If the folder isn't a git repository, it is made into one.
    If changes are found, a weekly commit is performed.
    Lastly, a summary email is sent out to report on findings.
    .NOTES
    Version:  1.5
    Ticket:   CHG0031543
    Requires: PowerShell v4
    Creator:  Matthew Hellmer
    History:  Version...Date.........User.....................Comment
              v1.0      2017.02.27   Matthew.Hellmer          Initial Creation
              v1.1      2017.02.28   Matthew.Hellmer          Added email generation sections.
              v1.2      2017.02.28   Matthew.Hellmer          Updated TryToAdd (adds files to objects). Added CollectInfo and BuildEmailMessage functions.
              v1.3      2017.03.01   Matthew.Hellmer          Added BuildEmailMessageHTML. Changed email to use this.
              v1.4      2017.03.02   Matthew.Hellmer          Updated PassesGitCheck (CheckGit).
              v1.5      2017.03.06   Matthew.Hellmer          Updated MakeGit (logs more comments).
#>

#Requires -Version 4
Import-Module '\\S01a-GitServer\F$\Script Repository\APSTools-Module\APSTools.psm1' -Force

#############
# Variables #
#############
$global:GlobalArgs   = $args
$global:emailObjects = @()
if($args -eq "Service"){
    $searchPath      = 'F:\Script Repository'
}
else{
    $searchPath      = 'F:\Script Repository\GitTest'
}
$commitStamp         = Get-Date -Format "yyyy-MM-dd"
$commitMessage       = "Weekly Backup and Commit $commitStamp"
$global:emailSubject = $commitMessage
$global:NewRecipient = "SystemEngineers@so1.smsuite.local"
CreateLogs -Ticket CHG0031543




#############
# Functions #
#############
Function BuildEmailMessage
{
<#
    .SYNOPSIS
    Builds the message for the email
    .DESCRIPTION
    Takes the created email objects array and parses the collected values into a more human readable format.
    .NOTES
    Version:  1.0
    Ticket:   None
    Requires: PowerShell v4
    Creator:  Matthew Hellmer
    History:  Version...Date.........User.....................Comment
              v1.0      2017.02.28   Matthew.Hellmer          Initial Creation
#>
    Begin{
        $lastWeek            = Get-Date (Get-Date).AddDays(-7)
        $global:emailObjects = $global:emailObjects | Sort-Object Folder
        $emailMessage        = ""
        $newFolderString     = "`t{0,-30} -- {1,-22} -- {2}`r`n"
        $newCommitString     = "`t`t`t{0,-7} -- {1,-10} -- {2,-40} -- {3}`r`n"
        $newAddedFilesString = "`t`t`t{0}`r`n"
    }
    Process{
        # Handle new folders.
        $emailMessage += "The following folders are newly created:`r`n"
        $newObjects = @($global:emailObjects | Where-Object {$_.Created -gt $lastWeek})
        if($newObjects){
            $emailMessage += $newFolderString -f "Folder", "Created", "Already Git"
            foreach($obj in $newObjects){
                $emailMessage += $newFolderString -f $obj.Folder, $obj.Created, $obj.Git
            }
        }
        else{
            $emailMessage += "`tNo new folders this week."
        }
        $emailMessage += "`r`n`r`n"
        
        # Handle weekly report
        $emailMessage += "The following changes were noted:`r`n"
        foreach($obj in $global:emailObjects){
            $emailMessage += "`t$($obj.Folder):`r`n"
            
            # Report Commits
            $emailMessage += "`t`tNew Commits: $($obj.CommitsCount)`r`n"
            if($obj.Commits){
                $emailMessage += $newCommitString -f "Hash", "Date", "Author", "Message"
                foreach($commit in $obj.Commits){
                    $commitParts = $commit -split ";"
                    $emailMessage += $newCommitString -f $commitParts[0], $commitParts[2], $commitParts[1], $commitParts[3]
                }
            }
            else{
                $emailMessage += "`t`t`tNo new commits this week."
            }
            # Report Files
            $emailMessage += "`t`tUncommitted Files: $($obj.AddedFilesCount)`r`n"
            if($obj.AddedFiles){
                foreach($file in $obj.AddedFiles | Sort-Object){
                    $emailMessage += $newAddedFilesString -f $file
                }
            }
            else{
                $emailMessage += "`t`t`tNo uncommitted files this week.`r`n"
            }
        }
    }
    End{
        return $emailMessage
    }
}


Function BuildEmailMessageHTML
{
<#
    .SYNOPSIS
    Builds the message for the email in HTML
    .DESCRIPTION
    Takes the created email objects array and parses the collected values into a more human readable format, using HTML.
    .NOTES
    Version:  1.0
    Ticket:   None
    Requires: PowerShell v4
    Creator:  Matthew Hellmer
    History:  Version...Date.........User.....................Comment
              v1.0      2017.02.28   Matthew.Hellmer          Initial Creation
#>
    Begin{
        $lastWeek            = Get-Date (Get-Date).AddDays(-7)
        $global:emailObjects = $global:emailObjects | Sort-Object Folder
        $emailMessage        = ""
        $newFolderString     = "`t<tr><td>{0}</td><td>{1}</td><td class={3}>{2}</td></tr>`r`n"
        $newFolderStringHead = "`t<tr><th>{0}</th><th>{1}</th><th>{2}</th></tr>`r`n"
        $newCommitString     = "`t`t`t<tr><td>{0}</td><td>{1}</td><td>{2}</td><td>{3}</td></tr>`r`n"
        $newCommitStringHead = "`t`t`t<tr><th>{0}</th><th>{1}</th><th>{2}</th><th>{3}</th></tr>`r`n"
        $newAddedFilesString = "`t`t`t<tr><td class={1}>{0}</td></tr>`r`n"

        # Build CSS Header
        $emailMessage += "<style>`r`n"
        $emailMessage += ".one          { text-indent: 1em; font-weight: bold; }`r`n"
        $emailMessage += ".two          { text-indent: 2em; }`r`n"
        $emailMessage += ".three        { text-indent: 3em; }`r`n"
        $emailMessage += "table, th, td { border: 1px solid black; }`r`n"
        $emailMessage += "table         { border-collapse: collapse; }`r`n"
        $emailMessage += "th            { font-weight: bold; }`r`n"
        $emailMessage += ".table        { margin-left: 2em; padding-left: 5px; padding-right: 5px; }`r`n"
        $emailMessage += ".Green        { color: Green; }`r`n"
        $emailMessage += ".Red          { color: Red; }`r`n"
        $emailMessage += "</style>`r`n"
    }
    Process{
        # Handle new folders.
        $emailMessage += "The following folders are newly created:<br>`r`n"
        $newObjects = @($global:emailObjects | Where-Object {$_.Created -gt $lastWeek})
        if($newObjects){
            $emailMessage += "<table class=table one>`r`n"
            $emailMessage += $newFolderStringHead -f "Folder", "Created", "Already Git"
            foreach($obj in $newObjects){
                if($obj.Git){
                    $class = "Green"
                }
                else{
                    $class = "Red"
                }
                $emailMessage += $newFolderString -f $obj.Folder, $obj.Created, $obj.Git, $class
            }
            $emailMessage += "</table>`r`n"
        }
        else{
            $emailMessage += "`t<div class=>No new folders this week.</div>"
        }
        $emailMessage += "<br><br>`r`n`r`n"
        
        # Handle weekly report
        $emailMessage += "The following changes were noted:`r`n"
        foreach($obj in $global:emailObjects){
            $emailMessage += "`t<div class=one>$($obj.Folder):</div>`r`n"
            
            # Report Commits
            $emailMessage += "`t`t<div class=two>New Commits: $($obj.CommitsCount)</div>`r`n"
            if($obj.Commits){
                $emailMessage += "<table class=table three>`r`n"
                $emailMessage += $newCommitStringHead -f "Hash", "Date", "Author", "Message"
                foreach($commit in $obj.Commits){
                    $commitParts = $commit -split ";"
                    $emailMessage += $newCommitString -f $commitParts[0], $commitParts[2], $commitParts[1], $commitParts[3]
                }
                $emailMessage += "</table>`r`n"
            }
            else{
                $emailMessage += "`t`t`t<div class=three>No new commits this week.</div>"
            }
            # Report Files
            $emailMessage += "`t`t<div class=two>Uncommitted Files: $($obj.AddedFilesCount)</div>`r`n"
            if($obj.AddedFiles){
                $emailMessage += "<table class=table three>`r`n"
                foreach($file in $obj.AddedFiles | Sort-Object){
                    $emailMessage += $newAddedFilesString -f $file, "Red"
                }
                $emailMessage += "</table>`r`n"
            }
            else{
                $emailMessage += "`t`t`t<div class=three>No uncommitted files this week.</div>`r`n"
            }
        }
    }
    End{
        return $emailMessage
    }
}


Function CollectInfo
{
<#
    .SYNOPSIS
    Grabs commits for the last week
    .DESCRIPTION
    Starts the build of objects that track new folders and new commits that will be used to generate email messages.
    .NOTES
    Version:  1.0
    Ticket:   None
    Requires: PowerShell v4
    Creator:  Matthew Hellmer
    History:  Version...Date.........User.....................Comment
              v1.0      2017.02.28   Matthew.Hellmer          Initial Creation
    .PARAMETER Folders
    The list of folders that are in the script repository
    .EXAMPLE
    CollectInfo -Folders $folders
    $folders are scanned and object records commits.
#>
    Param(
        [Parameter(Position=0, Mandatory=$true)]
        [Array]
        $Folders
    )
    Begin{
        $lastWeek     = Get-Date (Get-Date).AddDays(-7) -Format "yyyy.MM.dd"
        $logString    = "%h`";`"%cn`";`"%cd`";`"%s"
    }
    Process{
        foreach($folder in $folders){
            try{
                Log -Object $folder -CustomMessage "Beginning initial scan" -Type Info
                cd $folder.FullName
            
                # Build a record for the 
                $folderObj = New-Object -TypeName PSObject
                $folderObjName    = $folder.Name
                $folderObjCreated = Get-Date $folder.CreationTime
                Add-Member -InputObject $folderObj -MemberType NoteProperty -Name Folder  -Value $folderObjName
                Add-Member -InputObject $folderObj -MemberType NoteProperty -Name Created -Value $folderObjCreated

                # Check if already a git and report findings
                if(PassesGitCheck -Folder $folder){
                    $folderObjCommit   = git log --since=$lastWeek --date=short --pretty=format:$logString
                    $folderObjComCount = $folderObjCommit.Count
                    Add-Member -InputObject $folderObj -MemberType NoteProperty -Name Git           -Value $true
                    Add-Member -InputObject $folderObj -MemberType NoteProperty -Name Commits       -Value $folderObjCommit
                    Add-Member -InputObject $folderObj -MemberType NoteProperty -Name CommitsCount  -Value $folderObjComCount
                }
                else{
                    Add-Member -InputObject $folderObj -MemberType NoteProperty -Name Git           -Value $false
                    Add-Member -InputObject $folderObj -MemberType NoteProperty -Name Commits       -Value $null
                    Add-Member -InputObject $folderObj -MemberType NoteProperty -Name CommitsCount  -Value 0
                    #MakeGit -Folder $folder
                }
                $global:emailObjects += $folderObj
                Log -Object $folder -CustomMessage "Completed initial scan" -Type Pass
            }
            catch{
                Log -Object $folder -NewError $_ -CustomMessage "Unexpected error on intial scan" -Type Error
            }
        }
    }
}


Function MakeGit
{
<#
    .SYNOPSIS
    Initializes a folder as a git repository
    .DESCRIPTION
    Initializes a folder as a git repository, no harm if ran on a folder already initialized.
    .NOTES
    Version:  1.0
    Ticket:   None
    Requires: PowerShell v4
    Creator:  Matthew Hellmer
    History:  Version...Date.........User.....................Comment
              v1.0      2017.02.28   Matthew.Hellmer          Initial Creation
              v1.1      2017.03.06   Matthew.Hellmer          Added some logging.
    .PARAMETER Folder
    The folder that is processed.
    .EXAMPLE
    MakeGit -Folder "C:\Temp"
    C:\Temp\.git is made and git files are added for tracking repository changes.
#>
    Param(
        [Parameter(Position=0, Mandatory=$true)]
        [System.IO.DirectoryInfo]
        $Folder
    )
    Process{
        Log -Object $Folder -CustomMessage "Initializing as a git repository" -Type Info
        git init --quiet
        if(PassesGitCheck -Folder $Folder){
            Log -Object $Folder -CustomMessage "Passed initialization check." -Type Info
            TryToAdd -Folder $Folder
        }
        else{
            Log -Object $Folder -CustomMessage "Was not initialized as a git repository." -Type Fail
        }
    }
}


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


Function TryToAdd
{
<#
    .SYNOPSIS
    Checks for changes to commit
    .DESCRIPTION
    Checks for changes to commit. If any are found, a commit is performed titled "Weekly Backup and Commit $timestamp"
    .NOTES
    Version:  1.0
    Ticket:   None
    Requires: PowerShell v4
    Creator:  Matthew Hellmer
    History:  Version...Date.........User.....................Comment
              v1.0      2017.02.28   Matthew.Hellmer          Initial Creation
              v1.1      2017.02.28   Matthew.Hellmer          Added section to update list of email objects
    .PARAMETER Folder
    The folder that is processed.
    .EXAMPLE
    PassesGitCheck -Folder "C:\Temp"
    C:\Temp is checked for changed files.
#>
    Param(
        [Parameter(Position=0, Mandatory=$true)]
        [System.IO.DirectoryInfo]
        $Folder
    )
    Process{
        # remove pending staged files
        git reset head --quiet

        # stage changed files
        $AddedFiles = @(git add * --verbose)

        # get index of current folder
        $emailObj   = $global:emailObjects | Where {$_.Folder -eq $folder.Name}
        $indexObj   = $global:emailObjects.IndexOf($emailObj)

        if($AddedFiles){
            # if any changed files were found
            git commit --message=$commitMessage --quiet
            Log -Object $Folder -CustomMessage "Committed $($AddedFiles.Count) file(s)." -Type Pass

            # Strip file name from string.
            $files = @()
            foreach($file in $AddedFiles){
                $file -match "add '(?<file>.*)'" | Out-Null
                $files += $matches['file']
            }

            # Grabs files that aren't log type
            $NonLogs = $files | Where-Object {($_ -notlike "*.log") -and ($_ -notlike "*.txt")}

            # Add information on files added.
            Add-Member -InputObject $global:emailObjects[$indexObj] -MemberType NoteProperty -Name AddedFiles      -Value $files
            Add-Member -InputObject $global:emailObjects[$indexObj] -MemberType NoteProperty -Name AddedFilesCount -Value $AddedFiles.Count
            Add-Member -InputObject $global:emailObjects[$indexObj] -MemberType NoteProperty -Name NonLogsCount    -Value $NonLogs.Count
        }
        else{
            # if none were found
            Log -Object $Folder -CustomMessage "No files added." -Type Info

            Add-Member -InputObject $global:emailObjects[$indexObj] -MemberType NoteProperty -Name AddedFiles      -Value $null
            Add-Member -InputObject $global:emailObjects[$indexObj] -MemberType NoteProperty -Name AddedFilesCount -Value 0
            Add-Member -InputObject $global:emailObjects[$indexObj] -MemberType NoteProperty -Name NonLogsCount    -Value 0
        }
    }
}


Function Main
{
    Begin{
        $folders     = @(Get-ChildItem -Path $searchPath -Directory)
        CollectInfo -Folders $folders
    }
    Process{
        $folderCur   = -1
        $folderCount = $folders.Count
        foreach($folder in $folders){
            # Build Progress Bar
            $folderCur++
            $folderI  = [Math]::Round($folderCur/$folderCount * 100, 2)
            Write-Progress -Activity "Commiting current Script Folder" -CurrentOperation $Folder.Name -Status "$folderI % Done" -PercentComplete $folderI -Id 1
        
            # Set current folder to working directory
            cd $folder.FullName

            # Check if already a git repository
            if(PassesGitCheck -Folder $folder){
                TryToAdd -Folder $folder
            }
            else{
                Log -Object $folder -CustomMessage "Not a git folder yet" -Type Warn
                MakeGit -Folder $folder
            }
        }
        Write-Progress -Activity "Commiting current Script Folder" -Status "Done" -Id 1 -Completed
    }
    End{
        #$global:emailObjects
        SendEmail -Recipient $global:NewRecipient -Subject $global:emailSubject -Message BuildEmailMessageHTML -Attachments @($ErrorLogPath) -HTML
        BuildEmailMessage
    }
}




########
# Main #
########
Main
WaitToExit -NoExit
