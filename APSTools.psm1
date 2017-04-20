<#
    .SYNOPSIS
    This module holds commonly reused fucntions for Application Services scripts.
    .DESCRIPTION
    There are five functions held in this module that can be called on after importing it.
    CreateLogs       - Builds logpaths and global variables for them.
    GetExtendedProps - Grab the extended windows properties of for a file.
    Log              - Takes info that will be logged to the screen and a log file.
    OpenForMe        - Handles File/Folder selection dialog box.
    SelfTest         - Can be used to test against known settings.
    SendEmail        - Handles sending notification emails.
    WaitForExit      - Can handle smoothly exiting the script.
    .NOTES
    Version:  1.8
    Ticket:   None
    Requires: PowerShell v4
    Creator:  Matthew Hellmer
    History:  Version...Date.........User.....................Comment
              v1.0      2017.02.16   Matthew.Hellmer          Initial Creation
              v1.1      2017.02.23   Matthew.Hellmer          Updated CreateLogs (new parameter Override, fixed identified path to relative calling script)
              v1.2      2017.02.27   Matthew.Hellmer          Updated WaitToExit (new parameter NoExit). Updated Log (accepts File and Folder objects not).
              v1.3      2017.02.28   Matthew.Hellmer          Added SendEmail function.
              v1.4      2017.03.03   Matthew.Hellmer          Added OpenForMe function.
              v1.5      2017.03.07   Matthew.Hellmer          Updated OpenForMe (handles initial directory).
              v1.6      2017.03.14   Matthew.Hellmer          Added GetExtendedProps, Updated SendEmail (use alias for SMTP).
              v1.7      2017.03.17   Matthew.Hellmer          Updated GetExtendedProps (sorted output, added Range parameter).
              v1.8      2017.03.19   Matthew.Hellmer          Updated GetExtendedProps (added GetNums parameter).
              v1.9      2017.04.20   Matthew.Hellmer          Updated CreateLogs, OpenForMe. Added some variables.
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
$global:GPORepository       = "\\s01a-gitserver\GPORepository"
$global:LogRepository       = "\\s01a-gitserver\LogRepository"
$global:ScriptRepository    = "\\s01a-gitserver\ScriptRepository"
$global:TestingRepository   = "\\s01a-gitserver\TestingRepository"



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
    Version:  1.2
    Ticket:   None
    Requires: PowerShell v4
    Creator:  Matthew Hellmer
    History:  Version...Date.........User.....................Comment
              v1.0      2017.02.16   Matthew.Hellmer          Initial Creation
              v1.1      2017.02.23   Matthew.Hellmer          Supports making mulitple logs now.
              v1.2      2017.02.28   Matthew.Hellmer          Added a Override parameter. Fixed the identified folder to be relative to the calling script.
              v1.3      2017.04.20   Matthew.Hellmer          Changed default folder
    .PARAMETER Logs
    An array of logs to make paths for. Always includes Error
    .PARAMETER Ticket
    The ticket for the script.
    .PARAMETER Override
    This is a new path to override the log path with something other than the predesignated one.
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
                    $logPath = $Override
                }
                else{
                    $scriptFolder = Split-Path -Path $script:MyInvocation.PSCommandPath -Parent -ErrorAction Stop
                    $scriptStart = $scriptFolder.LastIndexOf("\")
                    $scriptEnd = $scriptFolder.Length - $scriptStart
                    $scriptParent = $scriptFolder.Substring($scriptStart, $scriptEnd)
                    $logPath = "$global:LogRepository$scriptParent"
                }
            }
            catch{
                $logPath = $predesignatedFolder
                Write-Host "Issue with assigning log path. Defaulting to: $logPath" -ForegroundColor Red
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


Function GetExtendedProps
{
<#
    .SYNOPSIS
    Get extended properties
    .DESCRIPTION
    This function will find all of the extended properties of the given object. These are the values you seen in Windows Explorer.
    .NOTES
    Version:  1.1
    Ticket:   None
    Requires: PowerShell v4
    Creator:  Matthew Hellmer
    History:  Version...Date.........User.....................Comment
              v1.0      2017.03.14   Matthew.Hellmer          Initial Creation
              v1.1      2017.03.15   Matthew.Hellmer          Added Range Parameter and ordered output
              v1.2      2017.03.19   Matthew.Hellmer          Added GetNums parameter
    .PARAMETER File
    This is a file that you want to get the Windows extended properties on.
    .PARAMETER Range
    This is an array of values between 0 and 287, and will default to that entire range. Be careful, as these numbers mean different things to different files.
    .PARAMETER GetNums
    This is a switch. It will output the same file as normal, except the values are the number for the oShell. Used for getting a list of numbers to use with Range.
    .EXAMPLE
    GetExtendedProps $file
    A custom object is returned and it has all of the extended properties of the file given.
#>
    Param(
        [Parameter(Position=0, Mandatory=$true)]
        [System.IO.FileInfo]
        $File,
        [Parameter(Position=1, Mandatory=$false)]
        [System.Array]
        $Range = @(0..287),
        [Parameter(Position=2, Mandatory=$false)]
        [Switch]
        $GetNums
    )
    Begin{
        # Makes a shell object that we need to access the extended properties.
        $oShell   = New-Object -ComObject Shell.Application
        $textInfo = (Get-Culture).TextInfo
    }
    Process{
        # Holds the gathered properties
        $props = @{}
        
        # Used to get the property names and values
        $oFolder = $oShell.Namespace($file.DirectoryName)
        $oItem = $oFolder.ParseName($file.Name)

        # Add all found values to a hash table
        ForEach($num in 0..287) {
            $ExtProp = $oFolder.GetDetailsOf($oFolder.Items, $num)
            if($GetNums){
                $ExtVal = $num
            }
            else{
                $ExtVal  = $oFolder.GetDetailsOf($oItem, $num)
            }
            if (-not $props.ContainsKey($ExtProp) -and ($ExtProp -ne ”")){
                # Strip funny characters
                $ExtProp2 = $TextInfo.ToTitleCase($ExtProp) -replace '[^a-zA-Z0-9]', ""
                if(-not $ExtProp2){
                    $ExtProp2 = $ExtProp
                }
                $props.Add($ExtProp2, $ExtVal)
            }
        }
        
        # Sort the values given
        $props = $props.GetEnumerator() | Sort Name
        
        # Rebuild the hash table with sorted values
        $props2 = [ordered]@{}
        foreach($prop in $props){
            $props2.Add($prop.Name, $prop.Value)
        }
        
        # Return the found properties and values
        return New-Object PSObject -Property $props2
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
              v1.1      2017.02.28   Matthew.Hellmer          Added Folders and Files to GetType switch.
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
                "FileInfo"             {$ObjectName = $Object.Name; break;}
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


Function OpenForMe
{
<#
    .SYNOPSIS
    Handles Open File and Folder Dialogues
    .DESCRIPTION
    Will produce a dialogue box that asks for files or folders, and capture an array of appropriate objects. If none are selected, it will return false.
    .NOTES
    Version:  1.1
    Ticket:   None
    Requires: PowerShell v4
    Creator:  Matthew Hellmer
    History:  Version...Date.........User.....................Comment
              v1.0      2017.03.03   Matthew.Hellmer          Initial Creation
              v1.1      2017.03.07   Matthew.Hellmer          Added InitialPath parameter. Defaults to folder that holds Error Logs.
              v1.2      2017.04.19   Matthew.Hellmer          Fixed handling Cancel.
              v1.3      2017.04.20   Matthew.Hellmer          Fixed window appearing behind issue.
    .PARAMETER Type
    This determines if the dialogue is for File or Folder.
    .PARAMETER Title
    This is the description on the popup.
    .PARAMETER Filter
    Submit an string for the filter to restrict File dialogue. Defaults to all. The format is a little tricky.
    Example "Pictures | *.png;*.jpg;*.gif|Logs | *.log"
    .PARAMETER InitialPath
    Takes a filepath to start the dialog in.
    .PARAMETER Multiple
    Switch for whether multiple files should be selected.
    .EXAMPLE
    OpenForMe -Type File -Title "Pick your Logs" -Filter "Pictures | *.png;*.jpg;*.gif|Logs | *.log"
    Opens a window for files that allows you to select all files or only the listed picture formats.
#>
    Param(
        [Parameter(Position=0, Mandatory=$true)]
        [ValidateSet("Folder", "File")]
        [String]
        $Type,
        [Parameter(Position=1, Mandatory=$false)]
        [String]
        $Title = "Please select your option.",
        [Parameter(Position=2, Mandatory=$false)]
        [String]
        $Filter = "All Files | *.*",
        [Parameter(Position=3, Mandatory=$false)]
        [String]
        $InitialPath = $null,
        [Switch]
        $Multiple
    )
    Begin{
        [Void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
        $StartPath = Split-Path $global:ErrorLogPath -Parent
        Add-Type -TypeDefinition @"
using System;
using System.Windows.Forms;
public class Win32Window : IWin32Window
{
    private IntPtr _hWnd;
    private int _data;

    public int Data
    {
        get { return _data; }
        set { _data = value; }
    }

    public Win32Window(IntPtr handle)
    {
        _hWnd = handle;
    }

    public IntPtr Handle
    {
        get { return _hWnd; }
    }
}
"@ -ReferencedAssemblies 'System.Windows.Forms.dll'
        $owner = New-Object Win32Window -ArgumentList ([System.Diagnostics.Process]::GetCurrentProcess().MainWindowHandle)
    }
    Process{
        if($InitialPath){
            $StartPath = $InitialPath
        }
        switch($Type){
            "Folder"{
                $OpenForMeObj = New-Object System.Windows.Forms.FolderBrowserDialog
                $OpenForMeObj.ShowNewFolderButton = $false
                $OpenForMeObj.Description = $Title
                $OpenForMeObj.SelectedPath = $StartPath
                $results = $OpenForMeObj.ShowDialog($owner) | Out-Null
                $selections = @($OpenForMeObj.SelectedPath)
            }
            "File"{
                $OpenForMeObj = New-Object System.Windows.Forms.OpenFileDialog
                $OpenForMeObj.initialDirectory = $StartPath
                $OpenForMeObj.Multiselect = $Multiple
                $OpenForMeObj.Title = $Title
                try{
                    $OpenForMeObj.Filter = $Filter
                }
                catch [System.Management.Automation.SetValueInvocationException]{
                    $OpenForMeObj.Filter = "All Files | *.*"
                    Log -NewError $_ -CustomMessage "Format for FileType Filter was wrong, defaulting to ALL. You provided: `"$Filter`"" -Type Error
                }
                catch{
                    $OpenForMeObj.Filter = "All Files | *.*"
                    Log -NewError $_ -CustomMessage "Unexpected error on OpenForMe-File." -Type Error
                }
                $results = $OpenForMeObj.ShowDialog($owner) | Out-Null
                $selections = @($OpenForMeObj.FileNames)
            }
        }

        if($results -eq "OK"){
            $Output = @()
            foreach($selection in $selections){
                $Output += Get-Item -Path $selection
            }
            return $Output
        }
        else{
            Log -CustomMessage "User did not select anything." -Type Info
            return $false
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


Function SendEmail
{
<#
    .SYNOPSIS
    Handles sending emails
    .DESCRIPTION
    This function will handle the creation and sending of an email. This allows just updating the APSTools module
    for changes in email settings.
    .NOTES
    Version:  1.1
    Ticket:   None
    Requires: PowerShell v4
    Creator:  Matthew Hellmer
    History:  Version...Date.........User.....................Comment
              v1.0      2017.02.27   Matthew.Hellmer          Initial Creation
              v1.1      2017.03.14   Matthew Hellmer          Changed default SMTP address to an alias.
    .PARAMETER Sender
    Automatically defaults to Notifications account, but can be overridden
    .PARAMETER Recipient
    Automatically defaults to SericeDesk account, but can be overridden
    .PARAMETER SMTP
    Automatically defaults to a standard exchange server, but can be overridden
    .PARAMETER Subject
    This is required, and will be the subject to the sent email.
    .PARAMETER Message
    This is required, and will be the body to the sent email.
    .PARAMETER Attachments
    If you want to include any attachments, include their filepaths in an array.
    .PARAMETER HTML
    Flip this flag if your message contains HTML.
    .EXAMPLE
    SendEmail -Subject "test" -Message "test1" -Attachments @($ErrorLogPath)
    An email is attempted to be sent from Notifications to ServiceDesk with the ErrorLog attached.
#>
    Param(
        [Parameter(Position=0, Mandatory=$false)]
        [String]
        $Sender = "Notifications@s01.smsuite.local",
        [Parameter(Position=1, Mandatory=$false)]
        [String]
        $Recipient = "ServiceDesk@s01.smsuite.local",
        [Parameter(Position=2, Mandatory=$false)]
        [String]
        $SMTP = "mail.s01.smsuite",
        [Parameter(Position=3, Mandatory=$true)]
        [String]
        $Subject,
        [Parameter(Position=4, Mandatory=$true)]
        [String]
        $Message,
        [Parameter(Position=5, Mandatory=$false)]
        [Array]
        $Attachments = @(),
        [Switch]
        $HTML
    )
    Begin{
        $fakeUser = "FakeUser"
        $fakePass = ConvertTo-SecureString "FakePass" -AsPlainText -Force
        $cred     = New-Object System.Management.Automation.PSCredential($fakeUser, $fakePass)
    }
    Process{
        $EmailParameters = @{
            'Body'       = $Message;
            'BodyAsHtml' = $HTML;
            'From'       = $Sender;
            'SmtpServer' = $SMTP;
            'Subject'    = $Subject;
            'To'         = $Recipient;
            'Cc'         = @($env:USERNAME,$env:USERDNSDOMAIN) -join "@";
            'Credential' = $cred;
            'DeliveryNotificationOption' = "OnSuccess, OnFailure"
        }
        if($Attachments.Count -gt 0){
            $EmailParameters['Attachments'] = $Attachments
        }
        try{
            Send-MailMessage @EmailParameters -ErrorAction Stop
        }
        catch{
            [System.GC]::Collect()
            Log -NewError $_ -CustomMessage "Error encountered while sending email" -Type Error
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
    Version:  1.1
    Ticket:   None
    Requires: PowerShell v4
    Creator:  Matthew Hellmer
    History:  Version...Date.........User.....................Comment
              v1.0      2017.02.16   Matthew.Hellmer          Initial Creation
              v1.1      2017.02.28   Matthew.Hellmer          NoExit switch added.
    .PARAMETER NoExit
    If called, the function won't actually exit. This is mostly for testing and debugging purposes.
#>
    Param(
        [Switch]
        $NoExit
    )
    Process{
        if(!($NoExit)){
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
Export-ModuleMember -Function GetExtendedProps
Export-ModuleMember -Function Log
Export-ModuleMember -Function OpenForMe
Export-ModuleMember -Function SelfTest
Export-ModuleMember -Function SendEmail
Export-ModuleMember -Function WaitToExit
Export-ModuleMember -Variable $global:ErrorList
Export-ModuleMember -Variable $global:ErrorLogPath
Export-ModuleMember -Variable $global:PostObjects
Export-ModuleMember -Variable $global:PreObjects
Export-ModuleMember -Variable $global:TimeStamp
Export-ModuleMember -Variable $logPath
Export-ModuleMember -Variable $global:GPORepository
Export-ModuleMember -Variable $global:LogRepository
Export-ModuleMember -Variable $global:ScriptRepository
Export-ModuleMember -Variable $global:TestingRepository



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
SendEmail -Subject "test" -Message "test1" -Attachments @($ErrorLogPath)
$file = Get-ChildItem -Path 'C:\Windows\System32\cmd.exe'
GetExtendedProps $file
#>
