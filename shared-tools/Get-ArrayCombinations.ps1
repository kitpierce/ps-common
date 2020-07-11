function Get-ArrayCombinations {
    <#
    .SYNOPSIS
    Get all unique combinations of array members.
    
    .DESCRIPTION
    For a given input array, collect all unique combinations of specific group count or group range.
    
    .PARAMETER InputArray
    Array of obects to group.
    
    .PARAMETER GroupCount
    Integer of exact number of group members.  Cannot be combined with 'MinimumGroup'
    or 'MaximumGroup' parameters.
    
    .PARAMETER MinimumGroup
    Integer of minimum number of group members.  Cannot be used with 'GroupCount' parameter.
    
    .PARAMETER MaximumGroup
    Integer of maximum number of group members.  Cannot be used with 'GroupCount' parameter.
    
    .PARAMETER IncludeEmpty
    Include resultant groups with zero members.
    
    .EXAMPLE
    Get-ArrayCombinations -InputArray @('first','second','third')

    Gets all possible combinations of the 3-member input array.

    .EXAMPLE
    Get-ArrayCombinations -InputArray @('first','second','third','fourth') -GroupCount 2

    Gets all combinations of the 3-member input array where the combination is comprised of exactly 2 members.

    .EXAMPLE
    Get-ArrayCombinations -InputArray @('first','second','third','fourth') -MinimumGroup 2 -MaximumGroup 4

    Gets all combinations of the 3-member input array where the combination is comprised of between 2 and 4 members.
    
    .NOTES
    Modified version of dfinke's powerSet' GitHub script - see link section of this help.

    .LINK
    https://github.com/dfinke/powershell-algorithms/blob/master/src/algorithms/sets/power-set/powerSet.ps1
    #>
    
    [CmdletBinding(DefaultParameterSetName='Exact')]
    [OutputType([Hashtable])]
    Param(
        # Input Objects To Combine Into Sets
        [Parameter(Position=0,Mandatory,ParameterSetName='Exact')]
        [Parameter(Position=0,Mandatory,ParameterSetName='Range')]
        [Array] $InputArray,

        # Group Member Count (exact)
        [Parameter(Position=1,ParameterSetName='Exact')]
        [Alias('Count')]
        [Int] $GroupCount,

        # Group Member Minimum Count
        [Parameter(Position=1,ParameterSetName='Range')]
        [Alias('Minimum')]
        [Int] $MinimumGroup,

        # Group Member Maximum Count
        [Parameter(Position=2,ParameterSetName='Range')]
        [Alias('Maximum')]
        [Int] $MaximumGroup,

        # Group Member Maximum Count
        [Parameter(Position=2,ParameterSetName='Exact')]
        [Parameter(Position=3,ParameterSetName='Range')]
        [Switch] $IncludeEmpty
    )
    begin {
        # Source: https://github.com/dfinke/powershell-algorithms/blob/master/src/algorithms/sets/power-set/powerSet.ps1
        $subSetCollection = @{}
        $innerCollection = @{}

        $minCount = 0
        $maxCount = [INT]::MaxValue

        # Set group count boundaries
        if ($PSCmdlet.ParameterSetName -like 'Exact') {
            if ($GroupCount) {
                $minCount = $GroupCount
                $maxCount = $GroupCount
            }
        }
        elseif ($MinimumGroup -AND $MaximumGroup -AND $MinimumGroup -gt $MaximumGroup) {
            Write-Warning "MinimumGroup value '$MinimumGroup' greater than MaximumGroup value '$MaximumGroup'"
            Write-Verbose "Ignoring invalid miniumum/maximum group settings"
        }
        else {
            if ($MinimumGroup) {
                $minCount = $MinimumGroup
            }
            if ($MaximumGroup) {
                $maxCount = $MaximumGroup
            }
        }
        $rangeLabel = "min=${minCount} & max=${maxCount}"
        Write-Verbose "Using group count values: $rangeLabel"
    }
    process {
        # We will have 2^n possible combinations (where n is a length of original set).
        # It is because for every element of original set we will decide whether to include
        # it or not (2 options for each set element).

        #$numberOfCombinations = [Math]::Pow(2, $InputArray.Count)
        $numberOfCombinations = 1 -shl $InputArray.Count

        # Each number in binary representation in a range from 0 to 2^n does exactly what we need:
        # it shoes by its bits (0 or 1) whether to include related element from the set or not.
        # For example, for the set {1, 2, 3} the binary number of 010 would mean that we need to
        # include only "2" to the current set.
        for ($combinationIndex = 0; $combinationIndex -lt $numberOfCombinations; $combinationIndex += 1) {
            $subSet = @()

            for ($setElementIndex = 0; $setElementIndex -lt $InputArray.Count; $setElementIndex += 1) {
                if ( ($combinationIndex -band (1 -shl $setElementIndex)) -gt 0) {
                    $subSet += $InputArray[$setElementIndex]
                }
            }

            $subSetCount = $subset.Count
            if ($subSetCount -lt $minCount -OR $subSetCount -gt $maxCount) {
                Write-Verbose "Group count '${subsetCount}' outside desired range ($rangeLabel)"
            }
            elseif ($subSetCount -eq 0 -AND $IncludeEmpty -ne $true) {
                Write-Verbose "Ignoring empty result set - use 'IncludeEmpty' to include"
            }
            else {
                # Add current subset to the list of all subsets.
                $innerCollection[$subset] = $null
            }
        }
    }
    end {
        $CollMeasure = $innerCollection.GetEnumerator() | Measure-Object
        Write-Verbose "Found $($CollMeasure.Count) unique sets using range $rangeLabel"
        return $innerCollection
    }
}

#$SetCollection = Get-PowerSet -Verbose -InputArray $TestArray # -MinimumGroup 1
