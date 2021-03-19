
#region FUNCTION: Set the OSD variable for Language Locale
Function Set-OSDLangLocale{
    param(
        [Parameter(Mandatory = $false, Position=1,ParameterSetName="Lang")]
        [string]$Name,
        [Parameter(Mandatory = $false, Position=1,ParameterSetName="LCID")]
        [string]$LCID
    )

    If ($PSCmdlet.ParameterSetName -eq "Lang") {
        $locales = [system.globalization.cultureinfo]::getcultures('AllCultures') | where { $_.Displayname -like "*$Name*" }
        #$LCIDToDecimal = [convert]::toint16($locales.LCID,16)
    }

    If ($PSCmdlet.ParameterSetName -eq "LCID") {
        $locales = [system.globalization.cultureinfo]::getcultures('AllCultures') | where { $_.LCID -eq $LCID }
        #$LCIDToDecimal = [convert]::tostring($locales.LCID,16)
    }

    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    If($Script:tsenv){
        Try{
            $tsenv.Value("UILanguage") = $locales.name
            $tsenv.Value("UserLocale") = ("{0} ::0000{0}" -f $locales.LCID)
            $tsenv.Value("InputLocale") = ("{0} ::0000{0}" -f $locales.LCID)
            $tsenv.Value("KeyboardLocale") = ("{0} ::0000{0}" -f $locales.LCID)
        }
        Catch{
            Throw $_.Exception.message
        }
        Finally{
            Write-LogEntry ("Property UILANGUAGE is now: {0}" -f $tsenv.Value("UILanguage")) -Source ${CmdletName} -Severity 0
            Write-LogEntry ("Property USERLOCALE is now: {0}" -f $tsenv.Value("UserLocale")) -Source ${CmdletName} -Severity 0
            Write-LogEntry ("Property INPUTLOCALE is now: {0}" -f $tsenv.Value("InputLocale")) -Source ${CmdletName} -Severity 0
            Write-LogEntry ("Property KEYBOARDLOCALE is now: {0}" -f $tsenv.Value("KeyboardLocale")) -Source ${CmdletName} -Severity 0
        }
    }
    Else{
        Write-LogEntry "These Language Locale [VARIABLE: value] would be set in a Task Sequence:" -Source ${CmdletName} -Severity 2
        Write-LogEntry ("UILANGUAGE {0}" -f $locales.name) -Source ${CmdletName} -Severity 1
        Write-LogEntry ("USERLOCALE: {0}:0000{0}" -f $locales.LCID) -Source ${CmdletName} -Severity 1
        Write-LogEntry ("INPUTLOCALE: {0}:0000{0}" -f $locales.LCID) -Source ${CmdletName} -Severity 1
        Write-LogEntry ("KEYBOARDLOCALE: {0}:0000{0}" -f $locales.LCID) -Source ${CmdletName} -Severity 1
    }

}
#endregion

#region FUNCTION: Set the OSD variable for Locale information
Function Set-OSDLocaleVariables {
    param(
        $SelectedTimeZone
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    #Attempt to get MDT Index
    $MDTIndex = $SelectedTimeZone.Index
    If($null -eq $MDTIndex){
        $MDTIndex = Get-TimeZoneIndex -TimeZone $SelectedTimeZone
    }

    $TimeZoneName = $SelectedTimeZone.StandardName

    If($Script:tsenv){
        Try{
            If($MDTIndex){$tsenv.Value("TimeZone") = $MDTIndex}
            $tsenv.Value("OSDTimeZone") = $TimeZoneName
            $tsenv.Value("TimeZoneName") = $TimeZoneName
            #$tsenv.Value("_SMSTSTimezone") = $TimeZoneName
        }
        Catch{
            Throw $_.Exception.message
        }
        Finally{
            If($MDTIndex){Write-LogEntry ("Property TIMEZONE is now: {0}" -f $tsenv.Value("TimeZone")) -Source ${CmdletName} -Severity 0}
            Write-LogEntry ("Property OSDTIMEZONE is now: {0}" -f $tsenv.Value("OSDTimeZone")) -Source ${CmdletName} -Severity 0
            Write-LogEntry ("Property TIMEZONENAME is now: {0}" -f $tsenv.Value("TimeZoneName")) -Source ${CmdletName} -Severity 0
        }
    }
    Else{
        Write-LogEntry "These Locale [VARIABLE: value] would be set in a Task Sequence:" -Source ${CmdletName} -Severity 2
        Write-LogEntry ("TIMEZONE: {0}" -f $MDTIndex) -Source ${CmdletName} -Severity 1
        Write-LogEntry ("OSDTIMEZONE: {0}" -f $TimeZoneName) -Source ${CmdletName} -Severity 1
        Write-LogEntry ("TIMEZONENAME: {0}" -f $TimeZoneName) -Source ${CmdletName} -Severity 1
    }
}
#endregion

#region FUNCTION: Set the custom OSD variable for Classification
Function Set-OSDClassificationVariables {
    param(
        $ClassificationList = $MenuLocaleClassificationList,
        $ClassificationFilter
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    $SelectedClassification = $ClassificationList | Where Level -eq $ClassificationFilter

    If($Script:tsenv){
        Try{
            If($SelectedClassification.Caveat){$tsenv.Value("Caveat") = $SelectedClassification.Caveat}
            $tsenv.Value("Classification") = $SelectedClassification.Id
            $tsenv.Value("ClassificationLevel") = $SelectedClassification.Level
            $tsenv.Value("ClassificationType") = $SelectedClassification.Type
            $tsenv.Value("ClassificationColor") = $SelectedClassification.Color
        }
        Catch{
            Throw $_.Exception.message
        }
        Finally{
            If($SelectedClassification.Caveat){Write-LogEntry ("Property CAVEAT is now: {0}" -f $tsenv.Value("Caveat")) -Source ${CmdletName} -Severity 0}
            Write-LogEntry ("Property CLASSIFICATION is now: {0}" -f $tsenv.Value("Classification")) -Source ${CmdletName} -Severity 0
            Write-LogEntry ("Property CLASSIFICATIONLEVEL is now: {0}" -f $tsenv.Value("ClassificationLevel")) -Source ${CmdletName} -Severity 0
            Write-LogEntry ("Property CLASSIFICATIONTYPE is now: {0}" -f $tsenv.Value("ClassificationType")) -Source ${CmdletName} -Severity 0
            Write-LogEntry ("Property CLASSIFICATIONCOLOR is now: {0}" -f $tsenv.Value("ClassificationColor")) -Source ${CmdletName} -Severity 0
        }
    }
    Else{
        Write-LogEntry "These Classification [VARIABLE: value] would be set in a Task Sequence:" -Source ${CmdletName} -Severity 2
        If($SelectedClassification.Caveat){Write-LogEntry ("CAVEAT: {0}" -f $SelectedClassification.Caveat) -Source ${CmdletName} -Severity 1}
        Write-LogEntry ("CLASSIFICATION: {0}" -f $SelectedClassification.Id) -Source ${CmdletName} -Severity 1
        Write-LogEntry ("CLASSIFICATIONLEVEL: {0}" -f $SelectedClassification.Level) -Source ${CmdletName} -Severity 1
        Write-LogEntry ("CLASSIFICATIONTYPE: {0}" -f $SelectedClassification.Type) -Source ${CmdletName} -Severity 1
        Write-LogEntry ("CLASSIFICATIONCOLOR: {0}" -f $SelectedClassification.Color) -Source ${CmdletName} -Severity 1
    }
}
#endregion

#region FUNCTION: updates the Identify information in UI using a Hashtable
Function Set-OSDIdentityVariables {
    param(
        $VariableTable
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    #clear all identity rules
    If($ClearValues){Clear-UIIdentityFields -Hide}

    $objMembers = $VariableTable.psobject.members | where-object membertype -like 'noteproperty'

    #create an empty hashtable to add objects to.
    $HashTable = @{}
    foreach ($obj in $objMembers) {
        $HashTable.add( "$($obj.name)", "$($obj.Value)")
    }

    #note if not in TS before loop
    If(!$Script:tsenv){Write-LogEntry "These identity [VARIABLE: value] would be set in a Task Sequence:" -Source ${CmdletName} -Severity 2}

    #parse thehashtable
    Foreach($item in $HashTable.Keys){
        #grab the value
        $VariableValue = $HashTable.Item($item)
        #Attempt to add  variable to task sequence
        If($Script:tsenv){
            Try{
                $tsenv.Value($item) = $VariableValue
            }
            Catch{
                Throw $_.Exception.message
            }
            Finally{
                Write-LogEntry ("Property {0} is now: {1}" -f $item.ToUpper(),$VariableValue) -Source ${CmdletName} -Severity 0
            }
        }
        Else{
            Write-LogEntry ("{0}: {1}" -f $item.ToUpper(),$VariableValue) -Source ${CmdletName} -Severity 1
        }
    }
}
#endregion

#region FUNCTION: Set indivdual OSD variable for Identity
Function Set-OSDIdentityVariable{
    param(
        [string]$Name,
        [string]$Value
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    #note if not in TS before loop
    If(!$Script:tsenv){Write-LogEntry "These identity [variables: values] would be set in a Task Sequence:" -Source ${CmdletName} -Severity 2}

    #Attempt to add  variable to task sequence
    If($Script:tsenv){
        Try{
            If($VarValue){$tsenv.Value($VarName) = $VarValue}Else{$tsenv.Value($VarName) = $null}
        }
        Catch{
            Throw $_.Exception.message
        }
        Finally{
            Write-LogEntry ("Property {0} is now: {1}" -f $VarName.ToUpper(),$tsenv.Value($VarName)) -Source ${CmdletName} -Severity 0
        }
    }
    Else{
        Write-LogEntry ("{0}: {1}" -f $VarName.ToUpper(),$VarValue) -Source ${CmdletName} -Severity 1
    }
}
#endregion

#region FUNCTION: Set the OSD variable for Domain join
Function Set-OSDDomainVariables {
    param(
        [Parameter(Mandatory = $true, Position=0)]
        $ComputerName,
        $DomainName,
        $DomainFQDN,
        $DomainOU,
        $AdminUsername,
        $AdminPassword,
        $CMSiteCode
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    #grab usernam info; parse it for if domain\username
    $UserName = Confirm-DomainAccount -DomainAccount $AdminUsername -returnDetails
    If($UserName.Domain){
        $JoinDomain = $UserName.Domain
        $JoinAccount = $UserName.Username
    }Else{
        $JoinDomain = $DomainFQDN
        $JoinAccount = $AdminUsername
    }

    If($DomainOU){
        #the domainOU is in parentheses, get only teh value inside
        $DomainOU = ($DomainOU -split "\(|\)")[1]
    }

    #set OSD join variables to domain
    $OSDNetworkJoinType = '0'

    #WARNING: if Debug mode and Verbose Mode, password will be displayed
    If($Global:DebugEnabled){$ShowYesNoPassword = $AdminPassword}Else{$ShowYesNoPassword = ($AdminPassword -replace '(.?)','*')}

    If($Script:tsenv){
        Try{
            #MDT Variables
            #[System.text.encoding]::ASCII.GetString([system.convert]::fromBase64String($AdminPassword))
            #[System.text.encoding]::ASCII.GetString([system.convert]::fromBase64String($JoinAccount))
            #$tsenv.Value("ComputerName") = $ComputerName
            #$tsenv.Value("DomainAdmin") = $JoinAccount
            #$tsenv.Value("DomainAdminDomain") = $JoinDomain
            #$tsenv.Value("DomainAdminPassword") = $AdminPassword
            #$tsenv.Value("DomainErrorRecovery") = 'AUTO'
            #$tsenv.Value("JoinDomain") = $DomainFQDN

            #allow values to be null or empty, but do not set them

            #MDT/SCCM Variables
            $tsenv.Value("OSDComputerName") = $ComputerName

            If(-not([string]::IsNullOrEmpty($DomainFQDN))){
                $tsenv.Value("OSDNetworkJoinType") = $OSDNetworkJoinType
                $tsenv.Value("OSDJoinType") = $OSDNetworkJoinType
                $tsenv.Value("OSDDomainName") = $DomainFQDN
                $tsenv.Value("OSDJoinDomainName") = $JoinDomain
            }
            If(-not([string]::IsNullOrEmpty($AdminUsername))){$tsenv.Value("OSDJoinAccount") = $JoinAccount}
            If(-not([string]::IsNullOrEmpty($AdminPassword))){$tsenv.Value("OSDJoinPassword") = $AdminPassword}

            If(-not([string]::IsNullOrEmpty($DomainOU))){
                $tsenv.Value("OSDDomainOUName") = $DomainOU
                $tsenv.Value("OSDJoinDomainOUName") = $DomainOU
            }
            #custom variables
            $tsenv.Value("DomainName") = $DomainName
            If(-not([string]::IsNullOrEmpty($CMSiteCode))){$tsenv.Value("CMSiteCode") = $CMSiteCode}
        }
        Catch{
            Throw $_.Exception.message
        }
        Finally{
            #MDT Variables
            #Write-LogEntry ("Property COMPUTERNAME is now: {0}" -f $tsenv.Value("ComputerName")) -Source ${CmdletName} -Severity 0
            #Write-LogEntry ("Property DOMAINADMIN is now: {0}" -f $tsenv.Value("DomainAdmin")) -Source ${CmdletName} -Severity 0
            #Write-LogEntry ("Property DOMAINADMINDOMAIN is now: {0}" -f $tsenv.Value("DomainAdminDomain")) -Source ${CmdletName} -Severity 0
            #Write-LogEntry ("Property DOMAINADMINPASSWORD is now: {0}" -f $ShowYesNoPassword) -Source ${CmdletName} -Severity 0
            #Write-LogEntry ("Property JOINDOMAIN is now: {0}" -f $tsenv.Value("JoinDomain")) -Source ${CmdletName} -Severity 0

            #MDT/SCCM Variables
            Write-LogEntry ("Property OSDCOMPUTERNAME is now: {0}" -f $tsenv.Value("OSDComputerName")) -Source ${CmdletName} -Severity 0
            If(-not([string]::IsNullOrEmpty($DomainFQDN))){
                Write-LogEntry ("Property OSDNETWORKJOINTYPE is now: {0}" -f $tsenv.Value("OSDNetworkJoinType")) -Source ${CmdletName} -Severity 0
                Write-LogEntry ("Property OSDJOINTYPE is now: {0}" -f $tsenv.Value("OSDJoinType")) -Source ${CmdletName} -Severity 0
                Write-LogEntry ("Property OSDJOINDOMAINNAME is now: {0}" -f $tsenv.Value("OSDJoinDomainName")) -Source ${CmdletName} -Severity 0
            }
            If(-not([string]::IsNullOrEmpty($AdminUsername))){Write-LogEntry ("Property OSDJOINACCOUNT is now: {0}" -f $tsenv.Value("OSDJoinAccount")) -Source ${CmdletName} -Severity 0}
            If(-not([string]::IsNullOrEmpty($AdminPassword))){Write-LogEntry ("Property OSDJOINPASSWORD is now: {0}" -f $ShowYesNoPassword) -Source ${CmdletName} -Severity 0}

            If(-not([string]::IsNullOrEmpty($DomainOU))){
                Write-LogEntry ("Property OSDDOMAINNAME is now: {0}" -f $tsenv.Value("OSDDomainName")) -Source ${CmdletName} -Severity 0
                Write-LogEntry ("Property OSDJOINDOMAINNAME is now: {0}" -f $tsenv.Value("OSDJoinDomainName")) -Source ${CmdletName} -Severity 0
                Write-LogEntry ("Property OSDDOMAINOUNAME is now: {0}" -f $tsenv.Value("OSDDomainOUName")) -Source ${CmdletName} -Severity 0
                Write-LogEntry ("Property OSDJOINDOMAINOUNAME is now: {0}" -f $tsenv.Value("OSDJoinDomainOUName")) -Source ${CmdletName} -Severity 0
            }
            #custom variables
            Write-LogEntry ("Property DOMAINNAME is now: {0}" -f $tsenv.Value("DomainName")) -Source ${CmdletName} -Severity 0
            Write-LogEntry ("Property CMSITECODE is now: {0}" -f $tsenv.Value("CMSiteCode")) -Source ${CmdletName} -Severity 0
        }
    }
    Else{
        Write-LogEntry "These Domain Join [VARIABLE: value] would be set in a Task Sequence:" -Source ${CmdletName} -Severity 2
        #mdt Variables
        #Write-LogEntry ("COMPUTERNAME: {0}" -f $ComputerName) -Source ${CmdletName} -Severity 1
        #Write-LogEntry ("DOMAINADMIN: {0}" -f $JoinAccount) -Source ${CmdletName} -Severity 1
        #Write-LogEntry ("DOMAINADMINDOMAIN: {0}" -f $JoinDomain) -Source ${CmdletName} -Severity 1
        #Write-LogEntry ("DOMAINADMINPASSWORD: {0}" -f $ShowYesNoPassword) -Source ${CmdletName} -Severity 1
        #Write-LogEntry ("JOINDOMAIN: {0}" -f $DomainFQDN) -Source ${CmdletName} -Severity 1

        #mdt/sccm variable
        Write-LogEntry ("OSDCOMPUTERNAME: {0}" -f $ComputerName) -Source ${CmdletName} -Severity 1
        Write-LogEntry ("OSDNETWORKJOINTYPE: {0}" -f $OSDNetworkJoinType) -Source ${CmdletName} -Severity 1
        Write-LogEntry ("OSDJOINTYPE: {0}" -f $OSDNetworkJoinType) -Source ${CmdletName} -Severity 1

        #sccm variables
        Write-LogEntry ("OSDDOMAINNAME: {0}" -f $JoinDomain) -Source ${CmdletName} -Severity 1
        Write-LogEntry ("OSDJOINACCOUNT: {0}" -f $JoinAccount) -Source ${CmdletName} -Severity 1
        Write-LogEntry ("OSDJOINPASSWORD: {0}" -f $ShowYesNoPassword) -Source ${CmdletName} -Severity 1

        Write-LogEntry ("OSDDOMAINNAME: {0}" -f $DomainFQDN) -Source ${CmdletName} -Severity 1
        Write-LogEntry ("OSDJOINDOMAINNAME: {0}" -f$JoinDomain) -Source ${CmdletName} -Severity 1
        If($DomainOU)
        {
            Write-LogEntry ("OSDDOMAINOUNAME: {0}" -f $DomainOU) -Source ${CmdletName} -Severity 1
            Write-LogEntry ("OSDJOINDOMAINOUNAME: {0}" -f $DomainOU) -Source ${CmdletName} -Severity 1
        }
        #custom variables
        Write-LogEntry ("DOMAINNAME: {0}" -f $DomainName) -Source ${CmdletName} -Severity 1
        Write-LogEntry ("CMSITECODE: {0}" -f $CMSiteCode) -Source ${CmdletName} -Severity 1
    }
}
#endregion

#region FUNCTION: Set the OSD variable for Workgroup join
Function Set-OSDWorkgroupVariables {
    param(
        [Parameter(Mandatory = $true, Position=0)]
        [string]$ComputerName,
        [string]$Workgroup,
        [string]$LocalAdminPassword
    )

    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    #set OSD join variables to domain
    $OSDNetworkJoinType = '1'

    #WARNING: if Debug mode and Verbose Mode, password will be displayed
    If($Global:DebugEnabled){$ShowYesNoPassword = $LocalAdminPassword}Else{$ShowYesNoPassword = ($LocalAdminPassword -replace '(.?)','*')}

    If($Script:tsenv){
        Try{
            #MDT Variables
            #$tsenv.Value("ComputerName") = $ComputerName
            #$tsenv.Value("JoinWorkGroup") = $OSDNetworkJoinType
            #$tsenv.Value("AdminPassword") = $LocalAdminPassword

            #MDT/SCCM Variables
            $tsenv.Value("OSDComputerName") = $ComputerName

            If(-not([string]::IsNullOrEmpty($Workgroup))){
                $tsenv.Value("OSDJoinType") = $OSDNetworkJoinType
                $tsenv.Value("OSDNetworkJoinType") = $OSDNetworkJoinType
                $tsenv.Value("OSDWorkgroupName") = $Workgroup
                $tsenv.Value("OSDJoinWorkgroupName") = $Workgroup
            }
            If(-not([string]::IsNullOrEmpty($LocalAdminPassword))){$tsenv.Value("OSDLocalAdminPassword") = $LocalAdminPassword}
        }
        Catch{
            Throw $_.Exception.message
        }
        Finally{
            #MDT Variables
            #Write-LogEntry ("Property COMPUTERNAME is now: {0}" -f $tsenv.Value("ComputerName")) -Source ${CmdletName} -Severity 0
            #Write-LogEntry ("Property JOINWORKGROUP is now: {0}" -f $tsenv.Value("JoinWorkGroup")) -Source ${CmdletName} -Severity 0
            #Write-LogEntry ("Property ADMINPASSWORD is now: {0}" -f $ShowYesNoPassword) -Severity 0

            #MDT/SCCM Variables
            Write-LogEntry ("Property OSDCOMPUTERNAME is now: {0}" -f $tsenv.Value("OSDComputerName")) -Source ${CmdletName} -Severity 0
            If(-not([string]::IsNullOrEmpty($Workgroup)))
            {
                Write-LogEntry ("Property OSDNETWORKJOINTYPE is now: {0}" -f $tsenv.Value("OSDNetworkJoinType")) -Source ${CmdletName} -Severity 0
                Write-LogEntry ("Property OSDJOINTYPE is now: {0}" -f $tsenv.Value("OSDJoinType")) -Source ${CmdletName} -Severity 0
                Write-LogEntry ("Property OSDWORKGROUPNAME is now: {0}" -f $tsenv.Value("OSDWorkgroupName")) -Source ${CmdletName} -Severity 0
                Write-LogEntry ("Property OSDJOINWORKGROUPNAME is now: {0}" -f $tsenv.Value("OSDJoinWorkgroupName")) -Source ${CmdletName} -Severity 0
            }
            If(-not([string]::IsNullOrEmpty($LocalAdminPassword))){Write-LogEntry ("Property OSDLOCALADMINPASSWORD is now: {0}" -f $ShowYesNoPassword) -Severity 0}
        }
    }
    Else{
        Write-LogEntry "These Workgroup [VARIABLE: value] would be set in a Task Sequence:" -Source ${CmdletName} -Severity 2
        #MDT Variables
        #Write-LogEntry ("COMPUTERNAME: {0}" -f $ComputerName) -Source ${CmdletName} -Severity 1
        #Write-LogEntry ("JOINWORKGROUP: {0}" -f $Workgroup) -Source ${CmdletName} -Severity 1
        #Write-LogEntry ("ADMINPASSWORD: {0}" -f $ShowYesNoPassword) -Source ${CmdletName} -Severity 1

        #MDT/SCCM Variables
        Write-LogEntry ("OSDCOMPUTERNAME: {0}" -f $ComputerName) -Source ${CmdletName} -Severity 1
        Write-LogEntry ("OSDNETWORKJOINTYPE: {0}" -f $OSDNetworkJoinType) -Source ${CmdletName} -Severity 1

        #SCCM Variables
        Write-LogEntry ("OSDJOINTYPE: {0}" -f $OSDNetworkJoinType) -Source ${CmdletName} -Severity 1
        Write-LogEntry ("OSDWORKGROUPNAME: {0}" -f $Workgroup) -Source ${CmdletName} -Severity 1
        Write-LogEntry ("OSDJOINWORKGROUPNAME: {0}" -f $Workgroup) -Source ${CmdletName} -Severity 1
        Write-LogEntry ("OSDLOCALADMINPASSWORD: {0}" -f $ShowYesNoPassword) -Source ${CmdletName} -Severity 1
    }
 }
#endregion


#region FUNCTION: Set the OSD variable for Offline Domain join
Function Set-OSDOdjVariables {
    #changed custom variable to support https://maikkoster.com/offline-domain-join-with-mdt/]
    param(
        [Parameter(Mandatory, Position=0, ParameterSetName="Blob")]
        [string]$BlobData,
        [Parameter(Mandatory, Position=0, ParameterSetName="File")]
        [string]$BlobFile,
        [Parameter(Position=1, ParameterSetName="Blob")]
        [string]$DomainFQDN,
        [Parameter(Position=1, ParameterSetName="File")]
        [string]$LocalAdminPassword,
        [string]$ComputerName
    )

    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    #The ODJ bLOB requires the system be set to join the domain
    # during the task sequence. The BLOB will replace the Domain values in unattend.xml
    # using https://maikkoster.com/offline-domain-join-with-mdt/ method
    If($PSCmdlet.ParameterSetName -eq "Blob"){
        $OSDNetworkJoinType = '0'
    }

    #File ODJ requires the system not to join the domain
    # during the task sequence. The ODJ will do that
    If($PSCmdlet.ParameterSetName -eq "File"){
        $OSDNetworkJoinType = '1'
    }

    #set OSD join variables to domain
    If($DomainFQDN){
        $JoinWorkgroupDomain = $DomainFQDN
    }
    Else{
        $JoinWorkgroupDomain = "ODJ"
    }

    #WARNING: if Debug mode and Verbose Mode, password will be displayed
    If($Global:DebugEnabled){$ShowYesNoPassword = $LocalAdminPassword}Else{$ShowYesNoPassword = ($LocalAdminPassword -replace '(.?)','*')}

    If($Script:tsenv){
        Try{
            #MDT Variables
            #$tsenv.Value("ComputerName") = $ComputerName
            #If($OSDNetworkJoinType -eq 0){$tsenv.Value("JoinDomain") = $JoinWorkgroupDomain}
            #If($OSDNetworkJoinType -eq 1){$tsenv.Value("JoinWorkgroup") = $JoinWorkgroupDomain}
            #If($PSCmdlet.ParameterSetName -eq "File"){$tsenv.Value("AdminPassword") = $ShowYesNoPassword}

            #MDT/SCCM Variables
            $tsenv.Value("OSDComputerName") = $ComputerName
            $tsenv.Value("OSDNetworkJoinType") = $OSDNetworkJoinType

            #SCCM Variables
            $tsenv.Value("OSDJoinType") = $OSDNetworkJoinType
            If($OSDNetworkJoinType -eq 0){
                $tsenv.Value("OSDDomainName") = $JoinWorkgroupDomain
                $tsenv.Value("OSDJoinDomainName") = $JoinWorkgroupDomain
            }
            If($OSDNetworkJoinType -eq 1){
                $tsenv.Value("OSDWorkgroupName") = $JoinWorkgroupDomain
                $tsenv.Value("OSDJoinWorkgroupName") = $JoinWorkgroupDomain
                $tsenv.Value("OSDLocalAdminPassword") = $LocalAdminPassword
            }

            #Custom variables
            If($PSCmdlet.ParameterSetName -eq "File"){
                $tsenv.Value("OfflineDomainJoinFile") = $BlobFile
            }
            If($PSCmdlet.ParameterSetName -eq "Blob"){
                $tsenv.Value("OfflineDomainJoinBlob") = $BlobData
            }
        }
        Catch{
            Throw $_.Exception.message
        }
        Finally{
            #MDT Variables
            #Write-LogEntry ("Property COMPUTERNAME is now: {0}" -f $tsenv.Value("OSDComputerName")) -Source ${CmdletName} -Severity 0
            #If($OSDNetworkJoinType -eq 0){Write-LogEntry ("Property JOINDOMAIN is now: {0}" -f $tsenv.Value("JoinDomain")) -Source ${CmdletName} -Severity 0}
            #If($OSDNetworkJoinType -eq 1){Write-LogEntry ("Property JOINWORKGROUP is now: {0}" -f $tsenv.Value("JoinWorkgroup")) -Source ${CmdletName} -Severity 0}
            #If($PSCmdlet.ParameterSetName -eq "File"){Write-LogEntry ("Property ADMINPASSWORD is now: {0}" -f $ShowYesNoPassword) -Severity 0}

            #MDT/SCCM Variables
            Write-LogEntry ("Property OSDCOMPUTERNAME is now: {0}" -f $tsenv.Value("OSDComputerName")) -Source ${CmdletName} -Severity 0
            Write-LogEntry ("Property OSDNETWORKJOINTYPE is now: {0}" -f $tsenv.Value("OSDNetworkJoinType")) -Source ${CmdletName} -Severity 0

            #SCCM Variables
            Write-LogEntry ("Property OSDJOINTYPE is now: {0}" -f $tsenv.Value("OSDJoinType")) -Source ${CmdletName} -Severity 0
            If($OSDNetworkJoinType -eq 0){
                Write-LogEntry ("Property OSDDOMAINNAME is now: {0}" -f $tsenv.Value("OSDDomainName")) -Source ${CmdletName} -Severity 0
                Write-LogEntry ("Property OSDJOINDOMAINNAME is now: {0}" -f $tsenv.Value("OSDJoinDomainName")) -Source ${CmdletName} -Severity 0
            }

            If($OSDNetworkJoinType -eq 1){
                Write-LogEntry ("Property OSDWORKGROUPNAME is now: {0}" -f $tsenv.Value("OSDWorkgroupName")) -Source ${CmdletName} -Severity 0
                Write-LogEntry ("Property OSDJOINWORKGROUPNAME is now: {0}" -f $tsenv.Value("OSDJoinWorkgroupName")) -Source ${CmdletName} -Severity 0
                Write-LogEntry ("Property OSDLOCALADMINPASSWORD is now: {0}" -f $ShowYesNoPassword) -Severity 0
            }
            #Custom variables
            If($PSCmdlet.ParameterSetName -eq "Blob"){
                #Write-LogEntry ("Property ODJ_BlobData: {0}" -f $tsenv.Value("ODJ_BlobData"))
                Write-LogEntry ("Property OFFLINEDOMAINJOINBLOB is now: {0}" -f $tsenv.Value("OfflineDomainJoinBlob"))
            }
            If($PSCmdlet.ParameterSetName -eq "File"){
                #Write-LogEntry ("Property ODJ_FilePath: {0}" -f $tsenv.Value("ODJ_FilePath"))
                Write-LogEntry ("Property OFFLINEDOMAINJOINFILE is now: {0}" -f $tsenv.Value("OfflineDomainJoinFile"))
            }
        }
    }
    Else{
        Write-LogEntry ("These Offline Domain Join using {0} [VARIABLE: value] would be set in a Task Sequence:" -f $PSCmdlet.ParameterSetName) -Source ${CmdletName} -Severity 2

        #MDT Variables
        #Write-LogEntry ("COMPUTERNAME: {0}" -f $ComputerName) -Source ${CmdletName} -Severity 1
        #If($OSDNetworkJoinType -eq 0){Write-LogEntry ("JOINDOMAIN: {0}" -f $JoinWorkgroupDomain) -Source ${CmdletName} -Severity 1}
        #If($OSDNetworkJoinType -eq 1){Write-LogEntry ("JOINWORKGROUP: {0}" -f $JoinWorkgroupDomain) -Source ${CmdletName} -Severity 1}

        #MDT/SCCM Variables
        Write-LogEntry ("OSDCOMPUTERNAME: {0}" -f $ComputerName) -Source ${CmdletName} -Severity 1
        Write-LogEntry ("OSDNETWORKJOINTYPE: {0}" -f $OSDNetworkJoinType) -Source ${CmdletName} -Severity 1

        #SCCM Variables
        Write-LogEntry ("OSDJOINTYPE: {0}" -f $OSDNetworkJoinType) -Source ${CmdletName} -Severity 1
        If($OSDNetworkJoinType -eq 0){
            Write-LogEntry ("OSDDOMAINNAME: {0}" -f $JoinWorkgroupDomain) -Source ${CmdletName} -Severity 1
            Write-LogEntry ("OSDJOINDOMAINNAME: {0}" -f $JoinWorkgroupDomain) -Source ${CmdletName} -Severity 1
        }
        If($OSDNetworkJoinType -eq 1){
            Write-LogEntry ("OSDWORKGROUPNAME: {0}" -f $JoinWorkgroupDomain) -Source ${CmdletName} -Severity 1
            Write-LogEntry ("OSDJOINWORKGROUPNAME: {0}" -f $JoinWorkgroupDomain) -Source ${CmdletName} -Severity 1
            Write-LogEntry ("OSDLOCALADMINPASSWORD: {0}" -f $ShowYesNoPassword) -Source ${CmdletName} -Severity 1
        }

        #Custom variables
        If($PSCmdlet.ParameterSetName -eq "Blob"){
            #Write-LogEntry ("ODJ_BlobData: {0}" -f $BlobData) -Source ${CmdletName} -Severity 1
            Write-LogEntry ("OFFLINEDOMAINJOINBLOB: {0}" -f $BlobData) -Source ${CmdletName} -Severity 1
        }
        If($PSCmdlet.ParameterSetName -eq "File"){
            #Write-LogEntry ("ODJ_FilePath: {0}" -f $BlobFile) -Source ${CmdletName} -Severity 1
            Write-LogEntry ("OFFLINEDOMAINJOINFILE: {0}" -f $BlobFile) -Source ${CmdletName} -Severity 1
        }
    }
 }
#endregion


#region FUNCTION: Set APp variable if selected
Function Set-OSDAppVariables {
    param(
        [array]$AppObjects,
        $AppList
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    Foreach($App in $AppObjects){
        #Attempt to add  variable to task sequence
        $AppVariable = ($AppList | Where {$_.Name -eq $App.Content.Text}).TSVar

        If($AppVariable)
        {
            If($Script:tsenv)
            {
                Try{
                    $tsenv.Value($AppVariable) = $App.IsChecked
                }
                Catch{
                    Throw $_.Exception.message
                }
                Finally{
                    Write-LogEntry ("Property {0} is now: {1}" -f $AppVariable.ToUpper(),$App.IsChecked) -Severity 0
                }
            }
            Else{
                Write-LogEntry "These app [VARIABLE: value] would be set in a Task Sequence:" -Source ${CmdletName} -Severity 2
                Write-LogEntry ("{0}: {1}" -f $AppVariable.ToUpper(),$App.IsChecked) -Source ${CmdletName} -Severity 1
            }
        }
        Else{
            Write-LogEntry ("No application [{0}] found in config" -f $App.Content.Text) -Source ${CmdletName} -Severity 1
        }

    }
}
#endregion