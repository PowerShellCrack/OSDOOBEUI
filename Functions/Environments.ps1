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

#region FUNCTION: Attempt to connect to Task Sequence environment
Function Test-SMSTSENV{
  <#
      .SYNOPSIS
          Tries to establish Microsoft.SMS.TSEnvironment COM Object when running in a Task Sequence

      .REQUIRED
          Allows Set Task Sequence variables to be set

      .PARAMETER ReturnLogPath
          If specified, returns the log path, otherwise returns ts environment
  #>
  param(
      [switch]$ReturnLogPath
  )

  Begin{
      ## Get the name of this function
      [string]${CmdletName} = $MyInvocation.MyCommand

      if ($PSBoundParameters.ContainsKey('Verbose')) {
          $VerbosePreference = $PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference')
      }
  }
  Process{
      try{
          # Create an object to access the task sequence environment
          $Script:tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
          If($DebugPreference){Write-LogEntry ("Task Sequence environment detected!") -Source ${CmdletName} -Severity 5}
      }
      catch{

          If($DebugPreference){Write-LogEntry ("Task Sequence environment NOT detected. Running with script environment variables") -Source ${CmdletName} -Severity 5}
          #set variable to null
          $Script:tsenv = $null
      }
      Finally{
          #set global Logpath
          if ($Script:tsenv){
              #grab the progress UI
              $Script:TSProgressUi = New-Object -ComObject Microsoft.SMS.TSProgressUI

              # Convert all of the variables currently in the environment to PowerShell variables
              #$tsenv.GetVariables() | ForEach-Object { Set-Variable -Name "$_" -Value "$($tsenv.Value($_))" }

              # Query the environment to get an existing variable
              # Set a variable for the task sequence log path

              #Something like: C:\MININT\SMSOSD\OSDLOGS
              #[string]$LogPath = $tsenv.Value("LogPath")
              #Somthing like C:\WINDOWS\CCM\Logs\SMSTSLog
              [string]$LogPath = $tsenv.Value("_SMSTSLogPath")

          }
          Else{
              [string]$LogPath = $env:Temp
              $Script:tsenv = $false
          }
      }
  }
  End{
      If($ReturnLogPath){
          return $LogPath
      }
      Else{
          return $Script:tsenv
      }
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

Function Resolve-ActualPath{
    [CmdletBinding()]
    param(
        [string]$FileName,
        [string]$WorkingPath,
        [Switch]$Parent
    )
    ## Get the name of this function
    [string]${CmdletName} = $MyInvocation.MyCommand

    Write-LogEntry ("Attempting to resolve filename: {0}" -f $FileName) -Source ${CmdletName} -Severity 1
    If(Resolve-Path $FileName -ErrorAction SilentlyContinue){
        $FullPath = Resolve-Path $FileName
    }
    #If unable to resolve the file path try building path from workign path location
    Else{
        $FullPath = Join-Path -Path $WorkingPath -ChildPath $FileName
    }

    Write-LogEntry ("Attempting to resolve with full path: {0}" -f $FullPath) -Source ${CmdletName} -Severity 1
    #Try to resolve the path one more time using the fullpath set
    Try{
        $ResolvedPath = Resolve-Path $FullPath -ErrorAction $ErrorActionPreference
    }
    Catch{
        Write-LogEntry ("Unable to resolve path: {0}: {1}" -f $FullPath,$_.Exception.Message) -Source ${CmdletName} -Severity 3
        Throw ("{0}" -f $_.Exception.Message)
    }
    Finally{
        If($Parent){
            $Return = Split-Path $ResolvedPath -Parent
        }Else{
            $Return = $ResolvedPath
        }
        $Return
    }
}

Function ConvertTo-Object {
    param (
        [Parameter(Position = 0,Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )] [object[]]$node
    )

    begin {
        $PSObject = New-Object PSObject
    }
    process {
        $PSObject = $node | ConvertTo-Csv | ConvertFrom-Csv
    }
    end{
        return $PSObject
    }

}
function ConvertFrom-Xml {
    <#
    .SYNOPSIS
        Converts XML object to PSObject representation for further ConvertTo-Json transformation
    .EXAMPLE
        # JSON->XML
        $xml = ConvertTo-Xml (get-content 1.json | ConvertFrom-Json) -Depth 4 -NoTypeInformation -as String
    .EXAMPLE
        # XML->JSON
        ConvertFrom-Xml ([xml]($xml)).Objects.Object | ConvertTo-Json
    #>
        param([System.Xml.XmlElement]$Object)

        if (($null -ne $Object) -and ($null -ne $Object.Property)) {
            $PSObject = New-Object PSObject

            foreach ($Property in @($Object.Property)) {
                if ($Property.Property.Name -like 'Property') {
                    $PSObject | Add-Member NoteProperty $Property.Name ($Property.Property | % {ConvertFrom-Xml $_})
                } else {
                    if ($null -ne $Property.'#text') {
                        $PSObject | Add-Member NoteProperty $Property.Name $Property.'#text'
                    } else {
                        if ($null -ne $Property.Name) {
                            $PSObject | Add-Member NoteProperty $Property.Name (ConvertFrom-Xml $Property)
                        }
                    }
                }
            }
            $PSObject
        }
    }
#endregion

function ConvertTo-HashTable{
    param($Node)

    $hash = @{}
    foreach($attribute in $node)
    {
        $hash.$($attribute.name) = $attribute.Value
    }
    $childNodesList = ($node.childnodes | ?{$_ -ne $null}).LocalName
    foreach($childnode in ($node.childnodes | ?{$_ -ne $null}))
    {
        if(($childNodesList | ?{$_ -eq $childnode.LocalName}).count -gt 1)
        {
            if(!($hash.$($childnode.LocalName))){
                $hash.$($childnode.LocalName) += @()
            }
            if ($null -ne $childnode.'#text') {
                $hash.$($childnode.LocalName) += $childnode.'#text'
            }
            $hash.$($childnode.LocalName) += xmlNodeToPsCustomObject($childnode)
        }
        else{
            if ($null -ne $childnode.'#text') {
                $hash.$($childnode.LocalName) = $childnode.'#text'
            }
            else{
                $hash.$($childnode.LocalName) = xmlNodeToPsCustomObject($childnode)
            }
        }
    }
    return $hash
}

Function Convert-XMLtoPSObject {
    Param (
        $XML
    )
    $Return = New-Object -TypeName PSCustomObject
    $xml |Get-Member -MemberType Property |Where-Object {$_.MemberType -EQ "Property"} |ForEach {
        IF ($_.Definition -Match "^\bstring\b.*$") {
            $Return | Add-Member -MemberType NoteProperty -Name $($_.Name) -Value $($XML.($_.Name))
        } ElseIf ($_.Definition -Match "^\System.Xml.XmlElement\b.*$") {
            $Return | Add-Member -MemberType NoteProperty -Name $($_.Name) -Value $(Convert-XMLtoPSObject -XML $($XML.($_.Name)))
        } Else {
            Write-Host " Unrecognized Type: $($_.Name)='$($_.Definition)'"
        }
    }
    $Return
}

function ConvertTo-Object {
    param (
        [Parameter(Position = 0,Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )] [object[]]$hashtable
    )

    begin { $i = 0; }

    process {
        foreach ($myHashtable in $hashtable) {
            if ($myHashtable.GetType().Name -eq 'hashtable') {
                $output = New-Object -TypeName PsObject;
                Add-Member -InputObject $output -MemberType ScriptMethod -Name AddNote -Value {
                    Add-Member -InputObject $this -MemberType NoteProperty -Name $args[0] -Value $args[1];
                }
                $myHashtable.Keys | Sort-Object | % {
                    $output.AddNote($_, $myHashtable.$_);
                }
                $output
            } else {
                Write-Warning "Index $i is not of type [hashtable]"
            }
            $i += 1;
        }
    }
}

Function Test-IsNull([string]$Value){
    if ( [string]::IsNullOrEmpty($Value) -or [string]::IsNullOrWhiteSpace($Value) ){ return $null }
    else { return $Value }
}