
#region FUNCTION: Converts IP Address to binary
Function Convert-IPv4AddressToBinaryString {
    Param(
        [IPAddress]$IPAddress='0.0.0.0'
    )
    $addressBytes=$IPAddress.GetAddressBytes()

    $strBuilder=New-Object -TypeName Text.StringBuilder
    foreach($byte in $addressBytes){
        $8bitString=[Convert]::ToString($byte,2).PadRight(8,'0')
        [void]$strBuilder.Append($8bitString)
    }
    Return $strBuilder.ToString()
}
#endregion

#region FUNCTION: Converts IP Address to integer
Function Convert-IPv4ToInt {
    [CmdletBinding()]
    Param(
        [String]$IPv4Address
    )
    Try{
        $ipAddress=[IPAddress]::Parse($IPv4Address)

        $bytes=$ipAddress.GetAddressBytes()
        [Array]::Reverse($bytes)

        [System.BitConverter]::ToUInt32($bytes,0)
    }Catch{
        Write-Error -Exception $_.Exception -Category $_.CategoryInfo.Category
    }
}
#endregion

#region FUNCTION: Converts integer to IP Address
Function Convert-IntToIPv4 {
    [CmdletBinding()]
    Param(
        [uint32]$Integer
    )
    Try{
        $bytes=[System.BitConverter]::GetBytes($Integer)
        [Array]::Reverse($bytes)
        ([IPAddress]($bytes)).ToString()
    }Catch{
        Write-Error -Exception $_.Exception -Category $_.CategoryInfo.Category
    }
}
#endregion

#region FUNCTION: Converts subnet to a CIDR address (eg. /24)
Function Add-IntToIPv4Address {
    Param(
        [String]$IPv4Address,
        [int64]$Integer
    )
    Try{
        $ipInt = Convert-IPv4ToInt -IPv4Address $IPv4Address -ErrorAction Stop
        $ipInt += $Integer

        Convert-IntToIPv4 -Integer $ipInt
    }Catch{
        Write-Error -Exception $_.Exception -Category $_.CategoryInfo.Category
    }
}
#endregion

#region FUNCTION: Converts a CIDR to a subnet address
Function Convert-CIDRToNetmask {
    [CmdletBinding()]
    Param(
    [ValidateRange(0,32)]
        [int16]$PrefixLength=0
    )
    $bitString=('1' * $PrefixLength).PadRight(32,'0')

    $strBuilder = New-Object -TypeName Text.StringBuilder

    for($i=0;$i -lt 32;$i+=8){
        $8bitString=$bitString.Substring($i,8)
        [void]$strBuilder.Append("$([Convert]::ToInt32($8bitString,2)).")
    }

    Return $strBuilder.ToString().TrimEnd('.')
}
#endregion

#region FUNCTION: Converts subnet to a CIDR address (eg. /24)
Function Convert-NetmaskToCIDR {
    [CmdletBinding()]
    Param(
        [String]$SubnetMask='255.255.255.0'
    )
    $byteRegex='^(0|128|192|224|240|248|252|254|255)$'
    $invalidMaskMsg="Invalid SubnetMask specified [$SubnetMask]"
    Try{
        $netMaskIP=[IPAddress]$SubnetMask
        $addressBytes=$netMaskIP.GetAddressBytes()

        $strBuilder=New-Object -TypeName Text.StringBuilder

        $lastByte=255
        foreach($byte in $addressBytes){

            # Validate byte matches net mask value
            if($byte -notmatch $byteRegex){
                Write-Error -Message $invalidMaskMsg -Category InvalidArgument -ErrorAction Stop
            }
            elseif($lastByte -ne 255 -and $byte -gt 0){
                Write-Error -Message $invalidMaskMsg -Category InvalidArgument -ErrorAction Stop
            }

            [void]$strBuilder.Append([Convert]::ToString($byte,2))
            $lastByte=$byte
        }

        Return ($strBuilder.ToString().TrimEnd('0')).Length
    }
    Catch{
        Write-Error -Exception $_.Exception -Category $_.CategoryInfo.Category
    }
}
#endregion

#region FUNCTION: Get the subnet information
Function Get-IPv4Subnet {
    [CmdletBinding(DefaultParameterSetName='PrefixLength')]
    Param(
        [Parameter(Mandatory=$true,Position=0)]
        [IPAddress]$IPAddress,

        [Parameter(Position=1,ParameterSetName='PrefixLength')]
        [Int16]$PrefixLength=24,

        [Parameter(Position=1,ParameterSetName='SubnetMask')]
        [IPAddress]$SubnetMask
    )
    Begin{
        $outputObject = New-Object -TypeName PSObject
    }
    Process{
        Try{
            if($PSCmdlet.ParameterSetName -eq 'SubnetMask'){
                $PrefixLength= Convert-NetmaskToCIDR -SubnetMask $SubnetMask -ErrorAction Stop
            }else{
                $SubnetMask = Convert-CIDRToNetmask -PrefixLength $PrefixLength -ErrorAction Stop
            }

            $netMaskInt = Convert-IPv4ToInt -IPv4Address $SubnetMask
            $ipInt = Convert-IPv4ToInt -IPv4Address $IPAddress

            $networkID = Convert-IntToIPv4 -Integer ($netMaskInt -band $ipInt)

            $maxHosts=[math]::Pow(2,(32-$PrefixLength)) - 2
            $broadcast = Add-IntToIPv4Address -IPv4Address $networkID -Integer ($maxHosts+1)

            $firstIP = Add-IntToIPv4Address -IPv4Address $networkID -Integer 1
            $lastIP = Add-IntToIPv4Address -IPv4Address $broadcast -Integer -1

            if($PrefixLength -eq 32){
                $broadcast=$networkID
                $firstIP=$null
                $lastIP=$null
                $maxHosts=0
            }

            $memberParam=@{
                InputObject=$outputObject;
                MemberType='NoteProperty';
                Force=$true;
            }
            Add-Member @memberParam -Name CidrID -Value "$networkID/$PrefixLength"
            Add-Member @memberParam -Name NetworkID -Value $networkID
            Add-Member @memberParam -Name SubnetMask -Value $SubnetMask
            Add-Member @memberParam -Name PrefixLength -Value $PrefixLength
            Add-Member @memberParam -Name HostCount -Value $maxHosts
            Add-Member @memberParam -Name FirstHostIP -Value $firstIP
            Add-Member @memberParam -Name LastHostIP -Value $lastIP
            Add-Member @memberParam -Name Broadcast -Value $broadcast
        }
        Catch{
            Write-Error -Exception $_.Exception -Category $_.CategoryInfo.Category
        }
    }
    End{
        Return $outputObject
    }
}
#endregion

#region FUNCTION: Convert network status integer to status message
function ConvertTo-NetworkStatus{
    Param([int]$Value)

    switch($Value){
       0 {$status = "Disconnected" }
       1 {$status = "Connecting" }
       2 {$status = "Connected" }
       3 {$status = "Disconnecting" }
       4 {$status = "Hardware not present" }
       5 {$status = "Hardware disabled" }
       6 {$status = "Hardware malfunction" }
       7 {$status = "Media disconnected" }
       8 {$status = "Authenticating" }
       9 {$status = "Authentication succeeded" }
       10 {$status = "Authentication failed" }
       11 {$status = "Invalid Address" }
       12 {$status = "Credentials Required" }
       Default {$status =  "Not connected" }
  }

  return $status

}
#endregion

#region FUNCTION: Grabs current client gateway
Function Get-ClientGateway
{
# Uses WMI to return IPv4-enabled network adapter gateway address for use in location identification
    [CmdletBinding()]
    [OutputType([PsObject])]
    Param()
    $arrGateways = (Get-CIMInstance Win32_networkAdapterConfiguration | Where-Object {$_.IPEnabled}).DefaultIPGateway
    foreach ($gateway in $arrGateways) {If ([string]::IsNullOrWhiteSpace($gateway)){}Else{$clientGateway = $gateway}}
    If ($clientGateway) {
        New-Object -TypeName PsObject -Property @{"IPv4address" = $clientGateway}
    }
    Else {
        Write-Host "Unable to detect Client IPv4 Gateway Address, check IPv4 network adapter/ DHCP configuration" -ForegroundColor Red
    }
}
#endregion

#region FUNCTION: Get the primary interface not matter the number of nics
Function Get-InterfaceDetails
{
    #pull each network interface on device
    #use .net class due to limited commands in PE
    $nics=[Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() | Where {($_.NetworkInterfaceType -ne 'Loopback') -and ($_.NetworkInterfaceType -ne 'Ppp') -and ($_.Supports('IPv4'))}

    #grab all nic in wmi to compare later (its faster than querying individually)
    $wminics = Get-CimInstance win32_NetworkAdapter | Where {($null -ne $_.MACAddress) -and ($_.Name -notlike '*Bluetooth*') -and ($_.Name -notlike '*Miniport*') -and ($_.Name -notlike '*Xbox*') }

    Write-Debug ("Detected {0} Network Inferfaces" -f $nics.Count)

    $InterfaceDetails =
    foreach($interface in $nics ){

        $ipProperties=$interface.GetIPProperties()
        $ipv4Properties=$ipProperties.GetIPv4Properties()

        $ipProperties.UnicastAddresses | where Address -NotLike fe80* | Foreach {
            if(!($_.Address.IPAddressToString)){
                continue
            }

            if($null -ne $ipProperties.GatewayAddresses.Address.IPAddressToString){
                $gateway=$ipProperties.GatewayAddresses.Address.IPAddressToString

                $adapterInfo = $wminics | Where Name -eq $interface.Description |
                        select MACAddress,Manufacturer,netconnectionstatus

                $subnetInfo = Get-IPv4Subnet -IPAddress $_.Address.IPAddressToString -PrefixLength $_.PrefixLength
                New-Object -TypeName PSObject -Property @{
                        InterfaceName=$interface.Name;
                        InterfaceDescription=$interface.Description;
                        InterfaceType=$interface.NetworkInterfaceType;
                        MacAddress=$adapterInfo.MACAddress;
                        AdapterManufacturer=$adapterInfo.Manufacturer;
                        NetworkID=$subnetInfo.NetworkID;
                        IPAddress=$_.Address.IPAddressToString;
                        SubnetMask=$subnetInfo.SubnetMask;
                        CidrID=$subnetInfo.CidrID;
                        DnsAddresses=$ipProperties.DnsAddresses.IPAddressToString;
                        GatewayAddresses=$gateway;
                        DhcpEnabled=$ipv4Properties.IsDhcpEnabled;
                        Status=(ConvertTo-NetworkStatus $adapterInfo.netconnectionstatus)
                    }

                }
                Write-Debug ("Interface Detected: {0}" -f $interface.Name)
                Write-Debug ("MAC Address: {0}" -f $adapterInfo.MACAddress)
                Write-Debug ("IP Address assigned: {0}" -f $_.Address.IPAddressToString)
                Write-Debug ("Gateway assigned: {0}" -f $gateway)
            }
    }

    #grab local route to find primary interface
    #wmi class is not avaliable WinPE, instead parse route print command
    <#
    Try{
        Write-Debug "Processing routing table..."
        $computer = 'localhost'
        $wmi = Get-CimInstance -namespace root\StandardCimv2 -ComputerName 'localhost' -Query "Select * from MSFT_NetRoute" -ErrorAction Stop
        $route = $wmi | ? { $_.DestinationPrefix -eq '0.0.0.0/0' } |
            Select @{Name = "Destination"; Expression = {$_.DestinationPrefix}},
                     @{Name = "Gateway"; Expression = {$_.NextHop}},
                     @{Name = "Metric"; Expression = {$_.InterfaceMetric}} -First 1
    }
    Catch{
        $tmpRoute = ((route print | ? { $_.trimstart() -like "0.0.0.0*" }) | % {$_}).split() | ? { $_ }
        $route = @{'Destination' = $tmpRoute[0];
               'Netmask'     = $tmpRoute[1];
               'Gateway'     = $tmpRoute[2];
               #'Interface'   = $tmpRoute[3];
               'Metric'      = $tmpRoute[4];
              }
    }
    #>
    $currentGateway = Get-ClientGateway

    Write-Debug "Determining primary interface by using routing table..."

    $PrimaryInterface = $InterfaceDetails | where {($_.GatewayAddresses -eq $currentGateway.IPv4address) -and ($_.Status -eq 'Connected')}
    return $PrimaryInterface
}
#endregion