function New-ArrayFromString {
    [CmdletBinding()]
    param (
        # Input String
        [Parameter(Position=0,Mandatory,ValueFromPipeline)]
        [Alias('InputString','Input')]
        [String[]] $String,

        # Character to split on
        [Parameter(Position=1)]
        [Alias('Split','SplitChar')]
        [System.Char] $SplitOn,

        # Collect string from clipboard
        [Parameter(Position=2)]
        [Switch] $FromClipboard,

        # Do not trim whitespace from array members
        [Parameter(Position=3)]
        [Switch] $NoTrim,

        # Split on whitespace
        [Parameter(Position=4)]
        [Switch] $WhitespaceSplit
    )
    
    begin {
        [ARRAY]$collection = @()

        if (($WhitespaceSplit -ne $true) -AND (-not $SplitOn)) {
            $response = Read-Host "Enter The Text Split Character (or ENTER for whitespace-split)"
            if ($response.Length -lt 1) {
                Write-Verbose "Response was empty, splitting on whitespace"
                $WhitespaceSplit = $true
            }
            else {
                $splitOn = $response.ToCharArray()[0]
            }
        }

        if ($FromClipboard -eq $true) {
            $string = Get-Clipboard
        }
    }
    
    process {
        ForEach ($inputString in $String) {
            if ($WhitespaceSplit -eq $true) {
                $tempColl = $inputString -split '\s+'
            }
            elseif ($inputString -notmatch [REGEX]::Escape($SplitOn)) {
                $tempColl = $inputString -split $SplitOn 
            }
            else {
                Write-Warning "Input string does not match split-on character: '$splitOn'"
            }
            
            $tempColl | ForEach-Object {
                if ($NoTrim -ne $false) { [ARRAY]$collection += $_ }
                else { [ARRAY]$collection += $($_).Trim()}
            }
        }
    }
    
    end {
        Return $collection
    }
}
