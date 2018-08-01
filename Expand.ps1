Function Expand {
    [CmdletBinding()]
    param (
        [Parameter(Position=0,ValueFromPipeline=$false)] $Property,  
        [Parameter(Position=1,ValueFromPipeline=$true)] $InputObject
    )
    Try { $MyInvocation.BoundParameters['InputObject'] | Select-Object -ExpandProperty $MyInvocation.BoundParameters['Property'] -ErrorAction Stop }
    Catch {Write-Warning "$($_.Exception.Message)"}
}
