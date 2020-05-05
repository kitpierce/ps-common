function Get-DeletedBitLockerKeys {
    [CmdletBinding()]
    param (
            # Admin Credentials
            [Parameter(Position=0)]
            [PSCredential] $Credential,
    
            # Objects Modified Within Last X Days
            [Parameter(Position=1)]
            [Int] $Days,


            # Resolve Deleted Computer Object
            [Parameter(Position=2)]
            [Switch] $ResolveComputer
    )
    
    begin {
        $ErrorActionPreference = 'Stop'

        # Define invocation call's name for use in Write-* commands
        if (-not ($MyInvocation.MyCommand.Name)) {$callName = ''}
        else {$callName = "[$($MyInvocation.MyCommand.Name)] "}

        [ARRAY]$local:DoNotPassParameters = @('ResolveComputer')
        $PassedParams = @{'Verbose' = $Verbose; 'AllProperties' = $true}
        $PSBoundParameters.GetEnumerator() | ForEach-Object {
            if ($_.Key -notin $local:DoNotPassParameters) {
                $PassedParams["$($_.Key)"] = $_.Value
            }
        }

        function Format-BitlockerKey {
            [CmdletBinding()]
            param (
                # Input Objects
                [Parameter(Position=0,Mandatory,ValueFromPipeline)]
                [Alias('AdObject','RecoveryInformation')]
                $KeyPackage
            )
            
            begin {
                $ErrorActionPreference = 'Stop'
        
                # Define invocation call's name for use in Write-* commands
                if (-not ($MyInvocation.MyCommand.Name)) {$callName = ''}
                else {$callName = "[$($MyInvocation.MyCommand.Name)] "}
            }
            
            process {
                $KeyPackage | Where-Object {$_} | ForEach-Object {
                    $item = $_
                    $class = $item | Select-Object -ExpandProperty ObjectClass -ErrorAction SilentlyContinue
        
                    if ($null -eq $class) {
                        Write-Warning "${callName}Null ObjectClass property for input object"
                    }
                    elseif ($class -notlike 'msFVE-RecoveryInformation') {
                        Write-Warning "${callName}Input ObjectClass is not a BitLocker key: '$class'"
                    }
                    else {
                        try {
                            #$RecoveryGUID = $($item.'msFVE-RecoveryGuid' -as [GUID]).GUID
                            #Write-Verbose "${callName}Processing BitLocker key: '$(($RecoveryGUID).ToUpper())'"
                            $flatProps = [Ordered]@{
                                ComputerName = $($item.LastKnownParent -split '\\0A' -replace '^CN=' | Select-Object -First 1)
                                DistinguishedName = $item.DistinguishedName
                                LastKnownParent = $item.LastKnownParent
                                Created = $item.Created
                                Modified = $item.Modified
                                LastKnownRDN = $item.'msDS-LastKnownRDN'
                                VolumeGuid = $($item.'msFVE-VolumeGuid' -as [GUID]).GUID
                                RecoveryGUID = $($item.'msFVE-RecoveryGuid' -as [GUID]).GUID
                                RecoveryPassword = $item.'msFVE-RecoveryPassword'
                                ObjectClass = $item.ObjectClass
                                IsDeleted = $item.IsDeleted
                            }
                            
                            Return $(New-Object -TypeName PSObject -Property $FlatProps)
                        }
                        catch {
                            Write-Warning "${callName}Error formatting BitLocker key"
                            Return $item
                        }
                    }
                }
            }
        }
        
        # Test for session access to required command(s)
        [ARRAY]$RequiredCommands = @('Get-DeletedObjects','Format-BitLockerKey')
        [ARRAY]$MissingCommands = $RequiredCommands | ForEach-Object {
            if ($null -eq (Get-Command -Name "$_" -ErrorAction SilentlyContinue)) {
                Write-Verbose "${callName}Cannot find command: '$_'"
                $_
            }
        }
        if ($MissingCommands) {
            Write-Warning "Missing $($MissingCommands.Count) required command(s): '$($MissingCommands -join "','")'"
            break
        }
        else {
            Remove-Variable -Scope Local -Name @('Missingcommands','RequiredCommands') -Verbose:$false
        }
    }
    
    process {
        Write-Verbose "${callName}Collecting deleted BitLocker key objects"
        try {
            $keys = Get-DeletedObjects -Type BitLockerKey @PassedParams
        }
        catch {
            Write-Warning "${callName}Failed to collect deleted BitLocker key objects"
            throw $_.Exception.Message
        }

        if ($keys.Count -lt 1) {
            Write-Warning "${callName}No BitLockerKey deleted objects returned - add 'Credential' parameter"
            break
        }

        if ($ResolveComputer -eq $true) {
            Write-Verbose "${callName}Collecting deleted ADComputer objects"
            try {
                $computers = Get-DeletedObjects -Type Computer @PassedParams
            }
            catch {
                Write-Warning "${callName}Failed to collect deleted ADComputer objects"
                #throw $_.Exception.Message
                $computers = $null
            }
        }
        else {
            $Computers = $null
        }

        Write-Verbose "${callName}Formatting BitLocker key data"
        $Formatted = New-Object -TypeName 'System.Collections.ArrayList'
        $keys | Where-Object {$_} | Sort-Object LastKnownParent | ForEach-Object {
            $tempKey = $_
            try {
                $tempForm = $tempKey | Format-BitLockerKey
                $Formatted += $tempForm
            }
            catch {
                Write-Warning "${callName}Formatting failed for key: '$($tempKey.DistinguishedName)'"
                $Formatted += $tempKey
            }
        }

        if ($null -ne $computers) {
            $Formatted | Where-Object {$_} | ForEach-Object {
                $tempKey = $_
                try {
                    $thisComp = $computers | Where-Object {$_.DistinguishedName -like $tempKey.LastKnownParent}
                    $_ | Add-Member -MemberType NoteProperty -Force -Name Computer -Value $thisComp
                }
                catch {
                    Write-Warning "${callName}Error resolving computer: '$($tempKey.ComputerName)'"
                }
            }
        }
    }
    
    end {
        $Formatted | Where-Object {$_} | ForEach-Object {$_}
    }
}
