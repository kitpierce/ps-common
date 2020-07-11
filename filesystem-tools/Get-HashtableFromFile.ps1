Function Get-HashtableFromFile {
    #See https://kevinmarquette.github.io/2017-02-20-Powershell-creating-parameter-validators-and-transforms/
    [cmdletbinding()]
    param( [Microsoft.PowerShell.DesiredStateConfiguration.ArgumentToConfigurationDataTransformation()] $Path )
    return $Path
}
