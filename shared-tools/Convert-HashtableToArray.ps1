Function Convert-HashtableToArray {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0,Mandatory=$True,ValueFromPipeline=$True)] [Alias("Hash","InputObject")] $Hashtable,
        [Parameter(Position=1,Mandatory=$False)] [Alias("KeyLabel")] $KeyName,
        [Parameter(Position=2,Mandatory=$False)] [Alias("ValueLabel")] $ValueName
    )
    
    # Set label/name for 'Key' field
    If ($PSBoundParameters['KeyName']) {Write-Verbose "Setting key label to '$KeyName'"}
    Else {$KeyName = 'Name'; Write-Verbose "Using default key label '$KeyName'"}
    
    # Set label/name for 'Value' field
    If ($PSBoundParameters['ValueName']) {Write-Verbose "Setting value label to '$ValueName'"}
    Else {$ValueName = 'Value'; Write-Verbose "Using default value label '$ValueName'" }

    Write-Verbose "Converting hashtable to array"
    # Create collector array
    [ARRAY]$GroupArray = @()

    # Enumerate hashtable, sort by key value
    $Hashtable.GetEnumerator() | Sort Key | % {
        # Define hash of properties
        $hashProps = [ORDERED]@{ 
            $KeyName = $_.Key;
            'Count' = $_.Value.Count; 
            $ValueName = $_.Value 
        }
        # Create object for each input hashtable key, and append to collector
        [ARRAY]$GroupArray += New-Object -TypeName PSObject -Property $hashProps
    }
    Return $GroupArray
}
