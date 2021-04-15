#===========================================================================
# Forms Functions - used only for this form
#===========================================================================
#region FUNCTION: Builds dynamic variables in form with alias
Function Get-FormVariable{
    param(
        [string]$Prefix  = $WPFVariable,
        [Parameter(Mandatory = $true, Position=0)]
        [string]$Suffix,
        [switch]$Wildcard

    )

    If($Wildcard){
        Return [array]($Global:AllFormVariables | Where Name -like ($Prefix + "_*" + $Suffix + '*')).Value
    }
    Else{
        Return [array]($Global:AllFormVariables | Where Name -eq ($Prefix + "_" + $Suffix)).Value
    }
}
#endregion

#Alias to filter function to streamline form call
New-Alias -Name WPFVar -Value Get-FormVariable -Force -ErrorAction SilentlyContinue

#region FUNCTION: Action for Next & back button to change tab
function Switch-TabItem {
    param(
        [Parameter(Mandatory = $true, Position=0)]
        [System.Windows.Controls.TabControl]$TabControlObject,
        [Parameter(Mandatory = $true, Position=1,ParameterSetName="index")]
        [int]$increment,
        [Parameter(Mandatory = $true, Position=1,ParameterSetName="name")]
        [string]$name
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    If ($PSCmdlet.ParameterSetName -eq "index") {
        #Add index number to current tab
        $newtab = $TabControlObject.SelectedIndex + $increment
        #ensure number is not greater than tabs
        If ($newtab -ge $TabControlObject.items.count) {
            $newtab=0
        }
        elseif ($newtab -lt 0) {
            $newtab = $TabControlObject.SelectedIndex - 1
        }
        #Set new tab index
        $TabControlObject.SelectedIndex = $newtab

        $message = ("index [{0}]" -f $newtab)
    }
    ElseIf($PSCmdlet.ParameterSetName -eq "name"){
        $newtab = $TabControlObject.items | Where Header -eq $name
        $newtab.IsSelected = $true

        $message = ("name [{0}]" -f $newtab.Header)

    }
    If($DebugPreference){Write-LogEntry ("Changed to tab {0}" -f $message) -Source ${CmdletName} -Severity 5}
}
#endregion

Function Get-UIFieldElement {
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true, Position=0,ParameterSetName="name",ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [object[]]$Name
    )
    Begin{
        ## Get the name of this function
        [string]${CmdletName} = $MyInvocation.MyCommand

        $objects = @()
    }
    Process{
        Foreach($item in $Name){
            If($null -ne (Get-FormVariable $item -Wildcard)){
                $FieldObject = (Get-FormVariable $item -Wildcard)
                $Objects += $FieldObject
                If($DebugPreference){Write-LogEntry ("Found field object [{0}]" -f $FieldObject.Name) -Source ${CmdletName} -Severity 5}
            }
            Else{
                If($DebugPreference){Write-LogEntry ("Field object [{0}] does not exist" -f $FieldObject.Name) -Source ${CmdletName} -Severity 5}
            }
        }

    }
    End{
        Return $Objects
    }
}

#region FUNCTION: Set UI fields to either visible and state
Function Set-UIFieldElement {
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true, Position=0,ParameterSetName="object",ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [object[]]$FieldObject,
        [parameter(Mandatory=$true, Position=0,ParameterSetName="name",ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string[]]$FieldName,
        [boolean]$Enable,
        [boolean]$Visible,
        [string]$Content,
        [string]$text,
        $Source
    )
    Begin{
        ## Get the name of this function
        [string]${CmdletName} = $MyInvocation.MyCommand

        #build field object from name
        If ($PSCmdlet.ParameterSetName -eq "name")
        {
            $FieldObject = @()
            $FieldObject = Get-UIFieldElement -Name $FieldName
        }

        #set visable values
        switch($Visible)
        {
            $true  {$SetVisible='Visible'}
            $false {$SetVisible='Hidden'}
        }

    }
    Process{
        Try{
            #loop each field object
            Foreach($item in $FieldObject)
            {
                #grab all the parameters
                $Parameters = $PSBoundParameters | Select -ExpandProperty Keys
                #loop each parameter
                Foreach($Parameter in $Parameters)
                {
                    #Determine what each parameter and value is
                    #if parameter is FieldObject of FieldName ignore setting it value
                    Switch($Parameter){
                        'Enable'    {$SetValue=$true;$Property='IsEnabled';$value=$Enable}
                        'Visible'    {$SetValue=$true;$Property='Visibility';$value=$SetVisible}
                        'Content'    {$SetValue=$true;$Property='Content';$value=$Content}
                        'Text'    {$SetValue=$true;$Property='Text';$value=$Text}
                        'Source'    {$SetValue=$true;$Property='Source';$value=$Source}
                        default     {$SetValue=$false;}
                    }

                    If($SetValue){
                       # Write-Host ('Parameter value is: {0}' -f $value)
                        If( $item.$Property -ne $value )
                        {
                            $item.$Property = $value
                            If($DebugPreference){Write-LogEntry ("Object [{0}] {1} property is changed to [{2}]" -f $item.Name,$Property,$Value) -Source ${CmdletName} -Severity 5}
                        }
                        Else
                        {
                            If($DebugPreference){Write-LogEntry ("Object [{0}] {1} property already set to [{2}]" -f $item.Name,$Property,$Value) -Source ${CmdletName} -Severity 5}
                        }
                    }
                }#endloop each parameter
            }#endloop each field object
        }
        Catch{
            Return $_.Exception.Message
        }
    }
}
#endregion


Function Enable-TabControl {
    param(
        [int]$TabNumber,
        [switch]$FlipButtons,
        [switch]$ReturnActiveBtn
    )

    #enable Tab
    (WPFVar "Tab$TabNumber") | Set-UIFieldElement -Visible:$true

    #flip buttons on before tab
    If($FlipButtons){
        $ButtonNum = $TabNumber
        #enable begin for the tab
        (WPFVar "btnTab$ButtonNum`Begin") | Set-UIFieldElement -Visible:$True -ErrorAction SilentlyContinue
        DO{
            If($ButtonNum -gt 1){(WPFVar "btnTab$ButtonNum`Back") | Set-UIFieldElement -Visible:$True -ErrorAction SilentlyContinue}
            $ButtonNum--
            (WPFVar "btnTab$ButtonNum`Begin") | Set-UIFieldElement -Visible:$False -ErrorAction SilentlyContinue
            (WPFVar "btnTab$ButtonNum`Next") | Set-UIFieldElement -Visible:$true -ErrorAction SilentlyContinue
        } Until ($ButtonNum -eq 1)

    }
    if($ReturnActiveBtn){
        return (WPFVar "Tab$TabNumber`Begin")
    }
}
#endregion

#region FUNCTION: Enable app tab for singlepage
Function Enable-AppTab {
    param(
        [int]$TabNumber = 2,
        [switch]$FlipButtons,
        [switch]$ReturnActiveBtn
    )

    #enable Tab
    (WPFVar "Tab$TabNumber") | Set-UIFieldElement -Visible:$true

    #getfirsttab
    $MainTab = $TabNumber - 1

    #flip buttons on before tab
    If($FlipButtons){
        #enable begin for the tab
        (WPFVar "btnTab$TabNumber`Begin") | Set-UIFieldElement -Visible:$True
        (WPFVar "btnTab$TabNumber`Back") | Set-UIFieldElement -Visible:$True
        (WPFVar "btnTab$MainTab`Begin") | Set-UIFieldElement -Visible:$False
        (WPFVar "btnTab$MainTab`Next") | Set-UIFieldElement -Visible:$True

        #Allow to navigate the tabs with buttons
        (WPFVar "btnTab$TabNumber`Back").Add_Click({Switch-TabItem -Tab (WPFVar "TabControl") -increment -1})
        (WPFVar "btnTab$MainTab`Next").Add_Click({Switch-TabItem -Tab (WPFVar "TabControl") -increment 1})
    }
    if($ReturnActiveBtn){
        return (WPFVar "btnTab$TabNumber`Begin")
    }
}
#endregion

#region FUNCTION: Disable app tab for singlepage
Function Disable-AppTab {
    param(
        [int]$TabNumber = 2,
        [switch]$FlipButtons,
        [switch]$ReturnActiveBtn
    )

    #enable Tab
    (WPFVar "Tab$TabNumber") | Set-UIFieldElement -Visible:$false

    #getfirsttab
    $MainTab = $TabNumber - 1

    #flip buttons on before tab
    If($FlipButtons){
        #enable begin for the tab
        (WPFVar "btnTab$TabNumber`Begin") | Set-UIFieldElement -Visible:$false
        (WPFVar "btnTab$TabNumber`Back") | Set-UIFieldElement -Visible:$false
        (WPFVar "btnTab$MainTab`Begin") | Set-UIFieldElement -Visible:$True
        (WPFVar "btnTab$MainTab`Next") | Set-UIFieldElement -Visible:$False
    }
    if($ReturnActiveBtn){
        return (WPFVar "btnTab$MainTab`Begin")
    }
}
#endregion

#region FUNCTION: Update app page with applicatons from config
Function Add-AppContent {
    param($AppData)

    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    $a = 0
    #grab the data & build content from it
    Do {
        $a++
        $App = $AppData | Where {$_.id -eq $a}
        If($App){
            If($VerbosePreference){Write-LogEntry ("Updating App [{0}] to [{1}]" -f (WPFVar "txtAppName_$($App.id)").Text,$App.Name) -Source ${CmdletName}}
            (WPFVar "tglAppInstall_$($App.id)").Visibility = 'Visible'
            (WPFVar "txtAppName_$($App.id)").Text = $App.Name
            If($App.DefaultEnabled -eq 'Yes'){
                (WPFVar "tglAppInstall_$($App.id)").IsChecked = $True
                Write-LogEntry ("Enabled App [{0}] by default" -f ${CmdletName},$App.Name) -Source ${CmdletName} -Severity 4
            }
            Else{
                (WPFVar "tglAppInstall_$($App.id)").IsChecked = $False
            }

            If($App.Desc){
                (WPFVar "txtAppDesc_$($App.id)").Visibility = 'Visible'
                (WPFVar "txtAppDesc_$($App.id)").Text = $App.Desc
            }
            Else{
                (WPFVar "txtAppDesc_$($App.id)").Visibility = 'Hidden'
            }
            #$OOBEUIWPF_tglAppInstall_1.IsChecked
        }

    } Until ($a -eq 8) #end data loop

}
#endregion

#region FUNCTION: pre-populate all time zones in dropdown
Function Add-UITimeZoneList{
    param(
        $TZCsvList = "$ResourcePath\TimeZonesIndex.csv",
        [Parameter(Mandatory = $true, Position=0)]
        $TimeZoneField,
        [switch]$ReturnList
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    #Get all timezones and format the properties
    If(Test-Path $TZCsvList -ErrorAction SilentlyContinue){
        $TZList = Import-Csv $TZCsvList -ErrorAction Stop | Select Index,TimeZone,@{l='StandardName';e={($_.TimeZone -replace '^.?\((.*?)\)','').Trim()}},UTC
    }Else{
        $TZList = Get-TimeZone -ListAvailable | Select @{l='TimeZone';e='DisplayName'},StandardName,@{l='UTC';e={$_.DisplayName -match ".?\((.*?)\).*" | Out-Null;$matches[1]}}
    }
    
    # populate it to combo box
    $TZList.TimeZone | ForEach-object {$TimeZoneField.Items.Add($_);
        If($VerbosePreference){Write-LogEntry ("Adding timezone to selection list: {0}" -f $_) -Source ${CmdletName} -Severity 1}} | Out-Null

    If($ReturnList){
        return $TZList
    }
}
#endregion

#region FUNCTION: pre-populate all domain FQDN in dropdown
Function Add-UIDomainNameList{
    param(
        [Parameter(Mandatory = $true, Position=0)]
        [object[]]$DomainList,
        [Parameter(Mandatory = $true, Position=1)]
        $DomainNameField,
        [string]$TypeFilter
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    #pre-populate all domain FQDN in dropdown
    $DomainList | Where Type -ne $TypeFilter | ForEach-object {$DomainNameField.Items.Add($_);
        If($VerbosePreference){Write-LogEntry ("Adding domains to selection list: {0}" -f $_) -Source ${CmdletName} -Severity 1}} | Out-Null
}
#endregion

#region FUNCTION: pre-populate all Sites in dropdown
Function Add-UISiteList{
    param(
        [Parameter(Mandatory = $true, Position=0)]
        $SiteList,
        [Parameter(Mandatory = $false, Position=1)]
        $SiteListField,
        [string]$DisplayFormat = '<id> - <Baselocation> [<SiteCode>]',
        [switch]$ReturnList
    )
    Begin{
        ## Get the name of this function
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

        #capture display format to ensure it doesn't get overwritten
        $DisplayReset = $DisplayFormat.ToLower()

        #test
        #$item = @{id='BRGG';Baselocation='FortBragg, nc';SiteCode='BRG'}
        #$SiteList = $MenuLocaleSiteList
        $DisplayName = @()
    }
    Process{
        Write-LogEntry ("Processing {0} sites" -f $SiteList.Count) -Source ${CmdletName} -Severity 4
        #loop through each site
        Foreach($site in $SiteList)
        {
            If($VerbosePreference){Write-LogEntry ("Processing {0} site..." -f $site.ID) -Source ${CmdletName} -Severity 4}
            #loop through each property
            foreach($property in $Site.PsObject.Properties){
                $Name = $property.Name.ToLower()
                $Value = $property.Value
                If($VerbosePreference){Write-LogEntry ("Searching Property [{0}] with value [{1}] against display format [{2}]" -f $Name,$Value,$DisplayFormat.ToLower()) -Source ${CmdletName} -Severity 4}
                If($DisplayFormat.ToLower() -match "<$Name>"){
                    #build display format with new values
                    $DisplayFormat = $DisplayFormat -replace $Matches[0],$Value
                    If($VerbosePreference){Write-LogEntry ("Matched property [{0}] with display format part [{1}], replaced with value [{2}]" -f $Name,$Matches[0],$Value) -Source ${CmdletName} -Severity 4}
                }
                Else{
                    $Matches = $null
                    If($VerbosePreference){Write-LogEntry ("Display format does not match property [{0}]" -f $Name) -Source ${CmdletName} -Severity 4}
                    Continue;
                }
            }

            #Build display name list
            $DisplayName += $DisplayFormat.Trim()

            #reset display back to original, then repeat for each site
            $DisplayFormat = $DisplayReset
        }

        #populate site list
        $DisplayName | ForEach-object {$SiteListField.Items.Add($_);
            If($VerbosePreference){Write-LogEntry ("Adding Site Id's to selection list: {0}" -f $_) -Source ${CmdletName} -Severity 1} } | Out-Null
    }
    End{
        If($ReturnList){
            return $DisplayName
        }
    }
}
#endregion


#region FUNCTION: Update WPF Fields using site ID Selection
Function Update-UILocaleFields {
    <#
    $SiteList=$MenuLocaleSiteList
    $SiteID=$SiteInfo.SiteID
    $UpdateSiteListObject=(WPFVar "inputCmbSiteList")
    $UpdateTimeZoneObject=(WPFVar "inputCmbTimeZoneList")
    $UpdateSiteCodeObject=(WPFVar "txtSiteCode")
    $UpdateDomainObject=(WPFVar "inputCmbDomainWorkgroupName")
    $ReturnProperties=$true
    #>
    param(
        [Parameter(Mandatory = $false, Position=0)]
        [object[]]$SiteList,
        [Parameter(Mandatory = $false, Position=1,ParameterSetName="site")]
        [string]$SiteID,
        [Parameter(Mandatory = $false, Position=1,ParameterSetName="base")]
        [string]$Base,
        $UpdateSiteListObject,
        $UpdateTimeZoneObject,
        [System.Windows.Controls.TextBox]$UpdateSiteCodeObject,
        #[System.Windows.Controls.TextBox]$UpdateDomainObject,
        $UpdateDomainObject,
        [switch]$ReturnProperties
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    If ($PSCmdlet.ParameterSetName -eq "site") {
        $MemberProperty = 'ID'
        $SearchCriteria = $SiteID
        $MessageSubject = "Site Id"
    }

    If($PSCmdlet.ParameterSetName -eq "base"){
        $MemberProperty = 'BaseLocation'
        $SearchCriteria = $Base
        $MessageSubject = "Base Location"
    }

    $MatchedLocale = $null
    Write-LogEntry ("Searching for {0} [{1}]" -f $MessageSubject,$SearchCriteria) -Source ${CmdletName}
    Try{
        #get current site list (from config) where the name matches
        $MatchedLocale = $SiteList | Where {$_.$MemberProperty -eq $SearchCriteria}

        #if site exists in list
        If($null -ne $MatchedLocale){
            #Update the Site field by search criteria
            $UpdateSiteListObject.SelectedItem = ($UpdateSiteListObject.Items | Where {$_ -match $SearchCriteria})
            $UpdateSiteListObject.Items.Refresh();

            If($VerbosePreference){Write-LogEntry ("Found match site from locale list: {0}" -f $MatchedLocale.BaseLocation) -Source ${CmdletName}}
            #grab the current time based on abbreviation
            $TimeZoneBySite = ConvertFrom-TimeZoneAbbreviation -abbr $MatchedLocale.TZ -Country $MatchedLocale.Region
            Write-LogEntry ("Time Zone abbreviation found [{0}], selecting time zone: [{1}]" -f $MatchedLocale.TZ,$TimeZoneBySite.FullTZName) -Source ${CmdletName}

            $UpdateTimeZoneObject.SelectedItem = $TimeZoneBySite.FullTZName

            #$MatchedLocale.Domain
            #$UpdateDomainObject.Text = $MatchedLocale.Domain

            #update site code
            $UpdateSiteCodeObject.text = $MatchedLocale.SiteCode
        }
        Else{
            Write-LogEntry ("No site match was found from locale list using search criteria: {0} [{1}]" -f $MessageSubject,$SearchCriteria) -Source ${CmdletName} -Severity 3
        }
    }
    Catch{
        If($VerbosePreference){Write-LogEntry ("No {0} [{1}] found, Breaking search..." -f $MessageSubject,$SearchCriteria) -Source ${CmdletName}}
    }
    Finally{
        If($MatchedLocale -and $ReturnProperties){

            $outputObject = New-Object -TypeName PSObject
            $memberParam=@{
                InputObject=$outputObject;
                MemberType='NoteProperty';
                Force=$true;
                }
                Add-Member @memberParam -Name SiteCode -Value $MatchedLocale.SiteCode
                Add-Member @memberParam -Name TimeZoneDisplay -Value $TimeZoneBySite.FullTZName
                Add-Member @memberParam -Name TimeZoneOSDName -Value $TimeZoneBySite.TZName
                Add-Member @memberParam -Name Domain -Value $MatchedLocale.Domain


                If($DebugPreference){Write-LogEntry ("Sitecode: [{0}], TimeZoneDisplay: [{1}], TimeZoneOSDName: [{2}], Domain: [{3}]" `
                         -f $outputObject.SiteCode,$TimeZoneBySite.FullTZName,$TimeZoneBySite.TZName,$MatchedLocale.Domain) -Source ${CmdletName} -Severity 5}
            $outputObject
        }
    }
}
#endregion

#region FUNCTION: Updates domain based on classification
Function Update-UIDomainFields{
   param(
        $SiteList = $MenuLocaleSiteList,
        $ClassificationList = $MenuLocaleClassificationList,
        $DomainList = $MenuLocaleDomainList,
        $DomainOUlist = $MenuLocaleDomainOUList,
        [string]$FilterDomainType = $MenuFilterAccountDomainType,
        [string]$FilterDomainProperty = $MenuFilterDomainProperty,
        [string]$ClassificationProperty,
        [string]$FilterLocale,
        [string]$FilterClass,
        [bool]$WorkgroupOption
    )

    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    #split Class value from name into array to determine if a word matches the same from the classification list
    $FoundClassMark = (Compare-Object -ReferenceObject $ClassificationList.Type -DifferenceObject ($FilterClass -split '\s') -IncludeEqual -ExcludeDifferent).InputObject

    #Identify the current classification Type
    $identifiedClass = $ClassificationList | Where {$_.Type -eq $FoundClassMark}

    #get current site list (from config) where the name matches
    $SiteDomain = $SiteList | Where {$_.BaseLocation -eq $FilterLocale}

    Write-LogEntry ("Searching [{0}] to determine domain details..." -f $FilterLocale) -Source ${CmdletName}

    #filter to just classification type Domains
    #dynamically append filter domain type if value exists
    If($FilterDomainProperty){$filterParam = [scriptblock]::Create("`$_.$FilterDomainProperty -eq `$identifiedClass.ID")}
    #build scriptblock for domain type
    If ($FilterDomainType) {
        $filterDomainParam = [scriptblock]::Create(" -and `$_.Type -ne `$FilterDomainType")
        $filterParam = [scriptblock]::Create($filterParam.ToString() + $filterDomainParam.ToString())
    }
    #if a filter exist, use it...
    If($filterParam){
        $FilteredDomains = $DomainList | Where-Object -FilterScript $filterParam
    }
    Else{
        $FilteredDomains = $DomainList
    }

    #Add workgroup if allowed
    If([bool]$WorkgroupOption)
    {
        $FilteredDomains += [PSCustomObject]@{Name='Workgroup';FQDN='Workgroup';Classid=$identifiedClass.ID;Type="Join"}
    }

    #poupulate all domain FQDN in dropdown based on classisification
    (WPFVar "inputCmbDomainWorkgroupName").Items.Clear();
    $FilteredDomains.FQDN | ForEach-object {(WPFVar "inputCmbDomainWorkgroupName").Items.Add($_);} | Out-Null

    #identify the filtered domain details associated with site ID domain
    $DomainDetails = $FilteredDomains | Where Name -eq $SiteDomain.Domain

    If($DomainDetails)
    {
        Write-LogEntry ("Found FQDN [{2}] that matched [{0}] under classification [{1}]" -f $SiteDomain.Domain,$identifiedClass.ID,$DomainDetails.FQDN) -Source ${CmdletName} -Severity 4

        #update domain FQDN dropdown
        (WPFVar "inputCmbDomainWorkgroupName").SelectedItem = $DomainDetails.FQDN

        #update Join to Domain Field to FQDN
        (WPFVar "inputTxtDomainWorkgroupName").text = $DomainDetails.FQDN

        #populate domain name for Domain account
        If($FilterDomainType) {
            Write-LogEntry ("Filtering domain by classification [{0}] & type [{1}]" -f $identifiedClass.ID,$FilterDomainType) -Source ${CmdletName} -Severity 4

            $filterQuery = "`$_.ClassId -eq `$identifiedClass.ID -and `$_.Type -eq `$FilterDomainType"
            $filterParam = [scriptblock]::Create($filterQuery)
            $DomainDetails = $DomainList | Where-Object -FilterScript $filterParam | Select -First 1
            If($DomainDetails){If($VerbosePreference){Write-LogEntry ("Found domain [{0}]" -f $DomainDetails.FQDN) -Source ${CmdletName}}}
        }

        #grab current value & just replace the domain value before \
        $CurrentUserValue = (WPFVar "inputTxtDomainAdminLocalAccount").text
        $OldDomain = [regex]::Match($CurrentUserValue,'^[^\\]*').Value
        If(!$OldDomain){$AddSlash = '\'}Else{$AddSlash = ''}

        #replace domain with new domain
        (WPFVar "inputTxtDomainAdminLocalAccount").text = $DomainDetails.Name + '\'
        (WPFVar "inputTxtDomainAdminLocalAccount").Foreground = 'Black'


        #clear items out first
        (WPFVar "inputCmbDomainOU").Items.Clear();
        #filter domain OU based on domain name & classification
        $FilteredDomainOU = $DomainOUlist | Where {($_.Domain -eq $SiteDomain.Domain) -and ($_.ClassId -eq $identifiedClass.ID)}

        #Populate Domain OU's if found
        If($FilteredDomainOU){
            Foreach($item in $FilteredDomainOU){
                $OUdisplayname = $item.Name + ' (' + $item.LDAPOU +')'
                (WPFVar "inputCmbDomainOU").Items.Add($OUdisplayname) | Out-Null
                If($VerbosePreference){Write-LogEntry ("Adding OU to List: {0}" -f $OUdisplayname) -Source ${CmdletName}}
            }
        }

        #show the classification color
        If( ($ClassificationProperty -eq 'None') -or ([string]::IsNullOrEmpty($ClassificationProperty)) ){
            # do nothing
        }
        Else{
            #update classification dropdown/textbox
            (WPFVar "txtClassification").Text = ($identifiedClass.$ClassificationProperty)
            (WPFVar "grdClassification").Visibility = 'Visible'
            (WPFVar "txtClassification").IsReadOnly = $true
            (WPFVar "txtClassification").Background = $identifiedClass.Color
            If($VerbosePreference){Write-LogEntry ("Adding Classification to List: {0}" -f ($identifiedClass.$ClassificationProperty)) -Source ${CmdletName}}
        }
    }
    Else
    {
        Write-LogEntry ("No Full Qualified Domains Names were found that matched [{0}] under classification [{1}]" -f $SiteDomain.Domain,$identifiedClass.ID) -Source ${CmdletName} -Severity 3
    }

}
#endregion

#region FUNCTION: grabs the computer name based on site selection
Function Get-ComputerNameLocale{

    param(
        [System.Windows.Controls.TextBox]$ComputerNameObject,
        $SiteList,
        [switch]$ReturnDetails
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    If( $ComputerNameObject.Text -match ($SiteList.ID -join '|') ){
        $SiteID = $Matches[0]

        #get starting position of site code and length of site id
        $CharPosition = ($ComputerNameObject.Text | Select-String $SiteID).Matches.Index
        $SiteIDLength = $SiteID.Length

        #updates the identity locale as well
        $BaseLocation = ($SiteList | Where ID -eq $SiteID).BaseLocation
        #If($IDFieldObject)
        #{
            $BaseLocation = ($SiteList | Where ID -eq $SiteID).BaseLocation
        #}
    }

    If($ReturnDetails){
        $outputObject = New-Object -TypeName PSObject
        $memberParam=@{
            InputObject=$outputObject;
            MemberType='NoteProperty';
            Force=$true;
        }
        # what to return? If validation is false;
        # return that no mater what, otherwise return what specified
        Add-Member @memberParam -Name 'CharPosition' -Value $CharPosition
        Add-Member @memberParam -Name 'SiteIDLength' -Value $SiteIDLength
        Add-Member @memberParam -Name 'SiteID' -Value $SiteID
        Add-Member @memberParam -Name 'BaseLocation' -Value $BaseLocation

        return $outputObject
    }
}
#endregion


#region FUNCTION: Updates the computer name based on site selection
Function Update-ComputerNameLocale{
    param(
        $SiteList,
        $SiteLocale,
        [System.Windows.Controls.TextBox]$ComputerNameObject = (WPFVar "inputTxtComputerName"),
        [System.Windows.Controls.TextBox]$IDFieldObject = (WPFVar 'txtID3'),
        $StartPosition,
        [bool]$UpdateComputeName,
        [switch]$ReturnSiteInfo
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    <# Test Data
        $SiteList=$MenuLocaleSiteList
        $SiteLocale=(WPFVar "inputCmbSiteList").SelectedItem
        $StartPosition=$Global:ComputerNameDetails.CharPosition
        $UpdateComputeName=$True
        $ReturnSiteInfo=$True
    #>

    #parse out the site ID from Site Locale (-)
    $NewSiteID = $SiteLocale.Split('-')[0].Trim()

    #get starting position of site code and length of site id
    If($null -ne $StartPosition){
        $CharPosition = $StartPosition
    }Else{
        $CharPosition = ($ComputerNameObject.Text | Select-String $NewSiteID).Matches.Index
    }
    $SiteIDLength = $NewSiteID.Length

    #if the computername is at least 6 chars long.
    If( ($ComputerNameObject.Text).Length -gt ($CharPosition + $SiteIDLength))
    {
        $CurrentSiteID = ($ComputerNameObject.Text).Substring($CharPosition,$SiteIDLength)
        If($UpdateComputeName)
        {
            $ComputerNameObject.Text = $ComputerNameObject.Text -replace $CurrentSiteID,$NewSiteID
            If($DebugPreference){Write-LogEntry  ("Updated device name site locale from [{0}] to [{1}]" -f $CurrentSiteID,$NewSiteID) -Source ${CmdletName} -Severity 5}
        }
    }
    #updates the identity locale as well
    If($IDFieldObject)
    {
        $BaseLocation = ($SiteList | Where ID -eq $NewSiteID).BaseLocation
        $IDFieldObject.text = $BaseLocation
    }

    If($ReturnSiteInfo){
        $outputObject = New-Object -TypeName PSObject
        $memberParam=@{
            InputObject=$outputObject;
            MemberType='NoteProperty';
            Force=$true;
        }
        # what to return? If validation is false;
        # return that no mater what, otherwise return what specified
        Add-Member @memberParam -Name 'SiteID' -Value $NewSiteID
        Add-Member @memberParam -Name 'BaseLocation' -Value $BaseLocation
        return $outputObject
    }
}
#endregion

#region FUNCTION: Updates the computer name based on site selection
#NOT USED. Testing...
Function Compare-ComputerNameLocale{
    param(
        $SiteList = $MenuLocaleSiteList,
        [Parameter(Mandatory, Position=0, ParameterSetName="Locale")]
        [string]$UpdateSiteLocaleTo,
        [Parameter(Mandatory, Position=0, ParameterSetName="ID")]
        [string]$UpdateSiteIdTo,
        [Parameter(Mandatory, Position=1, ParameterSetName="Locale")]
        [string]$CurrentSiteLocale,
        [Parameter(Mandatory, Position=1, ParameterSetName="ID")]
        [string]$CurrentSiteID,
        [int]$StartPosition,
        [System.Windows.Controls.TextBox]$ComputerNameObject = (WPFVar "inputTxtComputerName"),
        [System.Windows.Controls.TextBox]$IDFieldObject = (WPFVar 'txtID3')
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    #grab the current computername
    $CurrentComputerName = $ComputerNameObject.Text

    #parse out the site ID from Site Locale seelected
    if($PSCmdlet.ParameterSetName -eq "Locale"){
        $NewSiteID = ($UpdateSiteLocaleTo -split '-')[0].Trim()
        #$NewSiteID = [Regex]::Match($SiteLocale,".{1,$SiteIDLength}").Value
        $OldSiteID = ($CurrentSiteLocale -split '-')[0].Trim()
    }

    If($PSCmdlet.ParameterSetName -eq "ID"){
        $NewSiteID = $UpdateSiteIdTo
        $OldSiteID = $CurrentSiteID
    }

    Write-LogEntry ("Comparing device name [{0}] to SiteID [{1}]" -f $CurrentComputerName,$NewSiteID) -Source ${CmdletName} -Severity 4
    #if the computername is at least 6 chars long.
    #If($CurrentComputerName.Length -gt $NewSiteID.Length)
    If($CurrentComputerName -notmatch $NewSiteID)
    {
        #$CurrentSiteID = ($ComputerNameObject.Text).Substring(2,$NewSiteID.Length)
        $ComputerNameObject.Text = $CurrentComputerName -replace $OldSiteID,$NewSiteID
        $ComputerNameObject.Text.Refresh();
        Write-LogEntry ("Updated device name site locale from [{0}] to [{1}]" -f $OldSiteID,$NewSiteID) -Source ${CmdletName} -Severity 4
    }
    Else{
        Write-LogEntry ("Device name [{0}] matches Site ID [{1}]" -f $CurrentComputerName,$NewSiteID) -Source ${CmdletName} -Severity 4
    }
    #updates the identity locale as well
    If($IDFieldObject)
    {
        Write-LogEntry ("Searching location identifier for Site ID [{0}]" -f $SiteID) -Source ${CmdletName} -Severity 4
        $BaseLocation = ($SiteList | Where ID -eq $NewSiteID).BaseLocation
        $IDFieldObject.text = $BaseLocation
        Write-LogEntry ("Updated location identifier [{0}] to [{1}]" -f $IDFieldObject.Name,$BaseLocation) -Source ${CmdletName} -Severity 4
    }
}
#endregion

#region FUNCTION: Removed highlights border on objects
Function Reset-HighlightedFields {
    param($Object,[switch]$ClearErrorMessage)
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    If($ClearErrorMessage){
        Invoke-UIMessage -Message $Null -OutputErrorObject (WPFVar "txtError") -Type Info
    }

    Try{
        Foreach($item in $Object){
            If($item.BorderThickness.Bottom -gt 0)
            {
                $item.BorderThickness = "0"
                If($DebugPreference){Write-LogEntry ("Object [{0}] was reset" -f ${CmdletName},$item.Name) -Source ${CmdletName} -Severity 5}
            }
            Else{
                If($DebugPreference){Write-LogEntry ("Object [{0}] did not need reset" -f ${CmdletName},$item.Name) -Source ${CmdletName} -Severity 5}
            }
        }
    }Catch{}
}
#endregion

#region FUNCTION: Clears the other fields in UI
Function Clear-UIField {
    param(
        [string]$Name,
        [ValidateSet('Input', 'List', 'Grid','label')]
        [string]$Type,
        [switch]$Hide
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    #get each WPF object that matches the id
    $UIFieldName = WPFVar $Name -Wildcard
    Switch($Type){
        'Input' {$property = 'Text'}
        'List'  {$property = 'Content'}
        'Grid'  {$property = 'Grid'}
        'label'  {$property = 'Content'}
    }

    If($UIFieldName){
        Try{
            #clear value
            $UIFieldName.$property = ''
        }
        Catch{

        }
        Finally{
            #if set, hide the label & value block
            If($Hide)
            {
                $UIFieldName.Visibility = 'Hidden'
                If($DebugPreference){Write-LogEntry ("Cleared & Hide field: [{0}]" -f $UIFieldName.Name) -Source ${CmdletName} -Severity 5}
            }
            Else{
                If($DebugPreference){Write-LogEntry ("Cleared field: [{0}]" -f $UIFieldName.Name) -Source ${CmdletName} -Severity 5}
            }
        }
    }
}
#endregion

#region FUNCTION: Flips Combobox to Textbox (only suppos like fields)
Function ConvertTo-UITextBox{
    param(
        [System.Windows.Controls.ComboBox]$ComboBox
    )
    $ConvertCmbtoTxt = $ComboBox.Name -replace 'cmb','txt'

    (WPFVar $ComboBox.Name) | Set-UIFieldElement -Visible:$False
    If((WPFVar $ConvertCmbtoTxt))
    {
        (WPFVar $ConvertCmbtoTxt) | Set-UIFieldElement -Visible:$True
    }

}
#endregion

#region FUNCTION: Flips Textbox to Combobox (only suppos like fields)
Function ConvertTo-UIComboBox{
    param(
        [System.Windows.Controls.TextBox]$TextBox
    )
    $ConvertTxtToCmb = $TextBox.Name -replace 'txt','cmb'

    (WPFVar $TextBox.Name) | Set-UIFieldElement -Visible:$False
    If((WPFVar $ConvertTxtToCmb))
    {
        (WPFVar $ConvertTxtToCmb) | Set-UIFieldElement -Visible:$True
    }
}
#endregion

#region FUNCTION: Clears the Identify information in UI
Function Clear-UIIdentityFields {
    param(
        $IDList = $NameStandardRuleSets,
        [switch]$Hide
    )

    #loop through each ID
    Foreach($item in $IDList)
    {
        #get each WPF object that matches the id
        $UIFieldName = WPFVar ('txt' + $item.id) -Wildcard
        $UIFieldLabel = WPFVar ('lbl' + $item.id) -Wildcard

        #clear value
        $UIFieldName.Text = ''

        #if the value is null, just display ID as value
        If([string]::IsNullOrEmpty($UIFieldName.Text)){$FieldValue = $item.id}Else{$FieldValue = $UIFieldName.text}
        #if set, hide the label & value block
        If($Hide)
        {
            $UIFieldLabel.Visibility = 'Hidden'
            $UIFieldName.Visibility = 'Hidden'
            If($DebugPreference){Write-LogEntry ("Cleared & Hide field: [{0}]" -f $FieldValue) -Source ${CmdletName} -Severity 5}
        }
        Else{
            If($DebugPreference){Write-LogEntry ("Cleared field: [{0}]" -f $FieldValue) -Source ${CmdletName} -Severity 5}
        }

    } #end loop of ID's
}
#endregion


#region FUNCTION: updates the Identify information in UI
Function Update-UIIdentityFields {
    param(
        $RulesList = $NameStandardRuleSets,
        $FieldsTable,
        [switch]$ClearValues
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    #clear all identity rules
    If($ClearValues){Clear-UIIdentityFields -Hide}

    $objMembers = $FieldsTable.psobject.members | where-object membertype -like 'noteproperty'

    #create an empty hashtable to add objects to.
    $HashTable = @{}
    foreach ($obj in $objMembers) {
        $HashTable.add( "$($obj.name)", "$($obj.Value)")
    }

    #parse thehashtable
    Foreach($item in $HashTable.Keys){
        Try{
            #grab the key
            $UIFieldlabel = WPFVar ('lbl' + $item) -Wildcard
            $UIFieldText = WPFVar ('txt' + $item) -Wildcard

            #grab the value
            $UIFieldValue = $HashTable.Item($item)

            #grab name from rule
            $RuleSet = ($RulesList | Where Id -eq $item)
            $UIFieldlabelName = $RuleSet.Name
            [Boolean]$MustExist = [Boolean]::Parse($RuleSet.MustExist)

            #populate label if required (even though it may be empty)
            If($MustExist){
                $UIFieldlabel.Content = $UIFieldlabelName
                $UIFieldLabel.Visibility = 'Visible'
            }

            #if there is a value fill it
            If($UIFieldValue)
            {
                #make sure lbl & txt field are visible
                $UIFieldText.Visibility = 'Visible'
                $UIFieldlabel.Visibility = 'Visible'

                #update display name
                $UIFieldlabel.Content = $UIFieldlabelName
                $UIFieldText.Text = $UIFieldValue
                If($DebugPreference){Write-LogEntry ("Updated field: [{0}: {1}] to [{2}]" -f $item,$UIFieldlabelName,$UIFieldValue) -Source ${CmdletName} -Severity 5}
            }
        }
        Catch{
            #just in case there is not field object that exists
        }

    }
}
#endregion



#region FUNCTION: Throw errors to Form's Output field
Function Invoke-UIMessage {
    Param(
        [String]$Message,
        [ValidateSet('Warning', 'Error', 'Info','OK')]
        [String]$Type = 'Error',
        $HighlightObject,
        [System.Windows.Controls.TextBox]$OutputErrorObject,
        [switch]$ReturnBool
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    switch($Type){
        'Warning'   {$BgColor = 'Orange';$FgColor='Black';$Severity = 2}
        'Error'     {$BgColor = 'Red';$FgColor='Black';$Severity = 3}
        'Info'      {$BgColor = 'Green';$FgColor='Black';$Severity = 1}
        'OK'      {$BgColor = 'Black';$FgColor='White';$Severity = 0}
    }
    #default to true for retune value
    $ReturnValue = $true

    Try{
        If($Message.Length -gt 0){
            #put a red border around input
            $HighlightObject.BorderThickness = "2"
            $HighlightObject.BorderBrush = $BgColor

            #show error message
            $OutputErrorObject.Visibility = 'Visible'
            $OutputErrorObject.BorderBrush = $FgColor
            $OutputErrorObject.Background = $BgColor
            $OutputErrorObject.Foreground = $FgColor
            $OutputErrorObject.Text = $Message

            If($DebugPreference){Write-LogEntry ("{1} : {0}" -f $Message,$Type) -Source ${CmdletName} -Severity $Severity}
            $ReturnValue = $false
        }
        Else{
            $OutputErrorObject.Visibility = 'Hidden'
            $ReturnValue = $true
        }
    }
    Catch{
        If($DebugPreference){Write-LogEntry ("Unable to display {1} message [{0}] in UI..." -f $Message,$Type) -Source ${CmdletName} -Severity 3}
        If($message.Length -gt 0){$ReturnValue = $false}Else{$ReturnValue = $true}
    }

    If($ReturnBool){
        return $ReturnValue
    }
}
#endregion


#region FUNCTION: Validate ComputerName input & throw errors
Function Confirm-ComputerNameField {
    [CmdletBinding()]
    param(
        [System.Windows.Controls.TextBox]$ComputerNameObject,
        [System.Windows.Controls.TextBox]$OutputErrorObject,
        [string]$ExcludeExample,
        [Boolean]$ValidateAgainstRules = $MenuEnableValidateNameRules
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    Write-LogEntry ("Comparing device name [{0}] against standard name restrictions..." -f $ComputerNameObject.Text) -Source ${CmdletName} -Severity 4

    #set variables to initial state
    $Validation = $true
    $ErrorMessage = $null

    if ($ComputerNameObject.text -eq $ExcludeExample){$ErrorMessage = ("Enter a valid device name")}

    Elseif ($ComputerNameObject.text.length -eq 0){$ErrorMessage = ("Enter a valid device name")}

    Elseif ($ComputerNameObject.text.length -lt 5) {$ErrorMessage = ("Device name cannot less than 5 characters!")}

    Elseif ($ComputerNameObject.text.length -gt 15) {$ErrorMessage = ("Device name cannot be more than 15 characters!")}

    #Validation Rule for computer names
    Elseif ($ComputerNameObject.text -match "^[-_]|[^a-zA-Z0-9-_]"){$ErrorMessage = ("Device name has invalid character(s) [{0}]." -f $Matches[0])}

    $Validation = Invoke-UIMessage -Message $ErrorMessage -HighlightObject $ComputerNameObject -OutputErrorObject $OutputErrorObject -Type Error -ReturnBool
    return $Validation
}
#endregion

#region FUNCTION: Validate form inputs & throw errors
Function Confirm-AdminCredFields {
    param(
        [System.Windows.Controls.TextBox]$UserNameObject,
        [System.Windows.Controls.TextBox]$DomainNameObject,
        [System.Windows.Controls.PasswordBox]$PasswordObject,
        [System.Windows.Controls.PasswordBox]$ConfirmedPasswordObject,
        [System.Windows.Controls.TextBox]$OutputErrorObject,
        [Boolean]$WorkgroupAllowed
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    #set variables to initial state
    #Set validations to True, but If any point admin cred comes back with error, Validation will be false
    $Validation = $true
    $PasswordAssociation = "local admin"
    $PasswordCheck = 'password'

    #build message prefix
    If($WorkgroupAllowed){$MessagePrefix = 'Domain name or workgroup'}Else{$MessagePrefix = 'Domain name'}
    Write-LogEntry ("Validating credentials for {0}..." -f $MessagePrefix) -Source ${CmdletName} -Severity 1

    #Domain name filed can't be blank
    If([string]::IsNullOrEmpty($DomainNameObject.Text))
    {
        $Validation = Invoke-UIMessage -Message ("{0} must be provided" -f $MessagePrefix) -HighlightObject $DomainNameObject -OutputErrorObject $OutputErrorObject -Type Error -ReturnBool
    }
    # If workgroup not allowed
    ElseIf( ($DomainNameObject.Text -eq 'Workgroup') -and ($WorkgroupAllowed -eq $false) ){
        #in a workgroup the domain account field is used as workgroup name
        $Validation = Invoke-UIMessage -Message "A Workgroup is not allowed, specify a domain name" -HighlightObject $DomainNameObject -OutputErrorObject $OutputErrorObject -Type Error -ReturnBool
    }
    #check if name is workgrou
    ElseIf($DomainNameObject.Text -eq 'Workgroup'){
        #in a workgroup the domain account field is used as workgroup name
        If([string]::IsNullOrEmpty($UserNameObject.Text)){
            $Validation = Invoke-UIMessage -Message "A Workgroup name must be provided" -HighlightObject $UserNameObject -OutputErrorObject $OutputErrorObject -Type Error -ReturnBool
        }
        ElseIf(-not(Confirm-WorkgroupName $UserNameObject.Text)){
            $Validation = Invoke-UIMessage -Message "Workgroup name is not valid" -HighlightObject $UserNameObject -OutputErrorObject $OutputErrorObject -Type Error -ReturnBool
        }
    }
    # If other than workgroup is filled in, assume its a domain name. validate it with the username
    Else
    {
        $PasswordAssociation = "join domain credentials"
        If([string]::IsNullOrEmpty($UserNameObject.Text)){
            $Validation = Invoke-UIMessage -Message "Admin Credentials must be supplied" -HighlightObject $UserNameObject -OutputErrorObject $OutputErrorObject -Type Error -ReturnBool
        }
        ElseIf(-not(Confirm-DomainAccount $UserNameObject.Text)){
            $Validation = Invoke-UIMessage -Message "Domain account is not valid (eg. domain\username)" -HighlightObject $UserNameObject -OutputErrorObject $OutputErrorObject -Type Error -ReturnBool
        }
        ElseIf(( ($UserNameObject.Text).Length -gt 0) -and ([string]::IsNullOrEmpty($UserNameObject.Text))){
            $Validation = Invoke-UIMessage -Message "Admin Credentials must be supplied to join domain" -HighlightObject $UserNameObject -OutputErrorObject $OutputErrorObject -Type Error -ReturnBool
        }

        If(( ($UserNameObject.Text).Length -gt 0) -and ([string]::IsNullOrEmpty($DomainNameObject.Text))){
            $Validation = Invoke-UIMessage -Message "Domain name must be supplied with Admin Credentials" -HighlightObject $DomainNameObject -OutputErrorObject $OutputErrorObject -Type Error -ReturnBool
        }
        ElseIf(-not(Confirm-DomainFQDN $DomainNameObject.Text)){
            $Validation = Invoke-UIMessage -Message "Domain name is not valid" -HighlightObject $DomainNameObject -OutputErrorObject $OutputErrorObject -Type Error -ReturnBool
        }
    }

    #don't check password info until domain/workgroup is properly configured
    If($Validation){
        #check to see if password match
        If($PasswordObject.Password -eq $PasswordCheck -or $ConfirmedPasswordObject.Password -eq $PasswordCheck){
            $Validation = Invoke-UIMessage -Message "This is not a valid password." -HighlightObject $ConfirmedPasswordObject -OutputErrorObject $OutputErrorObject -Type Error -ReturnBool
        }
        ElseIf([string]::IsNullOrEmpty($PasswordObject.Password)){
            $Validation = Invoke-UIMessage -Message ("Password must be supplied for {0}" -f $PasswordAssociation) -HighlightObject $PasswordObject -OutputErrorObject $OutputErrorObject -Type Error -ReturnBool
        }
        ElseIf([string]::IsNullOrEmpty($ConfirmedPasswordObject.Password)){
            $Validation = Invoke-UIMessage -Message "Confirm Password must be supplied" -HighlightObject $ConfirmedPasswordObject -OutputErrorObject $OutputErrorObject -Type Error -ReturnBool
        }
        #check to see if password match
        ElseIf($PasswordObject.Password -ne $ConfirmedPasswordObject.Password){
            $Validation = Invoke-UIMessage -Message "Passwords do not match" -HighlightObject $ConfirmedPasswordObject -OutputErrorObject $OutputErrorObject -Type Error -ReturnBool
        }
    }

    Return $Validation
}
#endregion


#region FUNCTION: Validate site code for sccm
Function Confirm-SiteCode {
    param(
        [System.Windows.Controls.TextBox]$SiteCodeObject,
        [System.Windows.Controls.TextBox]$OutputErrorObject
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    #set variables to initial state
    $Validation = $true

    Write-LogEntry "Validating site code field..." -Source ${CmdletName} -Severity 1

    If([string]::IsNullOrEmpty($SiteCodeObject.Text)){
        $Validation = Invoke-UIMessage -Message "Site Code must be supplied" -HighlightObject $SiteCodeObject -OutputErrorObject $OutputErrorObject -Type Error -ReturnBool
    }
    ElseIf( (($SiteCodeObject.Text).length -lt 3) ){
        $Validation = Invoke-UIMessage -Message ("Site code is not long enough [{0}], it must be 3 characters" -f $SiteCodeObject.Text) -HighlightObject $SiteCodeObject -OutputErrorObject $OutputErrorObject -Type Error -ReturnBool
    }
    ElseIf( (($SiteCodeObject.Text).length -gt 3) ){
        $Validation = Invoke-UIMessage -Message ("Site code is too long [{0}], it must only be 3 characters" -f $SiteCodeObject.Text) -HighlightObject $SiteCodeObject -OutputErrorObject $OutputErrorObject -Type Error -ReturnBool
    }

    Return $Validation
}
#endregion


function Test-KeyPress
{
    <#
        .SYNOPSIS
        Checks to see if a key or keys are currently pressed.

        .DESCRIPTION
        Checks to see if a key or keys are currently pressed. If all specified keys are pressed then will return true, but if 
        any of the specified keys are not pressed, false will be returned.

        .PARAMETER Keys
        Specifies the key(s) to check for. These must be of type "System.Windows.Forms.Keys"

        .EXAMPLE
        Test-KeyPress -Keys ControlKey

        Check to see if the Ctrl key is pressed

        .EXAMPLE
        Test-KeyPress -Keys ControlKey,Shift

        Test if Ctrl and Shift are pressed simultaneously (a chord)

        .LINK
        Uses the Windows API method GetAsyncKeyState to test for keypresses
        http://www.pinvoke.net/default.aspx/user32.GetAsyncKeyState

        The above method accepts values of type "system.windows.forms.keys"
        https://msdn.microsoft.com/en-us/library/system.windows.forms.keys(v=vs.110).aspx

        .LINK
        http://powershell.com/cs/blogs/tips/archive/2015/12/08/detecting-key-presses-across-applications.aspx

        .INPUTS
        System.Windows.Forms.Keys

        .OUTPUTS
        System.Boolean
    #>

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Windows.Forms.Keys[]]
        $Keys
    )

    # use the User32 API to define a keypress datatype
    $Signature = @'
[DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)]
public static extern short GetAsyncKeyState(int virtualKeyCode);
'@
    $API = Add-Type -MemberDefinition $Signature -Name 'Keypress' -Namespace Keytest -PassThru

    # test if each key in the collection is pressed
    $Result = foreach ($Key in $Keys)
    {
        [bool]($API::GetAsyncKeyState($Key) -eq -32767)
    }

    # if all are pressed, return true, if any are not pressed, return false
    $Result -notcontains $false
}

function Start-UISplashScreen
{
    #launch the modal window with the progressbar
    $Script:Pwshell.Runspace = $Script:runspace
    $Script:Handle = $Pwshell.BeginInvoke()

    # we need to wait that all elements are loaded
    While (!($Global:SplashScreen.Window.IsInitialized)) {
        Start-Sleep -Milliseconds 500
    }
}

function Close-UISplashScreen
{
    param([int] $Delay)

    #Invokes UI to close
    $Global:SplashScreen.Window.Dispatcher.Invoke("Normal",[action]{$Global:SplashScreen.Window.close()})
    $Script:Pwshell.EndInvoke($Script:Handle) | Out-Null

    #Closes and Disposes the UI objects/threads
    $Script:Pwshell.Runspace.Close()
	$Script:Pwshell.Dispose()

}

Function Show-UISplashScreenProgress{
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [String] $Label,

        [Parameter(Position=1)]
        [int] $Progress,

        [Parameter(Position=2)]
        [switch] $Indeterminate,

        [string] $Color = "LightGreen"
    )

    if(!$Indeterminate){
        if(($Progress -ge 0) -and ($Progress -lt 100)){
	        $Global:SplashScreen.ProgressBar.Dispatcher.Invoke("Normal",[action]{
			        $Global:SplashScreen.ProgressBar.IsIndeterminate = $False
			        $Global:SplashScreen.ProgressBar.Value= $progress
			        $Global:SplashScreen.ProgressBar.Foreground=$Color
			        $Global:SplashScreen.ProgressLabel.Content= $label +" : "+$progress+" %"
            })
        }
        elseif($progress -eq 100){
            $Global:SplashScreen.ProgressBar.Dispatcher.Invoke("Normal",[action]{
			        $Global:SplashScreen.ProgressBar.IsIndeterminate = $False
			        $Global:SplashScreen.ProgressBar.Value= $progress
			        $Global:SplashScreen.ProgressBar.Foreground=$Color
			        $Global:SplashScreen.ProgressLabel.Content= $label +" : "+$progress+" %"
                    #$Global:SplashScreen.Button.Visibility ="Visible"
            })
        }
        else{Write-Warning "Out of range"}
    }
    else{
        $Global:SplashScreen.ProgressBar.Dispatcher.Invoke("Normal",[action]{
			$Global:SplashScreen.ProgressBar.IsIndeterminate = $True
			$Global:SplashScreen.ProgressBar.Foreground=$Color
            $Global:SplashScreen.ProgressLabel.Content=$label
      })
    }
}

#region FUNCTION: Displays IU
Function Show-UIMenu{
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    Write-LogEntry ("Launching UI for {0} [ver {1}]..." -f $MenuTitle, $MenuVersion) -Source ${CmdletName} -Severity 1
    If($Global:HostOutput){Write-Host ("=============================================================") -ForegroundColor Green}
    #Slower method to present form for non modal (no popups)
    #$UI.ShowDialog() | Out-Null

    #Console control
    # Credits to - http://powershell.cz/2013/04/04/hide-and-show-console-window-from-gui/
    Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();

[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'
    # Allow input to window for TextBoxes, etc
    [Void][System.Windows.Forms.Integration.ElementHost]::EnableModelessKeyboardInterop($UI)

    If(!(Test-IsISE)){
        $code = {
            If(Test-KeyPress -Keys F10)
            {
                $CloseTheSplashScreen = $True
                If($UI.Topmost){
                    $UI.Topmost = $false
                    If($CloseTheSplashScreen){Close-UISplashScreen; $CloseTheSplashScreen = $false}
                }
                Else{
                    $UI.Topmost = $True
                }
            }
        }
        $null = $UI.add_KeyDown($code)
    }
    Else{

        #for ISE testing only: Add ESC key as a way to exit UI
        $code = {
            [System.Windows.Input.KeyEventArgs]$esc = $args[1]
            if ($esc.Key -eq 'ESC')
            {
                $UI.Close()
                [System.Windows.Forms.Application]::Exit()
                #this will kill ISE
                [Environment]::Exit($ExitCode);
            }
        }
        $null = $UI.add_KeyUp($code)
    }

    $UI.Add_Closing({
        [System.Windows.Forms.Application]::Exit()
    })

    $async = $UI.Dispatcher.InvokeAsync({
        #make sure this display on top of every window
        $UI.Topmost = $true
        # Running this without $appContext & ::Run would actually cause a really poor response.
        $UI.Show() | Out-Null
        # This makes it pop up
        $UI.Activate() | Out-Null

        #$UI.window.ShowDialog()
    })
    $async.Wait() | Out-Null

    ## Force garbage collection to start form with slightly lower RAM usage.
    [System.GC]::Collect() | Out-Null
    [System.GC]::WaitForPendingFinalizers() | Out-Null

    # Create an application context for it to all run within.
    # This helps with responsiveness, especially when Exiting.
    $appContext = New-Object System.Windows.Forms.ApplicationContext
    [void][System.Windows.Forms.Application]::Run($appContext)

    #[Environment]::Exit($ExitCode);
}
#endregion

#region FUNCTION: Shows a console help for commands to run for UI
Function Show-UIMenuCommandHelp{
    param(
        [string]$ExampleText
    )

    Write-Host "Testmode enabled. To trigger tests run commands like:" -BackgroundColor Yellow -ForegroundColor Black
    Write-Host ''
    Write-Host "  `$OOBEUIWPF_inputTxtComputerName" -NoNewline -ForegroundColor Green
    Write-Host ".text" -NoNewline -ForegroundColor Gray
    Write-Host " = " -NoNewline -ForegroundColor Gray
    If($ExampleText){
        Write-Host "'$ExampleText'" -NoNewline  -ForegroundColor Red
    }Else{
    Write-Host "'ADPAW123456V1'" -NoNewline  -ForegroundColor Red
    }
    Write-Host ";" -ForegroundColor Gray
    Write-Host "  `$ComputerNameObject" -NoNewline -ForegroundColor Green
    Write-Host " = " -NoNewline -ForegroundColor Gray
    Write-Host "`$OOBEUIWPF_inputTxtComputerName" -NoNewline -ForegroundColor Green
    Write-Host ";" -ForegroundColor Gray
    Write-Host "  `$Validation" -NoNewline -ForegroundColor Red
    Write-Host " = " -NoNewline -ForegroundColor Gray
    Write-Host " `Confirm-ComputerNameRules" -NoNewline -ForegroundColor Magenta
    Write-Host " -ComputerNameObject" -NoNewline -ForegroundColor DarkGray
    Write-Host " `$OOBEUIWPF_inputTxtComputerName" -NoNewline -ForegroundColor Green
    Write-Host " -OutputErrorObject" -NoNewline -ForegroundColor DarkGray
    Write-Host " `$OOBEUIWPF_txtError" -NoNewline -ForegroundColor Green
    Write-Host " -ReturnOption" -NoNewline -ForegroundColor DarkGray
    Write-Host " All" -NoNewline -ForegroundColor White
    Write-Host ";" -ForegroundColor Gray
    Write-Host "  `Update-UILocaleFields" -NoNewline -ForegroundColor Magenta
    Write-Host " -SiteID" -NoNewline -ForegroundColor DarkGray
    Write-Host " `$Validation" -NoNewline -ForegroundColor Red
    Write-Host ".SiteID" -NoNewline -ForegroundColor Gray
    Write-Host " -UpdateSiteListObject" -NoNewline -ForegroundColor DarkGray
    Write-Host " (WPFVar `"inputCmbSiteList`")" -NoNewline -ForegroundColor White
    Write-Host " -UpdateTimeZoneObject" -NoNewline -ForegroundColor DarkGray
    Write-Host " (WPFVar `"inputCmbTimeZoneList`")" -NoNewline -ForegroundColor White
    Write-Host " -UpdateSiteCodeObject" -NoNewline -ForegroundColor DarkGray
    Write-Host " (WPFVar `"txtSiteCode`")" -NoNewline -ForegroundColor White
    Write-Host " -UpdateDomainObject" -NoNewline -ForegroundColor DarkGray
    Write-Host " (WPFVar `"inputCmbDomainWorkgroupName`")" -NoNewline -ForegroundColor White
    Write-Host ";" -ForegroundColor Gray
}
#endregion