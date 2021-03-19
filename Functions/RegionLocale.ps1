#region FUNCTION: Pulls all values from Windows regions
function Get-RegionInfo($Name='*')
{
    $cultures = [System.Globalization.CultureInfo]::GetCultures('InstalledWin32Cultures')

    foreach($culture in $cultures)
    {
       try{
           $region = [System.Globalization.RegionInfo]$culture.Name

           if($region.DisplayName -like $Name)
           {
                $region
           }
       }
       catch {}
    }
}
#endregion


Function Get-TimeZoneIndex{
    Param(
        $TZCsvList = "$ResourcePath\TimeZonesIndex.csv",
        $TimeZone
    )

    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    Try{
        $IndexData = Import-Csv $TZCsvList -ErrorAction Stop

        #remove the UTC/GMT in parenthesis
        $parsedName = ($TimeZone -replace '^.?\((.*?)\)','').Trim()
        #match the UTC offset in parenthesis
        $TimeZone.TimeZone -match '.?\((.*?)\).*' | Out-Null
        $UTC = $Matches[1]

        $TZI = $null
        #get only the timezones with matching UTC
        $filterData = $IndexData | where {$_.UTC -match $UTC}
        #if there is only one, then that is the index
        If($filterData.count -eq 1){
            $TZI = $filterData.Index
        }
        #multiple UTC zones exist
        else
        {
            #sometimes the names are comma deliminated
            $TZNames = ($parsedName).split(',').Trim()
            #loop through the filtered UTC zones
            Foreach($Index in $filterData)
            {
                Write-LogEntry ("Searching for TimeZone index with Displayname: [{0}]" -f $index.Name) -Source ${CmdletName} -Severity 4
                #if the names have commas split them up
                $IndexNames = ($index.Name).split(',').Replace('and','&').Trim()
                #compare the split objects to see if any of them match
                $Compared = Compare-Object $TZNames $IndexNames -IncludeEqual -ExcludeDifferent
                If($Compared){
                    $TZI = $index.Index
                }
                Else
                {
                    #try a few different methods to match the name to index
                    Foreach($Name in $IndexNames){
                        Write-LogEntry ("Searching for name: [{0}]" -f $Name) -Source ${CmdletName} -Severity 4
                        If($Name -like "*$parsedName*"){$TZI = $index.Index}
                        If($Name -contains $parsedName){$TZI = $index.Index}
                        If($Name -Match $parsedName){$TZI = $index.Index}
                        If($Name -in $parsedName){$TZI = $index.Index}
                    } #end index names loop
                }
            } #end filtered data loop
        }
    }
    Catch{
        #no csv data found in resource
    }
    Finally{
        If($TZI){
            $IndexValue = ('{0:d3}' -f [int]$TZI).ToString()
        }
    }
    return $IndexValue
}

#region FUNCTION: Attempt to convert abbreviations to time zones
Function ConvertFrom-TimeZoneAbbreviation
{
    <#
    $abbr=$MatchedLocale.TZ
    $Country=$MatchedLocale.Region
    $Offset='UTC-8'
    #>
    Param(
        $TZCsvList = "$ResourcePath\TimeZonesIndex.csv",
        [string]$abbr,
        [string]$Country,
        [string]$Offset
    )
    Begin{
        ## Get the name of this function
        [string]${CmdletName} = $MyInvocation.MyCommand

        if ($PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference')
        }

        # grab list of timezones
        If(Test-Path $TZCsvList -ErrorAction SilentlyContinue){
            $TZList = Import-Csv $TZCsvList | Select Index,TimeZone,@{l='StandardName';e={($_.TimeZone -replace '^.?\((.*?)\)','').Trim()}},UTC,Abbr
        }Else{
            $TZList = Get-TimeZone -ListAvailable | Select @{l='TimeZone';e='DisplayName'},StandardName,@{l='UTC';e={$_.DisplayName -match ".?\((.*?)\).*" | Out-Null;$matches[1]}}
        }
    
        $TimeZoneItems = @()
    }
    Process
    {
        Foreach($item in $TZlist)
        {
            $TZItem = [PSCustomObject]@{
                FullTZName = $item.TimeZone
                TZName = $item.StandardName
                Abbr = If($null -eq $item.abbr){
                            $item.StandardName -replace '([A-Z])\w+\s*','$1' -replace '\s','' -replace '\d','' -replace '[\W]', ''
                        }Else{
                            $item.abbr
                        }
                Offset = $item.UTC -replace 'UTC|GMT',''
                #Offset = [regex]::Match($item.UTC,'^\((UTC.*\d)\)|^\((GMT.*\d)\)').Groups[1].Value -replace ':00','' -replace '0([0-9])','$1'
            }

            #correct Universal Time Coordinated identifiers
            If($TZItem.Abbr -eq 'U' -or $TZItem.Abbr -eq 'CUT'){$TZItem.Abbr = 'UTC'}

            #Add data to array
            $TimeZoneItems += $TZItem
        }
        #filter to find Time Zone Name
        If($abbr)
        {
            $TZName = @($TimeZoneItems | Where Abbr -eq $abbr | Select -Unique)
            Write-LogEntry ("Searched by Time Zone Abbreviation [{0}]. Found: {1} " -f $abbr,$TZName.Count) -Source ${CmdletName} -Severity 4
        }

        #only need to filter again if list is more than one
        If([string]::IsNullOrEmpty($TZName.FullTZName) -or $TZName.count -gt 1){
            #filter by country
            If($Country){
                $TZName = @($TZName | Where FullTZName -match "\b$Country\b")
                Write-LogEntry ("Searched by Time Zone Country [{0}]. Found: {1} " -f $Country,$TZName.Count) -Source ${CmdletName} -Severity 4
            }
        }

        #if filtering by country comes back with more than one or is empty
        #try to filter by offset (if available)
        If([string]::IsNullOrEmpty($TZName.FullTZName) -or ($TZName.count -gt 1) ){
            If($Offset){
                $TZName = @($TimeZoneItems | Where Offset -eq $Offset)
                Write-LogEntry ("Searched by Time Zone Offset [{0}]. Found: {1} " -f $Offset,$TZName.Count) -Source ${CmdletName} -Severity 4
            }
        }

        #otherwise select first one in list
        If([string]::IsNullOrEmpty($TZName) -or ($TZName.count -gt 1) ){
            return ($TZName | Select -First 1)
            Write-LogEntry ("Unable to filter Time zone from list. Selecting first Time Zone: {0}." -f $TZName.FullTZName) -Source ${CmdletName} -Severity 4
        }
        Else{
            return $TZName
        }

    }
}
#endregion