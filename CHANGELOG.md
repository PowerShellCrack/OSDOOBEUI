# Change log for OOBEUIWPF.ps1

## 2.1.4 - Mar 18 2021

- Renamed script to OSDOOBEUI.ps1 to be more consistent with repo. 
- Changed AddButtons to AppButtons in XML; mistyped

## 2.1.3 - Mar 16 2021

- Changed Serial number to pull from WMI win32_BIOS; works with multiple platforms. 
- Removed task sequence variable checks for device info; always uses WMI
- Check computer name when initiated; uses TS variable _SMSTSMachineName
- Fixed Testmode; changed UI help cmdlet

## 2.1.2 - Mar 10, 2021

- Used Timezone spreadsheet instead of system timezones; accurately control index and time.
- Fixed domain and timezone pre selection when validating device name

## 2.1.1 - Mar 04, 2021

- Changed domainname to domainFQDN in Set-OSDDomainVariables function
- Added custom osd variable for domain join: domainname. Allows multiple 'Apply Network Settings' step in one TS using custom variable detection

## 2.1.0 - Dec 18, 2020

- Changed OSD values to log only when set.
- Changed parameters used when Control_HideDomainCreds and Control_HideDomainList are set.

## 2.0.9 - Dec 17, 2020

- Fixed process OSD variables when hiding fields; doing a check if value exist before setting it.

## 2.0.8 - Dec 16, 2020

- Added Control_HideDomainCreds and Control_HideDomainList; used manually for SCCM BareMetal Imaging and only want a computer name prompt
- Check for MININT in name during task sequence; set to computer name to null; otherwise set current name; used when enabling WinPE as Generate Name Method
- Changed Generate Name Method option WinPE to TSEnv; checks for OSDComputerName is not default name MININT;
- added clear option to Generate Name Method; nulls out any computer name
- Changed Set-OSDComputerName to Update-OSDComputerName

## 2.0.7 - Nov 03, 2020

- Added the ability to bypass validation using a key set in config; must be done at Begin step as well
- Added Function to convert (or flip) combobox to textbox; and visa versa
- Added outhost trigger to UI console in config in addition to logging; Outputs execution actions. must enable verbose/debug for additional output.
- Fixed domain account update process based on domain dropdown or txt field.

## 2.0.6 - Oct 20, 2020

- Removed MDT variables in the Set-OSDVariables.ps1; not used in OSD anymore. Causes issues with username and password

## 2.0.5 - Oct 18, 2020

- Fixed external site list path when importing; added function to check

## 2.0.4 - Oct 17, 2020

- Added System.Windows assembly; causes less crashing
- Fixed external site list path when importing; reverts to working path and not relative path
- Added two logo support for both UI and Splashscreen
- Fixed logging when using debug or verbose switch; only logs based on settings
- Added build version info to UI; only displays if in debug or verbose mode
- Added version control check based on changelog.md for more accurate version and date
- Added SYNOPSIS details to main script

## 2.0.3 - Oct 16, 2020

- Updated Splashscreen to display progress of menu status
- Moved Splashscreen functions to separate file; set Splashscreen runspace to a global scope
- Renamed Splashscreen functions to have 'UI' in the name; better consistency for all UI functions
- Fixed config path checks to look for rooted path, relative, and absolute
- Added Set-UIFieldElement to manage multiple parameter at once; shorting script for multiple element calls
- Add configuration display format control for site list in dropdown; set by xml file.

## 2.0.2 - Oct 14, 2020

- Added Application page control with function; identifies active begin and flips controls dynamically.
- Fixed workgroup option when not validating rules
- Disable computer name update during site list change when not validating rules
- Fixed Domain OU display control
- added TimeZonelist function for cleaner script

## 2.0.1 - Oct 12, 2020

- Updated logging for each ps1 file in Function folder
- Change ODJ to support blob (in unattend) or file option (from workgroup); changes the method of joining to domain
- Added MDT variables to domain join function (Set-OSDVariables.ps1)
- Added password generator as example and to password validation for ODJ join
- renamed to ZTIOOBEUI.ps1 to follow ZTI or LTI format.

## 1.9.9 - Oct 05, 2020

- Added logging to main script
- Added support to import an external site list; must be in CSV format.
- Fixed colors in UI message to output supported Foreground colors in PowerShell.
- Enforces TimeZone abbreviation converter to always use first selection
- Add the ability to display site list but have it disabled

## 1.9.8 - Sept 19, 2020

- Fixed ODJ UI to hide only if Blob content is there, if blank file exist, still prompt for creds
- Fixed focus on password and computer name
- Added the ability to overwrite config file using TS variables or parameter

## 1.9.7 - Sept 16, 2020

- Added Offline Domain Join feature. Hides Domain and username and password if found.
- Moved majority of functions to separate files

## 1.9.6 - Aug 19, 2020

- Changed OOBEWPFUI_OptionalPage.ps1 to OOBEWPFUI_SinglePage.ps1
- Fixed Update-ComputerNameLocale site locale changer
- fixed splash screen to close when menu opens; not after menu closes and not before menu opens. Added delay

## 1.9.5 - Aug 5, 2020

- Added example control in config.
- fixed hidden logo option during WPF process
- Update computer name change changer for site locale. dynamically grab site code

## 1.9.4 - July 20, 2020

- changed ShowClassificationColor to ShowClassificationProperty allowing to change the display text and color based on property in config.
- added classification variable output: Classification, ClassificationColor,ClassificationLevel,ClassificationType,ClassificationCaveat
- cleaned up debug/verbose output for easier reading
- excluded name change warning message on initial entry

## 1.9.3 - July 16, 2020

- add example text (light gray) within computer name and domain account fields
- Change validate to process basic computer name validation first, then rules
- Add XAML attribute to auto focus to place cursor in computer name textbox (FocusedElement)
- Changed computer name text font weight to bold
- Add XAML attribute to default the computer name textbox to all caps (CharacterCasing)

## 1.9.1 - July 14, 2020

- Rebuild Computer Name Rules to output psobject instead of hashtables; allows to be used by other functions; removed perform actions
- Added name rule perform actions to buttons for better control
- Fixed Begin validation check. Wasn't checking computer name if changed just before begin/ready
- Set Begin/ready buttons to disabled, until validate is performed.
- Changed UI Message to show different colors based on severity type (errors, warnings, info)
- Add handlers to monitor Computer Name change and forces to validate again before pressing begin/ready
- Renamed Update-LocalebyClassification to Update-UIDomainFields. Update domain to filter on classification
- Changed Classification combobox to readonly textbox; add filter control for classID
- Removed repeating debug  messages and changed Get-SMSTSEnv to use script scope variable

## 1.8.6 - July 13, 2020

- Add logo position for left, right, both, or hidden on menu and splash screen. Adjust position to be centered in position
- Fixed domain name selection when using dropdown. selection would go revert to default when begin is pressed.
- Updated splashscreen with progressbar

## 1.8.5 - July 12, 2020

- Add Get-TimeZoneIndex function. Updates the MDT OSD variable Timezone with index number instead of standard name.
- Add Update-computer name function. Site locale selection will update the computer name with the 4 characters site id

## 1.8.4 - July 11, 2020

- Changed _SMSAssetTag variable check to AssetTag
- Added Language Locale for future support

## 1.8.1 - July 10, 2020

- Changed domain type to domain for domain join.
- Added OSDNetworkJoinType to a variable to output verbose.
- Added debug (if set to true) to display password for troubleshooting
- Issue with computer name rules when multiple hashes are present; added minimum character identifier check

## 1.8.0 - July 9, 2020

- Updated script to support Visual Studio Code; added VSE detection and cleaned up script path check
- Changed Get-WMIObject to Get-CIMInstance to support PowerShell 7.0 or higher.
- Added AccountDomainType to filter domains based on type. This also forces the filtered domain to populate in user account as the primary domain.
- Add background color control. Allows main blue color to be replaced.
- Removed the computer name from being filled by OSDcomputername value upon bootup in MDT.
- Changed process messages from Verbose to debug output
- Remove network security option. 802.1x can be configured using separate script triggered by UI outputs

## 1.7.8 - July 8, 2020

- Add domain list dropdown features; allow to force domain selection instead of mistyping domain. Only useful if domain list is populated in configuration
- Fixed Naming rules validation when disabled. Hides validate button and fields and doesn't do rule check
- Renamed Rule Name Id to be generic in UI to allow more customizations. Config will populate the names based on rule set
- renamed inputs names to easily search names by wildcard search "input*; provides a a function to easily reset fields if errors previously.
- Fixed rule set where 39 and 89 was the same as 3 or 8; also fixed where a '19' was detected as '39' or '89'; built a more dynamic regex expression
        [stackoverflow](https://stackoverflow.com/questions/62765844/powershell-regex-validate-computer-name)
- Fixed Apps selection. Lists all apps and descriptions. Add variables to OSD
- Cleaned up code using Visual studio code plugins. Changed function to use proper nouns and fixed misspelling and removed empty spaces
- Centered Objects in XAML using even numbers.  Aligned objects evenly making it more fluid. Lightened Hardware and Identity Text
- Added workgroup support and handler to update UI with workgroup info: Added OSD variables for workgroup join
- Added AllowWorkgroupJoined configuration; allows workgroup selection
- Added Reset-HighlightedFields to reset all inputs and error message each time validation is done

## 1.6.1 - July 2, 2020

- Add Validate-DomainAccount function to identify and validate "domain\username" inputs and export each part as variables
- Fixed Domain FQDN issue; resolve FQDN domain name base on locale and populates admin account

## 1.5.0 - July 1, 2020

- Fixed issue with Rule not finding exact match when # symbols exist
- Fixed classification dropdown
- Fixed Domain OU dropdown
- Add FQDN list based on classification; auto update UI when name is validated

## 1.4.0 - June 30, 2020

- Adding domain an domain OU functionality to support multiple domains
- Added notes to configuration file

## 1.2.0 - June 26, 2020

- revamped standard naming rules from checking lengths in name to full regex build (from rules in config)
- Requested regex assistance to community to build regex query: [stackoverflow](https://stackoverflow.com/questions/62580859/using-regex-for-complicated-naming-convention)

## 1.2.0 - June 25, 2020

- COI identifier not testing when name changes; added clear field functionality

## 1.2.0 - June 23, 2020

- Adding additional features such as displaying appropriate information when the correct computer name
- locale is provided and ensure its feeding the variables for the deployment process for application installs.

## 1.5.0 - June 15, 2020

- Added splash screen to hide loading window
- Added Validate button

## 1.2.0 - June 10, 2020

- add sub tab menu to show naming convention output

## 1.1.0 - June 5, 2020

- changed design from 3 pages to one with optional app page

## 1.0.1 - June 2, 2020

- Basic PowerShell output for xaml
- Added XML for configurations
- Add network detection when multiple NICs exist

## 1.0.0 - June 1, 2020

- initial UI design