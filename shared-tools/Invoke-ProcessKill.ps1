function Invoke-ProcessKill {
    [Alias('killall')]
    [CmdletBinding()]
    param (
        # Process Name
        [Parameter(Position=0,ValueFromPipeline)]
        [String[]] $Name,

        # Use Fuzzy Name Matching
        [Parameter(Position=1)]
        [Switch] $FuzzyMatch,

        # Force Stop Process
        [Parameter(Position=2)]
        [Switch] $Force,

        # Provide Additional Feedback
        [Parameter(Position=3)]
        [Switch] $Troubleshoot
    )
    begin {
        $ErrorActionPreference = 'Stop'

        # Define invocation call's name for use in Write-* commands
        if (-not ($MyInvocation.MyCommand.Name)) {$callName = ''}
        else {$callName = "[$($MyInvocation.MyCommand.Name)] "}

        # Set verbose/debug levels as per 'Troubleshoot' parameter
        if ($Troubleshoot) {
            $DebugPreference = 'Continue'
            $VerbosePreference = 'Continue'
         }

        $procHash = [System.Collections.Hashtable]::New()
    }
    process {
        if ($null -eq $PSBoundParameters['Name']) {
            Write-Host "Enter process name: " -NoNewLine 
            $Name = Read-Host ":"
        }

        Write-Debug "${callName}Getting all processes"
        [System.Diagnostics.Process[]]$allProcs = Get-Process

        $Name | Where-Object {$_.Length -ge 1} | ForEach-Object {
            $i=0
            $thisName = $_
            Write-Debug "${callName}Comparing processes to input: '$thisName'"
            $thisInt = $thisName -AS [INT]
            $thisBase = $($thisName -as [System.IO.FileInfo]).BaseName

            $allProcs | Where-Object {$_} | ForEach-Object {
                $showPid = "[{0}]" -f $_.ID

                if ($thisInt -ge 1 -AND $_.ID -eq $thisInt) {
                    Write-Verbose "${callName}Found process by ID: $showPID '$($_.ProcessName)'"
                    $i++
                    $procHash["$($_.ID)"] = $_
                }
                elseif ($_.ProcessName -like $thisName) {
                    Write-Verbose "${callName}Found process by ProcessName: $showPid '$($_.ProcessName)'"
                    $i++
                    $procHash["$($_.ID)"] = $_
                }
                elseif ($_.Path -like $thisName) {
                    Write-Verbose "${callName}Found process by Path: $showPID '$($_.Path)'"
                    $i++
                    $procHash["$($_.ID)"] = $_
                }
                elseif ($_.MainModule.ModuleName -like $thisName) {
                    Write-Verbose "${callName}Found process by MainModule name: $showPID '$($_.ProcessName)'"
                    $i++
                    $procHash["$($_.ID)"] = $_
                }
                elseif ($_.MainModule.FileName -like $thisName) {
                    Write-Verbose "${callName}Found process by MainModule file: $showPID '$($_.ProcessName)'"
                    $i++
                    $procHash["$($_.ID)"] = $_
                }
                


                if ($i -lt 1 -AND $PSBoundParameters['FuzzyMatch'] -eq $true) {
                    $thisPattern = [Regex]::Escape($thisName) -replace '\\\*','.*'
                    Write-Debug "${callName}No exact matches for '$thisName' - performing fuzzy match tests"
                    if ($_.ProcessName -match $thisPattern) {
                        Write-Verbose "${callName}Found process by ProcessName pattern: $showPid '$($_.ProcessName)'"
                        $i++
                        $procHash["$($_.ID)"] = $_
                    }
                    elseif ($_.Path -match $thisPattern) {
                        Write-Verbose "${callName}Found process by Path pattern: $showPid '$($_.Path)'"
                        $i++
                        $procHash["$($_.ID)"] = $_
                    }
                }

                if ($i -lt 1 -AND $null -ne $thisBase -AND $thisBase -notlike $thisName) {
                    if ($_.ProcessName -like $thisBase) {
                        Write-Verbose "${callName}Found process by basename: $showPid '$($_.ProcessName)'"
                        $i++
                        $procHash["$($_.ID)"] = $_
                    }
                }
            }
            
            if ($i -lt 1) {
                Write-Warning "${callName}No processes for input: '$thisName'"
            }
        }
    }
    
    end {
        $keyCount = $procHash.Keys | Measure-Object | Select-Object -ExpandProperty Count

        if ($keyCount -lt 1) {
            Write-Verbose "${callName}No process matches for any 'Name' parameter value"
        }
        else {
            $showProcs = $procHash.Values | Sort-Object ID | Select-Object Name,
                @{N='MainModule';E={$_.MainModule.ModuleName}},Responding,ID,Handles,
                @{N='CPUs';E={[Math]::Round(($_.CPU),2)}},
                @{N='PagedMB';E={[Math]::Round(($_.PagedSystemMemorySize/1MB),2)}},
                @{N='NonpagedMB';E={[Math]::Round(($_.NonpagedSystemMemorySize/1MB),2)}},
                FileVersion | Format-Table -Autosize | Out-String
            Write-Host "${callName}Total matching process count: '$keyCount'" -ForegroundColor Green -BackgroundColor Black
            Write-Host ("{0}`n`n" -f $showProcs.TrimEnd())

            Write-Host "Kill process list above?" -ForegroundColor Yellow -BackgroundColor Black -NoNewLine
            $response = Read-Host " [yes/NO]"
            if ($response -notmatch '^(y|yes)$') {
                Write-Warning "${callName}User declined process kill - nothing to do"
            }
            else {
                $procHash.Values | Where-Object {$_} | ForEach-Object {
                    $handle = $_
                    $thisProc = $handle | Get-Process -ErrorAction SilentlyContinue

                    if ($null -eq $thisProc) {
                        Write-Warning "${callName}Process no longer exists: '$($handle.Name)' [ID:$($handle.ID)]"
                    }
                    else {
                        $showProc = "'{0}' [ID:{1}]" -f $thisProc.Name,$thisProc.ID

                        if ($PSBoundParameters['Force'] -eq $true) {
                            $windowClosed = $false
                        }
                        else {
                            Write-Debug "${CAllName}Invoking process 'CloseMainWindow' method: $showProc"
                            try {
                                $windowClosed = $thisProc.CloseMainWindow()
                                if ($windowClosed -eq $true) {
                                    Write-Verbose "${callName}Invoked 'CloseMainWindow' method for process: $showProc"
                                }
                            }
                            catch {
                                Write-Warning "${callName}Failed method 'CloseMainWindow' for process ID: '$($thisProc.ID)'"
                                $windowClosed = $false
                            }
                        }

                        if ($windowClosed -ne $true) {
                            Write-Debug "${CallName}Invoking 'Stop-Process' command: $showProc"
                            try {
                                $thisProc | Stop-Process -Force
                                Write-Verbose "${callName}Stopped process: $showProc"
                            }
                            catch {
                                $xm = "{0}`n{1}" -f $showProc,$_.Exception.Message
                                Write-Warning "${callName}Failed 'Stop-Process' for process: $xm"
                            }
                        }
                    }
                }
            }
        }
    }
}
