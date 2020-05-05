function Get-DeletedObjects {
    [Alias('Get-AdDeletedObjects')]
    [CmdletBinding()]
    param (
        # Object Type
        [Parameter(Position=0,Mandatory)]
        [ValidateSet('Computer','BitLockerKey','User')]
        [String] $Type,

        # Admin Credentials
        [Parameter(Position=1)]
        [PSCredential] $Credential,

        # Objects Modified Within Last X Days
        [Parameter(Position=2)]
        [Int] $Days,

        # Get All Properties For Objects
        [Parameter(Position=3)]
        [Switch] $AllProperties
    )
    
    begin {
        $ErrorActionPreference = 'Stop'

        if (-not ($MyInvocation.MyCommand.Name)) {$callName = ''}
        else {$callName = "[$($MyInvocation.MyCommand.Name)] "}

        $filterTable = @{
            'BitLockerKey' = '(IsDeleted -eq $True) -AND (LastKnownParent -ne "$null") -AND (objectClass -eq "msFVE-RecoveryInformation")'
            'Computer' = '(IsDeleted -eq $True) -AND (LastKnownParent -ne "$null") -AND (ObjectClass -eq "Computer")'
            'User' = '(IsDeleted -eq $True) -AND (LastKnownParent -ne "$null") -AND (ObjectClass -eq "User")'
        }

        $PropertyTable = @{
            #'BitLockerKey' = @('LastKnownParent','msFVE-RecoveryPassword')
            'Computer' = @('Description','createTimeStamp','modifyTimeStamp','LastKnownParent')
        }

        $SearchParams = @{
            'Verbose' = $true
            'IncludeDeletedObject' = $true
        }

        if ($null -ne $PSBoundParameters['Credential']) {
            Write-Verbose "${callName}Using credential for user: '$($PSBoundParameters['Credential'].UserName)'"
            $SearchParams['Credential'] = $PSBoundParameters['Credential']
        }

        $absDays = [Math]::Abs($PSBoundParameters['Days'])
        $baseline = (Get-Date).AddDays(-$absDays).Date

        if ($absDays -ne 0) {
            Write-Verbose "${callName}Filtering for objects modified since: '$baseLine'"
        }
    }
    
    process {
        $PSBoundParameters['Type'] | Where-Object {$_} | ForEach-Object {
            $thisType = $_
            
            Write-Verbose "${callName}Getting all deleted $thisType objects (this may take a while...)"

            $filterString = $filterTable[$thisType]
            $filter = [ScriptBlock]::Create("$filterString")
            "{0}Using {1} filter: '{2}'" -f $callName,$thisType,$filterString | Write-Debug
    
            $propertyArray = $PropertyTable[$thisType]
            if ($null -eq $propertyArray -or $AllProperties -eq $true) { $PropertyArray = '*' }
            "{0}Using {1} properties: '{2}'" -f $callName,$thisType,$($propertyArray -join "','") | Write-Debug

            $SearchParams['Filter'] = $filter
            $SearchParams['Properties'] = $propertyArray

            try {
                Get-ADObject @SearchParams | Where-Object {$absDays -eq 0 -OR $_.modifyTimeStamp -ge $baseline}
            }
            catch {
                Write-Warning "${callName}Error querying AD for deleted '$thisType' objects"
                throw $_.Exception.Message
            }
        }
    }
}
