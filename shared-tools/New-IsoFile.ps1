Function New-IsoFile {
    <#
        .Synopsis
        Creates a new ISO file

        .Description
        The New-IsoFile cmdlet creates a new ISO file containing content defined in 'Source' input parameter

        .Example
        New-IsoFile "C:\Tools","C:Downloads\utils"
        This command creates a ISO file in default location ($ENV:Temp folder) that contains 'C:\Tools' 
        and 'C:\Downloads\Utils' folders.  The folders themselves are included at the root of the ISO image.

        .Example
        New-IsoFile -FromClipboard -Verbose
        Before running this command, select and copy (Ctrl-C) files/folders in Explorer first.

        .Example
        $bootFile = "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\efisys.bin"
        Get-ChildItem C:\WinPE | New-IsoFile -Path C:\Temp\WinPE.iso -BootFile $bootFile -Media DVDPLUSR -Title "WinPE"

        This command creates a bootable ISO file containing the content within 'C:\WinPE' folder (using pipeline data from
        'Get-ChildItem') and using a BootFile from the Windows Assessment & Deployment Kit media.


        .Example
        $bootFile = "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\efisys.bin"
        New-IsoFile -Source "C:\WinPE\*" -Path C:\Temp\WinPE.iso -BootFile $bootFile -Media DVDPLUSR -Title "WinPE"

        This command creates the same media as the example above, using wildcard path resolution rather than 
        pipeline input for the 'Source' parameter.

        .Notes
        Enhanced version of script from TechNet Script Center - originally authored by Chris Wu
        URL: https://gallery.technet.microsoft.com/scriptcenter/New-ISOFile-function-a8deeffd
    #>
   
    [CmdletBinding(DefaultParameterSetName='Source')]
    Param(
      [parameter(Position=0,Mandatory=$true,ValueFromPipeline=$true,ParameterSetName='Source')]
      $Source,
      
      [parameter(Position=1)]
      [string] $OutFile,
      
      [ValidateScript({Test-Path -LiteralPath $_ -PathType Leaf})]
      [string]$BootFile = $null,
      
      [string]$Title,

      # Media Type Name (http://msdn.microsoft.com/en-us/library/windows/desktop/aa366217(v=vs.85).aspx)
      [Parameter(Position=4,HelpMessage='ISO Media Type')]
      [ValidateSet('CDR','CDRW','DVDRAM','DVDPLUSR','DVDPLUSRW','DVDPLUSR_DUALLAYER','DVDDASHR',
              'DVDDASHRW','DVDDASHR_DUALLAYER','DISK','DVDPLUSRW_DUALLAYER','BDR','BDRE')]
      [string] $Media,
      
      [switch]$Force,
      
      [parameter(ParameterSetName='Clipboard')]
      [switch]$FromClipboard
    )
   
      Begin {
          # Define invocation call's name for use in Write-* commands
          if (-not ($MyInvocation.MyCommand.Name)) {$callName = ''}
          else {$callName = "[$($MyInvocation.MyCommand.Name)] "}
  
          $herePattern = [REGEX]::Escape((Get-Location).Path)
  
          $DateStamp = (Get-Date).ToString('yyyyMMdd-HHmmss.ffff')
  
          if ($null -eq $PSBoundParameters['Media']) {
              $Media = 'DVDPLUSRW_DUALLAYER'
              Write-Verbose "${callName}Parameter 'Media' undefined - using default: '$Media'"
          }
  
          if ($null -eq $PSBoundParameters['OutFile']) {
              $outFile = Join-Path $env:temp "${dateStamp}.iso"
              Write-Verbose "${callName}Parameter 'OutFile' undefined - using default: '$outFile'"
          }
  
          if ($null -eq $PSBoundParameters['Title']) {
              $Title = "ISO_{0}_{1}" -f $Media.ToUpper(),$DateStamp
              Write-Verbose "${callName}Parameter 'Title' undefined - using default: '$Title'"
          }
  
  
          ($cp = new-object System.CodeDom.Compiler.CompilerParameters).CompilerOptions = '/unsafe'
          if (!('ISOFile' -as [type])) {
              Write-Verbose "${callName}Adding custom type definition: 'ISOFile'"
              Add-Type -CompilerParameters $cp -TypeDefinition @'
      public class ISOFile
      {
          public unsafe static void Create(string Path, object Stream, int BlockSize, int TotalBlocks)
          {
              int bytes = 0;
              byte[] buf = new byte[BlockSize];
              var ptr = (System.IntPtr)(&bytes);
              var o = System.IO.File.OpenWrite(Path);
              var i = Stream as System.Runtime.InteropServices.ComTypes.IStream;
  
              if (o != null) {
                  while (TotalBlocks-- > 0) {
                      i.Read(buf, BlockSize, ptr); o.Write(buf, 0, bytes);
                  }
                  o.Flush(); o.Close();
              }
          }
      }
'@
      }
   
          if ($BootFile) {
              $bootObject = Get-Item -LiteralPath $BootFile -ErrorAction SilentlyContinue
  
              if ($null -eq $bootObject) {
                  Write-Warning "${callName}BootFile path does not exist: '$bootFile'"
              }
              else {
                  if('BDR','BDRE' -contains $Media) {
                      Write-Warning "Bootable image doesn't seem to work with selected media type: '$Media'"
                  }
                  Write-Verbose "${callName}Using BootFile object: '$($bootObject.FullName)'"
                  ($Stream = New-Object -ComObject ADODB.Stream -Property @{Type=1}).Open()  # adFileTypeBinary
                  $Stream.LoadFromFile($bootObject.Fullname)
                  ($Boot = New-Object -ComObject IMAPI2FS.BootOptions).AssignBootImage($Stream)
              }
          }
  
          $MediaType = @('UNKNOWN','CDROM','CDR','CDRW','DVDROM','DVDRAM','DVDPLUSR','DVDPLUSRW',
          'DVDPLUSR_DUALLAYER','DVDDASHR','DVDDASHRW','DVDDASHR_DUALLAYER','DISK',
          'DVDPLUSRW_DUALLAYER','HDDVDROM','HDDVDR','HDDVDRAM','BDROM','BDR','BDRE')
  
          try {
              Write-Verbose "${callName}Creating COM Object: 'IMAPI2FS.MsftFileSystemImage'"
              $Image = New-Object -com IMAPI2FS.MsftFileSystemImage -Property @{VolumeName=$Title}
  
              Write-Verbose -Message "${callName}Setting media defaults for '$Media' with index value: '$($MediaType.IndexOf($Media))'"
              $Image.ChooseImageDefaultsForMediaType($MediaType.IndexOf($Media))
          }
          catch {
              Write-Verbose "${callName}Error creating MsftFileSystemImage COM object"
              throw $_.Exception.Message
          }
  
          if (!($Target = New-Item -Path $OutFile -ItemType File -Force:$Force -ErrorAction SilentlyContinue)) {
              Write-Error -Message "Cannot create file $OutFile. Use -Force parameter to overwrite if the target file already exists.";
              break 
          }
          else {
              Write-Verbose "${callName}Created empty target ISO file: '$($target.FullName)'"
          }
      }
   
      Process {
          if($FromClipboard) {
              if($PSVersionTable.PSVersion.Major -lt 5) {
                  Write-Error -Message 'The -FromClipboard parameter is only supported on PowerShell v5 or higher';
                  break
              }
              else {
                  Write-Verbose "${callName}Getting source data from clipboard"
              }
              $Source = Get-Clipboard -Format FileDropList
          }
          foreach($testPath in $Source) {
              if($testPath -isnot [System.IO.FileInfo] -and $testPath -isnot [System.IO.DirectoryInfo]) {
                  Write-Verbose "${callName}Attempting path resolution: '$testPath'"
                  $resolvedPaths = $testPath | Resolve-Path | Get-Item
              }
              else {
                  $resolvedPaths = $testPath
              }
  
              $resolvedPaths | Where-Object {$_} | ForEach-Object {
              #if($item) {
                  $item = $_
                  if ($item.FullName -match $herePattern) {
                      $showPath = $item | Resolve-Path -Relative
                  }
                  else {
                      $showPath = $item.FullName
                  }
                  $itemType = if ($item -is [System.IO.FileInfo]) {'file'}
                  elseif ($item -is [System.IO.DirectoryInfo]) {'directory'}
                  else {'unknown-type object'}
                  Write-Verbose -Message "${callName}Adding $itemType to image target: '${showPath}'"
                  try { 
                      $Image.Root.AddTree($item.FullName, $true)
                  }
                  catch { 
                      Write-Error -Message ($_.Exception.Message.Trim() + ' Try a different media type.')
                  }
              }
          }
      }
      End {
          if ($Boot) {
              Write-Verbose "${callName}Setting BootImageOption: '$boot'"
              $Image.BootImageOptions=$Boot
          }
          Write-Verbose "${callName}Creating ISO Image"
          $Result = $Image.CreateResultImage()
          [ISOFile]::Create($Target.FullName,$Result.ImageStream,$Result.BlockSize,$Result.TotalBlocks)
          Write-Verbose -Message "Target image creation complete: '$($Target.FullName)'"
          $Target
      }
  }
