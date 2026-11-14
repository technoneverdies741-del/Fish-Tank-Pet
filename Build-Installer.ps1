param(
  [string]$OutputPath = (Join-Path $PSScriptRoot 'dist\FishTankSetup.exe')
)

$ErrorActionPreference = 'Stop'
$payloadFiles = @('Install.cmd','Install-FishTank.ps1','Uninstall-FishTank.ps1','FishTank.ps1','README.md')
$tempParent = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$buildRoot = Join-Path $tempParent ('FishTankBuild-' + [guid]::NewGuid().ToString('N'))
$payloadDir = Join-Path $buildRoot 'payload'
$sedPath = Join-Path $buildRoot 'FishTankSetup.sed'
$tempInstaller = Join-Path $buildRoot 'FishTankSetup.exe'
$outputFullPath = [System.IO.Path]::GetFullPath($OutputPath)

try {
  New-Item -ItemType Directory -Path $payloadDir -Force | Out-Null
  foreach($file in $payloadFiles){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $payloadDir $file)}
  if($buildRoot.Contains(' ')){throw 'IExpress needs a temporary build path without spaces. Set TEMP to a path without spaces and run this script again.'}

  $iexpressPath = Join-Path $env:WINDIR 'SysWOW64\iexpress.exe'
  if(-not (Test-Path -LiteralPath $iexpressPath)){$iexpressPath=Join-Path $env:WINDIR 'System32\iexpress.exe'}
  if(-not (Test-Path -LiteralPath $iexpressPath)){throw 'IExpress was not found. Run this build on Windows 10 or Windows 11.'}

  $sed = @"
[Version]
Class=IEXPRESS
SEDVersion=3
[Options]
PackagePurpose=InstallApp
ShowInstallProgramWindow=0
HideExtractAnimation=1
UseLongFileName=1
InsideCompressed=1
CAB_FixedSize=0
CAB_ResvCodeSigning=0
RebootMode=N
InstallPrompt=%InstallPrompt%
DisplayLicense=%DisplayLicense%
FinishMessage=%FinishMessage%
TargetName=%TargetName%
FriendlyName=%FriendlyName%
AppLaunched=%AppLaunched%
PostInstallCmd=%PostInstallCmd%
AdminQuietInstCmd=%AdminQuietInstCmd%
UserQuietInstCmd=%UserQuietInstCmd%
SourceFiles=SourceFiles
[Strings]
InstallPrompt=
DisplayLicense=
FinishMessage=Fish Tank is installed.
TargetName=$tempInstaller
FriendlyName=Fish Tank Setup
AppLaunched=cmd.exe /c Install.cmd
PostInstallCmd=<None>
AdminQuietInstCmd=
UserQuietInstCmd=
SourceDir=$payloadDir\
FILE0=Install.cmd
FILE1=Install-FishTank.ps1
FILE2=Uninstall-FishTank.ps1
FILE3=FishTank.ps1
FILE4=README.md
[SourceFiles]
SourceFiles0=%SourceDir%
[SourceFiles0]
%FILE0%=
%FILE1%=
%FILE2%=
%FILE3%=
%FILE4%=
"@
  Set-Content -LiteralPath $sedPath -Value $sed -Encoding Ascii
  $build = Start-Process -FilePath $iexpressPath -ArgumentList @('/N','/Q',$sedPath) -Wait -PassThru
  if($build.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $tempInstaller)){throw "IExpress failed to build the installer (exit $($build.ExitCode))."}

  $outputDir = Split-Path -Parent $outputFullPath
  New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
  Copy-Item -LiteralPath $tempInstaller -Destination $outputFullPath -Force
  Write-Output "Created $outputFullPath"
} finally {
  $resolvedBuild = [System.IO.Path]::GetFullPath($buildRoot)
  if($resolvedBuild.StartsWith($tempParent,[System.StringComparison]::OrdinalIgnoreCase) -and (Split-Path -Leaf $resolvedBuild).StartsWith('FishTankBuild-')){
    Remove-Item -LiteralPath $resolvedBuild -Recurse -Force -ErrorAction SilentlyContinue
  }
}

