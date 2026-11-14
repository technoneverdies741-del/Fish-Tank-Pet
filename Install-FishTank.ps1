Add-Type -AssemblyName System.Windows.Forms

$source = $PSScriptRoot
$installDir = Join-Path $env:LOCALAPPDATA 'FishTankPet'
$desktopLink = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Fish Tank.lnk'
$startMenuDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Fish Tank'
$startupDir = [Environment]::GetFolderPath('Startup')
$powershell = Join-Path $PSHOME 'powershell.exe'

try {
  New-Item -ItemType Directory -Path $installDir -Force | Out-Null
  New-Item -ItemType Directory -Path $startMenuDir -Force | Out-Null
  Copy-Item -LiteralPath (Join-Path $source 'FishTank.ps1') -Destination (Join-Path $installDir 'FishTank.ps1') -Force
  Copy-Item -LiteralPath (Join-Path $source 'Uninstall-FishTank.ps1') -Destination (Join-Path $installDir 'Uninstall-FishTank.ps1') -Force
  Copy-Item -LiteralPath (Join-Path $source 'README.md') -Destination (Join-Path $installDir 'README.md') -Force

  $shell = New-Object -ComObject WScript.Shell
  foreach($shortcutPath in @($desktopLink,(Join-Path $startMenuDir 'Fish Tank.lnk'))){
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $powershell
    $shortcut.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$(Join-Path $installDir 'FishTank.ps1')`""
    $shortcut.WorkingDirectory = $installDir
    $shortcut.Description = 'Transparent desktop fish; can keep this PC awake while open.'
    $shortcut.Save()
  }

  $uninstallLink = $shell.CreateShortcut((Join-Path $startMenuDir 'Uninstall Fish Tank.lnk'))
  $uninstallLink.TargetPath = $powershell
  $uninstallLink.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$(Join-Path $installDir 'Uninstall-FishTank.ps1')`""
  $uninstallLink.WorkingDirectory = $installDir
  $uninstallLink.Description = 'Remove Fish Tank from this PC.'
  $uninstallLink.Save()

  $choice = [System.Windows.Forms.MessageBox]::Show(
    'Start Fish Tank automatically when this Windows account signs in?',
    'Fish Tank Setup',
    [System.Windows.Forms.MessageBoxButtons]::YesNo,
    [System.Windows.Forms.MessageBoxIcon]::Question,
    [System.Windows.Forms.MessageBoxDefaultButton]::Button2
  )
  $startupLink = Join-Path $startupDir 'Fish Tank.lnk'
  if($choice -eq [System.Windows.Forms.DialogResult]::Yes){
    New-Item -ItemType Directory -Path $startupDir -Force | Out-Null
    $startupShortcut = $shell.CreateShortcut($startupLink)
    $startupShortcut.TargetPath = $powershell
    $startupShortcut.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$(Join-Path $installDir 'FishTank.ps1')`""
    $startupShortcut.WorkingDirectory = $installDir
    $startupShortcut.Description = 'Launch Fish Tank when this account signs in.'
    $startupShortcut.Save()
  } else {
    Remove-Item -LiteralPath $startupLink -Force -ErrorAction SilentlyContinue
  }

  Start-Process -FilePath $powershell -WindowStyle Hidden -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$(Join-Path $installDir 'FishTank.ps1')`"")
  [void][System.Windows.Forms.MessageBox]::Show(
    'Fish Tank is installed. Its tray menu includes “Keep computer awake while Fish Tank is open.” This prevents sleep without moving the mouse.',
    'Fish Tank Setup',
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Information
  )
} catch {
  [void][System.Windows.Forms.MessageBox]::Show("Fish Tank could not be installed:`r`n$($_.Exception.Message)",'Fish Tank Setup',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)
  exit 1
}

