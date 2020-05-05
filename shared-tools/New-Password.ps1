Function New-Password {
    <#
    .SYNOPSIS
    Creates new password.
    
    .DESCRIPTION
    Creates one or more psuedo-random passwords or user-defined length.  Each password
    contains at least one upper-case character, one lower-case character, and 
    one non-alphanumeric character.
    
    .EXAMPLE
    PS C:\> New-Password
    
    Creates single password using default values

    .EXAMPLE
    PS C:\> New-Password -Length 32 -Count 10 -NonAlpha 3
    
    Creates 10 passwords, each 32 characters in length and containing 3 non-alphanumeric characters.
    
    .PARAMETER Length
    [Int] Length of new password.

    Default value: 24
    Minimum value: 8
    Maximum value: 256

    .PARAMETER Count
    [Int] Number of passwords to generate.

    Default value: 1
    Minimum value: 1
    Maximum value: 256

    .PARAMETER NonAlpha
    [Int] Number of non-alphanumeric characters to include.
    Values exceeding 50% of 'Length' parameter are rounded down.
    
    Default value: 1
    Minimum value: 1
    Maximum value: 128 (not to exceed 1/2 of 'Length')

    .PARAMETER AllowAmbiguous
    [Switch] Allow ambiguous characters in password.  If not set,
    passwords will not contain the following characters: 

        '|' - Pipe character
        'l' - lower-case letter 'L' (ell)
        'I' - upper-case letter 'I' (eye)
        'O' - upper-case letter 'O' (oh)
        '0' - numeral zero
        '1' - numeral one
       
    .OUTPUTS
    [System.String[]]
    
    #>
    [CmdletBinding()]
    param (
        # Password Length
        [Parameter(Position=0)]
        [ValidateRange(8,256)]
        [Int] $Length,

        # Count Of Passwords To Generate
        [Parameter(Position=1)]
        [ValidateRange(1,258)]
        [Int] $Count,

        # Number Of Non-Alpha Chars
        [Parameter(Position=2)]
        [ValidateRange(1,128)]
        [Int] $NonAlpha,

        # Allow Ambiguous Charaters
        [Parameter(Position=3)]
        [Switch] $AllowAmbiguous
    )
    begin {
        $ErrorActionPreference = 'Stop'

        # Define invocation call's name for use in Write-* commands
        if (-not ($MyInvocation.MyCommand.Name)) {$callName = ''}
        else {$callName = "[$($MyInvocation.MyCommand.Name)] "}

        # Set default value for 'Length'
        if ($null -eq $PSBoundParameters['Length']) {
            $Length = 24
            Write-Debug "${callName}Using default 'Length' value: '$Length'"
        }

        # Set default value for 'Count'
        if ($null -eq $PSBoundParameters['Count']) {
            $Count = 1
            Write-Debug "${callName}Using default 'Count' value: '$Count'"
        }

        # Set default value for 'NonAlpha'
        if ($null -eq $PSBoundParameters['NonAlpha']) {
            $NonAlpha = 2
            Write-Debug "${callName}Using default 'NonAlpha' value: '$NonAlpha'"
        }
        else {
            # Check that 'NonAlpha' is 50% or less of 'Length'
            $ratio = $NonAlpha/$Length
            if ($ratio -gt '0.5') {
                $NonAlpha = [math]::Floor($length/2)
                Write-Debug "${callName}Capping 'NonAlpha' relative to length: '$NonAlpha'"
            }
        }

        Write-Debug "${callName}Defining character arrays"
        $AlphaNum = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'.ToCharArray()
        $Special = '{]+-[*=@:)}$^%;(_!&#?>/|.'.ToCharArray()
        $Ambiguous = '|l1I0O'.ToCharArray()

        if ($AllowAmbiguous -ne $true) {
            $AlphaNum = $AlphaNum | Where-Object {$Ambiguous -notcontains $_}
            $Special = $Special | Where-Object {$Ambiguous -notcontains $_}
        }
        else {
            Write-Debug "${callName}Allowing ambiguous characters"
        }

        Add-Type -AssemblyName 'System.Web'

        Write-Debug "${callName}Creating cryptography object: 'RNGCryptoServiceProvider'"
        $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider

        $show = if ($count -eq 1) {'password'} else {'passwords'}
        "{0}Creating {1} {2} of length {3}" -f $callName,$Count,$show,$Length | Write-Verbose
    }
    process {
        For ($c=0; $c -lt $Count;$c++) {
            # Create trackers for presense of upper-case & lower-case
            $hasUpper = $false
            $hasLower = $false
            
            #Establish jagged array
            $bytes = New-Object 'System.Array[]'($length)
            For ($i = 0; $i -lt $bytes.Count ; $i++) {
                $bytes[$i] = New-Object byte[](2) #To hold the two bytes to convert to uint16
            }
            
            $Return = New-Object char[]($Length)

            # Get special characters
            For ($i = 0 ; $i -lt $NonAlpha ; $i++) {
                Do {
                    $rng.GetBytes($bytes[$i])
                    $num = [System.BitConverter]::ToUInt16($bytes[$i],0)
                }
                While ($num -gt ([uint16]::MaxValue - ([uint16]::MaxValue % $Special.Length) -1))
            
                $Return[$i] = $Special[$num % $Special.Length]
            }
            
            # Get alpha-numeric characters
            For ($i = $NonAlpha ; $i -lt $Length ; $i++) {
                Do {
                    $rng.GetBytes($bytes[$i])
                    $num = [System.BitConverter]::ToUInt16($bytes[$i],0)
                }
                While ($num -gt ([uint16]::MaxValue - ([uint16]::MaxValue % $AlphaNum.Length) -1) )

                # Track whether charater is upper-case or lower-case
                $toAdd = $AlphaNum[$num % $AlphaNum.Length]
                if ($toAdd -cmatch '[A-Z]') {$hasUpper = $true}
                elseif ($toAdd -cmatch '[a-z]') {$hasLower = $true}

                # If Length is reached, verify password contains at least one upper-case
                if ($i -eq ($Length - 1) -AND $hasUpper -ne $true) {
                    Write-Debug "${callName}Dropping character due to missing upper-case: '$toAdd'"
                    $i--
                }
                # If Length is reached, verify password contains at least one lower-case
                elseif ($i -eq ($Length - 1) -AND $hasLower -ne $true) {
                    Write-Debug "${callName}Dropping character due to missing lower-case: '$toAdd'"
                    $i--
                }
                # Add character to collection
                else {
                    $Return[$i] = $toAdd
                }
            }

            $outString = $(($Return | Where-Object {$_} | Get-Random -Count $length) -join '')
            #Write-Debug "${callName}Finished password creation: '$outString'"

            Write-Output $outString
        }
        
    }
    end {
        if ($count -gt 1) {
            Write-Verbose "${callName}Finished creating $count passwords"
        }
    }
}
