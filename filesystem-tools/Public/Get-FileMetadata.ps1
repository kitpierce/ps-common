function Get-FileMetaData { 
    <# 
    .SYNOPSIS 
        Get-FileMetaData returns metadata information about one or more files. 
 
    .DESCRIPTION 
        This function will return all metadata information about a file or files within a directory.
    
    .EXAMPLE 
        Get-FileMetaData -File "c:\temp\image.jpg" 
 
        Get information about an image file. 
 
    .EXAMPLE 
        Get-ChildItem -Path .\* | Get-FileMetaData
        
        Get information about all files in the local path
        
    .EXAMPLE 
        Get-ChildItem -Path .\* | Get-FileMetaData -Recurse
        
        Get information about all files in the local path and all its subfolders
  
    #> 
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$True,ValueFromPipeline)]
        $File,

        [Parameter(Position=1)]
        [alias('Type')]
        [string[]]$Extension,

        [Parameter(Position=2)]
        [switch]$Recurse,

        [Parameter(Position=3)]
        [int]$Depth
    )
    begin {
        if ($Extension) {
            $extPattern = $($Extension | ForEach-Object {[Regex]::Escape($_) -replace '\\\*','(.*)'}) -join '|'
        }
        else {
            $extPattern = '(.*)'
        }
    }
    process {
        ForEach ($tempFile in $File) {
            if ($tempFile.GetType().FullName -like 'System.String') {        
                try {
                    $tempString = $tempFile
                    $tempFile = Get-Item -Path $tempString -ErrorAction Stop
                    Write-Verbose "Resolved type '$($tempFile.GetType().FullName)' for string: '$tempString'"
                }
                catch {
                    Write-Warning "Failed 'Get-Item' for path: '$tempFile'"
                    Return
                }
            }

            if ($tempFile.GetType().FullName -like 'System.IO.FileInfo') {
                $pathname = $tempFile.DirectoryName 
                $filename = $tempFile.Name
 
                Write-Verbose "Collecting metadata for file: '$(Join-Path $pathName $filename)'"               

                $shellObj = New-Object -ComObject Shell.Application 
                $folderObj = $shellobj.namespace($pathname) 
                $fileObj = $folderobj.parsename($filename) 
    
                $propHash = [ORDERED]@{}
    
                for($a=0; $a -le 400; $a++) {
                    if($folderobj.getDetailsOf($folderobj, $a) -and $folderobj.getDetailsOf($fileobj, $a))  
                    { 
                        $propHash.Add($($folderobj.getDetailsOf($folderobj, $a)),$($folderobj.getDetailsOf($fileobj, $a)))
                    } 
                } 

                New-Object -TypeName PSObject -Property $propHash
        
            }
            elseif ( $tempFile.GetType().FullName -like 'System.IO.DirectoryInfo' ) {
                Write-Verbose "Getting directory members' metadata: '$($tempFile.FullName)'"
                $tempFile.EnumerateFiles() | Get-FileMetaData -Verbose
                If ($Recurse) {
                    $tempFile.EnumerateDirectories() | ForEach-Object {
                        $_ | Get-FileMetaData -Verbose -Recurse
                    }
                }
            }
            else {
                Write-Verbose "Skipping unsupprted input type: '$($tempFile.GetType().FullName)'"
            }
        }
    }
} 
