function New-ScriptBlock {
    [CmdletBinding()]
    param (
        # String of command to convert to scriptblock
        [Parameter(Position=0)]
        [String]
        $Command,

        # Create scriptblock from clipboard contents
        [Parameter(Position=1)]
        [Switch]
        $FromClipboard
    )
    if ($FromClipboard) {
        $command = Get-Clipboard -Raw
        if ($Command -eq $false) {
            Write-Verbose "Clipboard collection returned false."
            Return
        }
    }
    elseif ($Command.Length -lt 1) {
        $command = Read-Host "Enter command string"
    }
    [scriptblock]::Create($Command)
}
