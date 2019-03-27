function Get-Clipboard {
    [CmdletBinding()]
    param (
        # Use raw text
        [Parameter(Position=0)]
        [switch]$Raw,

        # Trim text
        [Parameter(Position=1)]
        [switch]$Trim,

        # Uppercase text
        [Parameter(Position=2)]
        [switch]$ToUpper
    )
    #[void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    Add-Type -AssemblyName System.Windows.Forms
	$textBox = New-Object System.Windows.Forms.TextBox
	$textBox.Multiline = $true
	$textBox.Paste()
	if ( !$Raw ) {
	    $arrText = $textBox.Text.Split("`r`n") | Where-Object { $_ }
	    $result = @()
	    foreach ( $line in $arrText ) {
		if ( $Trim ) { $line = $line.Trim() -Replace "^\W*",'' }
	        if ( $ToUpper ) { $line = $line.ToUpper() }
	        $result += $line
	    }
        Return $result
    }
	Return $textBox.Text
}
