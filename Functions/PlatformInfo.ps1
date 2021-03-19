
#region FUNCTION: convert chassis Types to friendly name
Function ConvertTo-ChassisType{
    [CmdletBinding()]
    Param($ChassisId)
    Switch ($ChassisId)
        {
            "1" {$Type = "Other"}
            "2" {$Type = "Virtual Machine"}
            "3" {$Type = "Desktop"}
            "4" {$type = "Low Profile Desktop"}
            "5" {$type = "Pizza Box"}
            "6" {$type = "Mini Tower"}
            "7" {$type = "Tower"}
            "8" {$type = "Portable"}
            "9" {$type = "Laptop"}
            "10" {$type = "Notebook"}
            "11" {$type = "Handheld"}
            "12" {$type = "Docking Station"}
            "13" {$type = "All-in-One"}
            "14" {$type = "Sub-Notebook"}
            "15" {$type = "Space Saving"}
            "16" {$type = "Lunch Box"}
            "17" {$type = "Main System Chassis"}
            "18" {$type = "Expansion Chassis"}
            "19" {$type = "Sub-Chassis"}
            "20" {$type = "Bus Expansion Chassis"}
            "21" {$type = "Peripheral Chassis"}
            "22" {$type = "Storage Chassis"}
            "23" {$type = "Rack Mount Chassis"}
            "24" {$type = "Sealed-Case PC"}
            Default {$type = "Unknown"}
         }
    Return $Type
}
#endregion

#region FUNCTION: Grab all machine platform details
Function Get-PlatformInfo {
# Returns device Manufacturer, Model and BIOS version, populating global variables for use in other functions/ validation
# Note that platformType is appended to psobject by Get-PlatformValid - type is manually defined by user to ensure accuracy
    [CmdletBinding()]
    [OutputType([PsObject])]
    Param()
    try{
        $CIMSystemEncloure = Get-CIMInstance Win32_SystemEnclosure -ErrorAction Stop
        $CIMComputerSystem = Get-CIMInstance CIM_ComputerSystem -ErrorAction Stop
        $CIMBios = Get-CIMInstance Win32_BIOS -ErrorAction Stop

        $ChassisType = ConvertTo-ChassisType -ChassisId $CIMSystemEncloure.chassistypes

        [boolean]$Is64Bit = [boolean]((Get-WmiObject -Class 'Win32_Processor' | Where-Object { $_.DeviceID -eq 'CPU0' } | Select-Object -ExpandProperty 'AddressWidth') -eq 64)
        If ($Is64Bit) { [string]$envOSArchitecture = '64-bit' } Else { [string]$envOSArchitecture = '32-bit' }

        New-Object -TypeName PsObject -Property @{
            "computerName" = [system.environment]::MachineName
            "computerDomain" = $CIMComputerSystem.Domain
            "platformBIOS" = $CIMBios.SMBIOSBIOSVersion
            "platformManufacturer" = $CIMComputerSystem.Manufacturer
            "platformModel" = $CIMComputerSystem.Model
            "AssetTag" = $CIMSystemEncloure.SMBiosAssetTag
            "SerialNumber" = $CIMBios.SerialNumber
            "Architecture" = $envOSArchitecture
            "Chassis" = $ChassisType
            }
    }
    catch{Write-Output "CRITICAL" "Failed to get information from Win32_Computersystem/ Win32_BIOS"}
}
#endregion