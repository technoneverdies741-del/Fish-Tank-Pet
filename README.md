# Fish Tank desktop pet

Fish Tank is a small Windows desktop pet written in PowerShell and Windows Forms. It draws a transparent, animated ASCII fish, swims around the screen, and can react to a focused text box.

## Install

1. [Download FishTankSetup.exe](https://github.com/technoneverdies741-del/Fish-Tank-Pet/raw/refs/heads/main/downloads/FishTankSetup.exe).
2. Open it and choose whether Fish Tank should start when you sign in.
3. Launch **Fish Tank** from the desktop or Start menu.

The installer is per-user and does not need administrator access. It installs to `%LOCALAPPDATA%\FishTankPet`. Use **Uninstall Fish Tank** in the Start menu to remove it.

## Keep the computer awake

Fish Tank can ask Windows to keep the computer from entering sleep while the app is open. The tray menu item **Keep computer awake while Fish Tank is open** is on by default. The request ends when Fish Tank closes or the option is turned off. Windows may still turn off the display, and work or school device policies can override this request.

Fish Tank does not move the pointer to simulate activity. Ask the computer's owner or IT administrator before using it on a managed work computer.

## Cursor behavior

When a text box is focused, Fish Tank hunts the pointer, carries it while the field remains focused, then drops it where it is when focus leaves. Press **Delete** to kick him off. Press **End** to manually lure him.

The tray menu's **Number of fish** setting starts with one fish and lets you add up to four. When more than one is selected, the fish pass the cursor to one another, each holding it for 10 seconds. With exactly two fish, they sometimes start a short, fast cursor-pong volley.

The cursor mischief chance and other options are in the Fish Tank tray menu. The fish changes between black and white based on nearby screen brightness.

## Requirements

- Windows 10 or Windows 11
- Built-in Windows PowerShell 5.1 and .NET Windows Forms/UI Automation components

The app runs locally and makes no network requests.

## Build the installer

Run `Build-Installer.ps1` in Windows PowerShell on Windows 10 or 11. It uses the built-in IExpress utility and writes `dist\FishTankSetup.exe`.

