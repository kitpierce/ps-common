function Resolve-IOPath {
    <#
    .SYNOPSIS
    Resolve path to FileInfo or DirectoryInfo objects.
    
    .DESCRIPTION
    For a given 'Path' parameter, or for a given 'ChildPath' 
    and 'ParentPath' combination, test whether the path exists.
    
    If the path exists, resolve the resultant 'Get-Item' output.
    If the path does not exist, create valid 'FileInfo' or 
    'DirectoryInfo' objects using type-casting.
    
    .PARAMETER Path
    String of the path to resolve.  This can be either a literal
    or non-literal path.
    
    .PARAMETER ChildPath
    One or more strings of child paths to resolve.
    
    .PARAMETER ParentPath
    String of parent path for 'Join-Path' to use (combined
    with the 'ChildPath' parameter input.)  If not defined,
    uses current working directory as returned by 'Get-Location'
    
    .PARAMETER Troubleshoot
    Parameter description
    
    .EXAMPLE
    Resolve-IOPath '..\SubDirectory\File.txt'

    Get the 'File.txt' object in the up-stream 'SubDirectory' directory.
    
    .EXAMPLE
    Resolve-FileInfo 'FileWithoutExtension'

    Get the 'FileWithoutExtension' object in the current directory.  If 
    this file does not exist, an object using the [System.IO] basetype 
    be created using type casting.  
    
    In this example, it will be forced to use type 'System.IO.FileInfo' 
    because the command was invoking using the 'Resolve-FileInfo' alias.

    .EXAMPLE
    Resolve-DirectoryInfo

    Get only the DirectoryInfo objects in the current directory.
    
    In this example, the 'Path' parameter will use the '*' default value.
    and any results that are not 'System.IO.DirectoryInfo' objects 
    (in other words, the FileInfo objects) will be filtered out because
    the command was invoking usingthe 'Resolve-DirectoryInfo' alias.

    .NOTES
    Author: Kit Pierce
    Date:   2021/11/05
    #>
    [Alias('Resolve-FileInfo', 'Resolve-DirectoryInfo', 'Resolve-FileSystemPath')]
    [CmdletBinding( DefaultParameterSetName = 'Literal' )]
    param (
        # Path To Resolve
        [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'Literal')]
        [Alias('FullName')]
        [String] $Path,

        # Parent path for 'Join-Path' operations
        [Parameter(Position = 0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'Joined')]
        [String[]] $ChildPath,

        # Parent path for 'Join-Path' operations
        [Parameter(Position = 1, ValueFromPipelineByPropertyName, ParameterSetName = 'Joined')]
        [String] $ParentPath,

        # Provide Additional Feedback
        [Parameter()] [Switch] $Troubleshoot
    )
    
    begin {
        $ErrorActionPreference = 'Stop'

        # Define invocation call's name for use in Write-* commands
        if (-not ($MyInvocation.MyCommand.Name)) { $callName = '' }
        else { $callName = "[$($MyInvocation.MyCommand.Name)] " }

        # Set verbose/debug levels as per 'Troubleshoot' parameter
        if ($Troubleshoot) {
            $DebugPreference = 'Continue'
            $VerbosePreference = 'Continue'
            if ($null -ne $Host.PrivateData) {
                try {
                    $Host.PrivateData.VerboseForegroundColor = 'Cyan'
                    $Host.PrivateData.DebugForegroundColor = 'Magenta'
                    $Host.PrivateData.WarningForegroundColor = 'Yellow'
                    $Host.PrivateData.ErrorForegroundColor = 'Red'
                }
                finally {}
            }
        }

        $PathsToTest = [System.Collections.Hashtable]::New()

        $allowedTypes = if ($MyInvocation.InvocationName -match 'FileInfo') { 'System.IO.FileInfo' }
        elseif ($MyInvocation.InvocationName -match 'DirectoryInfo') { 'System.IO.DirectoryInfo' }
        else { @('System.IO.DirectoryInfo', 'System.IO.FileInfo') }
    }
    
    process {
        $pSet = $PSCmdlet.ParameterSetName 

        Switch ($pSet) {
            'Literal' {
                if ($null -eq $PSBoundParameters['Path']) {
                    $Path = '*'
                    Write-Debug "${callName}No 'Path' defined, using default: '$Path'"
                }
                
                $Path | Where-Object { $_ } | ForEach-Object {
                    $thisPath = $_ 
                    $PathsToTest["$thisPath"] = [PSCustomObject]@{
                        'Mode'       = $pSet
                        'ChildPath'  = $thisPath 
                        'ParentPath' = $null
                    }
                }
            }
            'Joined' {

                $useParent = if ($PSBoundParameters['ParentPath'] -match '\S') { $PSBoundParameters['ParentPath'] }
                $PSBoundParameters['ChildPath'] | Where-Object { $_ } | ForEach-Object {
                    $thisPath = $_
                    $PathsToTest["$thisPath"] = [PSCustomObject]@{
                        'Mode'       = $pSet
                        'ChildPath'  = $thisPath 
                        'ParentPath' = $useParent
                    }
                }
            }
            default {
                Write-Warning "${callName}Unexpected parameter set name: '$pSet'"
            }
        }
    }
    
    end {
        $keyCount = $PathsToTest.Keys | Measure-Object | Select-Object -ExpandProperty Count 

        Write-Verbose "${callName}Processing input path count: '$keyCount'" 
        $PathsToTest.Values | Where-Object { $_ } | ForEach-Object {
            $thisSet = $_ 
            $fsCollection = [System.Collections.Specialized.OrderedDictionary]::New()
            $ignoredCollection = [System.Collections.Specialized.OrderedDictionary]::New()

            $showParams = "{0} `n " -f $($thisSet | Format-List | Out-String).TrimEnd()
            Write-Verbose "${callName}Processing tests for input: $showParams "

            $isAbsolute = $thisSet.ChildPath | Split-Path -IsAbsolute 
            $isValid = $thisSet.ChildPath | Test-Path -IsValid 
            $literalPathExists = Test-Path -LiteralPath $thisSet.ChildPath
            $anyPathExists = Test-Path -Path $thisSet.ChildPath

            if ($literalPathExists -eq $true) {
                Write-Debug "${callName}Literal path exists: '$($thisSet.ChildPath)'"

                $thisSet.ChildPath | Get-Item | Where-Object { $_ } | Sort-Object PSIsContainer, FullName | ForEach-Object {
                    $fn = $_.FullName 
                    $thisType = $_.GetType().FullName 

                    if ($allowedTypes -notcontains $thisType) {
                        $ignoredCollection[$_.FullName] = $_
                    }
                    else {
                        if ($_.PSIsContainer -eq $false) {
                            Write-Verbose "${callName}Found literal path for file: '$fn'"
                        }
                        else {
                            Write-Verbose "${callName}Found literal path for directory: '$fn'"
                        }
                        $fsCollection[$_.FullName] = $_
                    }
                }
            }
            elseif ($anyPathExists -eq $true) {
                Write-Debug "${callName}Non-literal path exists: '$($thisSet.ChildPath)'"
                $thisSet.ChildPath | Get-Item | Where-Object { $_ } | Sort-Object PSIsContainer, FullName | ForEach-Object {
                    $fn = $_.FullName 
                    $thisType = $_.GetType().FullName 

                    if ($allowedTypes -notcontains $thisType) {
                        $ignoredCollection[$_.FullName] = $_
                    }
                    else {
                        if ($_.PSIsContainer -eq $false) {
                            Write-Verbose "${callName}Found resolved path for file: '$fn'"
                        }
                        else {
                            Write-Verbose "${callName}Found resolved path for directory: '$fn'"
                        }
                        $fsCollection[$_.FullName] = $_
                    }
                }
            }
            else {
                # Check whether child path is an absolute path
                if ($isAbsolute -eq $true) {
                    Write-Debug "${callName}Absolute-path object does not exist: '$($thisSet.ChildPath)'"
                    $castString = $thisSet.ChildPath
                }
                # Check whether 'ParentPath' is a non-space string
                elseif ($thisSet.ParentPath -match '\S') {
                    Write-Debug "${callName}Joining path parts: '$($thisSet.ParentPath)' -> '$($thisSet.ChildPath)'"
                    $castString = Join-Path $thisSet.ParentPath $thisSet.ChildPath
                }
                # Default to current directory for path joins
                else {
                    Write-Debug "${callName}Using current directory for 'Join-Path' with child path: '$($thisSet.ChildPath)'"
                    $castString = Join-Path $(Get-Location).Path $thisSet.ChildPath 
                }

                # If user called function with 'FileInfo' alias, force file type-cast
                if ($MyInvocation.InvocationName -match 'FileInfo') {
                    Write-Debug "${callName}Force-casting as 'FileInfo' object: '$castString'"
                    
                    try {
                        $fsInfo = $castString -AS [System.IO.FileInfo]
                    }
                    catch {
                        Write-Warning "${callName}Failed 'FileInfo' cast for path: '$castString'"
                        Write-Warning "${callName}Exception message: '$($_.Exception.Message)'"
                        $fsInfo = $null
                    }
                }
                # If user called function with 'DirectoryInfo' alias, force directory type-cast
                elseif ($MyInvocation.InvocationName -match 'DirectoryInfo') {
                    Write-Debug "${callName}Force-casting as 'DirectoryInfo' object: '$castString'"
                    try {
                        $fsInfo = $castString -AS [System.IO.DirectoryInfo]
                    }
                    catch {
                        Write-Warning "${callName}Failed 'DirectoryInfo' cast for path: '$castString'"
                        Write-Warning "${callName}Exception message: '$($_.Exception.Message)'"
                        $fsInfo = $null
                    }
                }
                else {
                    # Try file type-cast initially
                    Write-Debug "${callName}Testing cast to 'FileInfo' object: '$castString'"
                    try {
                        $fsInfo = $castString -AS [System.IO.FileInfo]
                    }
                    catch {
                        Write-Warning "${callName}Failed 'FileInfo' cast for path: '$castString'"
                        Write-Warning "${callName}Exception message: '$($_.Exception.Message)'"
                        $fsInfo = $null
                    }
                    
                    # If file type-cast does not contain a valid extension property, 
                    # re-cast as a directory
                    if ($($fsInfo.Extension -replace "\.|\s").Length -lt 1) {
                        Write-Debug "${callName}Casting string to 'DirectoryInfo' object: '$castString'"
                        try {
                            $fsInfo = $thisSet.ChildPath -AS [System.IO.DirectoryInfo]
                        }
                        catch {
                            Write-Warning "${callName}Failed 'DirectoryInfo' cast for path: '$castString'"
                            Write-Warning "${callName}Exception message: '$($_.Exception.Message)'"
                            $fsInfo = $null
                        }
                    }
                }
                
                # If cast operation is not null, add to 'fsCollection' dicttionary
                if ($null -ne $fsInfo) {
                    $fsType = $fsInfo.GetType().Name 
                    Write-Verbose "${callName}Using '$fsType' cast result: '$($fsInfo.FullName)'"
                    $fsCollection[$fsInfo.FullName] = $fsInfo
                }
            }

            # Get statistic counts for test operations
            $tCount = $fsCollection.Values | Measure-Object | Select-Object -ExpandProperty Count
            $mCount = $fsCollection.Values | Where-Object { $_.Exists -ne $true } | Measure-Object | Select-Object -ExpandProperty Count
            $fCount = $fsCollection.Values | Where-Object { $_.PSIsContainer -eq $false } | Measure-Object | Select-Object -ExpandProperty Count
            $dCount = $fsCollection.Values | Where-Object { $_.PSIsContainer -eq $true } | Measure-Object | Select-Object -ExpandProperty count

            # Return PSCustomObject summary to pipeline
            [PSCustomObject]@{
                'Invocation'     = $MyInvocation.InvocationName
                'Mode'           = $thisSet.Mode
                'ChildPath'      = $thisSet.ChildPath 
                'ParentPath'     = $thisSet.ParentPath 
                'IsValid'        = $isValid
                'IsAbsolute'     = $isAbsolute 
                'LiteralExists'  = $literalPathExists 
                'PathExists'     = $anyPathExists
                'TotalCount'     = $tCount 
                'MissingCount'   = $mCount
                'FileCount'      = $fCount 
                'DirectoryCount' = $dCount 
                'IgnoreCount'    = $ignoredCollection.Keys.Count
                'FileSystemInfo' = $fsCollection 
                'IgnoreInfo'     = $ignoredCollection
            }
        }
    }
}
