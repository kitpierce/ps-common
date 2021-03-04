function Get-InstalledSoftware {
    [CmdletBinding()]
    param ()

    begin {
        $ErrorActionPreference = 'Stop'

        # Define invocation call's name for use in Write-* commands
        if (-not ($MyInvocation.MyCommand.Name)) {$callName = ''}
        else {$callName = "[$($MyInvocation.MyCommand.Name)] "}

        $InstalledSoftware = [System.Collections.Generic.List[Object]]::New()
        $DropPattern = '^PS(Path|ParentPath|ChildName|Provider)$'
    }

    process {

        ForEach ($hive in @('HKCU', 'HKLM')) {
            $scope = Switch ($Hive) {
                'HKCU' { 'CurrentUser' }
                'HKLM' { 'LocalMachine' }
                default { $Hive }
            }

            Write-Verbose "${callName}Getting software from scope: '$Scope'"

            $RegPath = "{0}:\{1}" -f $hive, 'Software\Microsoft\Windows\CurrentVersion\Uninstall'
            Get-ChildItem $RegPath | Where-Object { $_ } | ForEach-Object {
                $thisChild = $_ | Get-ItemProperty

                $OutProps = [ORDERED]@{
                    'Hive'            = $Scope
                    'Name'            = $thisChild.PSChildName
                    'DisplayName'     = $null
                    'Publisher'       = $null
                    'DisplayVersion'  = $null
                    'InstallLocation' = $null
                    'InstallDate'     = $null
                    'EstimatedSize'   = $null
                    'UninstallString' = $null
                    'RegistryPath'    = $thisChild.PSPath -replace '.*Registry::'
                }

                [String[]]$TableProps = $OutProps.Keys

                $foundProps = 0
                $thisChild.PSObject.Properties | Where-Object { $_ } | ForEach-Object {
                    if ($_.Name -notmatch $DropPattern) {
                        $foundProps++
                        $OutProps[$_.Name] = $_.Value
                    }
                }

                if ($foundProps -ge 1) {
                    $outObj = New-Object -TypeName PSObject -Property $OutProps
                    $showObj = "{0}`n" -f $($outObj | Format-List $TableProps | Out-String).TrimEnd()
                    Write-Verbose "${callName}Found installed program: $showObj"
                    $InstalledSoftware.Add($outObj)
                }
            }
        }
    }

    end {
        $InstalledSoftware | Where-Object {$_} | Sort-Object RegistryPath | ForEach-Object {$_}
        Write-Verbose "${callName}Total installed software count: '$($installedSoftware.Count)'"
    }
}
