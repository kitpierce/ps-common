Function Invoke-ExpandProperty {
    [CmdletBinding()]
    [Alias('Expand')]
    param (
        [Parameter(Position=0)]
        [String] $Property,  
        
        [Parameter(Position=1,Mandatory,ValueFromPipeline)]
        $InputObject
    )
    process {
        Try { 
            $MyInvocation.BoundParameters['InputObject'] | Select-Object -ExpandProperty $MyInvocation.BoundParameters['Property'] -ErrorAction Stop
        }
        Catch {
            throw $_.Exception.Message
        }
    }
}
