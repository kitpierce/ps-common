function Test-Process {
 <#
.SYNOPSIS
    Function to test a Windows process(es) 
.DESCRIPTION
    Function to test whether a Windows process matching name(s) provided is in a desired state (Running|NotRunning)
.EXAMPLE
    PS C:\> Test-Process -ProcessName 'nodepad'
    
    Checks for a process named 'notepad' - if process is running, return $false; if process is not running, return $true.
    Note: the name comparison is a Regex match, so this would search for any name containing 'notepad' (such as 'notepad' and 'notepad++')
.EXAMPLE
    PS C:\> Test-Process -ProcessName 'nodepad|wordpad' -ExactMatches
    
    Check for a process named either 'notepad' or 'wordpad'- if process matching either is found, return $false; if process is not found, return $true
.EXAMPLE
    PS C:\> Test-Process -ProcessName 'nodepad|wordpad' -DesiredState Running -ExactMatches -ReturnType Objects
    
    Check for a process named either 'notepad' or 'wordpad'- if process matching either is found, return $false; if process is not found, return $true

.INPUTS
    Mandatory input is $ProcessName containing one or more strings matching the process name.
.OUTPUTS
    If parameter 'ReturnType' is 'Boolean', the output will be either a Boolean 'True/False' - this is the default setting for 'ReturnType'
    
    If parameter 'ReturnType' is 'Objects' and 'DesiredState' is 'Running', the output will be the matching process objects found 
    or a Boolean 'True/False' if no such processes are found.
.NOTES
    Author:     Kit Pierce
    Version:    0.1
#>
    [CmdletBinding()]
    param (
        # Name (or names) of process to check.  Supports pipe to separate search terms.
        [Parameter(Position=0,Mandatory=$true)]
        [Alias('Name','Process')]
        [String[]] $ProcessName,

        # Desired state of process (either 'Running' or 'NotRunning')
        [Parameter(Position=1)]
        [Alias('State')]
        [ValidateSet('Running','NotRunning')]
        [String] $DesiredState = 'NotRunning',

        # Maximum wait in seconds before timeout (default: 60 seconds)
        [Parameter(Position=2)]
        [Int] $Timeout = 120,

        # Seconds between status checks
        [Parameter(Position=3)]
        [Int] $Interval = 3,

        # Type of object to return from function (either 'Boolean' or 'Objects')
        [Parameter(Position=4)]
        [Alias('Return')]
        [ValidateSet('Boolean','Objects')]
        [String] $ReturnType = 'Boolean',

        # Force strict matches for process name.  If specified, the name string provied must match exactly, otherwise Regex matches on name are used.
        [Switch]$ExactMatches
    )

    begin {
        ForEach ($testParam in @('DesiredState','Timeout','Interval','ReturnType','ExactMatches')) {
            If (-NOT $PSBoundParameters.ContainsKey("$TestParam")) {
                Write-Verbose "No PSBoundParamter '$testParam' - using default value: '$(Get-Variable -Name $testParam -ValueOnly)'"
            }
            Else {
                Write-Verbose "Using PSBoundParamter '$testParam' value: '$($PSBoundParameters["$TestParam"])'"
            }
        }
        

        If ($ExactMatches) {
            Write-Verbose "Creating array of names for process name matching"
            [ARRAY]$NameArray = $ProcessName -split '\|'
            Write-Verbose "Using name array: '$($NameArray -join "','")'"
        }
        Else {
            # Create Regex pattern for process name matches
            Write-Verbose "Creating Regex pattern for process name matching"
            $NamePattern = $( $ProcessName | ForEach-Object { 
                [REGEX]::Escape($_) -replace '\\\*','(.*)' -replace '\\\|','|'
            } ) -join '|'
            Write-Verbose "Using name Regex pattern: '$NamePattern'"
        }
        
        # Collect function's starting time (for timeout comparisons)
        $startTime = Get-Date
    }

    process {
        If ($DesiredState -like 'Running') {
            Do {
                # Collect processes meeting name search criteria (stored in array to provide testable 'Count' property)
                If ($ExactMatches) {
                    # Find processes using exact name match from 'NameArray'
                    [ARRAY]$RunningProcesses = Get-Process | Where-Object {$NameArray -contains $_.ProcessName} | Sort-Object -Property ID
                }
                Else {
                    # Find processes using Regex pattern match of 'NamePattern'
                    [ARRAY]$RunningProcesses = Get-Process | Where-Object {$_.ProcessName -match $NamePattern} | Sort-Object -Property ID
                }

                # Compare running time with 'StartTime' variable to collect total runtime in seconds
                $runTime = $(Get-Date) - $startTime | Select-Object -ExpandProperty TotalSeconds

                # Test whether found process count is positive (greater than zero)
                If ($RunningProcesses.Count -gt 0) {
                    # Create & display simple report of matching processes
                    Write-Verbose "Desired state '$DesiredState' has been reached."
                    
                    If ($ReturnType -like 'Boolean') {
                        $ProcessString = $($RunningProcesses | Sort-Object -Property ID | Out-String).TrimEnd()
                        Write-Verbose "Found $($runningProcesses.Count) process(es) matching search criteria`n$ProcessString`n"
                        
                        # Indicate success condition by returning boolean 'TRUE'
                        Return $true
                    }
                    Else {
                        # Return matching process objects
                        Return $RunningProcesses
                    }
                }
                # Test whether total runtime exceeds maximum wait timeout variable
                ElseIf ($runTime -ge $Timeout) {
                    Write-Warning "Timeout ($timeout seconds) reached while checking for desired state '$DesiredState'"
                    
                    # Indicate failure condition by returning boolean 'FALSE'
                    Return $false
                }
                # Sleep/wait the specified interval before restarting 'Do' loop
                Else {
                    Write-Verbose "`t--> Check for '$DesiredState' running for $runtime seconds, last iteration found no matching process(es)..."
                    Start-Sleep -Seconds $Interval
                }
            }
            Until (($RunningProcesses.Count -gt 0) -OR ($runTime -ge $Timeout))
        }

        ElseIf ($DesiredState -like 'NotRunning') {
            Do {
               # Collect processes meeting name search criteria (stored in array to provide testable 'Count' property)
               If ($ExactMatches) {
                    # Find processes using exact name match from 'NameArray'
                    [ARRAY]$RunningProcesses = Get-Process | Where-Object {$NameArray -contains $_.ProcessName} | Sort-Object -Property ID
                }
                Else {
                    # Find processes using Regex pattern match of 'NamePattern'
                    [ARRAY]$RunningProcesses = Get-Process | Where-Object {$_.ProcessName -match $NamePattern} | Sort-Object -Property ID
                }

                # Compare running time with 'StartTime' variable to collect total runtime in seconds
                $runTime = $(Get-Date) - $startTime | Select-Object -ExpandProperty TotalSeconds

                # Test whether and processes were fount (count is less than one)
                If ($RunningProcesses.Count -lt 1) {
                    Write-Verbose "Desired state '$DesiredState' has been reached - found no process matching search criteria"
                    # Indicate success condition by returning boolean 'TRUE'
                    Return $true
                }
                # Test whether total runtime exceeds maximum wait timeout variable
                ElseIf ($runTime -ge $Timeout) {
                    Write-Warning "Timeout ($timeout seconds) reached while checking for desired state '$DesiredState'"

                    # Create & display simple report of matching processes
                    $ProcessString = $($RunningProcesses | Sort-Object -Property ID | Out-String).TrimEnd()
                    Write-Warning "Last check returned the following results:`n$ProcessString`n"
                    
                    # Indicate failure condition by returning boolean 'FALSE'
                    Return $false
                }
                # Sleep/wait the specified interval before restarting 'Do' loop
                Else {
                    Write-Verbose "`t--> Check for '$DesiredState' running for $runtime seconds, last iteration found $($RunningProcesses.Count) matching process(es)..."
                    Start-Sleep -Seconds $Interval
                }
            }
            Until (($RunningProcesses.Count -lt 1) -OR ($runTime -ge $Timeout))
        }

        Else {
            Write-Warning "Unexpected 'DesiredState' parameter value: '$DesiredState'"
            # Indicate failure condition by returning boolean 'FALSE'
            Return $false
        }
    }
}


#[String[]]$TestName = 'wordpad|notepad','firefox','vmware' 
#Test-Process -Name $TestName -State Running -Timeout 10 -Verbose

