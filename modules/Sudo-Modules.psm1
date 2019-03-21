
function Redo-Command {
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter(Position=0)]
        $Command,

        # Prompt user for command to elevate
        [Switch] $Prompt,

        # Rerun last command
        [Switch] $Last,

        # Run command with elevated permissions
        [Alias('RunAs')]
        [Switch] $Sudo
    )
    
    begin {
        if ($Last -eq $true) {
            $Command = '!!'
        }

        if ($Prompt -eq $true) {
            $CommandString = 'Provide command to run'
        }
        elseif (-not $Command) {            
            Write-Warning "No command (or command ID) specified - nothing to do."
            Break
        }
        elseif ($Command -like '!!') {
            $histKey = $(Get-History ((Get-History).Count))[0]
            $histID = $histKey.ID
            $commandString = $histKey.CommandLine
            Write-Host "Running last command (ID: $($histID)): " -NoNewline -ForegroundColor Yellow
            Write-Host $commandString -ForegroundColor Red
        }
        elseif ($Command -match '\!([0-9])+') {
            try {
                $cmdNumber = $Command -replace '^\!'
                $historyIndex = [INT]$($cmdNumber - 1)
                $histKey = $(Get-History)[$historyIndex]
                $histID = $histKey.ID
                $commandString = $histKey.CommandLine
            }
            catch {
                Write-Warning "Unable to collect PSHistory object with ID of '$cmdNumber'"
                throw $_.Exception.Message
            }
            Write-Host "Running command #$($histID): " -NoNewline -ForegroundColor Yellow
            Write-Host $commandString -ForegroundColor Red
        }
        elseif ($Command.GetType().FullName -like 'System.Management.Automation.ScriptBlock') {
            $commandString = $Command.ToString()
            Write-Host "Detected 'ScriptBlock' input type - converted to string: " -NoNewline -ForegroundColor Yellow
            Write-Host $commandString -ForegroundColor Red
        }
        elseif ($Command.GetType().FullName -like 'System.Int32') {
            try {
                $cmdNumber = $command
                $historyIndex = [INT]$($cmdNumber - 1)
                $histKey = $(Get-History)[$historyIndex]
                $histID = $histKey.ID
                $commandString = $histKey.CommandLine
            }
            catch {
                Write-Warning "Unable to collect PSHistory object with ID of '$cmdNumber'"
                throw $_.Exception.Message
            }
            Write-Host "Running command #$($histID): " -NoNewline -ForegroundColor Yellow
            Write-Host $commandString -ForegroundColor Red
        }
        elseif ($Command.GetType().FullName -like 'System.String') {
            $commandString = $command
            Write-Host "Running command string: " -NoNewline -ForegroundColor Yellow
            Write-Host $commandString -ForegroundColor Red
        }
    }
    
    process {
        if ($PSBoundParameters['Sudo'] -eq $true) {
            $argList = $CommandString -split "\s+"
            Start-Process -FilePath powershell.exe -ArgumentList $argList -WorkingDirectory $(Get-Location) -Verb RunAs -Wait
        }
        else {
            Invoke-Command -ScriptBlock $([ScriptBlock]::Create($CommandString))
        }
    }
}

function Redo-AsAdmin {
    [CmdletBinding()]
    param (
        # Command to run
        [Parameter(Position=0)]
        [ValidateNotNullOrEmpty()]
        $Command,

        # Rerun last command
        [Parameter(Position=1)]
        [Switch] $Last,

        # Prompt for command to run
        [Parameter(Position=2)]
        [Switch] $Prompt 
    )
    
    if ($PSBoundParameters['Last'] -eq $true) {
        Redo-Command -Sudo -Last
    }
    elseif ($PSBoundParameters['Prompt'] -eq $true) {
        Redo-Command -Sudo -Prompt
    }
    elseif ($PSBoundParameters['Command'] -AND $Command.Length -gt 0) {
        Redo-Command -Sudo -Command $Command
    }
    else {
        Write-Warning "No command to run - use parameter 'Command' 'Last' or 'Propmpt'"
        break
    }
}

function Redo-LastCommandAsAdmin {
    $cmd = (Get-History ((Get-History).Count))[0].CommandLine
    $argList = $cmd -split "\s+"
    try {
        Start-Process -FilePath powershell.exe -ArgumentList $argList -WorkingDirectory $(Get-Location) -Verb RunAs -Wait -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed 'Start-Process' - exception: $($_.Exception.Message)"
    }
}

Set-Alias -Name FUUUUUUUUU -Value Redo-LastCommandAsAdmin
Set-Alias -Name redo -Value Redo-Command
Set-Alias -Name sudo -Value Redo-AsAdmin

Export-ModuleMember *
