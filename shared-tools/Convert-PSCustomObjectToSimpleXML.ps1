Function Convert-PSCustomObjectToSimpleXML {
    <#
    .SYNOPSIS
    Outputs a human readable simple text XML representation of a simple PS object

    .PARAMETER Object
    The input object to inspect and dump

    .PARAMETER Depth
    The maximum number of levels to traverse

    .PARAMETER RootElement
    The name of the root element in the document. If not specified and input 
    object contains single entry, will attempt to use that entry's name.
    Otherwise, will default to "root"

    .PARAMETER indentString
    The string used to indent each level of XML.  Set to "" to remove indentation.

    .DESCRIPTION
    Outputs a human readable simple text XML representation of a simple PS object.

    A PSObject with member types of NoteProperty will be dumped to XML.  Only
    nested PSObjects up to the depth specified will be searched. All other
    note properties will be ouput using their strings values.

    The output consists of node with property names and text nodes containing the
    proprty value.

    .NOTES
    Heavily modified and extended version of a function from: http://wannemacher.us/?p=430
    #>
    [cmdletbinding(DefaultParameterSetName='Default')]
    Param (
        [parameter(Position=0,ValueFromPipeline,ParameterSetName='InputObject')][PSCustomObject]$Object,
        [parameter(Position=1)][Int32]$Depth = 10,
        [parameter(Position=2)][String]$RootElement,
        [parameter(Position=3)][String]$IndentString = "`t",
        [parameter(Position=4)][Int32]$Indent = 0,
        [parameter(Position=5)][String]$Parent,
        [parameter(Position=6)][Switch]$IsRoot = $true
    )

    #region INTERNAL FUNCTION
    Function Get-ObjectDefaultProperties {
        [cmdletbinding()]
        Param($innerObject)
        Try {
            [ARRAY]$DefaultTypeProps = @(
                $innerObject.gettype().GetProperties() | Select-Object -ExpandProperty Name -ErrorAction Stop | Sort-Object -Unique
            )
            If ($DefaultTypeProps.count -gt 0) {
                Write-Debug "Excluding default properties for $($innerObject.gettype().Fullname):`n$($DefaultTypeProps | Out-String)"
            }
        }
        Catch {
            Write-Debug "Failed to extract properties from $($innerObject.gettype().Fullname): $_"
            [ARRAY]$DefaultTypeProps = @()
        }
        Return $DefaultTypeProps
    }
    #endregion

    If ($PSBoundParameters['Debug']) {$DebugPreference = "Continue"} Else {$DebugPreference = "SilentlyContinue"}
    If ($PSBoundParameters['Verbose']) {$VerbosePreference = "Continue"} Else {$VerbosePreference = "SilentlyContinue"}

    If ($PSBoundParameters['RootElement']) {$RootElement = "root"}
    ElseIf ($object.PSObject.Properties.Count -eq 1) {
        Try {
            $RootElement = $object.PSObject.Properties | Select-Object -First 1 -ExpandProperty Name
        }
        Catch {$RootElement = "root"}
    }
    Else {$RootElement = "root"}

    # write opening tag for root element
    If ($IsRoot) { "<{0}>" -f $RootElement }

    # If 'Parent' parameter passed, write opening tag for parent element
    If ($PSBoundParameters['Parent']) {
        Write-Debug "Found bound parent name value: '$Parent'"
        "{0}<{1}>" -f ($indentString * $indent), $Parent
    }

    # Get default properties for input object
    $objType = $object.GetType().Name
    [ARRAY]$defaultObjProperties = Get-ObjectDefaultProperties $object -Debug:$false

    # Enumerate object's non-default properties via '`$object.PSObject.Properties'"
    [ARRAY]$NoteProperties = $object.PSObject.Properties |
            Where {$_.MemberType -match "Property"}  |
            Where {$defaultObjProperties -notcontains $_.Name}

    Write-Debug "Processing $($NoteProperties.Count) object properties: '$($NoteProperties -Join "','")'"
    ForEach ($prop in $NoteProperties) {
        $child = $object.($prop.Name)
        [ARRAY]$defChildProps = Get-ObjectDefaultProperties $child -Debug:$false

        # Check in child is a PSCustomObject
        If ($child.GetType().Name -eq "PSCustomObject" -and $depth -gt 1) {
            "{0}<{1}>" -f ($indentString * $indent), $prop.Name
            Convert-PSCustomObjectToSimpleXML $child -isRoot:$false -indent ($indent + 1) `
                    -depth ($depth - 1) -indentString $indentString
            "{0}</{1}>" -f ($indentString * $indent), $prop.Name
        }
        ElseIf ($child.GetType().BaseType.ToString() -like "System.Array") {
            # Test for an array containing only PSCustomObjects
            $onlyPSObjects = $true
            $child | % {
                If ($_.GetType().Name -notlike "PSCustomObject") {
                    Write-Debug "Found array sub-child with type: '$($_.GetType().Name)'"
                    $onlyPSObjects = $false
                }
            }

            If (($onlyPSObjects -eq $true) -AND ($Indent -gt 0)) {
                Write-Debug "Found child array containing ONLY PSCustomObjects - setting parent name: '$($prop.Name))'"
                ForEach ($subChild in $child) {
                    Convert-PSCustomObjectToSimpleXML $subChild -IsRoot:$false -Indent ($indent + 1) `
                            -Depth ($depth - 1) -IndentString $indentString  -Parent $Prop.Name
                }
            }
            Else {
                ForEach ($subChild in $child) {
                    Convert-PSCustomObjectToSimpleXML $subChild -IsRoot:$false -Indent ($indent + 1) `
                            -Depth ($depth - 1) -IndentString $indentString
                }
            }
        }
        Else {
            # If parent exists, add extra indent
            If ($PSBoundParameters['Parent']) { $tempIndent = $indent + 1 }
            Else { $tempIndent = $Indent }

            # Print each element
            ForEach ($element in $child) {
                "{0}<{1}>{2}</{1}>" -f ($indentString * $tempIndent), $prop.Name, $element
            }
        }
    }

    # If 'Parent' parameter passed, write closing tag for parent element
    If ($PSBoundParameters['Parent']) {
        Write-Debug "Found bound parent name value: '$Parent'"
        "{0}</{1}>" -f ($indentString * $indent), $Parent
    }

    # Write the closing tag for the root element
    If ($IsRoot) {
        "</{0}>" -f $RootElement
    }
}
