# Fish Tank desktop pet

Fish Tank is a lightweight Windows desktop pet written in PowerShell and Windows Forms. It draws animated ASCII fish that swim around a transparent, resizable tank.

## Install

1. Download `FishTankSetup.exe` from the [GitHub downloads folder](https://github.com/technoneverdies741-del/Fish-Tank-Pet/tree/main/downloads).
2. Open it and choose whether Fish Tank should start when you sign in.
3. Launch **Fish Tank** from the desktop or Start menu.

The installer is per-user and does not need administrator access. It installs to `%LOCALAPPDATA%\FishTankPet`. Use **Uninstall Fish Tank** in the Start menu to remove it.

## Tray panel

The tray menu lets you:

- Set the water background color and transparency.
- Choose a style for each fish, color fish, and select hats.
- Add up to 1,000 fish and set their reproduction interval.
- Remap Pong, cursor mischief, and add/remove fish keys to keys available on compact keyboards.
- Check for updates. After an update, a What's New page describes the changes.
- Restore any earlier published source version, from v1 to the current version.

The fish start with one fish. Keyboard shortcuts can be changed from the tray panel.

## Keep the computer awake

Fish Tank can ask Windows to keep the computer from entering sleep while the app is open. The tray menu item **Keep computer awake while Fish Tank is open** is on by default. Fish Tank does not move the pointer to simulate activity. Windows may still turn off the display, and work or school device policies can override the request.

## Requirements

- Windows 10 or Windows 11
- Built-in Windows PowerShell 5.1 and .NET Windows Forms/UI Automation components
- Internet access for in-app updates and version restores

## Build the installer

Run `Build-Installer.ps1` in Windows PowerShell on Windows 10 or 11. It uses the built-in IExpress utility and writes `dist\FishTankSetup.exe`.
