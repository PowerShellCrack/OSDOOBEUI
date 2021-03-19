<#
.SYNOPSIS
    A PowerShell Driven Single page UI.

.DESCRIPTION
   A PowerShell Driven Single page UI that looks and feels like Windows 10 OOBE. Used in SCCM/MDT TaskSequence Bare-metal deployments

.NOTES
    Author		: Dick Tracy II <richard.tracy@microsoft.com>
	Source		: https://github.com/PowerShellCrack/OSDOOBEUI
    Version		: 2.1.1
    #Requires -Version 3.0
    IMPORTANT: Review OOBEWPFUI.config for more details and confiugrations

.PARAMETER Config
    STRING. Used to identify configuration file;
    DEFAULT: to OOBEWPFUI.config

.EXAMPLE
    .\OSDOOBEUI_SinglePage.ps1

.EXAMPLE
    .\OSDOOBEUI_SinglePage.ps1 -Config OOBEWPFUI.contoso.config

.EXAMPLE
    ;Call in Task Sequence example
    Powershell -ExecutionPolicy Bypass -File %SCRIPTROOT%\Custom\OSDOOBEUI\OSDOOBEUI_SinglePage.ps1 -Config OSDOOBEUI.nmci.config

.LINK
    LTIHashCheckUI.ps1
#>
[Cmdletbinding()]
Param (
    [Parameter(Mandatory=$False)]
    [String]$Config
)

$VerbosePreference = 'SilentlyContinue'
$DebugPreference = 'SilentlyContinue'
#*=============================================
##* Runtime Function - REQUIRED
##*=============================================
#region FUNCTION: Check if running in WinPE
Function Test-WinPE{
    return Test-Path -Path Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlset\Control\MiniNT
}
#endregion

#region FUNCTION: Check if running in ISE
Function Test-IsISE {
    # try...catch accounts for:
    # Set-StrictMode -Version latest
    try {
        return ($null -ne $psISE);
    }
    catch {
        return $false;
    }
}
#endregion

#region FUNCTION: Check if running in Visual Studio Code
Function Test-VSCode{
    if($env:TERM_PROGRAM -eq 'vscode') {
        return $true;
    }
    Else{
        return $false;
    }
}
#endregion

#region FUNCTION: Find script path for either ISE or console
Function Get-ScriptPath {
    <#
        .SYNOPSIS
            Finds the current script path even in ISE or VSC
        .LINK
            Test-VSCode
            Test-IsISE
    #>
    param(
        [switch]$Parent
    )

    Begin{}
    Process{
        if ($PSScriptRoot -eq "")
        {
            if (Test-IsISE)
            {
                $ScriptPath = $psISE.CurrentFile.FullPath
            }
            elseif(Test-VSCode){
                $context = $psEditor.GetEditorContext()
                $ScriptPath = $context.CurrentFile.Path
            }Else{
                $ScriptPath = (Get-location).Path
            }
        }
        else
        {
            $ScriptPath = $PSCommandPath
        }
    }
    End{

        If($Parent){
            Split-Path $ScriptPath -Parent
        }Else{
            $ScriptPath
        }
    }

}
#endregion

# Make PowerShell Disappear in WINPE
If(Test-WinPE){
    $windowcode = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
    $asyncwindow = Add-Type -MemberDefinition $windowcode -name Win32ShowWindowAsync -namespace Win32Functions -PassThru
    $null = $asyncwindow::ShowWindowAsync((Get-Process -PID $pid).MainWindowHandle, 0)
}
##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VARIABLES: Building paths & values
# Use function to get paths because Powershell ISE & other editors have differnt results
[string]$scriptPath = Get-ScriptPath
[string]$scriptName = [IO.Path]::GetFileNameWithoutExtension($scriptPath)
[string]$scriptRoot = Split-Path -Path $scriptPath -Parent

#Get required folder & File paths
[string]$FunctionPath = Join-Path -Path $scriptRoot -ChildPath 'Functions'
[string]$ResourcePath = Join-Path -Path $scriptRoot -ChildPath 'Resources'
[string]$XAMLPath = Join-Path -Path $ResourcePath -ChildPath 'OOBEUIWPF_SinglePage.xaml'

#*=============================================
##* Additional Runtime Function - REQUIRED
##*=============================================
#Load functions from external files
. "$FunctionPath\Environments.ps1"
. "$FunctionPath\Logging.ps1"
. "$FunctionPath\Accounts.ps1"
. "$FunctionPath\PlatformInfo.ps1"
. "$FunctionPath\InterfaceDetails.ps1"
. "$FunctionPath\RegionLocale.ps1"
. "$FunctionPath\ComputerNameRules.ps1"
. "$FunctionPath\UIControls.ps1"
. "$FunctionPath\SetOSDVariables.ps1"

#Return log path (either in task sequence or temp dir)
#build log name
[string]$FileName = $scriptName +'.log'
#build global log fullpath
$Global:LogFilePath = Join-Path (Test-SMSTSENV -ReturnLogPath -Verbose) -ChildPath $FileName
Write-Host "logging to file: $LogFilePath" -ForegroundColor Cyan
#=======================================================
# PARSE CONFIG FILE
#=======================================================
#region CONFIG: & variables from configuration file

#if config specified, use that, otherwise use default
#TEST: $ConfigPath = 'OOBEUIWPF.nmci.config'
If($PSBoundParameters.ContainsKey('Config'))
{
    [string]$ConfigPath = $ConfigPath = $Config
    $ConfigLocation = 'Config Param'

}
#variable found in TaskSequence overwrite whats used from script
Elseif($tsenv:UIControl_ConfigFile)
{
    [string]$ConfigPath = $tsenv.Value("UIControl_ConfigFile")
    $ConfigLocation = 'TS Variable'
}
#otherwise use default
Else{
    [string]$ConfigPath = 'OSDOOBEUI.config'
    $ConfigLocation = 'Default location'
}
#resolve path to config
$ConfigResolvedFilePath = Resolve-ActualPath -FileName $ConfigPath -WorkingPath $scriptRoot -ErrorAction Stop
Write-LogEntry ("Grabbing Configurations [{0}] from [{1}]" -f $ConfigResolvedFilePath,$ConfigLocation) -Severity 1
[Xml.XmlDocument]$XmlConfigFile = Get-Content $ConfigResolvedFilePath -ErrorAction Stop

#  Parse config xml
[Xml.XmlElement]$xmlConfig = $xmlConfigFile.OOBEMenu_Configs
#  Get Config File Details
[Xml.XmlElement]$configDetails = $xmlConfig.Menu_Details
[string]$MenuTitle = [string]$configDetails.Detail_Title
[string]$MenuVersion = [string]$configDetails.Detail_Version
[string]$MenuDate = [string]$configDetails.Detail_Date

#parse changelog for version for a more accurate version
$ChangeLogPath = Resolve-ActualPath -FileName 'CHANGELOG.md' -WorkingPath $scriptRoot -ErrorAction SilentlyContinue
If($ChangeLogPath){
    $ChangeLog = Get-Content $ChangeLogPath
    $Changedetails = (($ChangeLog -match '##')[0].TrimStart('##') -split '-').Trim()
    [string]$MenuVersion = [version]$Changedetails[0]
    [string]$MenuDate = $Changedetails[1]
}

# Get Menu Options
[Xml.XmlElement]$xmlMenuOptions = $xmlConfig.Menu_Options
[string]$Logo1Position = Test-IsNull $xmlMenuOptions.Option_Logo1Position
[string]$Logo1file = Test-IsNull $xmlMenuOptions.Option_Logo1File
[string]$Logo2Position = Test-IsNull $xmlMenuOptions.Option_Logo2Position
[string]$Logo2file = Test-IsNull $xmlMenuOptions.Option_Logo2File
[string]$WPFVariable = $xmlMenuOptions.Option_FormVariable
[Boolean]$VerboseMode = [Boolean]::Parse($xmlMenuOptions.Option_VerboseMode)
[Boolean]$DebugMode = [Boolean]::Parse($xmlMenuOptions.Option_DebugMode)
[Boolean]$TestMode = [Boolean]::Parse($xmlMenuOptions.Option_TestMode)
[Boolean]$Global:HostOutput = [Boolean]::Parse($xmlMenuOptions.Option_HostOutput)
[string]$BackgroundColor = Test-IsNull $xmlMenuOptions.Option_BackgroundColor

# Get UI Controls
[Xml.XmlElement]$xmlUIControls = $xmlConfig.UI_Controls
[Boolean]$MenuOverWriteUIControlByTS = [Boolean]::Parse($xmlUIControls.Control_OverWriteUIControlByTS)
[Boolean]$MenuShowSplashScreen = [Boolean]::Parse($xmlUIControls.Control_ShowSplashScreen)
[Boolean]$MenuShowSiteCode = [Boolean]::Parse($xmlUIControls.Control_ShowSiteCode)
[Boolean]$MenuShowSiteListSelection = [Boolean]::Parse($xmlUIControls.Control_ShowSiteListSelection)
[Boolean]$MenuShowDomainOUSelection = [Boolean]::Parse($xmlUIControls.Control_ShowDomainOUListSelection)
[Boolean]$MenuEnableNetworkDetection = [Boolean]::Parse($xmlUIControls.Control_EnableNetworkDetection)
[Boolean]$MenuEnableValidateNameRules = [Boolean]::Parse($xmlUIControls.Control_ValidateNameRules)
[Boolean]$MenuAllowCustomDomain = [Boolean]::Parse($xmlUIControls.Control_AllowCustomDomain)
[Boolean]$MenuAllowWorkgroupJoin = [Boolean]::Parse($xmlUIControls.Control_AllowWorkgroupJoin)
[Boolean]$MenuAllowSiteSelection = [Boolean]::Parse($xmlUIControls.Control_AllowSiteSelection)
[Boolean]$MenuHideDomainCreds = [Boolean]::Parse($xmlUIControls.Control_HideDomainCreds)
[Boolean]$MenuHideDomainList = [Boolean]::Parse($xmlUIControls.Control_HideDomainList)
[string[]]$MenuAllowRuleBypassModeKey = $xmlUIControls.Control_AllowRuleBypassModeKey
[string]$MenuFilterAccountDomainType = $xmlUIControls.Control_FilterAccountDomainType
[string]$MenuFilterDomainProperty = $xmlUIControls.Control_FilterDomainProperty
[string]$MenuShowClassificationProperty = $xmlUIControls.Control_ShowClassificationProperty
[string]$MenuGenerateNameMethod = $xmlUIControls.Control_GenerateNameMethod
[string]$MenuGenerateNameSource = $xmlUIControls.Control_GenerateNameSource
#page Selection
[Xml.XmlElement]$xmlUIPages = $xmlConfig.UI_Pages

[Boolean]$MenuShowAppSelection = [Boolean]::Parse($xmlUIPages.Page_ShowAppSelection)

# Get UI Lists
If($null -ne $xmlConfig.Locale_Sites.ExternalList)
{
    #grab the first row for column definitions
    $MenuLocaleSiteColumns = $xmlConfig.Locale_Sites.site | Select -First 1

    #if CSV path is found, import it, otherwise unable to continue
    $ExternalCsv = Resolve-ActualPath -FileName $xmlConfig.Locale_Sites.ExternalList -WorkingPath $scriptRoot -ErrorAction Stop
    Write-LogEntry ("Grabbing External Site list from [{0}]" -f $ExternalCsv) -Severity 1
    $MenuLocaleSiteExternalList = Import-Csv $ExternalCsv -ErrorAction Stop
    #convert Site list to object
    $MenuLocaleSiteList = $MenuLocaleSiteExternalList | Select-Object -Property `
                @{name="ID"; expression={$_.($MenuLocaleSiteColumns | Select -ExpandProperty ID)}},
                @{name="BaseLocation"; expression={$_.($MenuLocaleSiteColumns | Select -ExpandProperty BaseLocation)}},
                @{name="TZ"; expression={$_.($MenuLocaleSiteColumns | Select -ExpandProperty TZ)}},
                @{name="Region"; expression={$_.($MenuLocaleSiteColumns | Select -ExpandProperty Region)}},
                @{name="SiteCode"; expression={$_.($MenuLocaleSiteColumns | Select -ExpandProperty SiteCode)}},
                @{name="Domain"; expression={$_.($MenuLocaleSiteColumns | Select -ExpandProperty Domain)}}
}
Else{
    $MenuLocaleSiteList = $xmlConfig.Locale_Sites.site
    $MenuLocaleSiteList = $MenuLocaleSiteList | Select ID,BaseLocation,TZ,Region,SiteCode,Domain
}

# Get Format for Site list
[string]$SiteListFormat = $xmlConfig.Locale_Sites.DisplayFormat
[string]$SiteCodeFormat = $xmlConfig.Locale_Sites.SiteCodeFormat
#build format based on config
If($MenuShowSiteCode -and $SiteCodeFormat){$DisplayFormat = ($SiteListFormat + $SiteCodeFormat) }Else{$DisplayFormat = $SiteListFormat}

$MenuLocaleClassificationList = $xmlConfig.Locale_Classifications.classification
$MenuLocaleDomainList = $xmlConfig.Locale_Domains.Domain
$MenuLocaleDomainOUList = $xmlConfig.Locale_DomainOUs.OU
$MenuLocaleNetworkList = $xmlConfig.Locale_NetworkDetection.network

#get App menu buttons
$MenuAppButtonsItems = $xmlConfig.Menu_AppButtons.item

#get Computer name standard
[Xml.XmlElement]$xmlNameGeneration = $xmlConfig.Name_Generation_Rules
$NameStandardRuleSets = $xmlNameGeneration.rulesets
$NameStandardRuleExampleText = $xmlNameGeneration.Example

#logo images
If($Logo1file){
    [string]$Logo1ImgPath = Join-Path -Path $ResourcePath -ChildPath $Logo1file
}
If($Logo2file){
    [string]$Logo2ImgPath = Join-Path -Path $ResourcePath -ChildPath $Logo2file
}
#endregion

#Overwrites config menu if running in TS and has variables found
If(Test-SMSTSENV -and $MenuOverWriteUIControlByTS){
    # Global Settings
    If($tsenv:Debug){
        [Boolean]$VerboseMode = [boolean]::Parse($tsenv.Value("Debug"))
        [Boolean]$DebugMode = [boolean]::Parse($tsenv.Value("Debug"))
    }
    If($tsenv:TSDebugMode){
        [Boolean]$VerboseMode = [boolean]::Parse($tsenv.Value("TSDebugMode"))
        [Boolean]$DebugMode = [boolean]::Parse($tsenv.Value("TSDebugMode"))
    }

    #controls
    If($tsenv:UIControl_MenuShowSplashScreen){[Boolean]$MenuShowSplashScreen = [boolean]::Parse($tsenv.Value("UIControl_MenuShowSplashScreen"))}
    If($tsenv:UIControl_ShowSiteCode){[Boolean]$MenuShowSiteCode = [boolean]::Parse($tsenv.Value("UIControl_ShowSiteCode"))}
    If($tsenv:UIControl_ShowSiteListSelection){[Boolean]$MenuShowSiteListSelection = [boolean]::Parse($tsenv.Value("UIControl_ShowSiteListSelection"))}
    If($tsenv:UIControl_ShowDomainOUListSelection){[Boolean]$MenuShowDomainOUSelection = [boolean]::Parse($tsenv.Value("UIControl_ShowDomainOUListSelection"))}
    If($tsenv:UIControl_EnableNetworkDetection){[Boolean]$MenuEnableNetworkDetection = [boolean]::Parse($tsenv.Value("UIControl_EnableNetworkDetection"))}
    If($tsenv:UIControl_ValidateNameRules){[Boolean]$MenuEnableValidateNameRules = [boolean]::Parse($tsenv.Value("UIControl_ValidateNameRules"))}
    If($tsenv:UIControl_AllowCustomDomain){[Boolean]$MenuAllowCustomDomain = [boolean]::Parse($tsenv.Value("UIControl_AllowCustomDomain"))}
    If($tsenv:UIControl_AllowWorkgroupJoin){[Boolean]$MenuAllowWorkgroupJoin = [boolean]::Parse($tsenv.Value("UIControl_AllowWorkgroupJoin"))}
    If($tsenv:UIControl_AllowSiteSelection){[Boolean]$MenuAllowSiteSelection = [boolean]::Parse($tsenv.Value("UIControl_AllowSiteSelection"))}
    If($tsenv:UIControl_AllowRuleBypassModeKey){[String[]]$MenuAllowRuleBypassModeKey = $tsenv.Value("Control_AllowRuleBypassModeKey")}
    If($tsenv:UIControl_FilterAccountDomainType){[string]$MenuFilterAccountDomainType = $tsenv.Value("UIControl_FilterAccountDomainType")}
    If($tsenv:UIControl_FilterDomainProperty){[string]$MenuFilterDomainProperty = $tsenv.Value("UIControl_FilterDomainProperty")}
    If($tsenv:UIControl_ShowClassificationProperty){[string]$MenuShowClassificationProperty = $tsenv.Value("UIControl_ShowClassificationProperty")}
    If($tsenv:UIControl_GenerateNameMethod){[string]$MenuGenerateNameMethod = $tsenv.Value("UIControl_GenerateNameMethod")}
    If($tsenv:UIControl_GenerateNameSource){[string]$MenuGenerateNameSource = $tsenv.Value("UIControl_GenerateNameSource")}

    #pages
    If($tsenv:UIPage_MenuShowAppSelection){[Boolean]$MenuShowAppSelection = [boolean]::Parse($tsenv.Value("UIPage_MenuShowAppSelection"))}
}

#=======================================================
# LOAD ASSEMBLIES
#=======================================================
[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')       | out-null #creating Windows-based applications
[System.Reflection.Assembly]::LoadWithPartialName('WindowsFormsIntegration')    | out-null # Call the EnableModelessKeyboardInterop; allows a Windows Forms control on a WPF page.
[System.Reflection.Assembly]::LoadWithPartialName('System.Windows')             | out-null #Encapsulates a Windows Presentation Foundation application.
[System.Reflection.Assembly]::LoadWithPartialName('System.ComponentModel')      | out-null #systems components and controls and convertors
[System.Reflection.Assembly]::LoadWithPartialName('System.Data')                | out-null #represent the ADO.NET architecture; allows multiple data sources
[System.Reflection.Assembly]::LoadWithPartialName('PresentationFramework')      | out-null #required for WPF
[System.Reflection.Assembly]::LoadWithPartialName('PresentationCore')           | out-null #required for WPF

#=======================================================
# Splash Screen
#=======================================================

# build a hash table with locale data to pass to runspace
$Global:SplashScreen = [hashtable]::Synchronized(@{})
$Global:SplashScreen.Title = $MenuTitle
$Global:SplashScreen.Logo1Position = $Logo1Position
$Global:SplashScreen.Logo1file = $Logo1ImgPath
$Global:SplashScreen.Logo2Position = $Logo2Position
$Global:SplashScreen.Logo2file = $Logo2ImgPath
$Global:SplashScreen.BGColor = $BackgroundColor
#build runspace
$Script:runspace = [runspacefactory]::CreateRunspace()
$Script:runspace.ApartmentState = "STA"
$Script:runspace.ThreadOptions = "ReuseThread"
$Script:runspace.Open()
$Script:runspace.SessionStateProxy.SetVariable("SplashScreen",$Global:SplashScreen)
$Script:Pwshell = [PowerShell]::Create()

#Create a scripblock with variables from hashtable
$Script:Pwshell.AddScript({
    [String]$MenuTitle = $Global:SplashScreen.Title
    [String]$Logo1Position = $Global:SplashScreen.Logo1Position
    [String]$Logo1File = $Global:SplashScreen.Logo1file
    [String]$Logo2Position = $Global:SplashScreen.Logo2Position
    [String]$Logo2File = $Global:SplashScreen.Logo2file
    [string]$BGColor = $Global:SplashScreen.BGColor
    $xml = @"
<Window x:Class="OOBEUI_ForTS.splashscreen"
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
    xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
    xmlns:local="clr-namespace:OOBEUI_ForTS"
    mc:Ignorable="d"
    WindowState="Maximized"
    WindowStartupLocation="CenterScreen"
    WindowStyle="None"
    Title="Splashscreen"
    Width="1024" Height="768"
    Background="#1f1f1f">
<Grid x:Name="background" Background="#004275" VerticalAlignment="Center">
    <Grid x:Name="ShowProgressBar" Visibility="Visible" HorizontalAlignment="Stretch" VerticalAlignment="Center" Height="180" Panel.ZIndex="20" >
        <Image x:Name="LogoImgLeft" HorizontalAlignment="Left" Margin="30,21,0,0" Width="100" Height="100" VerticalAlignment="Top" />
        <StackPanel Orientation="Vertical" Width="500" HorizontalAlignment="Center" VerticalAlignment="Center">
            <Label x:Name="LogoLabel" Foreground="White" Height="70" FontSize="50" Margin="5,0,0,0" />
            <ProgressBar x:Name="ProgressBar" Height="20" HorizontalAlignment="Stretch" Foreground="White" VerticalAlignment="Top" Margin="10,10,10,10"/>
            <Label x:Name="ProgressLabel" Content=" " Foreground="White" FontSize="16" Width="300" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="10,10,10,0"/>
        </StackPanel>
        <Image x:Name="LogoImgRight" HorizontalAlignment="Right" Margin="0,21,30,0" Width="100" Height="100" VerticalAlignment="Top" />
    </Grid>
</Grid>
</Window>
"@

    $SplashXml = $xml -replace 'mc:Ignorable="d"','' -replace "x:N",'N' -replace '^<Win.*', '<Window'
    If($Global:SplashScreen.BGColor){$SplashXml = $SplashXml -replace 'Background="#004275"', "Background=`"$BGColor`""}
    [xml]$XAML = $SplashXml
    $reader = New-Object System.Xml.XmlNodeReader ([xml]$XAML)
    $Global:SplashScreen.window = [Windows.Markup.XamlReader]::Load($reader)
    $Global:SplashScreen.ProgressBar = $Global:SplashScreen.window.FindName("ProgressBar")
    $Global:SplashScreen.ProgressLabel = $Global:SplashScreen.window.FindName("ProgressLabel")
    $Global:SplashScreen.LogoLabel = $Global:SplashScreen.window.FindName("LogoLabel")
    $Global:SplashScreen.LogoImgLeft = $Global:SplashScreen.window.FindName("LogoImgLeft")
    $Global:SplashScreen.LogoImgRight = $Global:SplashScreen.window.FindName("LogoImgRight")
    If( $Logo1File -and ( ($null -ne $Logo1Position) -or ($Logo1Position -ne 'hidden' )) ){
        If(Resolve-Path $Logo1File -ErrorAction SilentlyContinue)
        {
            switch($Logo1Position){
                'Left'  {
                            $LogoLeftVisible='Visible'
                            $Global:SplashScreen.LogoImgLeft.Source = $Logo1file
                        }
                'Right' {
                            $LogoRightVisible='Visible'
                            $Global:SplashScreen.LogoImgRight.Source = $Logo1file
                        }
                'Both'  {
                            $LogoLeftVisible='Visible'
                            $Global:SplashScreen.LogoImgLeft.Source = $Logo1file
                            $LogoRightVisible='Visible'
                            $Global:SplashScreen.LogoImgRight.Source = $Logo1file
                        }
                default {
                            $LogoLeftVisible='Visible'
                            If($Logo2Position -ne 'both'){$Global:SplashScreen.LogoImgLeft.Source = $Logo1file}
                        }
            }
        }
    }
    If($Logo2File -and ( ($null -ne $Logo2Position) -or ($Logo2Position -ne 'hidden' )) ){
        If(Resolve-Path $Logo2File -ErrorAction SilentlyContinue)
        {
            switch($Logo2Position){
                'Left'  {
                            $LogoLeftVisible='Visible'
                            $Global:SplashScreen.LogoImgLeft.Source = $Logo2file
                        }
                'Right' {
                            $LogoRightVisible='Visible'
                            $Global:SplashScreen.LogoImgRight.Source = $Logo2file
                        }
                'Both'  {
                            $LogoLeftVisible='Visible'
                            $Global:SplashScreen.LogoImgLeft.Source = $Logo2file
                            $LogoRightVisible='Visible'
                            $Global:SplashScreen.LogoImgRight.Source = $Logo2file
                        }
                default {
                            $LogoRightVisible='Visible'
                            If($Logo1Position -ne 'both'){$Global:SplashScreen.LogoImgRight.Source = $Logo2file}
                        }
            }
        }
    }
    $Global:SplashScreen.LogoImgLeft.Visibility = $LogoLeftVisible
    $Global:SplashScreen.LogoImgRight.Visibility = $LogoRightVisible

    $Global:SplashScreen.LogoLabel.Content = $MenuTitle
    #make sure this display on top of every window
    $Global:SplashScreen.window.Topmost = $true

    $Global:SplashScreen.window.ShowDialog()
    $Script:runspace.Close()
    $Script:runspace.Dispose()
    $Global:SplashScreen.Error = $Error
}) | Out-Null

#only run splash screen if enabled & testmode is disabled
If($MenuShowSplashScreen -and !$TestMode){
    Start-UISplashScreen
    Show-UISplashScreenProgress -Label ("Loading UI [ver {0}], please wait..." -f $MenuVersion) -Indeterminate
}

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#generate a random password
$script:RandomPassword = New-SWRandomPassword -MinPasswordLength 8 -MaxPasswordLength 12 -Count 1 -FirstChar 'abcdefghijkmnpqrstuvwxyzABCEFGHJKLMNPQRSTUVWXYZ'

Write-Verbose "Grabbing System properties Variables..."
$DeviceInfo = Get-PlatformInfo
$primaryinterface = Get-InterfaceDetails
$ComputerName = $DeviceInfo.computerName
$SerialNumber = $DeviceInfo.SerialNumber
$Make = $DeviceInfo.platformManufacturer
$Model = $DeviceInfo.platformModel
$MacAddress = $primaryinterface.MacAddress
$IpAddress = $primaryinterface.IPAddress
$AssetTag = $DeviceInfo.assettag
$script:PasswordValue = $script:RandomPassword


#verbose & debug settings
If($VerboseMode -or ($PSBoundParameters['Verbose']) ){$Global:VerbosePreference = 'Continue';$Global:VerboseEnabled=$True}Else{$Global:VerbosePreference = 'SilentlyContinue';$Global:VerboseEnabled=$False}
If($DebugMode -or ($PSBoundParameters['Debug'] )){$Global:DebugPreference = 'Continue';$Global:DebugEnabled=$True}Else{$Global:DebugPreference = 'SilentlyContinue';$Global:DebugEnabled=$False}
Write-LogEntry ("Verbose mode is set to: {0}" -f $VerboseEnabled.ToString()) -Severity 2
Write-LogEntry ("Debug mode is set to: {0}" -f $DebugEnabled.ToString()) -Severity 2
#===========================================================================
# XAML LANGUAGE
#===========================================================================
#region CODE: Initializes XAML language for UI
#Certain characters will need to be replaced to support XML format
$XAML = (get-content $XAMLPath -ReadCount 0) -replace 'mc:Ignorable="d"','' -replace "x:N",'N' -replace '^<Win.*', '<Window' -replace 'Click=".*','/>' -replace 'Demo',''
#replace background color if specified
If($BackgroundColor){$XAML = $XAML -replace 'Background="#004275"', "Background=`"$BackgroundColor`""}

#convert XAML to XML
[xml]$XAML = $XAML

$reader = New-Object System.Xml.XmlNodeReader ([xml]$XAML)
try{
    Write-LogEntry "Loading XAML file: $XAMLPath" -Severity 0
    $UI=[Windows.Markup.XamlReader]::Load($reader)
}
catch{
    If($MenuShowSplashScreen -and !$TestMode){Close-UISplashScreen}
    $ErrorMessage = $_.Exception.Message
    Write-Host "Unable to load Windows.Markup.XamlReader for $AppXAMLPath. Some possible causes for this problem include:
    - .NET Framework is missing
    - PowerShell must be launched with PowerShell -sta
    - invalid XAML code was encountered
    - The error message was [$ErrorMessage]" -ForegroundColor White -BackgroundColor Red
    Exit
}

# Store Form Objects In PowerShell
#===========================================================================
#take the xaml properties & make them variables
$xaml.SelectNodes("//*[@Name]") | %{Set-Variable -Name "$($WPFVariable)_$($_.Name)" -Value $UI.FindName($_.Name)}

$Global:AllFormVariables = Get-Variable $WPFVariable*

If($Global:DebugEnabled){
    Write-LogEntry "Displaying intractable elements from the form" -Severity 5
    $global:AllFormVariables
}
#endregion



#identify all items in XAML that are input fields.
$InputFields = @("inputCmbSiteList","inputCmbTimeZoneList","inputCmbDomainWorkgroupName","inputTxtDomainWorkgroupName","inputCmbDomainOU")
$ButtonFields = @("Begin","Next")
#===========================================================================
# DATA: Populate menu with the Data & looks
#===========================================================================
#populate Device info in fields
(WPFVar "txtAssetTag").Text = $AssetTag
(WPFVar "txtSerialNumber").Text = $SerialNumber
(WPFVar "txtManufacturer").Text = $Make
(WPFVar "txtModel").Text = $model
(WPFVar "txtMac").Text = $MacAddress
(WPFVar "txtIP").Text = $IpAddress

#show menu version if in verbose/debug mode
If($VerboseEnabled -or $DebugEnabled){(WPFVar "Version" -Wildcard) | Set-UIFieldElement -Text ('Build Version: ' + $MenuVersion + ' (' + $MenuDate + ')')}

#disable Begin Buttons until Validation is done
(WPFVar "Begin" -Wildcard) | Set-UIFieldElement -Enable:$false -ErrorAction SilentlyContinue

#hide log images to start
(WPFVar "ImgLogo" -Wildcard) | Set-UIFieldElement -Visible:$False

#resolve logo 1 and check position
If($Logo1ImgPath -and ( ($null -ne $Logo1Position) -or ($Logo1Position -ne 'hidden' ) ) )
{
    If(Resolve-Path $Logo1ImgPath -ErrorAction SilentlyContinue)
    {
        switch($Logo1Position){
            'Left'  {
                        (WPFVar "ImgLogoLeft" -Wildcard) | Set-UIFieldElement -Visible:$true -Source $Logo1ImgPath
                    }
            'Right' {
                        (WPFVar "ImgLogoRight" -Wildcard) | Set-UIFieldElement -Visible:$true -Source $Logo1ImgPath
                    }
            'Both'  {
                        (WPFVar "ImgLogo" -Wildcard) | Set-UIFieldElement -Visible:$true -Source $Logo1ImgPath
                    }
            default {
                        If($Logo2Position -ne 'both'){(WPFVar "ImgLogoLeft" -Wildcard) | Set-UIFieldElement -Visible:$true -Source $Logo1ImgPath}
                    }
        }
    }
}

#resolve logo 2 and check position
If($Logo2ImgPath -and ( ($null -ne $Logo2Position) -or ($Logo2Position -ne 'hidden' ) ) )
{
    If(Resolve-Path $Logo2ImgPath -ErrorAction SilentlyContinue)
    {
        switch($Logo2Position){
        'Left'  {
                    (WPFVar "ImgLogoLeft" -Wildcard) | Set-UIFieldElement -Visible:$true -Source $Logo2ImgPath
                }
        'Right' {
                    (WPFVar "ImgLogoRight" -Wildcard) | Set-UIFieldElement -Visible:$true -Source $Logo2ImgPath
                }
        'Both'  {
                    (WPFVar "ImgLogo" -Wildcard) | Set-UIFieldElement -Visible:$true -Source $Logo2ImgPath
                }
        default {
                    If($Logo1Position -ne 'both'){(WPFVar "ImgLogoRight" -Wildcard) | Set-UIFieldElement -Visible:$true -Source $Logo2ImgPath}
                }
        }
    }
}

#replace title
(WPFVar "Tab1MainTitle").Text = (WPFVar "Tab1MainTitle").Text -replace "@Title",$MenuTitle

#hide error screen
(WPFVar "txtError").Visibility = 'Hidden'

#on load make a default password field gray to demonstrate example
(WPFVar "inputTxtPassword").Foreground = 'LightGray'
(WPFVar "inputTxtPasswordConfirm").Foreground = 'LightGray'
(WPFVar "inputTxtPassword").Password = $script:PasswordValue
(WPFVar "inputTxtPasswordConfirm").Password = $script:PasswordValue

#fill in computername example
If($NameStandardRuleExampleText){
    #replace the xaml resource example with config's example
    (WPFVar "lblComputerNameExample").Content = '(eg. ' + $NameStandardRuleExampleText + ')'
}
Else{
    #If config has no example, use xaml reource file, but just grab the value
    $NameStandardRuleExampleText = ((WPFVar 'lblComputerNameExample').Content -replace "\(eg.|\)","").Trim()
}

#Get all timezones & populate it to combo box
If($MenuShowSplashScreen -and !$TestMode){Show-UISplashScreenProgress -Label ("Populating Time Zones...") -Indeterminate}
$AllTimeZones = Add-UITimeZoneList -TimeZoneField (WPFVar "inputCmbTimeZoneList") -ReturnList

If($MenuEnableValidateNameRules){
    #Change to first sub tab
    Switch-TabItem -TabControlObject (WPFVar "subtabControl") -increment 1
    #Set the fields to disable until name is validated
    Get-UIFieldElement -Name $InputFields | Set-UIFieldElement -Enable:$false -ErrorAction SilentlyContinue
    Get-UIFieldElement -Name $ButtonFields | Set-UIFieldElement -Enable:$false -ErrorAction SilentlyContinue
}
Else{
    #hide validation section if not enabled
    (WPFVar "btnTab1Validate").Visibility = 'Hidden'
    (WPFVar "subtab2").Visibility = 'Hidden'
    #make sure all field are enabled
    Get-UIFieldElement -Name $InputFields | Set-UIFieldElement -Enable:$true -ErrorAction SilentlyContinue
    Get-UIFieldElement -Name $ButtonFields | Set-UIFieldElement -Enable:$true -ErrorAction SilentlyContinue
}

#Hide if OU selection if not enabled
If(!$MenuShowDomainOUSelection){Get-UIFieldElement -Name "DomainOU"  | Set-UIFieldElement -Visible:$false}

#switch domain field from combobox to textbox
If($MenuAllowCustomDomain -or $MenuLocaleDomainList.count -eq 0)
{
    #hide dropdown & enable textbox
    ConvertTo-UITextBox -Combobox (WPFVar "inputCmbDomainWorkgroupName")
}
Else
{
    #hide textbox & enable dropdown
    ConvertTo-UIComboBox -Textbox (WPFVar "inputTxtDomainWorkgroupName")

    #pre-populate all domain FQDN in dropdown
    If($MenuShowSplashScreen -and !$TestMode){Show-UISplashScreenProgress -Label ("Populating Domains...") -Indeterminate}
    Add-UIDomainNameList -DomainList $MenuLocaleDomainList.FQDN -DomainNameField (WPFVar "inputCmbDomainWorkgroupName") -TypeFilter $MenuFilterAccountDomainType

    #Add workgroup is allowed
    If($MenuAllowWorkgroupJoin){(WPFVar "inputCmbDomainWorkgroupName").Items.Add('Workgroup') | Out-Null}
}

#check if show classification section is used & display it
#this will hide the site code section
If( ($MenuShowClassificationProperty -eq 'None') -or ([string]::IsNullOrEmpty($MenuShowClassificationProperty)) ){
    Get-UIFieldElement -Name "grdClassification" | Set-UIFieldElement -Visible:$false -ErrorAction SilentlyContinue
}
Else{
    Get-UIFieldElement -Name "grdClassification" | Set-UIFieldElement -Visible:$true -ErrorAction SilentlyContinue
    Get-UIFieldElement -Name "grdSiteCode" | Set-UIFieldElement -Visible:$false -ErrorAction SilentlyContinue
}

#check if site code section is used & display it
#this will hide the classification section
If($MenuShowSiteCode){
    Get-UIFieldElement -Name "grdClassification" | Set-UIFieldElement -Visible:$false -ErrorAction SilentlyContinue
    Get-UIFieldElement -Name "grdSiteCode" | Set-UIFieldElement -Visible:$true -ErrorAction SilentlyContinue
}
Else{
    Get-UIFieldElement -Name "grdSiteCode" | Set-UIFieldElement -Visible:$false -ErrorAction SilentlyContinue
}


#control app section
If($MenuShowAppSelection)
{
    #hide all default apps for initial set
    Get-UIFieldElement -Name "tglAppInstall" | Set-UIFieldElement -Visible:$False

    #Add apps selection from config
    Add-AppContent -AppData $MenuAppButtonsItems

    $ActiveBeginBtn = Enable-AppTab -FlipButtons -ReturnActiveBtn
}
Else{
    $ActiveBeginBtn = Disable-AppTab -FlipButtons -ReturnActiveBtn
}



#Populate site list
If($MenuShowSiteListSelection -and $MenuLocaleSiteList.count -gt 0)
{
    If($MenuShowSplashScreen -and !$TestMode){Show-UISplashScreenProgress -Label ("Populating Sites from list...") -Indeterminate}
    Add-UISiteList -SiteList $MenuLocaleSiteList -SiteListField (WPFVar "inputCmbSiteList") -DisplayFormat $DisplayFormat

    #be sure to show the menu
    (WPFVar "SiteList" -Wildcard) | Set-UIFieldElement -Visible:$MenuShowSiteListSelection
}
Else
{
    (WPFVar "SiteList" -Wildcard) | Set-UIFieldElement -Visible:$false

    #move timezone up
    (WPFVar "lblTimeZoneList").Margin = "160,212,0,0"
    (WPFVar "inputCmbTimeZoneList").Margin = "160,243,0,0"
}


#When enabled, Network detection can only be used if there are values in the list & Site List is enabled
If($MenuEnableNetworkDetection -and ($MenuLocaleNetworkList.count -gt 0) -and $MenuShowSiteListSelection){
    #detemine if value in config matches the network the device it on
    Foreach($network in $MenuLocaleNetworkList){
        If($network.CidrAddr -eq $primaryinterface.CidrID){
            #updates the locale fields
            $SelectedLocaleFields = Update-UILocaleFields -SiteList $MenuLocaleSiteList -SiteID $network.SiteId `
                                            -UpdateSiteListObject (WPFVar "inputCmbSiteList") `
                                            -UpdateTimeZoneObject (WPFVar "inputCmbTimeZoneList") `
                                            -UpdateSiteCodeObject (WPFVar "txtSiteCode") `
                                            -UpdateDomainObject (WPFVar "inputCmbDomainWorkgroupName") -ReturnProperties
        }
    }
}

#Generate Computer name based on config control
switch -Wildcard ($MenuGenerateNameMethod){
    'ODJ*' {
        If($MenuShowSplashScreen -and !$TestMode){Show-UISplashScreenProgress -Label ("Searching Offline Domain Join (ODJ) File...") -Indeterminate}
        $ODJNetworkPath = $MenuGenerateNameSource
        $DeviceODJs = Get-ChildItem $ODJNetworkPath -Filter "*.odj" -Recurse
        If($Null -ne $DeviceODJs){
            #build the name to look for:
            #Must be named: <assettag>_<serialnumber>_<computername>.odj
            $FileName = ($AssetTag + '_' + $SerialNumber + '_')
            $DeviceODJ = $DeviceODJs | Where {$_.BaseName -like "$FileName*"}
            If($DeviceODJ)
            {
                IIf($MenuShowSplashScreen -and !$TestMode){Show-UISplashScreenProgress -Label ("Found ODJ File, populating device details...") -Indeterminate}
                #split file into sections to determine variables
                $ODJAssetTag = ($DeviceODJ.BaseName).Split("_")[0]
                $ODJSerialNumber = ($DeviceODJ.BaseName).Split("_")[1]
                $ComputerName = ($DeviceODJ.BaseName).Split("_")[2]
                Write-LogEntry ("Found a ODJ file that matches assest tag [{0}] and serial number [{1}]" -f $ODJAssetTag,$ODJSerialNumber) -Severity 0

                #detemine if content exist in blob (could be blank file)
                $ODJBlobData = Get-Content ($DeviceODJ.FullName)

                If([string]::IsNullOrEmpty($ODJBlobData))
                {
                    (WPFVar "grdDomainSection").Visibility = 'Visible'
                    Write-LogEntry ("ODJ file is empty, domain credentials are still required! Auto naming device [{0}] " -f $ComputerName) -Severity 2
                }
                Else{
                    (WPFVar "grdDomainSection").Visibility = 'Hidden'
                    (WPFVar "lblComputerNameExample").Visibility = 'Hidden'
                    (WPFVar "lblComputerNameQuestion").Content = "Device Name has been generated, Please validate before continuing."
                    Set-UIFieldElement -FieldName @("inputTxtComputerName","inputCmbSiteList") -Enable:$false
                }
            }
            Else{
                Write-LogEntry ("Unable to find a ODJ file that matches assest tag and serial number") -Severity 3
                $MenuGenerateNameMethod = $null
                $ComputerName = $null
                (WPFVar "grdDomainSection").Visibility = 'Visible'
            }

        }
        Else{
            Write-LogEntry ("Unable to access network share [{0}] to retrieve ODJ file" -f $MenuGenerateNameSource) -Severity 3
            $MenuGenerateNameMethod = $null
            $ComputerName = $null
        }
    }
    'AD' {
        $ADLDAP = $MenuGenerateNameSource
        #Add function to Identify all AD objects & compare with name
        }
    'SQL'{
        $SQLConn = $MenuGenerateNameSource
        #Add function to Query SQL for name (prepopulated)
        }
    'Locale' {
        $LocalDB = $MenuGenerateNameSource
        #Add function to Randomizes computer name, name can be controlled using networkdetection locale & rules
        }

    'TSEnv' {
            If(Test-SMSTSENV){
                $ComputerName = Update-OSDComputerName -Current $tsenv.Value("OSDCOMPUTERNAME")
                If($Null -eq $ComputerName){
                    $ComputerName = Update-OSDComputerName -Current $tsenv.Value("_SMSTSMachineName")
                }
            }
            Else{
                $ComputerName = Update-OSDComputerName -Current $DeviceInfo.computerName
            }
        }

    'Clear' {
        #null out name
        $ComputerName = $null
    }

    default {
            #Do nothing
        }
}

#fill in computername
(WPFVar "inputTxtComputerName").Text = $ComputerName

#Hide entire areas if set to true
If($MenuHideDomainList -and $MenuHideDomainCreds){
    (WPFVar "grdDomainSection" -Wildcard) | Set-UIFieldElement -Visible:$false
}
Else{
    #Hide domain list and OU areas if set to true
    If($MenuHideDomainList){
        (WPFVar "DomainWorkgroup" -Wildcard) | Set-UIFieldElement -Visible:$false
        (WPFVar "DomainOU" -Wildcard) | Set-UIFieldElement -Visible:$false
    }
    #Hide credential areas if set to true
    If($MenuHideDomainCreds){
        (WPFVar "DomainCreds" -Wildcard) | Set-UIFieldElement -Visible:$false
        (WPFVar "DomainAccount" -Wildcard) | Set-UIFieldElement -Visible:$false
        (WPFVar "DomainAdmin" -Wildcard) | Set-UIFieldElement -Visible:$false
        (WPFVar "Password" -Wildcard) | Set-UIFieldElement -Visible:$false
    }
}
#====================================
# CHANGE EVENTS
#====================================

#Textbox placeholder remove default text when textbox is being used
(WPFVar "inputTxtComputerName").Add_GotFocus({
    #if it has an example
    if ((WPFVar "inputTxtComputerName").Text -eq $NameStandardRuleExampleText) {
        #clear value and make it black bold ready for input
        (WPFVar "inputTxtComputerName").Text = ''
        (WPFVar "inputTxtComputerName").Foreground = 'Black'
        (WPFVar "inputTxtComputerName").FontWeight = 'Medium'
        #should be black while typing....
    }
    #if it does not have an example
    Else{
        #ensure test is black and medium
        (WPFVar "inputTxtComputerName").Foreground = 'Black'
        (WPFVar "inputTxtComputerName").FontWeight = 'Medium'
    }
})

#Textbox placeholder grayed out text when textbox empty and not in being used
(WPFVar "inputTxtComputerName").Add_LostFocus({
    #if text is null (after it has been clicked on which cleared by the Gotfocus event)
    if ((WPFVar "inputTxtComputerName").Text -eq '') {
        #add example back in light gray font
        (WPFVar "inputTxtComputerName").Foreground = 'LightGray'
        (WPFVar "inputTxtComputerName").FontWeight = 'Light'
        (WPFVar "inputTxtComputerName").Text = $NameStandardRuleExampleText
    }
})

#Textbox placeholder remove default text when textbox is being used
(WPFVar "inputTxtDomainAdminLocalAccount").Add_GotFocus({
    If((WPFVar "inputTxtPassword").Password -eq $script:PasswordValue){
        (WPFVar "inputTxtPassword").Password = ''
    }
    If((WPFVar "inputTxtPasswordConfirm").Password -eq $script:PasswordValue){
        (WPFVar "inputTxtPasswordConfirm").Password = ''
    }
})

#After typing in user account, make password fiels black text
(WPFVar "inputTxtPassword").Add_LostFocus({
    If((WPFVar "inputTxtPassword").Password -eq $script:PasswordValue){
        (WPFVar "inputTxtPassword").Password = ''
    }
    If((WPFVar "inputTxtPasswordConfirm").Password -eq $script:PasswordValue){
        (WPFVar "inputTxtPasswordConfirm").Password = ''
    }
})

#After typing in user account, make password fiels black text
(WPFVar "inputTxtPasswordConfirm").Add_LostFocus({
    If((WPFVar "inputTxtPassword").Password -eq $script:PasswordValue){
        (WPFVar "inputTxtPassword").Password = ''
    }
    If((WPFVar "inputTxtPasswordConfirm").Password -eq $script:PasswordValue){
        (WPFVar "inputTxtPasswordConfirm").Password = ''
    }
})

#After typing in user account, make password fiels black text
(WPFVar "inputTxtDomainAdminLocalAccount").Add_LostFocus({
    (WPFVar "inputTxtPassword").Foreground = 'Black'
    (WPFVar "inputTxtPasswordConfirm").Foreground = 'Black'
})


#reset computer name details
#$CurrentLocaleDetails = $null

#handle the selection change
(WPFVar "inputCmbSiteList").Add_SelectionChanged({

    #Grab computer name details to populate character position to update the site id in the computer name ONLY if a new site is selected.
    $CurrentLocaleDetails = Get-ComputerNameLocale -SiteList $MenuLocaleSiteList -ComputerNameObject (WPFVar "inputTxtComputerName") -ReturnDetails

    #update computername. Start position is null at first.
    $SiteInfo = Update-ComputerNameLocale -SiteList $MenuLocaleSiteList `
                                        -SiteLocale (WPFVar "inputCmbSiteList").SelectedItem `
                                        -StartPosition $CurrentLocaleDetails.CharPosition `
                                        -UpdateComputeName:$MenuEnableValidateNameRules -ReturnSiteInfo

    #get current site list where the name matches
    $SelectedLocaleFields = Update-UILocaleFields -SiteList $MenuLocaleSiteList -SiteID $SiteInfo.SiteID `
                                            -UpdateSiteListObject (WPFVar "inputCmbSiteList") `
                                            -UpdateTimeZoneObject (WPFVar "inputCmbTimeZoneList") `
                                            -UpdateSiteCodeObject (WPFVar "txtSiteCode") `
                                            -UpdateDomainObject (WPFVar "inputCmbDomainWorkgroupName") -ReturnProperties

    Write-LogEntry ("Changed Locale TimeZone to: {0}" -f $SelectedLocaleFields.TimeZoneOSDName) -Severity 1

    #Grab computer name details to populate character position to update the site id in the computer name ONLY if a new site is selected.
    #$NewLocaleDetails = Get-ComputerNameLocale -SiteList $MenuLocaleSiteList -ComputerNameObject (WPFVar "inputTxtComputerName") -ReturnDetails
})


#Grab the text value if cursor is in field
$script:FocusedComputerName = $null
$script:FirstTimeBootup = $true
(WPFVar "inputTxtComputerName").AddHandler(
    [System.Windows.Controls.Primitives.TextBoxBase]::GotFocusEvent,
    [System.Windows.RoutedEventHandler]{
        #set a variable if there is text in field BEFORE the new name is typed
        If((WPFVar "inputTxtComputerName").Text){
            $script:FocusedComputerName = (WPFVar "inputTxtComputerName").Text
        }
    }
)

#Grab the text value when cursor leaves (AFTER Typed)
(WPFVar "inputTxtComputerName").AddHandler(
    [System.Windows.Controls.Primitives.TextBoxBase]::LostFocusEvent,
    [System.Windows.RoutedEventHandler]{
        #because there is a example text field in the box by default, check for that
        If((WPFVar "inputTxtComputerName").Text -eq (WPFVar 'lblComputerNameExample').Content){
            If($MenuEnableValidateNameRules){
                Invoke-UIMessage -Message "Enter a device name and validate to continue" -HighlightObject (WPFVar "inputTxtComputerName") -OutputErrorObject (WPFVar "txtError") -Type Info
                Get-UIFieldElement -Name $ButtonFields | Set-UIFieldElement -Enable:$false -ErrorAction SilentlyContinue
            }
        }
        #check if the BEFORE type value is different than the AFTER typed
        ElseIf($script:FocusedComputerName -ne (WPFVar "inputTxtComputerName").Text){
            #for the first time, don't display a message, but show message after all others
            If($script:FirstTimeBootup){
                $script:FirstTimeBootup = $false
            }
            Else{
                If($MenuEnableValidateNameRules){
                    Invoke-UIMessage -Message "Detected device name change, press validate to continue" -HighlightObject (WPFVar "inputTxtComputerName") -OutputErrorObject (WPFVar "txtError") -Type Warning
                    Get-UIFieldElement -Name $ButtonFields | Set-UIFieldElement -Enable:$false -ErrorAction SilentlyContinue
                }
            }
        }

    }
)

#Event handler trigger when cursor is moved away from inpute domain account, ensure only one slash exists
#This helps with single threaded UI
(WPFVar "inputTxtDomainAdminLocalAccount").AddHandler(
    [System.Windows.Controls.Primitives.TextBoxBase]::LostFocusEvent,
    [System.Windows.RoutedEventHandler]{
        $countSlashes = [Regex]::Matches((WPFVar "inputTxtDomainAdminLocalAccount").text, "\\").Count
        If($countSlashes -gt 1){
            (WPFVar "inputTxtDomainAdminLocalAccount").text -replace '\\{2,}','\'
        }
    }
)

#make sure domain name textbox synced with dropdown selection
#this allows for Set-OSDDomainvariables or Set-OSDWorkgroupVariables to be updated without code to support dropdown object
(WPFVar "inputCmbDomainWorkgroupName").Add_SelectionChanged({

    If($MenuHideDomainList -eq $false)
    {
        #populate domain name for Domain account based on selection
        If((WPFVar "inputCmbDomainWorkgroupName").SelectedItem -ne 'Workgroup')
        {
            #If OU enabled Populate Domain OU list. Move domain name field up to make room
            If($MenuShowDomainOUSelection -and $MenuLocaleDomainOUList.count -gt 0)
            {
                (WPFVar "DomainOU" -Wildcard) | Set-UIFieldElement -Visible:$true
            }
            Else
            {
                #move Domain join down & hide Domain OU
                (WPFVar "DomainOU" -Wildcard) | Set-UIFieldElement -Visible:$false
            }
    
            #change label & account description (this ensures if workgroup is selected then changed back to domain, the values change back)
            (WPFVar "lblDomainCredsInstruction").Content = 'You must provide credentials with permissions to join the domain'
            (WPFVar "lblDomainCredsExample").Content = '(eg. domain\first.last.adm)'
            (WPFVar "lblDomainAccountWorkgroupName").Content = 'Domain Account'
    
            #grab current value & just replace the domain value before
            $CurrentDomainAndAccount = (WPFVar "inputTxtDomainAdminLocalAccount").text
            $CurrentDomain = $CurrentDomainAndAccount.split('\')[0]
            $CurrentUser = $CurrentDomainAndAccount.split('\')[1]
    
            #grab Domain Name from config list based on FQDN
            If($MenuFilterAccountDomainType){
                $SelectedClassid = ($MenuLocaleDomainList | Where FQDN -eq (WPFVar "inputCmbDomainWorkgroupName").SelectedItem).ClassId
                #if multiple types exist for same classification, be sure to just select one
                $SelectFirstDomain = ($MenuLocaleDomainList | Where {($_.ClassId -eq $SelectedClassid) -and ($_.Type -eq $MenuFilterAccountDomainType)}).Name | Select -First 1
            }
            Else{
                #select domain name from FQDN
                $SelectFirstDomain = ($MenuLocaleDomainList | Where FQDN -eq (WPFVar "inputCmbDomainWorkgroupName").SelectedItem).Name
            }
    
            #if new domain is selected replace account domain
            If($SelectFirstDomain){
                $SelectedDomainName = $SelectFirstDomain + '\' + $CurrentUser
            }
            ElseIf($Null -ne (WPFVar "inputCmbDomainWorkgroupName").SelectedItem){
                $SelectedDomainName = (WPFVar "inputCmbDomainWorkgroupName").SelectedItem  + '\' + $CurrentUser
            }
            Else{
                $SelectedDomainName = $CurrentDomain + '\' + $CurrentUser
            }
    
            #replace domain with new domain for creds
            (WPFVar "inputTxtDomainAdminLocalAccount").text = $SelectedDomainName
        }
        Else
        {
            #move Domain join down & hide Domain OU
            (WPFVar "DomainOU" -Wildcard) | Set-UIFieldElement -Visible:$false
    
            #change label & account description
            (WPFVar "lblDomainCredsInstruction").Content = 'Provide a Workgroup Name & the local admin password'
            (WPFVar "lblDomainCredsExample").Content = ''
            (WPFVar "lblDomainAccountWorkgroupName").Content = 'Workgroup Name'
    
            (WPFVar "inputTxtDomainAdminLocalAccount").text = $SelectedDomainName
        }
        #sync boh domain FQDN fields (ComboBox and Textbox)
        (WPFVar "inputTxtDomainWorkgroupName").Text = (WPFVar "inputCmbDomainWorkgroupName").SelectedItem
    }
})

#Event handler trigger when cursor is moved away from inpute Domain Name field instead of textchanged event
#This helps with single threaded UI
(WPFVar "inputTxtDomainWorkgroupName").AddHandler(
    [System.Windows.Controls.Primitives.TextBoxBase]::LostFocusEvent,
    [System.Windows.RoutedEventHandler]{
        Write-Verbose ("Domain Field changed to [{0}]" -f (WPFVar "inputTxtDomainWorkgroupName").Text)

        If($MenuHideDomainList -eq $false)
            {
                If( (WPFVar "inputTxtDomainWorkgroupName").Text -ne 'Workgroup'){
        
                    #If OU enabled Populate Domain OU list. Move domain name field up to make room
                    If($MenuShowDomainOUSelection -and $MenuLocaleDomainOUList.count -gt 0)
                    {
                        (WPFVar "DomainOU" -Wildcard) | Set-UIFieldElement -Visible:$true
                    }
                    Else
                {
                    #move Domain join down & hide Domain OU
                    (WPFVar "DomainOU" -Wildcard) | Set-UIFieldElement -Visible:$false
                }
    
                #change label & account description (this ensures if workgroup is selected then changed back to domain, the values change back)
                (WPFVar "lblDomainCredsInstruction").Content = 'You must provide credentials with permissions to join the domain'
                (WPFVar "lblDomainCredsExample").Content = '(eg. domain\first.last.adm)'
                (WPFVar "lblDomainAccountWorkgroupName").Content = 'Domain Account'
    
                #grab current value & just replace the domain value before \
                $CurrentDomainAndAccount = (WPFVar "inputTxtDomainAdminLocalAccount").text
                $CurrentDomain = $CurrentDomainAndAccount.split('\')[0]
                $CurrentUser = $CurrentDomainAndAccount.split('\')[1]
    
                #grab Domain Name from config list based on FQDN
                If($MenuFilterAccountDomainType){
                    $SelectedClassid = ($MenuLocaleDomainList | Where FQDN -eq (WPFVar "inputTxtDomainWorkgroupName").Text).ClassId
                    #if multiple types exist for same classification, be sure to just select one
                    $SelectFirstDomain = ($MenuLocaleDomainList | Where {($_.ClassId -eq $SelectedClassid) -and ($_.Type -eq $MenuFilterAccountDomainType)}).Name | Select -First 1
                }
                Else{
                    $SelectFirstDomain = ($MenuLocaleDomainList | Where FQDN -eq (WPFVar "inputCmbDomainWorkgroupName").SelectedItem).Name
                }
    
                #if new domain is selected replace account domain
                If($SelectFirstDomain){
                    $SelectedDomainName = $SelectFirstDomain + '\' + $CurrentUser
                }
                ElseIf($Null -ne (WPFVar "inputTxtDomainWorkgroupName").Text){
                    $SelectedDomainName = (WPFVar "inputTxtDomainWorkgroupName").Text + '\' + $CurrentUser
                }
                Else{
                    $SelectedDomainName = $CurrentDomain + '\' + $CurrentUser
                }
    
                #replace domain with new domain
                (WPFVar "inputTxtDomainAdminLocalAccount").text = $SelectedDomainName
            }
            Else
            {
                #move Domain join down & hide Domain OU
                (WPFVar "DomainOU" -Wildcard) | Set-UIFieldElement -Visible:$false
    
                If($MenuAllowWorkgroupJoin -eq $false)
                {
                    Invoke-UIMessage -Message "A Workgroup is not allowed, Specify a domain name" -HighlightObject (WPFVar "inputTxtDomainWorkgroupName") -OutputErrorObject (WPFVar "txtError") -Type Error
                }
                Else
                {
                    Reset-HighlightedFields -Object (WPFVar "inputTxtDomainWorkgroupName") -ClearErrorMessage
                    #change label & account description
                    (WPFVar "lblDomainCredsInstruction").Content = 'Provide a Workgroup Name & the local admin password'
                    (WPFVar "lblDomainCredsExample").Content = ''
                    (WPFVar "lblDomainAccountWorkgroupName").Content = 'Workgroup Name'
    
                    (WPFVar "inputTxtDomainAdminLocalAccount").text = $SelectedDomainName
                }
            }
            Write-Verbose ("Domain Account Field changed to [{0}]" -f (WPFVar "inputTxtDomainAdminLocalAccount").text )
        }
    }
)



#====================================
# KEYBOARD EVENTS
#====================================
<#enable keyboard tab naviagation
$UI.Add_KeyDown({
    $key = $_.Key
    If ([System.Windows.Input.Keyboard]::IsKeyDown("RightCtrl") -OR [System.Windows.Input.Keyboard]::IsKeyDown("LeftCtrl")) {
        Switch ($Key) {
            "LEFT" {
                Switch-TabItem -TabControlObject (WPFVar "subtabControl") -name 'Hardware'
            }
            "RIGHT" {
                Switch-TabItem -TabControlObject (WPFVar "subtabControl") -name 'Identity'
            }
            Default {$Null}
        }
    }
})

#>

#====================================
# BUTTON EVENTS
#====================================
#Region CLICKACTION: Allows UI to be updated based input
(WPFVar "Validate" -Wildcard).Add_Click({

    #first thing: capture if bypass mode key is pressed
    If($null -ne $MenuAllowRuleBypassModeKey){
        $CaptureBypassModeKey = Test-KeyPress -Keys $MenuAllowRuleBypassModeKey
    }Else{
        $CaptureBypassModeKey = $false
    }

    Invoke-UIMessage -Message ("Validating device name: {0}" -f (WPFVar "inputTxtComputerName").text) -HighlightObject (WPFVar "inputTxtComputerName") -OutputErrorObject (WPFVar "txtError") -Type Info
    #Reset any highlighted input fields
    Reset-HighlightedFields -Object (WPFVar "input" -Wildcard) -ClearErrorMessage

    #first check if the computer name meets basic standards
    $ValidateComputerName = Confirm-ComputerNameField -ComputerNameObject (WPFVar "inputTxtComputerName") -OutputErrorObject (WPFVar "txtError") -ExcludeExample $NameStandardRuleExampleText

    #check if name needs to be validated against rules
    If($ValidateComputerName -and $MenuEnableValidateNameRules){

        $ValidateIdentity = Confirm-ComputerNameRules -SiteList $MenuLocaleSiteList `
                                                    -XmlRules $NameStandardRuleSets `
                                                    -ComputerNameObject (WPFVar "inputTxtComputerName") `
                                                    -OutputErrorObject (WPFVar "txtError") -ReturnOption All

        #Change sub tab to identity
        Switch-TabItem -TabControlObject (WPFVar "subtabControl") -name 'Identity'

        Update-UIIdentityFields -FieldsTable $ValidateIdentity -ClearValues
        #get current site list where the name matches a rule value
        Update-UILocaleFields -SiteList $MenuLocaleSiteList -SiteID $ValidateIdentity.SiteID `
                                        -UpdateSiteListObject (WPFVar "inputCmbSiteList") `
                                        -UpdateTimeZoneObject (WPFVar "inputCmbTimeZoneList") `
                                        -UpdateSiteCodeObject (WPFVar "txtSiteCode") `
                                        -UpdateDomainObject (WPFVar "inputCmbDomainWorkgroupName")

        #update site info (and domain) by classification
        Update-UIDomainFields -FilterLocale $ValidateIdentity.Id3 -FilterClass $ValidateIdentity.Id4 `
                       -WorkgroupOption:$MenuAllowWorkgroupJoin -ClassificationProperty $MenuShowClassificationProperty

       If($CaptureBypassModeKey)
       {
            #show it bypass mode was used
            Invoke-UIMessage -Message ('USER BYPASS MODE: Hold [{0}] and press Begin' -f ($MenuAllowRuleBypassModeKey -join "+")) -HighlightObject (WPFVar "inputTxtComputerName") -OutputErrorObject (WPFVar "txtError") -Type OK
            $ValidateIdentity = $true

            #hide dropdown & enable textbox
            ConvertTo-UITextBox -ComboBox (WPFVar "inputCmbDomainWorkgroupName")
            Switch-TabItem -TabControlObject (WPFVar "subtabControl") -name 'Hardware'
       }
    }
    Else{
        $ValidateIdentity = $ValidateComputerName
    }

    #if validated, be sure to enable fields and buttons in UI
    If($ValidateIdentity){
        #remove site list if not allowed to change
        If($MenuAllowSiteSelection -eq $false){$InputFields = $InputFields -ne 'inputCmbSiteList'}
        #enable input fields
        Get-UIFieldElement -Name $InputFields | Set-UIFieldElement -Enable:$true -ErrorAction SilentlyContinue
        Get-UIFieldElement -Name $ButtonFields | Set-UIFieldElement -Enable:$true -ErrorAction SilentlyContinue
    }
    Else{
        Get-UIFieldElement -Name $InputFields | Set-UIFieldElement -Enable:$false -ErrorAction SilentlyContinue
        Get-UIFieldElement -Name $ButtonFields | Set-UIFieldElement -Enable:$false -ErrorAction SilentlyContinue
    }
})
#endregion



#Region CLICKACTION: Begin will be enabled if validated is run
$ActiveBeginBtn.Add_Click({

    #first thing: capture if bypass mode key is pressed
    If($null -ne $MenuAllowRuleBypassModeKey){
        $CaptureBypassModeKey = Test-KeyPress -Keys $MenuAllowRuleBypassModeKey
    }Else{
        $CaptureBypassModeKey = $false
    }

    #Reset any highlighted input fields
    Reset-HighlightedFields -Object (WPFVar "input" -Wildcard) -ClearErrorMessage

    #first check if the computer name meets basic standards
    $ValidateComputerName = Confirm-ComputerNameField -ComputerNameObject (WPFVar "inputTxtComputerName") -OutputErrorObject (WPFVar "txtError") -ExcludeExample $NameStandardRuleExampleText

    #check if name needs to be validated against rules (only if basic computer name is valid)
    If($CaptureBypassModeKey){
        $ValidateComputerNameRules = $true
    }
    ElseIf($ValidateComputerName -and $MenuEnableValidateNameRules)
    {
        $ValidateComputerNameRules = Confirm-ComputerNameRules -SiteList $MenuLocaleSiteList `
                                                            -XmlRules $NameStandardRuleSets `
                                                            -ComputerNameObject (WPFVar "inputTxtComputerName") `
                                                            -OutputErrorObject (WPFVar "txtError") -ReturnOption Variables
        Set-OSDIdentityVariables -VariableTable $ValidateComputerNameRules
    }
    Else{
        $ValidateComputerNameRules = $true
    }

    #check if site code needs to be validated.
    If($MenuShowSiteCode)
    {
        $ValidateSiteCode = Confirm-SiteCode -SiteCodeObject (WPFVar "txtSiteCode") -OutputErrorObject (WPFVar "txtError")
    }
    Else{
        $ValidateSiteCode = $true
    }

    #check if admin credentials are valid format. Ignor if using ODJ
    If($MenuGenerateNameMethod -like 'ODJ*'){
        $ValidateAdminCreds = $true
    }
    ElseIf($MenuHideDomainList -or $MenuHideDomainCreds){
        $ValidateAdminCreds = $true
    }
    Else{
        $ValidateAdminCreds = Confirm-AdminCredFields -DomainNameObject (WPFVar "inputTxtDomainWorkgroupName") `
                                -UserNameObject (WPFVar "inputTxtDomainAdminLocalAccount") -PasswordObject (WPFVar "inputTxtPassword") -ConfirmedPasswordObject (WPFVar "inputTxtPasswordConfirm") `
                               -OutputErrorObject (WPFVar "txtError") -WorkgroupAllowed:$MenuAllowWorkgroupJoin
    }

    #all check must be valid to preceed
    If($ValidateSiteCode -and $ValidateComputerName -and $ValidateComputerNameRules -and $ValidateAdminCreds)
    {
        #Build Parameters for OSD Variables
        $OSDParams = @{ComputerName=(WPFVar "inputTxtComputerName").Text}
        If($MenuHideDomainList -ne $true){
            If( (WPFVar "inputTxtDomainWorkgroupName").Text -eq 'Workgroup' ){
                $OSDParams += @{DomainName=(WPFVar "inputTxtDomainWorkgroupName").Text}
            }Else{
                $OSDParams += @{DomainName=(WPFVar "inputTxtDomainWorkgroupName").Text;DomainOU=(WPFVar "inputCmbDomainOU").Text}
            }
        }
        If($MenuHideDomainCreds -ne $true){
            If( (WPFVar "inputTxtDomainWorkgroupName").Text -eq 'Workgroup' ){
                $OSDParams += @{LocalAdminPassword=(WPFVar "inputTxtPassword").Password}
            }Else{
                $OSDParams += @{AdminUsername=(WPFVar "inputTxtDomainAdminLocalAccount").Text;AdminPassword=(WPFVar "inputTxtPassword").Password}
            }
        }
        $OSDParams += @{CMSiteCode=(WPFVar "txtSiteCode").Text}


        #Set OSD variables for ODJ Join using a file
        If($MenuGenerateNameMethod -eq 'ODJFile'){
            Set-OSDOdjVariables -BlobFile $DeviceODJ.FullName -ComputerName (WPFVar "inputTxtComputerName").Text -LocalAdminPassword (WPFVar "inputTxtPassword").Password
        }
        #Set OSD variables for ODJ Join using blob data
        ElseIf($MenuGenerateNameMethod -eq 'ODJBlob'){
            Set-OSDOdjVariables -BlobData $ODJBlobData -ComputerName (WPFVar "inputTxtComputerName").Text -DomainName (WPFVar "inputTxtDomainWorkgroupName").Text
        }
        ElseIf($MenuHideDomainList -and $MenuHideDomainCreds){
            Set-OSDDomainVariables -ComputerName (WPFVar "inputTxtComputerName").Text
        }
        #Set OSD variables for Workgroup Join
        ElseIf( ((WPFVar "inputTxtDomainWorkgroupName").Text -eq 'Workgroup')){
            If($MenuHideDomainCreds){
                Set-OSDWorkgroupVariables -ComputerName (WPFVar "inputTxtComputerName").Text -Workgroup (WPFVar "inputTxtDomainAdminLocalAccount").Text
            }Else{
                Set-OSDWorkgroupVariables -ComputerName (WPFVar "inputTxtComputerName").Text -Workgroup (WPFVar "inputTxtDomainAdminLocalAccount").Text `
                                -LocalAdminPassword (WPFVar "inputTxtPassword").Password
            }
        }
        #Set OSD variables for Domain Join
        Else{
            $DomainName = $MenuLocaleDomainList | Where {$_.FQDN -eq (WPFVar "inputTxtDomainWorkgroupName").Text} | Select -ExpandProperty Name
            If($MenuHideDomainCreds){

                Set-OSDDomainVariables -ComputerName (WPFVar "inputTxtComputerName").Text -DomainName $DomainName -DomainFQDN (WPFVar "inputTxtDomainWorkgroupName").Text -DomainOU (WPFVar "inputCmbDomainOU").Text`
                                -CMSiteCode (WPFVar "txtSiteCode").Text
            }Else{
                Set-OSDDomainVariables -ComputerName (WPFVar "inputTxtComputerName").Text -DomainName $DomainName -DomainFQDN (WPFVar "inputTxtDomainWorkgroupName").Text -DomainOU (WPFVar "inputCmbDomainOU").Text`
                                -AdminUsername (WPFVar "inputTxtDomainAdminLocalAccount").Text -AdminPassword (WPFVar "inputTxtPassword").Password `
                                -CMSiteCode (WPFVar "txtSiteCode").Text
            }
        }
        #Set OSD variables for Timezones/Locale
        Set-OSDLocaleVariables -SelectedTimeZone ($AllTimeZones | Where {$_.TimeZone -eq (WPFVar "inputCmbTimeZoneList").SelectedItem})
        #Set OSD variables for Applications
        If($MenuShowAppSelection){Set-OSDAppVariables -AppObjects (WPFVar "tglAppInstall" -Wildcard) -AppList $MenuAppButtonsItems}
        #Set OSD variables for Classification
        Set-OSDClassificationVariables -ClassificationFilter (WPFVar "txtClassification").Text

        $UI.Close() | Out-Null
    }
    #if validation fails; ensure begin button is disabled
    Else{
        If($MenuEnableValidateNameRules){Set-UIFieldElement -FieldObject $ActiveBeginBtn -Enable:$false}
    }
})
#endregion


#====================
# Shows the form
#====================
#if test mode then don't run the menu just the functions
If(!$TestMode)
{
    If($MenuShowSplashScreen){Show-UISplashScreenProgress -Label ("Loading User Interface...") -Progress 100}
    Show-UIMenu
    If($MenuShowSplashScreen){Close-UISplashScreen}
}
Else
{
    Show-UIMenuCommandHelp -ExampleText $NameStandardRuleExampleText
}