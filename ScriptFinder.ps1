<#
    .SYNOPSIS
    This script finds other scripts
    .DESCRIPTION
    This script will find servers on your network and then scan those servers to see if any scripts or executables were placed on it.
    A CSV file of all of these found files will be produced.
    .NOTES
    Version:  1.0
    Ticket:   None
    Requires: PowerShell v4
    Creator:  Matthew Hellmer
    History:  Version...Date.........User.....................Comment
              v1.0      2017.03.14   Matthew.Hellmer          Initial Creation
#>

#Requires -Version 4
Import-Module "\APSTools.psm1" -Force -Verbose

#############
# Variables #
#############
$domainServer = "s01.test"
$company      = "ABC"
$timeStamp    = Get-Date -Format "yyyy.MM.dd.HHmmss"
$global:excludedFolder    = @("Program Files", "Program Files (x86)", "Windows")
$global:fileTypes         = @("*.dll", "*.exe", "*.hta", "*.ps1", "*.psm1", "*.vbs")
$global:foundFilesLogPath = "C:\Temp\FoundFilesLog_$timeStamp.txt"

#############
# Functions #
#############
Function BuildCSV
{
<#
    .SYNOPSIS
    Adds info to CSV
    .DESCRIPTION
    Takes the array of files given and builds a custom object with information for each file.
    This information is then appended to a CSV for late checking.
    .NOTES
    Version:  1.0
    Ticket:   None
    Requires: PowerShell v4
    Creator:  Matthew Hellmer
    History:  Version...Date.........User.....................Comment
              v1.0      2017.03.14   Matthew.Hellmer          Initial Creation
    .PARAMETER Server
    The server that the files reside on.
    .PARAMETER Files
    The array of collected and verified files.
    .EXAMPLE
#>
    Parm(
        [Parameter(Position=0, Mandatory=$true)]
        [ADComputer]
        $Server,
        [Parameter(Position=1, Mandatory=$true)]
        [System.Array]
        $Files
    )
    Process{
        foreach($file in $files){
            # grab values for CSV
            $path = $file.FullName -replace ":","$"
            $foundFileObj = New-Object -TypeName PSObject
            Add-Member -InputObject $foundFileObj -MemberType NoteProperty -Name Server -Value $Server.Name
            Add-Member -InputObject $foundFileObj -MemberType NoteProperty -Name Path   -Value $path
            Add-Member -InputObject $foundFileObj -MemberType NoteProperty -Name File   -Value $file.Name

            # Add to CSV
            $foundFileObj | Export-Csv -Path $global:foundFilesLogPath -Append -Force
        }
    }
}


Function CheckFiles
{
 <#
    .SYNOPSIS
    Checks if we made the file
    .DESCRIPTION
    We only care about a few EXEs and DLLs, and we marked them as being made by us.
    This function checks for that mark and dumps off any that were not made by us.
    .NOTES
    Version:  1.0
    Ticket:   None
    Requires: PowerShell v4
    Creator:  Matthew Hellmer
    History:  Version...Date.........User.....................Comment
              v1.0      2017.03.14   Matthew.Hellmer          Initial Creation
    .PARAMETER Files
    The array of files we are checking.
    .EXAMPLE
#>
   Param(
        [Parameter(Position=0, Mandatory=$true)]
        [System.Array]
        $Files
    )
    Process{
        $checkedFiles = @()
        foreach($file in $Files){
            if($file.Extension -eq ".exe" -or $file.Extension -eq ".dll"){
                $fileProps = GetExtendedProps -File $file
                if($fileProps.Company -eq $company){
                    # This is one of our .exe files
                    $checkedFiles += $file
                }
            }
            else{
                $checkedFiles += $file
            }
        }

        return $checkedFiles
    }
}


Function GetDrives
{
<#
    .SYNOPSIS
    Finds the network shares
    .DESCRIPTION
    Pulls out the assigned letters of the harddrives on the remote server scanned.
    .NOTES
    Version:  1.0
    Ticket:   None
    Requires: PowerShell v4
    Creator:  Matthew Hellmer
    History:  Version...Date.........User.....................Comment
              v1.0      2017.03.14   Matthew.Hellmer          Initial Creation
    .PARAMETER Server
    The remote server we are scanning.
    .EXAMPLE
#>
    Param(
        [Parameter(Position=0, Mandatory=$true)]
        [ADComputer]
        $Server
    )
    Process{
        # Get all of the drives on the provided server
        $drives = Get-WmiObject win32_logicaldisk -Computername $Server.Name
        
        # Filter out harddrives
        $drives = $drives | Where-Object {$_.DriveType -eq 3}

        # Get just the letters
        $driveLetters = @()
        foreach($drive in $drives){
            $driveLetters += $drive.DeviceID[0]
        }

        return $driveLetters
    }
}


Function GetFiles
{
<#
    .SYNOPSIS
    Finds files on remote server
    .DESCRIPTION
    This returns an array of files matching certain extensions (DLL, EXE, HTA, PS1, PSM1, VBS).
    All files matching this criteria on the remote server are returned.
    .NOTES
    Version:  1.0
    Ticket:   None
    Requires: PowerShell v4
    Creator:  Matthew Hellmer
    History:  Version...Date.........User.....................Comment
              v1.0      2017.03.14   Matthew.Hellmer          Initial Creation
    .PARAMETER Server
    The remote server currently being scanned.
    .PARAMETER Drive
    The drive on the current server currently being scanned.
    .EXAMPLE
#>
    Param(
        [Parameter(Position=0, Mandatory=$true)]
        [ADComputer]
        $Server,
        [Parameter(Position=1, Mandatory=$true)]
        [String]
        $Drive
    )
    Process{
        $filePath = "\\$($server.Name)\$drive`$\"
        $files    = Get-ChildItem -Path $filePath -Include $global:fileTypes -File
        $folders  = Get-ChildItem -Path $filePath -Directory

        # Drop folders that we don't want
        $folders = $folders | Where-Object {$_.Name -notin $global:excludedFolder}

        foreach($folder in $folders){
            $newFilePath = Join-Path -Path $filePath -ChildPath $folder.Name
            $files += Get-ChildItem -Path $newFilePath -Include $global:fileTypes -Recurse -File
        }

        return CheckFiles -Files $files
    }
}


Function Main
{
    Begin{
        Import-Module ActiveDirectory
        CreateLogs -Logs @("FoundFiles") -Ticket "CHG00XXXX" -

        $servers = Get-ADComputer -Filter "*" -Server $domainServer -Properties OperatingSystem
        $servers = $servers | Where-Object {$_.OperatingSystem -like "*Server*"}
    }
    Process{
        $curServer   = -1
        $countServer = $servers.Count
        foreach($server in $servers){
            $curServer++
            $iServer = [Math]::Round($curServer/$countServer * 100, 2)
            Write-Progress -Activity "Processing Current Server" -CurrentOperation $server.Name -Status "$iServer % Done" -PercentComplete $iServer -Id 1
            
            # Get network drives for current server
            $drives = GetDrives -Server $server

            $curDrive   = -1
            $countDrive = $drives.Count
            foreach($drive in $drives){
                $curDrive++
                $iDrive = [Math]::Round($curDrive/$countDrive * 100, 2)
                Write-Progress -Activity "Processing Current Drive" -CurrentOperation $drive -Status "$iDrive % Done" -PercentComplete $iDrive -Id 2 -ParentId 1

                # Get the files on the current drive
                $keptFiles = GetFiles -Server $server -Drive $drive

                # Log found files

            }
            Write-Progress -Activity "Processing Current Drive" -Status "All Done" -Id 2 -ParentId 1 -Completed
        }
        Write-Progress -Activity "Processing Current Server" -Status "All Done" -Id 1 -Completed
    }
}



########
# Main #
########
Main
