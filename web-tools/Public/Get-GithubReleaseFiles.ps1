function Get-GithubReleaseFiles {
    [CmdletBinding()]
    param (
        # Properties To Display
        [Parameter(Position=0)]
        [Alias('OutputPath','PSPath')]
        $Path = $(Join-Path $env:USERPROFILE "Downloads"),

        # Properties To Display
        [Parameter(Position=1,ValueFromPipeline)]
        [Alias('GithubURL')]
        $URL, 

        # Include Prerelease Versions
        [Switch]$Prerelease,

        # Download all files for the release
        [Switch]$AllFiles,

        # Replace existing files (if any)
        [Switch]$Replace
    )
    
    begin {
        $color_hi = 'Yellow'

        # Set options for 'Invoke-WebRequest'
        $WebRequestOptions = @{
            'Verbose' = $False;
            'Debug' = $False;
            'ErrorAction' = 'Stop';
        }

        # Set TLS v1.2
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }
    
    process {
        ForEach ($GithubURL in $URL) {
            if (-not $($GithubURL -as [URI])) {
                Write-Host "Input is not in valid URI format: " -NoNewline
                Write-Host "'$GithubURL'" -ForegroundColor Red
            }
            elseif ($GithubURL -notmatch 'github\.com') {
                Write-Host "Input is not a valid Github URL: " -NoNewline
                Write-Host "'$GithubURL'" -ForegroundColor Red
            }
            else {
                [ARRAY]$repoParts = $GithubURL -replace '^http(.*)github.com\/' -split '\/'

                if ($repoParts.Count -lt 2) {
                    Write-Warning "Invalid repo format for URL: '$GithubURL'"
                    Return
                }
                $repoName = $repoParts[1]
                $repo = $($repoParts | Select-Object -First 2) -join '/'
                
                $releaseURL = "https://api.github.com/repos/$repo/releases"

                Write-Host "Determining Latest Release Of Repo: " -NoNewline
                Write-Host "'$releaseURL'" -ForegroundColor $color_hi

                try {
                    [ARRAY]$releaseResponse = Invoke-WebRequest -Uri $releaseURL -UseBasicParsing @WebRequestOptions | ConvertFrom-Json
                }
                catch {
                    Write-Warning "Failed 'Invoke-WebRequest' for URL: '$ReleaseURL'"
                    throw  $_.Exception.Message
                }



                if ($releaseResponse.Count -lt 1) {
                    Write-Warning "API query succeeded, but no releases returned."
                    Break
                }

                if ($Prerelease -ne $true) {
                    Write-Verbose "Filtering out prerelease versions - use 'Prerelease' switch to preserve"
                    [ARRAY]$releases = $releaseResponse | Where-Object {$_.Prerelease -ne $true}
                }
                else {
                    [ARRAY]$releases = $releaseResponse | ForEach-Object {$_}
                }

                if ($releases.Count -lt 1) {
                    Write-Warning "No valid releases found - nothing to do."
                    Break
                }

                try {
                    $latest = $releases | Select-Object -First 1
                    $tag = $latest | Select-Object -ExpandProperty tag_name -ErrorAction Stop
                    [ARRAY]$assets = $latest | Select-Object -ExpandProperty assets -ErrorAction Stop
                    Write-Verbose "Found $($releases.Count) releases - selecting number: '$tag'"
                }
                catch {
                    Write-Warning "Error determining latest release by expanding 'Tag_Name' & 'Assets' properties"
                    throw $_.Exception.Message
                }

                if ($AllFiles) {
                    $selectedFiles = $assets | ForEach-Object {$_}
                }
                else {
                    [ARRAY]$selection = $assets | Select-Object -Property Name,Size,Download_Count,Updated_At | 
                        Out-Gridview -Title "Select File(s) To Download" -OutputMode Multiple

                    [ARRAY]$selectedFiles = $assets | Where-Object {$selection.Name -contains $_.Name}
                }

                ForEach ($handle in $selectedFiles) {
                    try {
                        $URL = $handle | Select-Object -ExpandProperty browser_download_url -ErrorAction Stop
                        $file = $handle | Select-Object -ExpandProperty name -ErrorAction Stop
                    }
                    catch {
                        Write-Warning "Error getting file name or URL"
                        throw $_.Exception.Message
                    }

                    $dirName = "$($RepoName)_$($tag)"
                    $outDirectory = Join-Path $Path $dirName

                    if (-not  (Test-Path -Path $outDirectory)) {
                        try {
                            New-Item -Path $outDirectory -ItemType Directory -ErrorAction Stop | Out-Null
                            Write-Verbose "Created output directory: '$outDirectory'"
                        }
                        catch {
                            Write-Warning "Error creating output directory: '$outDirectory'"
                            throw  $_.Exception.Message
                        }
                    }

                    $outFile = Join-Path $outDirectory $file

                    if ($(Test-Path -Path $outFile -PathType Leaf) -AND $($Replace -ne $true)) {
                        Write-Host "File Already Exists: " -NoNewline
                        Write-Host "'$outFile'" -ForegroundColor $color_hi
                    }
                    else {
                        Write-Host "Dowloading Release File " -NoNewline
                        Write-Host "'$file'" -NoNewline -ForegroundColor $color_hi
                        Write-Host " from URL: " -NoNewline
                        Write-Host "'$URL'" -ForegroundColor $color_hi
    
                        try {
                            Invoke-WebRequest -URI $URL -OutFile $outFile @WebRequestOptions
                        }
                        catch {
                            Write-Warning "Error downloading from '$URL'"
                            throw $_.Exception.Message
                        }
                    }
                }
            }
        }
    }
}



#$TestURL = 'https://github.com/gitahead/gitahead'

#$TestURL | Get-GitHubReleaseFiles -Verbose -AllFiles
