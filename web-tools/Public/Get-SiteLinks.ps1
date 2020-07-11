function Get-SiteLinks {
    [CmdletBinding()]
    param (
        # URL To Query
        [Parameter(Position=0,Mandatory,ValueFromPipeline)]
        [String[]] $URL,

        # Return Links As String (Default: URI Object)
        [Parameter(Position=1)]
        [Switch] $AsString,

        # Maximum Redirection
        [Parameter(Position=2)]
        [Int] $MaxRedirect,

        # Same Domain Links
        [Parameter(Position=3)]
        [Switch] $SameDomain,

        # Include Schemes Other Than HTTP/HTTPS
        [Parameter(Position=4)]
        [Switch] $IncludeNonHttp,

        # Include Duplicate Link Logging
        [Parameter(Position=5)]
        [Switch] $ShowDuplicate,

        # Provide Additinonal Feedback
        [Parameter(Position=6)]
        [Switch] $Troubleshoot
    )
    
    begin {
        $ErrorActionPreference = 'Stop'

        if (-not ($MyInvocation.MyCommand.Name)) {$callName = ''}
        else {$callName = "[$($MyInvocation.MyCommand.Name)] "}

        if ($Troubleshoot) {
            $VerbosePreference = 'Continue'
            $DebugPreference = 'Continue'
        }

        $iwrParams = @{
            'ErrorAction' = 'Stop'
            'Verbose' = $False
            'SkipCertificateCheck' = $True
        }

        if ([Math]::Abs($PSBoundParameters['MaxRedirect']) -gt 0) {
            $iwrParams['MaximumRedirection'] = [Math]::Abs($PSBoundParameters['MaxRedirect'])
        }

        # Create collection hashtable for links
        $linkHash = New-Object -TypeName 'System.Collections.Hashtable'
    }
    
    process {   
        $URL | Where-Object {$_} | ForEach-Object {
            $inURL = $_
            # Convert input URL to URI object
            try {
                $uriObject = $inURL -as [URI]
            }
            catch {
                Write-Warning "${callName}Error casting URI object: '$URL'"
                throw $_.Exception.Message
            }

            # Verify URL is a vaiid Absolute URI
            if ($null -eq $uriObject.AbsoluteURI) {
                Write-Warning "${callName}Input is not a valid URI: '$URL'"
                throw "No AbsoluteURI for input: '$URL'"
            }
            else {
                Write-Debug "${callName}Testing URL: '$($uriObject.AbsoluteURI)'"
            }

            # Collect DNSSafeHost property
            try {
                $inSafeHost = $uriObject | Select-Object -ExpandProperty DNSSafeHost
                $inScheme = $uriObject | Select-Object -ExpandProperty Scheme

            }
            catch {
                Write-Warning "${callName}Error extracting DnsSafeHost or Scheme property from URI"
                throw $_.Exception.Message
            }

            # Get website content
            try {
                $webRequest = Invoke-WebRequest -Uri $uriObject @iwrParams
            }
            catch {
                Write-Warning "${callName}Failed 'Invoke-WebRequest': '$($uriObject.AbsoluteURI)'"
                Write-Warning "${callNAme}Exception message: '$($_.Exception.Message)'"
                $webRequest = $null
            }

            # Parse response object 'Links' property
            
            if ($null -ne $webRequest) {
                $i=0
                $webRequest.Links | Where-Object {$null -ne $_.HREF -AND $linkHash.Keys -notcontains $_.HREF} | ForEach-Object {
                    $thisLink = $_
                    $linkType = 'UNKNOWN'
                    $thisURI = $thisLink.HREF -as [URI]

                    # For absolute URI links, continue
                    if ($null -ne $thisURI.AbsoluteUri) {
                        #Write-Debug "${callName}Found absolute URI link: '$absPath'"
                        $linkType = '{0}-absolute' -f $thisURI.Scheme
                    }
                    # For relative URI links, compose a full URL and test again
                    else {
                        $linkType = 'composed'
                        if ($thisURI.AbsolutePath.Length -ge 1) {
                            $absPath = $thisURI.AbsolutePath
                        }
                        else {
                            $absPath = $thisURI.OriginalString
                        }
                        #Write-Debug "${callName}Found relative URI link: '$absPath'"
                        
                        # Compose URL path using input object's Scheme & DNSSafeHost
                        $relPath = $absPath -replace '^(\/)+'
                        $composedPath = "{0}://{1}/{2}" -f $inScheme,$inSafeHost,$relPath

                        # Get URI object for composed path
                        try {
                            $composedURI = $composedPath -AS [URI]
                            $thisURI = $composedURI
                            $linkType = '{0}-relative' -f $thisURI.Scheme
                        }
                        catch {
                            Write-Warning "${callName}Failed getting URI object for composed path: '$composedPath'"
                            $thisURI = $null
                        }
                    }

                    if ($thisURI.Scheme -notmatch '^HTTP(S)?$') {
                        $linkType = $thisURI.Scheme
                    }

                    # Validate that AbsoluteURI is not empty string
                    if ($thisURI.AbsoluteURI.Length -lt 5) {
                        Write-Debug "${callName}Skipping non-absolute URI: '$($thisLink.HREF)'"
                    }
                    # Validate that link is not already in collection
                    elseif ($linkHash.Keys -contains $thisURI.AbsoluteURI) {
                        if ($ShowDuplicate) {
                            Write-Debug "${callName}Skipping duplicate link: '$($thisURI.AbsoluteURI)'"
                        }
                    }
                    # Add unique link to collection
                    else {
                        # Test whether link has same DNSSafeHost as input URL
                        $isSameHost = $thisURI.DnsSafeHost -like $inSafeHost

                        # Add properties to link URI object
                        $thisURI | Add-Member -MemberType NoteProperty -Force -Name 'SourceURL' -Value $uriObject.AbsoluteURI
                        $thisURI | Add-Member -MemberType NoteProperty -Force -Name 'SameDomain' -Value $isSameHost
                        $thisURI | Add-Member -MemberType NoteProperty -Force -Name 'LinkType' -Value $linkType

                        # Add link URI to collection hashtable
                        $linkHash[$thisURI.AbsoluteURI] = $thisURI
                        $i++
                    }
                }
            }

            if ($i -lt 1) {
                Write-Debug "${callName}No unique links found: '$($URIObject.AbsoluteURI)'"
            }
            else {
                Write-Verbose "${callName}Collected $i link(s) from URI: '$($URIObject.AbsoluteURI)'"
            }
        }
    }
    
    end {
        $i=0
        $linkHash.Values | Sort-Object -Property SourceURL,LinkType,AbsoluteURI | ForEach-Object {
            $showURI = $_.OriginalString
            # Test whether link is in same domain as source URL
            if ($SameDomain -eq $True -and $_.SameDomain -ne $true) {
                Write-Verbose "${callName}Skipping cross-domain link: '$showURI'"
            }
            # Validate URI Scheme is a desired value
            elseif ($IncludeNonHttp -ne $True -AND $_.Scheme -notmatch '^HTTP(.*)') {
                Write-Debug "${callName}Skipping '$($_.Scheme)' link: '$showURI'"
            }
            else {
                $i++
                if ($AsString -eq $true) {
                    $_.AbsoluteURI
                }
                else {
                    $_
                }
            }
        }
        Write-Verbose "${callName}Total link count returned to pipeline: '$i'"
    }
}

<#

$test = "https://www.youtube.com/watch?v=aVwwjh3xwV8","https://news.ycombinator.com","https://news.ycombinator.com"
$global:AllLinks = $test | Get-SiteLinks -Troubleshoot

#>