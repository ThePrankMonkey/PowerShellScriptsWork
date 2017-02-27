<#
    .SYNOPSIS
    This module holds commonly reused fucntions for Application Services scripts.
    .DESCRIPTION
    There are four functions held in this module that can be called on after importing it.
    CreateLogs  - Builds logpaths and global variables for them.
    Log         - Takes info that will be logged to the screen and a log file.
    SelfTest    - Can be used to test against known settings.
    WaitForExit - Can handle smoothly exiting the script.
    .NOTES
    Version:  1.0
    Ticket:   None
    Requires: PowerShell v4
    Creator:  Matthew Hellmer
    History:  Version...Date.........User.....................Comment
              v1.0      2017.02.16   Matthew.Hellmer          Initial Creation
#>

#Requires -Version 4

#############
# Variables #
#############
$global:ErrorList     = @()
$global:ErrorLogPath  = ""
$global:TimeStamp     = Get-Date -Format "yyyy.MM.ddTHH.mm.ss"
$global:PostObjects   =  @()
$global:PreObjects    =  @()
$global:GlobalArgs    = ""
$logPath              = ""
$domainServer         = "S01A-DC01"
$predesignatedFolder  = "C:\Temp"




####################
# Public Functions #
####################
Function CreateLogs
{
<#
    .SYNOPSIS
    Creates log folder and Error log file.
    .DESCRIPTION
    This function will force the creation of a folder either relative to the location the script was ran from, or in a pre-designated folder.
    Then the function will make a path where errors will be logged, and additional ones if called on again.
    .NOTES
    Version:  1.1
    Ticket:   None
    Requires: PowerShell v4
    Creator:  Matthew Hellmer
    History:  Version...Date.........User.....................Comment
              v1.0      2017.02.16   Matthew.Hellmer          Initial Creation
              v1.0      2017.02.23   Matthew.Hellmer          Supports making mulitple logs now.
    .PARAMETER Logs
    An array of logs to make paths for. Always includes Error
    .PARAMETER Ticket
    The ticket for the script.
    .PARAMETER Override
    This is a new path to 
    .PARAMETER Predesignated
    This is a switch as to whether or not the script defaults to the predesignated folder. Default is $false and attempts to store in relative folder.
    .EXAMPLE
    CreateLogs -Logs @("Extra", "FoundUsers") -Ticket "CHG0012345"
    Will create three log paths (Error, Extra, FoundUsers) that look like ???\CHG0012345_ErrorLog_2017.01.31T12.45.34.log
    This reassigns the automatic ???\ErrorLog_2017.01.31T12.45.34.log
#>
    Param(
        [Parameter(Position=0, Mandatory=$false)]
        [Array]
        $Logs = @(),
        [Parameter(Position=1, Mandatory=$false)]
        [String]
        $Ticket = $null,
        [Parameter(Position=2, Mandatory=$false)]
        [String]
        $Override = $null,
        [Switch]
        $Predesignated
    )
    Process{
        # Forces an Error log to be added to the list to make
        $Logs += "Error"

        # If a ticket is provided, this alters the text a little to make things look nicer.
        if($Ticket){
            $Ticket += "_"
        }

        # If the switch was triggered, the logpath will always be the predesignated one.
        if($Predesignated){
            $logPath = $predesignatedFolder
        }
        else{
            try{
                if($Override){
                    $logPath = Split-Path -Path $Override -Parent -ErrorAction Stop
                }
                else{
                    Write-Host 1, $script:MyInvocation.PSCommandPath.Path
                    Write-Host 2, $script:MyInvocation.PSCommandPath
                    Write-Host 3, $MyInvocation.PSCommandPath.Path
                    Write-Host 4, $MyInvocation.PSCommandPath
                    $logPath = Split-Path -Path $MyInvocation.PSCommandPath -Parent -ErrorAction Stop
                }
            }
            catch{
                $logPath = $predesignatedFolder
            }
        }

        # Builds logpath and make its folder
        $logPath = Join-Path -Path $logPath -ChildPath "Logs"
        if(!(Test-Path -Path $logPath)){
            New-Item -Path $logPath -ItemType Directory | Out-Null
        }

        # Make log paths and global variables for them.
        foreach($Log in $Logs){
            $VarName = "$($Log)LogPath"
            $LogName = "{0}{1}_{2}.log" -f $Ticket, $Log, $global:TimeStamp
            Set-Variable -Name $VarName -Scope Global -Value (Join-Path -Path $logPath -ChildPath $LogName)
        }
    }
}


Function Log
{
<#
    .SYNOPSIS
    Logs information to screen and file.
    .DESCRIPTION
    This handles all of the logging, whether to the screen or to status or error logs.
    .NOTES
    Version:  1.0
    Ticket:   None
    Requires: PowerShell v4
    Creator:  Matthew Hellmer
    History:  Version...Date.........User.....................Comment
              v1.0      2017.02.16   Matthew.Hellmer          Initial Creation
    .PARAMETER Object
    This is the object that triggered the error, and will default to an empty string if nor provided.
    .PARAMETER NewError
    This is the error that triggered.
    .PARAMETER CustomMessage
    This is a custom message detailing what caused the error.
    .PARAMETER Type
    This is the type of message: Info, Warn, Error, Pass, Fail
    .EXAMPLE
    Log -Object $user -NewError $_ -CustomMessage "User not found"
    Screen Output:
        Issue with Test.USer
            User not found
            Cannot find an object with identity: 'Test.User' under 'DC=s01,DC=com'
    Log Output
        Error log file gets various entried appended to it.
#>
    Param(
        [Parameter(Position=0, Mandatory=$false)]
        $Object = "",
        [Parameter(Position=1, Mandatory=$false)]
        [System.Management.Automation.ErrorRecord]
        $NewError = $null,
        [Parameter(Position=2, Mandatory=$true)]
        [String]
        $CustomMessage,
        [Parameter(Position=3, Mandatory=$false)]
        [ValidateSet("Info", "Warn", "Error", "Pass", "Fail")]
        [String]
        $Type = "Error"
    )
    Process{
        # Handle the passed object
        if($Object -ne $null){
            switch($Object.GetType().Name){
                "ADComputer"           {$ObjectName = $Object.SamAccountNAme; break;}
                "ADOrganizationalUnit" {$ObjectName = $Object.DistinguishedName; break;}
                "ADUser"               {$ObjectName = $Object.SamAccountName; break;}
                "DirectoryInfo"        {$ObjectName = $Object.Name; break;}
                "FileInfo     "        {$ObjectName = $Object.Name; break;}
                "String"               {$ObjectName = $Object; break;}
                default                {$ObjectName = $Object; break;}
            }
        }
        else{
            $ObjectName = "NullNullNull"
        }
        
        # Handle error types and their coloring
        switch($Type){
            "Info"  {$foreColor = "White";  $backColor = "Black"; break;}
            "Warn"  {$foreColor = "Yellow"; $backColor = "Black"; break;}
            "Error" {$foreColor = "Red";    $backColor = "Black"; break;}
            "Pass"  {$foreColor = "Green";  $backColor = "Blue";  break;}
            "Fail"  {$foreColor = "Red";    $backColor = "Blue";  break;}
            default {$foreColor = "White";  $backColor = "Blue";  break;}
        }

        # Build error components
        if($NewError -ne $null){
            $errorLocation = "$($NewError.InvocationInfo.ScriptLineNumber):$($NewError.InvocationInfo.OffsetInLine)"
            $errorMessage  = ($NewError.Exception.Message -split "`n") -join " "
            $errorType     = "[" + $NewError.Exception.GetType().FullName + "]"
        }
        else{
            $errorLocation = ""
            $errorMessage  = ""
            $errorType     = ""
        }
        $errorTime   = Get-Date -Format "yyyy.MM.ddTHH:mm:ss"
        $errorArray  = @($errorTime,$Type,$ObjectName,$CustomMessage,$errorType,$errorLocation,$errorMessage)
        $errorFormat = "{0,19} -- {1,-5} -- {2,20} -- {3}; {4}; {5}; {6}"
        $errorString = "$errorFormat" -f $errorArray
        
        # Handle error to screen
        #Write-Host "Issue with $ObjectName`n`t$CustomMessage`n`t$errorMessage" -ForegroundColor $foreColor -BackgroundColor $backColor
        Write-Host $errorString -ForegroundColor $foreColor -BackgroundColor $backColor

        # Handle error to log
        if(!(Test-Path -Path $global:ErrorLogPath)){
            "$errorFormat" -f "Time", "Type", "Object", "Custom Message", "Error Type", "Location", "Full Error Message" | Add-Content -Path $global:ErrorLogPath -Force
        }
        #$errorArray -join "`t" | Add-Content -Path $global:ErrorLogPath -Force
        $errorString | Add-Content -Path $global:ErrorLogPath -Force

        # Handle error list
        if($Type -eq "Error"){
            $errObj = New-Object -TypeName PSObject
            Add-Member -InputObject $errObj -MemberType NoteProperty -Name Time     -Value $errorTime
            Add-Member -InputObject $errObj -MemberType NoteProperty -Name Name     -Value $ObjectName
            Add-Member -InputObject $errObj -MemberType NoteProperty -Name Custom   -Value $CustomMessage
            Add-Member -InputObject $errObj -MemberType NoteProperty -Name Type     -Value $errorType
            Add-Member -InputObject $errObj -MemberType NoteProperty -Name Location -Value $errorLocation
            Add-Member -InputObject $errObj -MemberType NoteProperty -Name Message  -Value $errorMessage
            $global:ErrorList += $errObj
        }
    }
}


Function SelfTest
{
<#
    .SYNOPSIS
    Handles SelfTest data collection and summary when called on.
    .DESCRIPTION
    By calling before and after the amin function is ran, this script will collect setttings for test objects.
    These settings will be compared against expected values to see if pre and post test conditions match.
    Lastly, this function can be called on to provide a summary at the end of the script.
    .NOTES
    Version:  1.0
    Ticket:   None
    Requires: PowerShell v4
    Creator:  Matthew Hellmer
    History:  Version...Date.........User.....................Comment
              v1.0      2017.02.16   Matthew.Hellmer          Initial Creation
    .PARAMETER Type
    This is the type of scan that is being ran.
    "Pre"     is used to collect information before the main script is ran.
    "Post"    is used to collect information after the main script is ran.
    "Summary" is used to post a formatted summary of the pre and post self tests.
    .PARAMETER Objects
    The is a array of one or more objects that will be tested.
    .PARAMETER Expected
    This is a hash of expected values for the test. Keys will be used to look up properties for object.
    .EXAMPLE
    SelfTest -Type "Pre" -Objects @(Get-ADUser "Test.USer1", Get-ADUser "Test.User2") -Expected @{"Enable"=$true; "StreetAddress"="123 Fake St"}
#>
    Param(
        [Parameter(Position=0, Mandatory=$true)]
        [ValidateSet("Pre", "Post", "Summary")]
        [String]
        $Type,
        [Parameter(Position=1, Mandatory=$false)]
        [Array]
        $Objects,
        [Parameter(Position=2, Mandatory=$false)]
        [Hashtable]
        $Expected
    )
    Process{
        switch($Type){
            "Pre"{
                $global:PreObjects  = @(BuildTestObject -TestInObjects $Objects -Expected $Expected)
                break
            }
            "Post"{
                $global:PostObjects  = @(BuildTestObject -TestInObjects $Objects -Expected $Expected)
                break
            }
            "Summary"{
                # Reports a summary
                Write-Host "------------------------------------------------------------------------------"
                Write-Host "                                  Self Test                                   "
                Write-Host "------------------------------------------------------------------------------"
                Write-Host "Pre Checks"
                Colorize $global:PreObjects
                Write-Host "Post Checks"
                Colorize $global:PostObjects
                break
            }
        }
    }
}


Function WaitToExit
{
<#
    .SYNOPSIS
    Handles exits for the script.
    .DESCRIPTION
    Handles exiting, whether the script is ran via ISE or command line. Also allows for auto closing if "Service" is passed when the script runs.
    .NOTES
    Version:  1.0
    Ticket:   None
    Requires: PowerShell v4
    Creator:  Matthew Hellmer
    History:  Version...Date.........User.....................Comment
              v1.0      2017.02.16   Matthew.Hellmer          Initial Creation
#>
    Process{
        if($global:GlobalArgs -eq "Service"){
            exit
        }
        try{
            Write-Host "Press any key to exit..."
            $host.UI.RawUI.FlushInputBuffer()
            $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            exit
        }
        catch{
            Write-Host "Ignore the next message, pressing Enter will exit."
            Pause
            exit
        }
    }
}




####################
# Private Function #
####################
Function BuildTestObject{
<#
    .SYNOPSIS
    Private Function. Handles building the pre and post results for SelfTest data collection.
    .DESCRIPTION
    Private Function.
    Builds the array of collected results for pre or post SelftTest runs.
    .NOTES
    Version:  1.0
    Ticket:   None
    Requires: PowerShell v4
    Creator:  Matthew Hellmer
    History:  Version...Date.........User.....................Comment
              v1.0      2017.02.16   Matthew.Hellmer          Initial Creation
    .PARAMETER TestInObjects
    This is a list of objects to be scanned. It is passed on from SelfTest.
    .PARAMETER Expected
    This is a hash of expected values for the test. It is passed on from SelfTest.
    .EXAMPLE
    BuildTestObject -TestInObjects $Objects -Expected $Expcted
    This will make the lsit of SelfTest results.
#>
    Param(
        [Parameter(Position=0, Mandatory=$true)]
        [PSCustomObject]
        $TestInObjects,
        [Parameter(Position=1, Mandatory=$true)]
        [Hashtable]
        $Expected
    )
    Process{
        $TestOutObjects = @()
        # Loop through each object to grab info on.
        foreach($TestInObject in $TestInObjects){
            $command = "Get-$($TestInObject.GetType().Name) -Identity '$TestInObject' -Server $domainServer -Properties $($Expected.KEys -join ", ")"
            $TestObject = Invoke-Expression -Command $command
            
            # Build an object that holds the test results
            foreach($prop in $Expected.Keys){
                $TempObject     = New-Object -TypeName PSObject
                $TempObjectName = $TestInObject.Name
                $ExpectedValue  = $Expected[$prop]
                $NewValue       = ($TestObject | Select-Object -Property $prop).$prop
                Add-Member -InputObject $TempObject -MemberType NoteProperty -Name Check    -Value ($NewValue -eq $ExpectedValue)
                Add-Member -InputObject $TempObject -MemberType NoteProperty -Name Name     -Value $TempObjectName
                Add-Member -InputObject $TempObject -MemberType NoteProperty -Name Property -Value $prop
                Add-Member -InputObject $TempObject -MemberType NoteProperty -Name Expected -Value $ExpectedValue
                Add-Member -InputObject $TempObject -MemberType NoteProperty -Name Actual   -Value $NewValue
                $TestOutObjects += $TempObject
            }
        }
        return $TestOutObjects | Sort-Object -Property Property, Name
    }
}


Function Colorize{
<#
    .SYNOPSIS
    Private Function. Colors the output for SelfTest summary.
    .DESCRIPTION
    Private Function.
    This goes through each line of test results and colors it according to check results. False are red, True are green, Headings are blue.
    .NOTES
    Version:  1.0
    Ticket:   None
    Requires: PowerShell v4
    Creator:  Matthew Hellmer
    History:  Version...Date.........User.....................Comment
              v1.0      2017.02.16   Matthew.Hellmer          Initial Creation
    .PARAMETER InputObject
    This is the pre or post test results. It's passed on from SelfTest.
    .EXAMPLE
    Colorize $global:PreObjects
    Prints the results to the screen in color.
#>
    Param(
        [Parameter(Position=0, Mandatory=$true)]
        [PSCustomObject]
        $InputObject
    )
    Process{
        $lines = $InputObject | Format-Table -AutoSize | Out-String | ForEach-Object -Process {$_ -split "`n"}
        foreach($line in $lines){
            $color = "Blue"
            if($line -like " True*"){
                $color = "Green"
            }
            elseif($line -like "False*"){
                $color = "Red"
            }
            Write-Host "`t$line" -ForegroundColor $color
        }
    }
}




################
# Import Steps #
################
CreateLogs




#################
# Export Module #
#################
Export-ModuleMember -Function CreateLogs
Export-ModuleMember -Function Log
Export-ModuleMember -Function SelfTest
Export-ModuleMember -Function WaitToExit
Export-ModuleMember -Variable $global:ErrorList
Export-ModuleMember -Variable $global:ErrorLogPath
Export-ModuleMember -Variable $global:PostObjects
Export-ModuleMember -Variable $global:PreObjects
Export-ModuleMember -Variable $global:TimeStamp
Export-ModuleMember -Variable $logPath




#############
# Test Data #
#############
<#
Import-Module ActiveDirectory
Log -CustomMessage "Testing Info" -Type Info
try{
    $user = Get-ADUser -Identity "Fake.User" -Server $domainServer
}
catch{
    Log -NewError $_ -CustomMessage "Testing Error" -Type Error
}
$user1 = Get-ADUser -Identity "Norm.Test1" -Server $domainServer
$user2 = Get-ADUser -Identity "Norm.Test2" -Server $domainServer
$TestDataObjects  = @($user1, $user2)
$TestDataExpected = @{"Name"="Norm Test1"; "StreetAddress"="1000 Cha St"}
SelfTest -Type Pre  -Objects $TestDataObjects -Expected $TestDataExpected
SelfTest -Type Post -Objects $TestDataObjects -Expected $TestDataExpected
SelfTest -Type Summary
#>