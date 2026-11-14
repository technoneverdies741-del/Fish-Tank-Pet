Add-Type -AssemblyName System.Windows.Forms

$installDir = Join-Path $env:LOCALAPPDATA 'FishTankPet'
$startMenuDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Fish Tank'
$desktopLink = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Fish Tank.lnk'
$startupLink = Join-Path ([Environment]::GetFolderPath('Startup')) 'Fish Tank.lnk'

$answer = [System.Windows.Forms.MessageBox]::Show(
  'Remove Fish Tank and its shortcuts from this Windows account?',
  'Uninstall Fish Tank',
  [System.Windows.Forms.MessageBoxButtons]::YesNo,
  [System.Windows.Forms.MessageBoxIcon]::Question,
  [System.Windows.Forms.MessageBoxDefaultButton]::Button2
)
if($answer -ne [System.Windows.Forms.DialogResult]::Yes){exit 0}

Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'powershell.exe' -and $_.CommandLine -like "*$installDir*FishTank.ps1*" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Remove-Item -LiteralPath $desktopLink,$startupLink -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $startMenuDir,$installDir -Recurse -Force -ErrorAction SilentlyContinue
[void][System.Windows.Forms.MessageBox]::Show('Fish Tank has been removed.','Uninstall Fish Tank',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information)

