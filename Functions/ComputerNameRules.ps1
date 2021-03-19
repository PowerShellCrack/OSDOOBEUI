#region FUNCTION: Builds a dummy computer name to use
Function Update-OSDComputerName{
    [CmdletBinding()]
    param(
        [string]$Current
    )

    If ($Current.StartsWith('MININT')) {
        return $null
    }
    ElseIf ($Current.StartsWith('MINWINPC')) {
        return $null
    }
    Else {
        return $Current
    }
}
#endregion

#region Formats rules to support regex rules
Function Format-ArrayToRegex([string[]]$Array,[string]$type)
{
    #get only unique values in array
    $Array = $Array | select -Unique

    [regex]$HashSymbol = '#'
    $HashCount = $HashSymbol.matches($Array).count
    $LastExpression = $null

    #remove # from array, but be sure account for it later on
    If($HashCount -eq 1)
    {
        #replace the single pound symbol with digits regex group
        $Array = ($Array -replace '#','')
        $LastExpression = "\d{$HashCount}"
    }

    #determine is min count of characters per value in a rule
    $MinCharLength = ($Array.GetEnumerator().length | Select -Unique | Measure -Minimum).Minimum

    #determine is max count of characters per value in a rule
    $MaxCharLength = ($Array.GetEnumerator().length | Select -Unique | Measure -Maximum).Maximum

    #determine if array is all numbers,regex query uses \d, & non integers is \D
    If($type -ceq 'd'){$regexPrefix='\d'}Else{$regexPrefix='\D'}

    #if the min length & max length are same, cobined them in a simple regex expression (eg. AB|CD|EF)
    If($MinCharLength -eq $MaxCharLength){
        $FormattedRules = $Array -join "|"
    }
    Else{
        #since lengths are different, build it so the larger set is checked first
        #by using regex look behind "eg. (?<=\d{2})..." on large set & exact (eg. ...{1}) on last
        $FirstExpression = "(?<=$regexPrefix{$MaxCharLength})"
        If($LastExpression -eq $null){$LastExpression = "{$MinCharLength}"}
        $MaxCharSet = ($array | Where {$_.Length -eq $MaxCharLength}) -join '|'
        $MinCharSet = '[' + (($array | Where {$_.Length -eq $MinCharLength}) -join '') + ']'
        #$OtherCharSet = '[' + (($array | Where {$_.Length -ne $MaxCharLength -and $_.Length -ne $MinCharLength}) -join '') + ']'

        $FormattedRules = $MaxCharSet + $FirstExpression + '|' + $MinCharSet + $LastExpression
    }
    return $FormattedRules
}
#endregion


#region Converts xml Rules into a hashtable
Function ConvertTo-RuleHash
{
    [CmdletBinding()]
    param(
        $XmlRules
    )
    #determine max char on all rulesets & the max length for rulesets that must be process
    $RulesHashes = [ordered]@{}
    $MatchRules = $null

    $f = 0
    $max = $XmlRules.Count
    #TEST: Foreach($ruleSet in $XmlRules){if($ruleSet.id -eq 'ID4'){break}}
    Foreach($ruleSet in $XmlRules){
        $f++
        If($ruleSet.MinCharIdentifier){
            [int]$MinCharCheck = $ruleSet.MinCharIdentifier
        }
        #First rule will get the regex ^ for start string
        If($f -eq 1){$RegexStartWith = '^'}Else{$RegexStartWith = ''}
        #Last rule will get the regex $ for last in string
        If($f -eq $max){$RegexEndsWith = '?$'}Else{$RegexEndsWith = ''}
        $RuleSetName = $ruleSet.VarName
        #reset some variables
        $CharacterArray = @()

        #TEST: Foreach($rule in $ruleSet.rule){}
        Foreach($rule in $ruleSet.rule)
        {
            $AppendUniqueRule = $false
            $HashCount = 0
            #$OptionalNumberSet = @()

            #check if there is a pound symbol in rule character
            [regex]$HashSymbol = '#'
            #be sure to get the count
            $HashCount = $HashSymbol.matches($rule.Char).count
            $RegexCharType = 'd'

            #check to see if rule is looking for another variable array to process
            If($rule.GetVariable)
            {
                $VariableRule = (Get-Variable $rule.GetVariable -ValueOnly)
                #determine if there is a property on new array to target
                If($rule.MatchProperty)
                {
                    $RuleToAdd = $VariableRule.($rule.MatchProperty)
                }
                Else{
                    $RuleToAdd = $VariableRule
                }
            }
            #build rule if hash char is present
            ElseIf($HashCount -eq 1)
            {
                #replace the single pound symbol with digits regex group
                $RuleToAdd = $rule.Char
            }
            #build rule if hash char is present
            ElseIf($HashCount -gt 1)
            {
                $RuleToAdd = $rule.Char -replace '#',''
                $AppendUniqueRule = $true
            }
            Else
            {
                $RuleToAdd = $rule.Char
            }
            #build processed rules into an array
            $CharacterArray += $RuleToAdd

            #set the appropiate type based on characters in rule
            If($RuleToAdd -match '\D'){$RegexCharType = 'D'}
        } #end rules loop

        $FormattedRule = Format-ArrayToRegex -Array $CharacterArray -type $RegexCharType


        #build rules for each rulest in a hashtable
        $RulesHashes.Add($RuleSetName,("$RegexStartWith(?<$RuleSetName>$FormattedRule)").Trim())

        #If multiple hashes are found in rules, add another unique rule to hashtable to identify remaining numbers
        #If($AppendRule){$RulesHashes.Add('UniqueID',"(?<UniqueID>\d{4}(?(1)|\d))")}
        If($AppendUniqueRule){$RulesHashes.Add('UniqueID',"(?<UniqueID>\$RegexCharType{$MinCharCheck})")}

    }#end ruleset loop

    #append to last key:value in hashtable to identify end of regex
    $RulesHashes[$max] += '?$'

    Return $RulesHashes
}
#endregion


#region Formats rules to support regex rules
Function Format-Rules([string[]]$Array) {
    #get only unique values in array
    $Array = $Array | select -Unique

    #determine is max count of characters per value in a rule
    $GetMaxCharLenghtInArray = ($Array.GetEnumerator().length | Select -Unique | Measure -Maximum).Maximum

    #join list that have more than one character using pipe deliminator for regex
    #if all is one character, no need for pipe, but add brackets
    If($GetMaxCharLenghtInArray -gt 1)
    {
        $FormattedRules = $Array -join "|"
    }
    Else{
        $FormattedRules = '[' + ($Array -join "") + ']'
    }
    return $FormattedRules
}
#endregion


#region FUNCTION: Validate Identity Rules for computername & throw errors
Function Confirm-ComputerNameRules{
    [CmdletBinding()]
    param(
        $SiteList = $MenuLocaleSiteList,
        $XmlRules = $NameStandardRuleSets,
        [System.Windows.Controls.TextBox]$ComputerNameObject,
        [System.Windows.Controls.TextBox]$OutputErrorObject,
        [ValidateSet('Fields', 'Variables', 'All','Status')]
        [string]$ReturnOption

    )
    Begin
    {
        ## Get the name of this function
        [string]${CmdletName} = $MyInvocation.MyCommand
        #set variables to initial state
        $Validation = $true
        $ErrorMessage = $null

        Write-LogEntry ("Comparing device name [{0}] against naming standard rules..." -f $ComputerNameObject.Text) -Source ${CmdletName} -Severity 4

        #convert the XML list to a hashtable to build regex
        $HashedRules = (ConvertTo-RuleHash $XmlRules)

        Foreach ($item in $HashedRules.Keys) {
            If($DebugPreference){Write-LogEntry ("{0} : {1}" -f $item,$HashedRules.item($item)) -Source ${CmdletName} -Severity 5}
        }

        $FullRulesHash = -join $HashedRules.Values

        If($DebugPreference){Write-LogEntry ("Regex Query to match: {0}" -f $FullRulesHash) -Source ${CmdletName} -Severity 5}

        #even though the conpute name errores, update the fields
        Clear-UIIdentityFields -Hide
        Clear-UIField  -Name 'grdClassification' -Type Grid -Hide
        Clear-UIField  -Name 'grdSiteCode' -Type Grid -Hide
    }
    Process{

        Try
        {
            If($ComputerNameObject.text -match $FullRulesHash)
            {
                #get the Fields in UI that corresponds with hashtable
                $UIFields = @{}
                $VarValues = @{}

                #put in variable to ensure it available throughout the logic
                $MatchedRules = $matches

                #get all matches from computer name

                Foreach ($item in $MatchedRules.Keys)
                {
                    #match the ruleset with the matched identity  from computer name
                    $RuleSet = $XmlRules | Where {$_.VarName -eq $item}
                    #if a ruleset was found, find its matching rule
                    If($RuleSet)
                    {
                        # what is the value for this rule
                        $MatchedValue = $MatchedRules.Item($RuleSet.VarName)
                        If($DebugPreference){Write-LogEntry ("Matched ruleset [{0}], friendly name: [{1}] with value: [{2}]" -f $item,$RuleSet.Name,$MatchedValue) -Source ${CmdletName} -Severity 5}

                        #Loop through each rule in a ruleset looking for the matched value
                        Foreach($rule in $RuleSet.Rule){

                            #reset value to null on each loop
                            $FieldsValue = $null
                            $VariableValue = $null
                            If($RuleSet.VarName -and $rule.VarValue)
                            {
                                #Use a regex boundary arounf the exact character incase simliar characters are in list
                                $FoundRule = $rule | Where {$_.Char -match "\b$MatchedValue\b"}
                                #if the matching rule was found, then build some values to use
                                If($FoundRule)
                                {
                                    If($DebugPreference){Write-LogEntry ("Under ruleset [{0}], found matched rule [{1}] using identified value: [{2}]" -f $item,$Rule.Name,$FoundRule.Char) -Source ${CmdletName} -Severity 5}
                                    $FieldsValue = $FoundRule.Name
                                    $VariableValue = $FoundRule.VarValue

                                        Write-LogEntry ("Device identified as [{0}]; setting value to [{1}]" -f $FieldsValue,$VariableValue) -Source ${CmdletName} -Severity 1
                                    #check to see if the name already exists, it it does skip adding another one
                                    $VarValues.Add($RuleSet.VarName, $VariableValue)
                                    $UIFields.Add($RuleSet.Id, $FieldsValue)
                                }
                            }
                            ElseIf($rule.GetVariable)
                            {
                                If($DebugPreference){Write-LogEntry ("Querying [{0}] with matched property [{1}] using identified value: [{2}]" -f $rule.GetVariable,$rule.MatchProperty,$MatchedRules.Item($rule.SetVariable)) -Source ${CmdletName} -Severity 5}
                                try{
                                    $ExternalVariable = Get-Variable $rule.GetVariable -ValueOnly -ErrorAction Stop
                                    $FieldsValue = ($ExternalVariable | Where $rule.MatchProperty -eq $MatchedRules.Item($rule.SetVariable) ).($rule.DisplayProperty)
                                    $VariableValue = $MatchedRules.Item($rule.SetVariable)

                                    Write-LogEntry ("Device identified as [{0}]; setting value to [{1}]" -f $FieldsValue,$VariableValue) -Source ${CmdletName} -Severity 1
                                    $VarValues.Add($RuleSet.VarName, $VariableValue)
                                    $UIFields.Add($RuleSet.Id, $FieldsValue)
                                }
                                Catch{
                                    Write-LogEntry ("There was an error retrieving array [{0}]: {1}" -f$rule.GetVariable,$_.Exception.Message) -Source ${CmdletName} -Severity 3
                                }
                            }

                        }#end rule loop

                    } #end ruleset check

                }#end ruleset loop

                #if it gets here, all validations are true
                #$Validation = $true
            }
            #if computer does not match, determine the why
            Else
            {
                $done = $false;
                $test = [text.stringbuilder]''
                $HashedRules.GetEnumerator() | Foreach-Object {
                    if ($done) { return; }
                    $null = $test.Append($_.Value)
                    if (!($ComputerNameObject.text -match $test.ToString())) {
                        #"{0} failed at [{1}]" -f $OOBEUIWPF_inputTxtComputerName.text,$($_.Key)
                        $done = $true;
                        $Validation = Invoke-UIMessage -Message ("Device name is not compliant with naming standards. Rule: [{0}]" -f $($_.Key)) -HighlightObject $ComputerNameObject -OutputErrorObject $OutputErrorObject -Type Error -ReturnBool
                    }
                }

            }

        }
        #if computername failure
        Catch{
            $Validation = Invoke-UIMessage -Message ("Device name query error for: [{0}]" -f $ComputerNameObject.text) -HighlightObject $ComputerNameObject -OutputErrorObject $OutputErrorObject -Type Error -ReturnBool
            Write-LogEntry ("{1}" -f $_.Exception.Message) -Source ${CmdletName} -Severity 3
        }
    }
    End{
        # Build PSobject for Return Object
        $outputObject = New-Object -TypeName PSObject
        $memberParam=@{
            InputObject=$outputObject;
            MemberType='NoteProperty';
            Force=$true;
        }
        # what to return? If validation is false;
        # return that no mater what, otherwise return what specified
        Switch ($ReturnOption)
        {
        'Fields'    {
                        If($UIFields){
                            Foreach($Field in $UIFields.Keys){
                                Add-Member @memberParam -Name $Field -Value $UIFields.Item($Field)
                            }
                            Return $outputObject
                        }
                        Else{
                            Return $Validation
                        }
                    }

        'Variables' {
                        If($UIFields){
                            Foreach($Variable in $VarValues.Keys){
                                Add-Member @memberParam -Name $Variable -Value $VarValues.Item($Variable)
                            }
                            Return $outputObject
                        }
                        Else{
                            Return $Validation
                        }
                    }

        'All'       {
                        If($UIFields -and $VarValues){
                            Foreach($Field in $UIFields.Keys){
                                Add-Member @memberParam -Name $Field -Value $UIFields.Item($Field)
                            }
                            Foreach($Variable in $VarValues.Keys){
                                Add-Member @memberParam -Name $Variable -Value $VarValues.Item($Variable)
                            }
                            Return $outputObject
                        }
                        Else{
                            Return $Validation
                        }
                    }

        'status'    {Return $Validation}
        default     {Return $Validation}
        }
    }
}
#endregion