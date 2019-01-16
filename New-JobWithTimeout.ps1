function New-JobWithTimeout {
    [CmdletBinding(
        SupportsShouldProcess
    )]
    param (
        [Parameter(Position=0,Mandatory)] [Alias('CMD')] $Command,
        [Parameter(Position=1)] [Alias('Wait')] [Int] $Timeout = 10,
        [Switch]$KeepResults
    )
    
    begin {
        Write-Verbose "Issuing command: '$Command'"
        $CmdScriptblock = [scriptblock]::Create($Command)
    }
    
    process {
        $innerJob = Start-Job -Name "Job-$([Math]::Round((Get-Date).ToFileTimeUTC()))" -ScriptBlock $CmdScriptblock
        Write-Verbose "Starting job '$($innerJob.Name)' with ID '$($innerJob.ID)'"
        $innerJob | Wait-Job -Timeout $timeout | Out-Null
        $results = Receive-Job -Id $innerJob.Id -Keep:$KeepResults
        If ($KeepResults -ne $true) {
            $innerJob | Remove-Job -Force
        }
    }
    
    end {
        Write-Output $results
    }
}

#$Demo = "Get-ChildItem -Path '$(Get-Location)' -File -Recurse"
#$Demo = "Resolve-DNSName google.com"

#New-JobWithTimeout -Command $Demo -Verbose -KeepResults
