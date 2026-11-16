Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
[System.Windows.Forms.Application]::EnableVisualStyles()

$native = @'
using System;
using System.Runtime.InteropServices;

public static class FishTankNative {
  [DllImport("user32.dll", EntryPoint="GetWindowLong", SetLastError=true)] static extern int GetWindowLong32(IntPtr h, int n);
  [DllImport("user32.dll", EntryPoint="GetWindowLongPtr", SetLastError=true)] static extern IntPtr GetWindowLongPtr64(IntPtr h, int n);
  [DllImport("user32.dll", EntryPoint="SetWindowLong", SetLastError=true)] static extern int SetWindowLong32(IntPtr h, int n, int v);
  [DllImport("user32.dll", EntryPoint="SetWindowLongPtr", SetLastError=true)] static extern IntPtr SetWindowLongPtr64(IntPtr h, int n, IntPtr v);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int key);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint flags);
  [DllImport("kernel32.dll")] static extern IntPtr GetConsoleWindow();
  [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int command);
  public static void HideConsole() { IntPtr h=GetConsoleWindow(); if(h!=IntPtr.Zero) ShowWindow(h,0); }
  public static long GetStyle(IntPtr h, int n) { return IntPtr.Size == 8 ? GetWindowLongPtr64(h,n).ToInt64() : GetWindowLong32(h,n); }
  public static void SetStyle(IntPtr h, int n, long v) { if (IntPtr.Size == 8) SetWindowLongPtr64(h,n,new IntPtr(v)); else SetWindowLong32(h,n,(int)v); }
}
'@
Add-Type -TypeDefinition $native
[FishTankNative]::HideConsole()
$script:FishTankVersion='20'
$script:FishTankInstallFolder=Join-Path $env:LOCALAPPDATA 'FishTankPet'
$script:PendingWhatsNewPath=Join-Path $script:FishTankInstallFolder 'whats-new.pending'
$script:FishTankReleaseNotes=@(
  'Background water is blue with an adjustable transparency slider.',
  'Fish, hats, and labels have thicker dark outlines for clear contrast.',
  'Fish swim across compact tanks instead of looping in place.',
  'Choose a different glyph style for each fish.',
  'Map Pong, cursor mischief, and fish-count controls to keys your keyboard has.'
)
$script:FishStyleChoices=@(
  [pscustomobject]@{Name='Classic';Left='<o))><';Right='><((o>'},
  [pscustomobject]@{Name='Slim';Left='<><';Right='><>'},
  [pscustomobject]@{Name='Goldfish';Left='<°))><';Right='><((°>'},
  [pscustomobject]@{Name='Longfin';Left='<o))))><';Right='><((((o>'},
  [pscustomobject]@{Name='Puffer';Left='<O))><';Right='><((O>'},
  [pscustomobject]@{Name='Shark';Left='<°)))><';Right='><(((°>'}
)

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Fish Tank'
$form.StartPosition = 'CenterScreen'
$form.ClientSize = New-Object System.Drawing.Size(620, 390)
$form.MinimumSize = New-Object System.Drawing.Size(300, 220)
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
$form.TopMost = $true
$form.BackColor = [System.Drawing.Color]::FromArgb(18,18,18)
$form.Opacity = 1.0
$form.TransparencyKey = $form.BackColor
$form.KeyPreview = $true

$tank = New-Object System.Windows.Forms.Panel
try{$doubleBufferProperty=$tank.GetType().GetProperty('DoubleBuffered',[System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic);if($doubleBufferProperty){$doubleBufferProperty.SetValue($tank,$true,$null)}}catch{}
$tank.Dock = [System.Windows.Forms.DockStyle]::Fill
$tank.BackColor = $form.TransparencyKey
$form.Controls.Add($tank)
$screenSampleBitmap=New-Object System.Drawing.Bitmap(1,1)
$screenSampleGraphics=[System.Drawing.Graphics]::FromImage($screenSampleBitmap)

$state = [pscustomobject]@{ X=260.0; Y=120.0; Direction=1; Phase=0.0; Speed=3.2; Angle=0.0; LookAngle=0.0; Heading=0.0; TargetX=0.0; TargetY=0.0; Follow=$false; TypingForcedFollow=$false; WindowedBounds=[System.Drawing.Rectangle]::Empty; TextFocused=$false; LastFocusCheck=[datetime]::MinValue; KeepAwake=$true; KeepAwakeRefresh=[datetime]::MinValue; RocketLeaguePaused=$false; RocketLeaguePauseStarted=[datetime]::MinValue; LastRocketLeagueCheck=[datetime]::MinValue; Tilt=$true; ClickThrough=$false; IsDragging=$false; DraggingFishIndex=-1; FishCount=1; FishHidden=$false; HomeWasDown=$false; CarrierIndex=0; StealTurnsRemaining=0; PongActive=$false; PongVX=0.0; PongVY=0.0; PongHits=0; PongScoreLeft=0; PongScoreRight=0; PongHitLimit=0; PongEndsAt=[datetime]::MinValue; PongLastHitIndex=1; PongMode=$false; PongOnly=$false; PongPasses=0; Physics=$false; VelX=0.0; VelY=0.0; DragAt=[datetime]::UtcNow; PinnedCorner=$false; Stealing=$false; StealPhase=''; TypingSteal=$false; TypingGrabEnabled=$true; TypingSuppressedUntil=[datetime]::MinValue; LastTypingAt=[datetime]::MinValue; StealOriginX=0; StealOriginY=0; StealEnabled=$true; StealChance=5; StealUntil=[datetime]::MinValue; StealTargetX=0.0; StealTargetY=0.0; EndWasDown=$false; InsertWasDown=$false; DeleteWasDown=$false; BlubUntil=[datetime]::MinValue; NextBlub=[datetime]::UtcNow.AddSeconds(8); DragOffsetX=0.0; DragOffsetY=0.0; LastDragX=0.0; LastDragY=0.0; DragAxis=''; DragDir=0; DragLeg=0.0; DragPath=0.0; DragMin=0.0; DragMax=0.0; DragReversals=0; DragStarted=[datetime]::MinValue; AngryUntil=[datetime]::MinValue; LastLoc=$form.Location; LastMove=[datetime]::MinValue; WindowDragging=$false; WindowPhysics=$false; WindowVelX=0.0; WindowVelY=0.0; WindowBounds=[System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea; WindowAt=[datetime]::UtcNow; ShakeAxis=''; ShakeDir=0; ShakeLeg=0.0; ShakePath=0.0; ShakeMin=0; ShakeMax=0; ShakeReversals=0; ShakeStarted=[datetime]::MinValue; LastCursor=[System.Windows.Forms.Cursor]::Position; CursorStillSince=[datetime]::UtcNow }
$state | Add-Member -NotePropertyName Dragging -NotePropertyValue $false
$state | Add-Member -NotePropertyName LookAngle -NotePropertyValue 0.0
$state | Add-Member -NotePropertyName Style -NotePropertyValue 'Classic'
$state | Add-Member -NotePropertyName BackgroundTransparency -NotePropertyValue 35
$state | Add-Member -NotePropertyName FishColor -NotePropertyValue ([System.Drawing.Color]::White)
$state | Add-Member -NotePropertyName HatsEnabled -NotePropertyValue $true
$state | Add-Member -NotePropertyName HatStyle -NotePropertyValue 'Traffic cone'
$state | Add-Member -NotePropertyName HatColor -NotePropertyValue ([System.Drawing.Color]::FromArgb(255,238,112,32))
$state | Add-Member -NotePropertyName HatAccentColor -NotePropertyValue ([System.Drawing.Color]::White)
$state | Add-Member -NotePropertyName HatColorCustom -NotePropertyValue $false
$state | Add-Member -NotePropertyName RocketLeagueOverrideUntil -NotePropertyValue ([datetime]::MinValue)
$state | Add-Member -NotePropertyName AutoBreedEnabled -NotePropertyValue $false
$state | Add-Member -NotePropertyName NextBreed -NotePropertyValue ([datetime]::MaxValue)
$state | Add-Member -NotePropertyName BreedInterval -NotePropertyValue 10
$state | Add-Member -NotePropertyName InsertKeyVK -NotePropertyValue 0x2D
$state | Add-Member -NotePropertyName DeleteKeyVK -NotePropertyValue 0x2E
$state | Add-Member -NotePropertyName EndKeyVK -NotePropertyValue 0x23
$state | Add-Member -NotePropertyName PageUpKeyVK -NotePropertyValue 0x21
$state | Add-Member -NotePropertyName PageDownKeyVK -NotePropertyValue 0x22
$backgroundOverlay=New-Object System.Windows.Forms.Form
$backgroundOverlay.FormBorderStyle=[System.Windows.Forms.FormBorderStyle]::None
$backgroundOverlay.ShowInTaskbar=$false
$backgroundOverlay.StartPosition=[System.Windows.Forms.FormStartPosition]::Manual
$backgroundOverlay.BackColor=[System.Drawing.Color]::FromArgb(24,104,214)
$backgroundOverlay.TopMost=$true
$backgroundOverlay.Opacity=0.01
$backgroundOverlayBounds=[System.Drawing.Rectangle]::Empty
$overlayStyle=[FishTankNative]::GetStyle($backgroundOverlay.Handle,-20)
$overlayStyle=$overlayStyle -bor 0x20 -bor 0x80000 -bor 0x80 -bor 0x8000000
[FishTankNative]::SetStyle($backgroundOverlay.Handle,-20,$overlayStyle)
$updateBackgroundOverlay={
  if($state.BackgroundTransparency -ge 100 -or $tank.ClientSize.Width -le 0 -or $tank.ClientSize.Height -le 0){if($backgroundOverlay.Visible){$backgroundOverlay.Hide()};return}
  $targetBounds=$tank.RectangleToScreen($tank.ClientRectangle)
  $needsZOrder=$false
  if(-not $backgroundOverlay.Bounds.Equals($targetBounds)){$backgroundOverlay.Bounds=$targetBounds;$needsZOrder=$true}
  $targetOpacity=[Math]::Max(0.01,[Math]::Min(1.0,(100.0-$state.BackgroundTransparency)/100.0))
  if([Math]::Abs($backgroundOverlay.Opacity-$targetOpacity) -gt 0.001){$backgroundOverlay.Opacity=$targetOpacity}
  if(-not $backgroundOverlay.Visible){$backgroundOverlay.Show();$needsZOrder=$true}
  if($needsZOrder){
    [FishTankNative]::SetWindowPos($backgroundOverlay.Handle,$form.Handle,$targetBounds.X,$targetBounds.Y,$targetBounds.Width,$targetBounds.Height,0x10 -bor 0x40) | Out-Null
  }
}
$script:drawResources=$null
$script:refreshDrawingResources={
  $key="$($state.FishColor.ToArgb()):$($state.HatColor.ToArgb()):$($state.HatAccentColor.ToArgb())"
  if($script:drawResources -and $script:drawResources.Key -eq $key){return}
  if($script:drawResources){
    $script:drawResources.FishFont.Dispose();$script:drawResources.FishBrush.Dispose();$script:drawResources.FishOutlineBrush.Dispose();foreach($glyphSet in $script:drawResources.FishGlyphs.Values){$glyphSet.Left.Dispose();$glyphSet.Right.Dispose()};$script:drawResources.HatOutlinePen.Dispose();$script:drawResources.TextOutlineBrush.Dispose();$script:drawResources.HatBrush.Dispose();$script:drawResources.HatAccentBrush.Dispose()
    foreach($b in $script:drawResources.PartyBrushes){$b.Dispose()}
    $script:drawResources.AngerFont.Dispose();$script:drawResources.AngerBrush.Dispose();$script:drawResources.BlubFont.Dispose();$script:drawResources.BlubBrush.Dispose();$script:drawResources.BubblePen.Dispose();$script:drawResources.GlintBrush.Dispose();$script:drawResources.ScoreFont.Dispose();$script:drawResources.ScoreBrush.Dispose()
  }
  $party=@((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,239,68,68))),(New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,255,145,35))),(New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,255,215,55))),(New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,54,181,95))),(New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,58,126,235))),(New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,153,79,207))))
  $fishFont=New-Object System.Drawing.Font('Consolas',14,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
  $fishBrush=New-Object System.Drawing.SolidBrush($state.FishColor)
  $fishOutlineBrush=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,3,12,24))
  $makeFishGlyph={param([string]$glyph)
    $bitmap=New-Object System.Drawing.Bitmap(64,28,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $bitmapGraphics=[System.Drawing.Graphics]::FromImage($bitmap);$bitmapGraphics.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::AntiAlias;$bitmapGraphics.TextRenderingHint=[System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    foreach($offset in @(@(-1.4,-1.4),@(0,-1.8),@(1.4,-1.4),@(-1.8,0),@(1.8,0),@(-1.4,1.4),@(0,1.8),@(1.4,1.4))){$bitmapGraphics.DrawString($glyph,$fishFont,$fishOutlineBrush,[single](2+$offset[0]),[single](1+$offset[1]))}
    $bitmapGraphics.DrawString($glyph,$fishFont,$fishBrush,[single]2,[single]1);$bitmapGraphics.Dispose();return $bitmap
  }
  $fishGlyphs=@{}
  foreach($styleChoice in $script:FishStyleChoices){$fishGlyphs[$styleChoice.Name]=[pscustomobject]@{Left=(& $makeFishGlyph $styleChoice.Left);Right=(& $makeFishGlyph $styleChoice.Right)}}
  $fishOutlineBrush.Dispose()
  $script:drawResources=[pscustomobject]@{
    Key=$key
    FishFont=$fishFont
    FishBrush=$fishBrush
    FishOutlineBrush=(New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,3,12,24)))
    FishGlyphs=$fishGlyphs
    HatOutlinePen=(New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,3,12,24),2.6))
    TextOutlineBrush=(New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,3,12,24)))
    HatBrush=(New-Object System.Drawing.SolidBrush($state.HatColor))
    HatAccentBrush=(New-Object System.Drawing.SolidBrush($state.HatAccentColor))
    PartyBrushes=$party
    AngerFont=(New-Object System.Drawing.Font('Consolas',15,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel))
    AngerBrush=(New-Object System.Drawing.SolidBrush([System.Drawing.Color]::OrangeRed))
    BlubFont=(New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold))
    BlubBrush=(New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(190,255,255,255)))
    BubblePen=(New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(95,205,205,205),1))
    GlintBrush=(New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(85,224,224,224)))
    ScoreFont=(New-Object System.Drawing.Font('Consolas',15,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel))
    ScoreBrush=(New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White))
  }
}
$drawOutlinedText={param($graphics,[string]$text,$font,$brush,[single]$x,[single]$y,[single]$radius)
  foreach($offset in @(@(-1,-1),@(0,-1),@(1,-1),@(-1,0),@(1,0),@(-1,1),@(0,1),@(1,1))){$graphics.DrawString($text,$font,$script:drawResources.TextOutlineBrush,[single]($x+$offset[0]*$radius),[single]($y+$offset[1]*$radius))}
  $graphics.DrawString($text,$font,$brush,$x,$y)
}
$script:dellLogoBitmap=$null
$script:dellLogoColorKey=''
$script:dellLogoPngBase64='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'
$script:refreshDellLogo={
  if($script:dellLogoBitmap){return}
  $logoBytes=[Convert]::FromBase64String($script:dellLogoPngBase64)
  $logoStream=New-Object System.IO.MemoryStream(,$logoBytes)
  $sourceLogo=[System.Drawing.Bitmap]::FromStream($logoStream)
  $sourceLogo.MakeTransparent([System.Drawing.Color]::White)
  $script:dellLogoBitmap=New-Object System.Drawing.Bitmap(128,128,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $logoGraphics=[System.Drawing.Graphics]::FromImage($script:dellLogoBitmap)
  $logoGraphics.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $logoGraphics.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $logoGraphics.Clear([System.Drawing.Color]::Transparent)
  $logoWhite=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
  $logoGraphics.FillEllipse($logoWhite,6,6,116,116)
  $logoGraphics.DrawImage($sourceLogo,0,0,128,128)
  $logoWhite.Dispose();$logoGraphics.Dispose();$sourceLogo.Dispose();$logoStream.Dispose();$script:dellLogoColorKey='source-logo'
}
$state | Add-Member -NotePropertyName PgUpWasDown -NotePropertyValue $false
$state | Add-Member -NotePropertyName PgDownWasDown -NotePropertyValue $false
$state | Add-Member -NotePropertyName PgUpStarted -NotePropertyValue ([datetime]::MinValue)
$state | Add-Member -NotePropertyName PgDownStarted -NotePropertyValue ([datetime]::MinValue)
$state | Add-Member -NotePropertyName PgUpLastAdjust -NotePropertyValue ([datetime]::MinValue)
$state | Add-Member -NotePropertyName PgDownLastAdjust -NotePropertyValue ([datetime]::MinValue)
$makeFish = { param($x,$y,$speed) [pscustomobject]@{ X=[double]$x; Y=[double]$y; Direction=1; Angle=0.0; LookAngle=0.0; Heading=0.0; TargetX=0.0; TargetY=0.0; Speed=[double]$speed; Style='Classic'; Dragging=$false; BlubUntil=[datetime]::MinValue; NextBlub=[datetime]::MinValue; AngryUntil=[datetime]::MinValue; DragOffsetX=0.0; DragOffsetY=0.0; LastDragX=0.0; LastDragY=0.0 } }
$buddy = & $makeFish 400 230 2.8
$fish3 = & $makeFish 180 260 2.5
$fish4 = & $makeFish 340 80 2.6
$fishies=@($state,$buddy,$fish3,$fish4)
$rng = New-Object System.Random
for($i=$fishies.Count;$i -lt 1000;$i++){$extraFish=& $makeFish (30+$rng.NextDouble()*520) (30+$rng.NextDouble()*310) (2.3+$rng.NextDouble()*1.0);$fishies+=,$extraFish}
for($i=0;$i -lt $fishies.Count;$i++){$fishies[$i].NextBlub=[datetime]::UtcNow.AddSeconds(2+($i*1.6)+$rng.NextDouble()*3)}
$pickRoamTarget = {
  $left=18.0; $right=[Math]::Max($left+1,$tank.ClientSize.Width-88.0)
  $top=18.0; $bottom=[Math]::Max($top+12,$tank.ClientSize.Height-34.0)
  $state.TargetX=$left+$rng.NextDouble()*($right-$left)
  $state.TargetY=$top+$rng.NextDouble()*($bottom-$top)
}
$pickBuddyTarget = {
  $left=18.0;$right=[Math]::Max($left+1,$tank.ClientSize.Width-88.0)
  $top=18.0;$bottom=[Math]::Max($top+12,$tank.ClientSize.Height-34.0)
  $buddy.TargetX=$left+$rng.NextDouble()*($right-$left)
  $buddy.TargetY=$top+$rng.NextDouble()*($bottom-$top)
}
$pickFishTarget = { param($fish)
  $left=18.0;$right=[Math]::Max($left+1,$tank.ClientSize.Width-88.0)
  $top=18.0;$bottom=[Math]::Max($top+12,$tank.ClientSize.Height-34.0)
  $fish.TargetX=$left+$rng.NextDouble()*($right-$left);$fish.TargetY=$top+$rng.NextDouble()*($bottom-$top)
}
$pickStealTarget = {
  $left=30.0;$right=[Math]::Max($left+1,$tank.ClientSize.Width-125.0)
  $top=28.0;$bottom=[Math]::Max($top+1,$tank.ClientSize.Height-62.0)
  $state.StealTargetX=$left+$rng.NextDouble()*($right-$left)
  $state.StealTargetY=$top+$rng.NextDouble()*($bottom-$top)
}
$startPongGame = {
  $state.FishCount=2
  $fishCountMenu.Text="Number of fish ($($state.FishCount))"
  foreach($item in $fishCountItems){$item.Checked=([int]$item.Tag -eq 2)}
  if($buddy.TargetX -le 0){& $pickFishTarget $buddy}
  $w=$tank.ClientSize.Width;$h=$tank.ClientSize.Height;$leftCenter=$w*0.24;$rightCenter=$w*0.72;$middleY=$h*0.5
  $state.X=$leftCenter-43;$state.Y=$middleY-14;$state.Heading=0.0;$state.Direction=1;$state.Angle=0.0;$state.Dragging=$false
  $buddy.X=$rightCenter-43;$buddy.Y=$middleY-14;$buddy.Heading=[Math]::PI;$buddy.Direction=-1;$buddy.Angle=0.0;$buddy.Dragging=$false
  $state.Stealing=$false;$state.StealPhase='';$state.IsDragging=$false;$state.Physics=$false;$state.PinnedCorner=$false;$state.PongMode=$false;$state.PongOnly=$false
  $state.PongActive=$true;$state.PongHits=0;$state.PongScoreLeft=0;$state.PongScoreRight=0;$state.PongHitLimit=0;$state.PongEndsAt=[datetime]::MaxValue;$state.PongLastHitIndex=1
  $ballX=($leftCenter+$rightCenter)/2;$ballY=$middleY
  $state.PongVX=-12.0;$state.PongVY=($rng.NextDouble()-0.5)*4.4
  $origin=$tank.PointToScreen([System.Drawing.Point]::Empty);$px=[int]($origin.X+$ballX);$py=[int]($origin.Y+$ballY)
  [FishTankNative]::SetCursorPos($px,$py)|Out-Null;$state.LastCursor=New-Object System.Drawing.Point($px,$py);$state.CursorStillSince=[datetime]::UtcNow
}
$togglePong = {
  if($state.PongActive){
    $state.PongActive=$false;$state.PongMode=$false;$state.PongOnly=$false
    $state.LastCursor=[System.Windows.Forms.Cursor]::Position;$state.CursorStillSince=[datetime]::UtcNow
    & $pickRoamTarget;& $pickFishTarget $buddy
  }else{& $startPongGame}
  $tank.Invalidate()
}
$typingKeys=@(8,9,13,32)+@(48..90)+@(96..111)+@(186..192)+@(219..222)
$startCursorSteal = {
  if(-not $state.Stealing){
    $state.Stealing=$true;$state.StealPhase='Hunting';$state.StealUntil=[datetime]::MinValue
    $state.StealOriginX=[System.Windows.Forms.Cursor]::Position.X;$state.StealOriginY=[System.Windows.Forms.Cursor]::Position.Y
    $state.PinnedCorner=$false;$state.IsDragging=$false;$tank.Capture=$false;$state.Physics=$false;$state.VelX=0;$state.VelY=0
    # Let the fish nearest the pointer make the first catch; later fish take turns.
    $screenOrigin=$tank.PointToScreen([System.Drawing.Point]::Empty);$cursor=[System.Windows.Forms.Cursor]::Position
    $best=0;$bestDistance=[double]::MaxValue
    for($i=0;$i -lt $state.FishCount;$i++){$fish=$fishies[$i];$fx=$screenOrigin.X+$fish.X+43;$fy=$screenOrigin.Y+$fish.Y+14;$d=[Math]::Pow($cursor.X-$fx,2)+[Math]::Pow($cursor.Y-$fy,2);if($d -lt $bestDistance){$best=$i;$bestDistance=$d}}
    $state.CarrierIndex=$best;$state.StealTurnsRemaining=$state.FishCount;$state.PongMode=($state.FishCount -eq 2 -and $rng.Next(100) -lt 24);$state.PongPasses=if($state.PongMode){6}else{0}
    $state.PongOnly=$false
    if($state.PongMode){& $startPongGame}
    & $pickStealTarget
  }
}

# Build a short, quiet pair of downward bubble chirps in memory.
$sampleRate=16000;$durations=@(0.14,0.17);$gapSamples=[int]($sampleRate*0.045)
$toneSamples=@([int]($sampleRate*$durations[0]),[int]($sampleRate*$durations[1]))
$pcm=New-Object byte[] (($toneSamples[0]+$gapSamples+$toneSamples[1])*2)
$sampleIndex=0
for($tone=0;$tone -lt 2;$tone++){
  $duration=$durations[$tone];$count=$toneSamples[$tone];$startHz=if($tone -eq 0){330.0}else{255.0};$endHz=if($tone -eq 0){145.0}else{115.0}
  for($i=0;$i -lt $count;$i++){
    $t=$i/[double]$sampleRate;$phase=2*[Math]::PI*($startHz*$t+(($endHz-$startHz)/(2*$duration))*$t*$t)
    $envelope=[Math]::Pow([Math]::Sin([Math]::PI*$t/$duration),1.5)*0.16
    $sample=[int16]([Math]::Sin($phase)*$envelope*32767);$bytes=[BitConverter]::GetBytes($sample)
    $pcm[2*$sampleIndex]=$bytes[0];$pcm[2*$sampleIndex+1]=$bytes[1];$sampleIndex++
  }
  if($tone -eq 0){$sampleIndex+=$gapSamples}
}
$wav=New-Object System.IO.MemoryStream;$writer=New-Object System.IO.BinaryWriter($wav)
$writer.Write([byte[]][Text.Encoding]::ASCII.GetBytes('RIFF'));$writer.Write([int](36+$pcm.Length));$writer.Write([byte[]][Text.Encoding]::ASCII.GetBytes('WAVE'))
$writer.Write([byte[]][Text.Encoding]::ASCII.GetBytes('fmt '));$writer.Write([int]16);$writer.Write([int16]1);$writer.Write([int16]1);$writer.Write([int]$sampleRate);$writer.Write([int]($sampleRate*2));$writer.Write([int16]2);$writer.Write([int16]16)
$writer.Write([byte[]][Text.Encoding]::ASCII.GetBytes('data'));$writer.Write([int]$pcm.Length);$writer.Write([byte[]]$pcm);$writer.Flush()
$blubStream=New-Object System.IO.MemoryStream(,$wav.ToArray());$blubPlayer=New-Object System.Media.SoundPlayer($blubStream);$blubPlayer.Load()
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 30

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$awakeItem = New-Object System.Windows.Forms.ToolStripMenuItem('Keep computer awake while Fish Tank is open')
$awakeItem.Checked = $true
$followItem = New-Object System.Windows.Forms.ToolStripMenuItem('Follow cursor across monitor')
$clickItem = New-Object System.Windows.Forms.ToolStripMenuItem('Click-through (turn off to move or shake tank)')
$clickItem.Checked = $false
$tiltItem = New-Object System.Windows.Forms.ToolStripMenuItem('Tilt toward cursor')
$tiltItem.Checked = $true
$ambienceItem = New-Object System.Windows.Forms.ToolStripMenuItem('Water ambience')
$ambienceItem.Checked = $true
$typingGrabItem = New-Object System.Windows.Forms.ToolStripMenuItem('Grab cursor while typing')
$typingGrabItem.Checked = $true
$mischiefItem = New-Object System.Windows.Forms.ToolStripMenuItem('Cursor mischief (End lures fish; Delete kicks him off)')
$mischiefItem.Checked = $true
$backgroundTransparencyItem=New-Object System.Windows.Forms.ToolStripMenuItem('Tank background transparency (100%)')
$backgroundTransparencyItem.Add_Click({
  $previousTransparency=$state.BackgroundTransparency
  $transparencyDialog=New-Object System.Windows.Forms.Form
  $transparencyDialog.Text='Tank background transparency';$transparencyDialog.FormBorderStyle=[System.Windows.Forms.FormBorderStyle]::FixedDialog;$transparencyDialog.StartPosition=[System.Windows.Forms.FormStartPosition]::CenterParent;$transparencyDialog.ClientSize=New-Object System.Drawing.Size(330,112);$transparencyDialog.MaximizeBox=$false;$transparencyDialog.MinimizeBox=$false;$transparencyDialog.ShowInTaskbar=$false
  $transparencyLabel=New-Object System.Windows.Forms.Label;$transparencyLabel.Text="$($state.BackgroundTransparency)% transparent";$transparencyLabel.Location=New-Object System.Drawing.Point(12,10);$transparencyLabel.AutoSize=$true
  $transparencyTrack=New-Object System.Windows.Forms.TrackBar;$transparencyTrack.Minimum=0;$transparencyTrack.Maximum=100;$transparencyTrack.TickFrequency=10;$transparencyTrack.SmallChange=1;$transparencyTrack.LargeChange=10;$transparencyTrack.Value=$state.BackgroundTransparency;$transparencyTrack.Location=New-Object System.Drawing.Point(8,30);$transparencyTrack.Size=New-Object System.Drawing.Size(310,42)
  $transparencyTrack.Add_ValueChanged({$state.BackgroundTransparency=$transparencyTrack.Value;$transparencyLabel.Text="$($state.BackgroundTransparency)% transparent";& $updateBackgroundOverlay})
  $okTransparency=New-Object System.Windows.Forms.Button;$okTransparency.Text='OK';$okTransparency.DialogResult=[System.Windows.Forms.DialogResult]::OK;$okTransparency.Location=New-Object System.Drawing.Point(226,76)
  $cancelTransparency=New-Object System.Windows.Forms.Button;$cancelTransparency.Text='Cancel';$cancelTransparency.DialogResult=[System.Windows.Forms.DialogResult]::Cancel;$cancelTransparency.Location=New-Object System.Drawing.Point(144,76)
  [void]$transparencyDialog.Controls.Add($transparencyLabel);[void]$transparencyDialog.Controls.Add($transparencyTrack);[void]$transparencyDialog.Controls.Add($okTransparency);[void]$transparencyDialog.Controls.Add($cancelTransparency);$transparencyDialog.AcceptButton=$okTransparency;$transparencyDialog.CancelButton=$cancelTransparency
  if($transparencyDialog.ShowDialog($form) -ne [System.Windows.Forms.DialogResult]::OK){$state.BackgroundTransparency=$previousTransparency;& $updateBackgroundOverlay}
  $backgroundTransparencyItem.Text="Tank background transparency ($($state.BackgroundTransparency)%)"
  $transparencyDialog.Dispose()
})
$chanceMenu = New-Object System.Windows.Forms.ToolStripMenuItem('Cursor steal chance')
$chanceItems = @()
foreach($pct in 5..50 | Where-Object { $_ % 5 -eq 0 }) {
  $chanceItem = New-Object System.Windows.Forms.ToolStripMenuItem("$pct%")
  $chanceItem.Tag = $pct
  $chanceItem.Checked = ($pct -eq 5)
  [void]$chanceMenu.DropDownItems.Add($chanceItem)
  $chanceItems += $chanceItem
  $chanceItem.Add_Click({
    $state.StealChance = [int]$this.Tag
    foreach($item in $chanceItems){$item.Checked = ([int]$item.Tag -eq $state.StealChance)}
  })
}
$fishCountMenu=New-Object System.Windows.Forms.ToolStripMenuItem('Number of fish')
$fishCountItems=@()
$setFishCount = {
  param($count)
  $state.FishCount=[Math]::Max(1,[Math]::Min(1000,[int]$count))
  $fishCountMenu.Text="Number of fish ($($state.FishCount))"
  foreach($item in $fishCountItems){$item.Checked=([int]$item.Tag -eq $state.FishCount)}
  for($i=1;$i -lt $state.FishCount;$i++){if($fishies[$i].TargetX -le 0){& $pickFishTarget $fishies[$i]}}
  if($state.CarrierIndex -ge $state.FishCount){$state.CarrierIndex=0}
  if($state.Stealing -and $state.StealPhase -eq 'Carrying' -and $state.CarrierIndex -ge $state.FishCount){$state.StealPhase='Hunting'}
  if($state.FishCount -ge 1000 -and $state.AutoBreedEnabled){$state.AutoBreedEnabled=$false;$breedItem.Checked=$false;$state.NextBreed=[datetime]::MaxValue}
  $tank.Invalidate()
}
$fishCountMenu.Add_Click({
  $countDialog=New-Object System.Windows.Forms.Form
  $countDialog.Text='Number of fish';$countDialog.FormBorderStyle=[System.Windows.Forms.FormBorderStyle]::FixedDialog;$countDialog.StartPosition=[System.Windows.Forms.FormStartPosition]::CenterParent;$countDialog.ClientSize=New-Object System.Drawing.Size(240,92);$countDialog.MaximizeBox=$false;$countDialog.MinimizeBox=$false;$countDialog.ShowInTaskbar=$false
  $countLabel=New-Object System.Windows.Forms.Label;$countLabel.Text='Choose 1 to 1000 fish:';$countLabel.Location=New-Object System.Drawing.Point(12,12);$countLabel.AutoSize=$true
  $countBox=New-Object System.Windows.Forms.NumericUpDown;$countBox.Minimum=1;$countBox.Maximum=1000;$countBox.Value=$state.FishCount;$countBox.Location=New-Object System.Drawing.Point(148,9);$countBox.Width=76
  $okButton=New-Object System.Windows.Forms.Button;$okButton.Text='OK';$okButton.DialogResult=[System.Windows.Forms.DialogResult]::OK;$okButton.Location=New-Object System.Drawing.Point(68,52)
  $cancelButton=New-Object System.Windows.Forms.Button;$cancelButton.Text='Cancel';$cancelButton.DialogResult=[System.Windows.Forms.DialogResult]::Cancel;$cancelButton.Location=New-Object System.Drawing.Point(148,52)
  [void]$countDialog.Controls.Add($countLabel);[void]$countDialog.Controls.Add($countBox);[void]$countDialog.Controls.Add($okButton);[void]$countDialog.Controls.Add($cancelButton);$countDialog.AcceptButton=$okButton;$countDialog.CancelButton=$cancelButton
  if($countDialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK){& $setFishCount ([int]$countBox.Value)}
  $countDialog.Dispose()
})
$breedItem=New-Object System.Windows.Forms.ToolStripMenuItem('Reproduce every 10 seconds')
$breedItem.Checked=$false
$breedIntervalMenu=New-Object System.Windows.Forms.ToolStripMenuItem('Reproduction interval')
$breedIntervalItems=@()
foreach($seconds in 1..10){
  $label=if($seconds -eq 1){'1 second'}else{"$seconds seconds"}
  $intervalItem=New-Object System.Windows.Forms.ToolStripMenuItem($label)
  $intervalItem.Tag=$seconds;$intervalItem.Checked=($seconds -eq $state.BreedInterval)
  [void]$breedIntervalMenu.DropDownItems.Add($intervalItem);$breedIntervalItems+=$intervalItem
  $intervalItem.Add_Click({
    $state.BreedInterval=[int]$this.Tag
    foreach($item in $breedIntervalItems){$item.Checked=([int]$item.Tag -eq $state.BreedInterval)}
    $breedItem.Text=if($state.BreedInterval -eq 1){'Reproduce every 1 second'}else{"Reproduce every $($state.BreedInterval) seconds"}
    if($state.AutoBreedEnabled){$state.NextBreed=[datetime]::UtcNow.AddSeconds($state.BreedInterval)}
  })
}
$breedItem.Add_Click({
  $breedItem.Checked=-not $breedItem.Checked
  $state.AutoBreedEnabled=$breedItem.Checked
  $state.NextBreed=if($state.AutoBreedEnabled){[datetime]::UtcNow.AddSeconds($state.BreedInterval)}else{[datetime]::MaxValue}
})
$colorDialog=New-Object System.Windows.Forms.ColorDialog
$colorDialog.AllowFullOpen=$true;$colorDialog.FullOpen=$true;$colorDialog.Color=$state.FishColor
$fishColorItem=New-Object System.Windows.Forms.ToolStripMenuItem('Fish color…')
$fishColorItem.Add_Click({if($colorDialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK){$state.FishColor=$colorDialog.Color;$tank.Invalidate()}})
$fishStylesItem=New-Object System.Windows.Forms.ToolStripMenuItem('Fish styles…')
$fishStylesItem.Add_Click({
  $styleDialog=New-Object System.Windows.Forms.Form;$styleDialog.Text='Fish styles';$styleDialog.FormBorderStyle=[System.Windows.Forms.FormBorderStyle]::FixedDialog;$styleDialog.StartPosition=[System.Windows.Forms.FormStartPosition]::CenterParent;$styleDialog.ClientSize=New-Object System.Drawing.Size(340,146);$styleDialog.MaximizeBox=$false;$styleDialog.MinimizeBox=$false;$styleDialog.ShowInTaskbar=$false
  $fishNumberLabel=New-Object System.Windows.Forms.Label;$fishNumberLabel.Text='Fish number:';$fishNumberLabel.Location=New-Object System.Drawing.Point(16,18);$fishNumberLabel.AutoSize=$true
  $fishNumberBox=New-Object System.Windows.Forms.NumericUpDown;$fishNumberBox.Minimum=1;$fishNumberBox.Maximum=$state.FishCount;$fishNumberBox.Value=1;$fishNumberBox.Location=New-Object System.Drawing.Point(190,14);$fishNumberBox.Width=110
  $fishStyleLabel=New-Object System.Windows.Forms.Label;$fishStyleLabel.Text='Appearance:';$fishStyleLabel.Location=New-Object System.Drawing.Point(16,52);$fishStyleLabel.AutoSize=$true
  $fishStyleBox=New-Object System.Windows.Forms.ComboBox;$fishStyleBox.DropDownStyle=[System.Windows.Forms.ComboBoxStyle]::DropDownList;$fishStyleBox.Location=New-Object System.Drawing.Point(190,48);$fishStyleBox.Width=130
  foreach($styleChoice in $script:FishStyleChoices){[void]$fishStyleBox.Items.Add($styleChoice.Name)}
  $fishStyleBox.SelectedItem=$fishies[0].Style
  $fishNumberBox.Add_ValueChanged({$currentStyle=[string]$fishies[[int]$fishNumberBox.Value-1].Style;if(-not $fishStyleBox.Items.Contains($currentStyle)){$currentStyle='Classic'};$fishStyleBox.SelectedItem=$currentStyle})
  $applyStyleButton=New-Object System.Windows.Forms.Button;$applyStyleButton.Text='Apply';$applyStyleButton.DialogResult=[System.Windows.Forms.DialogResult]::OK;$applyStyleButton.Location=New-Object System.Drawing.Point(238,102)
  $cancelStyleButton=New-Object System.Windows.Forms.Button;$cancelStyleButton.Text='Cancel';$cancelStyleButton.DialogResult=[System.Windows.Forms.DialogResult]::Cancel;$cancelStyleButton.Location=New-Object System.Drawing.Point(152,102)
  [void]$styleDialog.Controls.Add($fishNumberLabel);[void]$styleDialog.Controls.Add($fishNumberBox);[void]$styleDialog.Controls.Add($fishStyleLabel);[void]$styleDialog.Controls.Add($fishStyleBox);[void]$styleDialog.Controls.Add($applyStyleButton);[void]$styleDialog.Controls.Add($cancelStyleButton);$styleDialog.AcceptButton=$applyStyleButton;$styleDialog.CancelButton=$cancelStyleButton
  if($styleDialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK){$fishies[[int]$fishNumberBox.Value-1].Style=[string]$fishStyleBox.SelectedItem;$tank.Invalidate()}
  $styleDialog.Dispose()
})
$script:HotkeyCodes=@{'None'=0;'Insert'=0x2D;'Delete'=0x2E;'End'=0x23;'Page Up'=0x21;'Page Down'=0x22;'Home'=0x24;'Space'=0x20;'Tab'=0x09;'Escape'=0x1B}
foreach($letterCode in 'A'..'Z'){$script:HotkeyCodes[$letterCode]=[int][char]$letterCode}
foreach($digitCode in 0..9){$script:HotkeyCodes[[string]$digitCode]=0x30+$digitCode}
foreach($functionIndex in 1..12){$script:HotkeyCodes["F$functionIndex"]=0x6F+$functionIndex}
$script:HotkeyChoiceNames=@('None','Insert','Delete','End','Page Up','Page Down','Home','Space','Tab','Escape')+@('F1','F2','F3','F4','F5','F6','F7','F8','F9','F10','F11','F12')+@('A'..'Z')+@('0'..'9')
$keyboardShortcutsItem=New-Object System.Windows.Forms.ToolStripMenuItem('Keyboard shortcuts…')
$keyboardShortcutsItem.Add_Click({
  $shortcutDialog=New-Object System.Windows.Forms.Form;$shortcutDialog.Text='Keyboard shortcuts';$shortcutDialog.FormBorderStyle=[System.Windows.Forms.FormBorderStyle]::FixedDialog;$shortcutDialog.StartPosition=[System.Windows.Forms.FormStartPosition]::CenterParent;$shortcutDialog.ClientSize=New-Object System.Drawing.Size(360,244);$shortcutDialog.MaximizeBox=$false;$shortcutDialog.MinimizeBox=$false;$shortcutDialog.ShowInTaskbar=$false
  $shortcutRows=@(@('Toggle Pong','InsertKeyVK'),@('Cursor mischief','EndKeyVK'),@('Kick fish off cursor','DeleteKeyVK'),@('Add fish','PageUpKeyVK'),@('Remove fish','PageDownKeyVK'));$shortcutCombos=@();$rowIndex=0
  foreach($row in $shortcutRows){$label=New-Object System.Windows.Forms.Label;$label.Text=$row[0];$label.Location=New-Object System.Drawing.Point(14,(14+$rowIndex*36));$label.AutoSize=$true;$combo=New-Object System.Windows.Forms.ComboBox;$combo.DropDownStyle=[System.Windows.Forms.ComboBoxStyle]::DropDownList;$combo.Location=New-Object System.Drawing.Point(185,(10+$rowIndex*36));$combo.Width=150;[void]$combo.Items.AddRange([object[]]$script:HotkeyChoiceNames);$currentVK=[int]$state.($row[1]);$currentName=($script:HotkeyCodes.GetEnumerator()|Where-Object{$_.Value -eq $currentVK}|Select-Object -First 1).Key;if(-not $currentName){$currentName='None'};$combo.SelectedItem=$currentName;[void]$shortcutDialog.Controls.Add($label);[void]$shortcutDialog.Controls.Add($combo);$shortcutCombos+=,$combo;$rowIndex++}
  $shortcutHelp=New-Object System.Windows.Forms.Label;$shortcutHelp.Text='Choose any available key; avoid keys you type with.';$shortcutHelp.Location=New-Object System.Drawing.Point(14,194);$shortcutHelp.AutoSize=$true
  $saveShortcuts=New-Object System.Windows.Forms.Button;$saveShortcuts.Text='Apply';$saveShortcuts.DialogResult=[System.Windows.Forms.DialogResult]::OK;$saveShortcuts.Location=New-Object System.Drawing.Point(252,214)
  $cancelShortcuts=New-Object System.Windows.Forms.Button;$cancelShortcuts.Text='Cancel';$cancelShortcuts.DialogResult=[System.Windows.Forms.DialogResult]::Cancel;$cancelShortcuts.Location=New-Object System.Drawing.Point(168,214)
  [void]$shortcutDialog.Controls.Add($shortcutHelp);[void]$shortcutDialog.Controls.Add($saveShortcuts);[void]$shortcutDialog.Controls.Add($cancelShortcuts);$shortcutDialog.AcceptButton=$saveShortcuts;$shortcutDialog.CancelButton=$cancelShortcuts
  if($shortcutDialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK){for($i=0;$i -lt $shortcutRows.Count;$i++){$state.($shortcutRows[$i][1])=[int]$script:HotkeyCodes[[string]$shortcutCombos[$i].SelectedItem]}}
  $shortcutDialog.Dispose()
})
$hatColorDialog=New-Object System.Windows.Forms.ColorDialog
$hatColorDialog.AllowFullOpen=$true;$hatColorDialog.FullOpen=$true;$hatColorDialog.Color=$state.HatColor
$hatStyleMenu=New-Object System.Windows.Forms.ToolStripMenuItem('Hat style')
$hatStyleItems=@()
foreach($style in @('Traffic cone','Top hat','Beanie','Crown','Cowboy hat','Party hat','Dell logo','None')){
  $styleItem=New-Object System.Windows.Forms.ToolStripMenuItem($style)
  $styleItem.Tag=$style;$styleItem.Checked=($style -eq $state.HatStyle)
  [void]$hatStyleMenu.DropDownItems.Add($styleItem);$hatStyleItems+=$styleItem
  $styleItem.Add_Click({
    $state.HatStyle=[string]$this.Tag;$state.HatsEnabled=($state.HatStyle -ne 'None');$state.HatColorCustom=$false
    switch($state.HatStyle){
      'Traffic cone' {$state.HatColor=[System.Drawing.Color]::FromArgb(255,238,112,32);$state.HatAccentColor=[System.Drawing.Color]::White}
      'Top hat' {$state.HatColor=[System.Drawing.Color]::FromArgb(255,22,22,27);$state.HatAccentColor=[System.Drawing.Color]::White}
      'Beanie' {$state.HatColor=[System.Drawing.Color]::FromArgb(255,52,145,126);$state.HatAccentColor=[System.Drawing.Color]::White}
      'Crown' {$state.HatColor=[System.Drawing.Color]::FromArgb(255,232,180,38);$state.HatAccentColor=[System.Drawing.Color]::FromArgb(255,220,46,55)}
      'Cowboy hat' {$state.HatColor=[System.Drawing.Color]::FromArgb(255,156,105,62);$state.HatAccentColor=[System.Drawing.Color]::FromArgb(255,82,46,31)}
      'Party hat' {$state.HatColor=[System.Drawing.Color]::White;$state.HatAccentColor=[System.Drawing.Color]::White}
      'Dell logo' {$state.HatColor=[System.Drawing.Color]::FromArgb(255,0,114,198);$state.HatAccentColor=[System.Drawing.Color]::White}
    }
    $hatColorDialog.Color=$state.HatColor
    foreach($item in $hatStyleItems){$item.Checked=([string]$item.Tag -eq $state.HatStyle)}
    $tank.Invalidate()
  })
}
$hatColorItem=New-Object System.Windows.Forms.ToolStripMenuItem('Hat color…')
$hatColorItem.Add_Click({if($hatColorDialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK){$state.HatColor=$hatColorDialog.Color;$state.HatColorCustom=$true;$tank.Invalidate()}})
[void]$hatStyleMenu.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator))
[void]$hatStyleMenu.DropDownItems.Add($hatColorItem)
$playPongItem=New-Object System.Windows.Forms.ToolStripMenuItem('Toggle cursor pong (Insert; uses 2 fish)')
$updateItem = New-Object System.Windows.Forms.ToolStripMenuItem('Check for updates')
$whatsNewItem=New-Object System.Windows.Forms.ToolStripMenuItem("New stuff in v$($script:FishTankVersion)")
$restoreVersionItem=New-Object System.Windows.Forms.ToolStripMenuItem('Restore an older version…')
$exitItem = New-Object System.Windows.Forms.ToolStripMenuItem('Quit Fish Tank')
[void]$menu.Items.Add($awakeItem); [void]$menu.Items.Add($followItem); [void]$menu.Items.Add($clickItem); [void]$menu.Items.Add($tiltItem); [void]$menu.Items.Add($ambienceItem); [void]$menu.Items.Add($backgroundTransparencyItem); [void]$menu.Items.Add($fishColorItem); [void]$menu.Items.Add($fishStylesItem); [void]$menu.Items.Add($hatStyleMenu); [void]$menu.Items.Add($typingGrabItem); [void]$menu.Items.Add($mischiefItem); [void]$menu.Items.Add($keyboardShortcutsItem); [void]$menu.Items.Add($chanceMenu); [void]$menu.Items.Add($fishCountMenu); [void]$menu.Items.Add($breedItem); [void]$menu.Items.Add($breedIntervalMenu); [void]$menu.Items.Add($playPongItem); [void]$menu.Items.Add($updateItem);[void]$menu.Items.Add($whatsNewItem);[void]$menu.Items.Add($restoreVersionItem)
[void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)); [void]$menu.Items.Add($exitItem)
$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Text = 'Fish Tank settings'
$tray.Icon = [System.Drawing.SystemIcons]::Information
$tray.ContextMenuStrip = $menu
$tray.Visible = $true
$tray.Add_Click({ if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) { $menu.Show([System.Windows.Forms.Cursor]::Position) } })
$showWhatsNew={
  $newsDialog=New-Object System.Windows.Forms.Form;$newsDialog.Text="Fish Tank v$($script:FishTankVersion) - New Stuff";$newsDialog.FormBorderStyle=[System.Windows.Forms.FormBorderStyle]::FixedDialog;$newsDialog.StartPosition=[System.Windows.Forms.FormStartPosition]::CenterParent;$newsDialog.ClientSize=New-Object System.Drawing.Size(450,320);$newsDialog.MaximizeBox=$false;$newsDialog.MinimizeBox=$false;$newsDialog.ShowInTaskbar=$false
  $newsHeading=New-Object System.Windows.Forms.Label;$newsHeading.Text="Added in Fish Tank v$($script:FishTankVersion)";$newsHeading.Font=New-Object System.Drawing.Font('Segoe UI',12,[System.Drawing.FontStyle]::Bold);$newsHeading.Location=New-Object System.Drawing.Point(18,16);$newsHeading.AutoSize=$true
  $newsText=New-Object System.Windows.Forms.TextBox;$newsText.Multiline=$true;$newsText.ReadOnly=$true;$newsText.ScrollBars=[System.Windows.Forms.ScrollBars]::Vertical;$newsText.BorderStyle=[System.Windows.Forms.BorderStyle]::FixedSingle;$newsText.Location=New-Object System.Drawing.Point(18,52);$newsText.Size=New-Object System.Drawing.Size(414,208);$newsText.Text=(($script:FishTankReleaseNotes|ForEach-Object{"- $_"}) -join [Environment]::NewLine)
  $newsClose=New-Object System.Windows.Forms.Button;$newsClose.Text='Close';$newsClose.DialogResult=[System.Windows.Forms.DialogResult]::OK;$newsClose.Location=New-Object System.Drawing.Point(348,274)
  [void]$newsDialog.Controls.Add($newsHeading);[void]$newsDialog.Controls.Add($newsText);[void]$newsDialog.Controls.Add($newsClose);$newsDialog.AcceptButton=$newsClose;[void]$newsDialog.ShowDialog($form);$newsDialog.Dispose()
}
$getVersionHistory={
  $allCommits=@();$client=New-Object System.Net.WebClient;$client.Headers.Add('User-Agent','Fish-Tank-Version-History');$client.Encoding=[System.Text.Encoding]::UTF8
  try{for($page=1;$page -le 50;$page++){$uri="https://api.github.com/repos/technoneverdies741-del/Fish-Tank-Pet/commits?path=FishTank.ps1&per_page=10&page=$page";$json=$client.DownloadString($uri);$pageItems=@($json|ConvertFrom-Json);if($pageItems.Count -eq 0){break};$allCommits+=@($pageItems);if($pageItems.Count -lt 10){break}}}finally{$client.Dispose()}
  if($allCommits.Count -eq 0){throw 'No published Fish Tank source versions were found.'}
  $versions=@();for($i=0;$i -lt $allCommits.Count;$i++){$commit=$allCommits[$i];$version=$allCommits.Count-$i;$message=(([string]$commit.commit.message -split "`r?`n")[0] -replace '\s+',' ').Trim();$versions+=,[pscustomobject]@{Version=$version;Sha=[string]$commit.sha;Message=$message;Label="v$version - $message"}}
  return ,$versions
}
$whatsNewItem.Add_Click({& $showWhatsNew})
$restoreVersionItem.Add_Click({
  $restoreVersionItem.Enabled=$false
  try{
    $history=@(& $getVersionHistory);$older=@($history|Where-Object{$_.Version -lt [int]$script:FishTankVersion})
    if($older.Count -eq 0){throw 'No earlier versions are available yet.'}
    $restoreDialog=New-Object System.Windows.Forms.Form;$restoreDialog.Text='Restore an older version';$restoreDialog.FormBorderStyle=[System.Windows.Forms.FormBorderStyle]::FixedDialog;$restoreDialog.StartPosition=[System.Windows.Forms.FormStartPosition]::CenterParent;$restoreDialog.ClientSize=New-Object System.Drawing.Size(470,240);$restoreDialog.MaximizeBox=$false;$restoreDialog.MinimizeBox=$false;$restoreDialog.ShowInTaskbar=$false
    $restoreLabel=New-Object System.Windows.Forms.Label;$restoreLabel.Text='Choose a saved source version (v1 is the oldest):';$restoreLabel.Location=New-Object System.Drawing.Point(14,14);$restoreLabel.AutoSize=$true
    $restoreCombo=New-Object System.Windows.Forms.ComboBox;$restoreCombo.DropDownStyle=[System.Windows.Forms.ComboBoxStyle]::DropDownList;$restoreCombo.Location=New-Object System.Drawing.Point(14,40);$restoreCombo.Size=New-Object System.Drawing.Size(442,26);foreach($entry in $older){[void]$restoreCombo.Items.Add($entry.Label)};$restoreCombo.SelectedIndex=0
    $restoreDetails=New-Object System.Windows.Forms.TextBox;$restoreDetails.Multiline=$true;$restoreDetails.ReadOnly=$true;$restoreDetails.Location=New-Object System.Drawing.Point(14,76);$restoreDetails.Size=New-Object System.Drawing.Size(442,100);$restoreDetails.Text=$older[0].Message
    $restoreCombo.Add_SelectedIndexChanged({if($restoreCombo.SelectedIndex -ge 0){$restoreDetails.Text=$older[$restoreCombo.SelectedIndex].Message}})
    $restoreButton=New-Object System.Windows.Forms.Button;$restoreButton.Text='Restore';$restoreButton.DialogResult=[System.Windows.Forms.DialogResult]::OK;$restoreButton.Location=New-Object System.Drawing.Point(360,194)
    $restoreCancel=New-Object System.Windows.Forms.Button;$restoreCancel.Text='Cancel';$restoreCancel.DialogResult=[System.Windows.Forms.DialogResult]::Cancel;$restoreCancel.Location=New-Object System.Drawing.Point(274,194)
    [void]$restoreDialog.Controls.Add($restoreLabel);[void]$restoreDialog.Controls.Add($restoreCombo);[void]$restoreDialog.Controls.Add($restoreDetails);[void]$restoreDialog.Controls.Add($restoreButton);[void]$restoreDialog.Controls.Add($restoreCancel);$restoreDialog.AcceptButton=$restoreButton;$restoreDialog.CancelButton=$restoreCancel
    $dialogResult=$restoreDialog.ShowDialog($form);$selectedVersion=if($restoreCombo.SelectedIndex -ge 0){$older[$restoreCombo.SelectedIndex]}else{$null};$restoreDialog.Dispose()
    if($dialogResult -eq [System.Windows.Forms.DialogResult]::OK -and $selectedVersion){
      $installedPath=Join-Path $env:LOCALAPPDATA 'FishTankPet\FishTank.ps1';$client=New-Object System.Net.WebClient;$client.Headers.Add('User-Agent','Fish-Tank-Restore');$client.Encoding=[System.Text.Encoding]::UTF8
      try{$download=$client.DownloadString("https://raw.githubusercontent.com/technoneverdies741-del/Fish-Tank-Pet/$($selectedVersion.Sha)/FishTank.ps1")}finally{$client.Dispose()}
      if([string]::IsNullOrWhiteSpace($download) -or $download.Length -lt 1000){throw 'The selected version download was empty or incomplete.'}
      $tempPath=$installedPath+'.restore-'+[guid]::NewGuid().ToString('N')+'.ps1';[System.IO.File]::WriteAllText($tempPath,$download,(New-Object System.Text.UTF8Encoding($false)));$parseTokens=$null;$parseErrors=$null;[System.Management.Automation.Language.Parser]::ParseFile($tempPath,[ref]$parseTokens,[ref]$parseErrors)|Out-Null
      if($parseErrors.Count -gt 0){Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue;throw 'The selected version failed its PowerShell syntax check.'}
      $backupPath=$installedPath+".pre-restore-v$($script:FishTankVersion).bak";Copy-Item -LiteralPath $installedPath -Destination $backupPath -Force
      Move-Item -LiteralPath $tempPath -Destination $installedPath -Force
      $launch=New-Object System.Diagnostics.ProcessStartInfo;$launch.FileName=(Join-Path $PSHOME 'powershell.exe');$launch.Arguments='-NoProfile -ExecutionPolicy Bypass -File "'+$installedPath+'"';$launch.UseShellExecute=$false;[System.Diagnostics.Process]::Start($launch)|Out-Null;$form.Close()
    }
  }catch{[void][System.Windows.Forms.MessageBox]::Show("Fish Tank couldn't load or restore versions:`r`n$($_.Exception.Message)",'Fish Tank versions',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)}
  finally{$restoreVersionItem.Enabled=$true}
})
$updateItem.Add_Click({
  $updateItem.Enabled=$false
  $updateItem.Text='Checking for updates…'
  try {
    $installedPath=Join-Path $env:LOCALAPPDATA 'FishTankPet\FishTank.ps1'
    if(-not (Test-Path -LiteralPath $installedPath)){$installedPath=$PSCommandPath}
    $latestUri='https://raw.githubusercontent.com/technoneverdies741-del/Fish-Tank-Pet/main/FishTank.ps1'
    $client=New-Object System.Net.WebClient
    $client.Headers.Add('User-Agent','Fish-Tank-Updater')
    $downloadBytes=$client.DownloadData($latestUri)
$download=[System.Text.Encoding]::UTF8.GetString($downloadBytes).TrimStart([char]0xFEFF)
    if([string]::IsNullOrWhiteSpace($download) -or $download.Length -lt 1000){throw 'The update download was empty or incomplete.'}
    $tempPath=$installedPath+'.update-'+[guid]::NewGuid().ToString('N')+'.ps1'
    [System.IO.File]::WriteAllText($tempPath,$download,(New-Object System.Text.UTF8Encoding($false)))
    $parseTokens=$null;$parseErrors=$null
    [System.Management.Automation.Language.Parser]::ParseFile($tempPath,[ref]$parseTokens,[ref]$parseErrors)|Out-Null
    if($parseErrors.Count -gt 0){Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue;throw 'The downloaded update did not pass the PowerShell syntax check.'}
    $newVersionMatch=[regex]::Match($download,'(?m)^\s*\$script:FishTankVersion\s*=\s*''([^'']+)''')
    if(-not $newVersionMatch.Success){Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue;throw 'The downloaded update has no version number.'}
    $newVersion=$newVersionMatch.Groups[1].Value
        $sha=[System.Security.Cryptography.SHA256]::Create()
    try {
      $currentHash=[Convert]::ToBase64String($sha.ComputeHash([System.IO.File]::ReadAllBytes($installedPath)))
      $latestHash=[Convert]::ToBase64String($sha.ComputeHash([System.IO.File]::ReadAllBytes($tempPath)))
    } finally { $sha.Dispose() }
    if($currentHash -eq $latestHash){Remove-Item -LiteralPath $tempPath -Force;[void][System.Windows.Forms.MessageBox]::Show('Fish Tank is already up to date.','Fish Tank updates',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information)}
    else {
      $backupPath=$installedPath+'.previous'
      Copy-Item -LiteralPath $installedPath -Destination $backupPath -Force
      try { Move-Item -LiteralPath $tempPath -Destination $installedPath -Force }
      catch { Copy-Item -LiteralPath $backupPath -Destination $installedPath -Force;throw }
      New-Item -ItemType Directory -Path $script:FishTankInstallFolder -Force | Out-Null
      [System.IO.File]::WriteAllText($script:PendingWhatsNewPath,$newVersion,(New-Object System.Text.UTF8Encoding($false)))
      $launch=New-Object System.Diagnostics.ProcessStartInfo
      $launch.FileName=(Join-Path $PSHOME 'powershell.exe')
      $launch.Arguments='-NoProfile -ExecutionPolicy Bypass -File "'+$installedPath+'"'
      $launch.UseShellExecute=$false
      [System.Diagnostics.Process]::Start($launch)|Out-Null
      $form.Close()
    }
  } catch {
    [void][System.Windows.Forms.MessageBox]::Show("Fish Tank couldn't check for or install an update:`r`n$($_.Exception.Message)",'Fish Tank updates',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)
  } finally {
    $updateItem.Enabled=$true
    $updateItem.Text='Check for updates'
  }
})
$exitItem.Add_Click({ $form.Close() })
$applyKeepAwake = { if($state.KeepAwake){[FishTankNative]::SetThreadExecutionState([uint32]2147483651) | Out-Null;$state.KeepAwakeRefresh=[datetime]::UtcNow}else{[FishTankNative]::SetThreadExecutionState([uint32]2147483648) | Out-Null;$state.KeepAwakeRefresh=[datetime]::MinValue} }
$awakeItem.Add_Click({$awakeItem.Checked=-not $awakeItem.Checked;$state.KeepAwake=$awakeItem.Checked;& $applyKeepAwake})
$tiltItem.Add_Click({ $state.Tilt = $tiltItem.Checked = -not $tiltItem.Checked })
$ambienceItem.Add_Click({ $ambienceItem.Checked = -not $ambienceItem.Checked; $tank.Invalidate() })
$typingGrabItem.Add_Click({
  $typingGrabItem.Checked=-not $typingGrabItem.Checked
  $state.TypingGrabEnabled=$typingGrabItem.Checked
  if(-not $state.TypingGrabEnabled -and $state.TypingSteal){
    $state.Stealing=$false;$state.StealPhase='';$state.TypingSteal=$false;$state.Physics=$false
    if($state.TypingForcedFollow){$state.TypingForcedFollow=$false;$followItem.PerformClick()}
  }
})
$playPongItem.Add_Click({
  # The tray control and Insert key both toggle the cursor-pong game.
  if($state.TypingSteal){$state.TypingSteal=$false;if($state.TypingForcedFollow){$state.TypingForcedFollow=$false;$followItem.PerformClick()}}
  & $togglePong
})
$mischiefItem.Add_Click({$mischiefItem.Checked=-not $mischiefItem.Checked;$state.StealEnabled=$mischiefItem.Checked})
$clickItem.Add_Click({
  $clickItem.Checked = -not $clickItem.Checked
  $state.ClickThrough = $clickItem.Checked
  $style=[FishTankNative]::GetStyle($form.Handle,-20)
  $style=$style -band (-bnot (0x20 -bor 0x8000000))
  if($state.ClickThrough){$style=$style -bor 0x20}
  if($state.ClickThrough){$style=$style -bor 0x8000000}
  [FishTankNative]::SetStyle($form.Handle,-20,$style)
})

$followItem.Add_Click({
  $state.Follow = -not $state.Follow
  $followItem.Checked = $state.Follow
  if ($state.Follow) {
    $state.WindowedBounds=$form.Bounds
    $screen = [System.Windows.Forms.Screen]::FromPoint([System.Windows.Forms.Cursor]::Position).Bounds
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.Bounds = $screen
    $form.TopMost = $true
    # In cursor mode let the fish receive grabs; transparent canvas pixels remain transparent.
    $clickItem.Checked = $false
    $state.ClickThrough = $false
    $tank.Location = [System.Drawing.Point]::Empty
  } else {
    $state.ClickThrough = $clickItem.Checked
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
    $form.TopMost = $true
    $form.StartPosition = 'Manual'
    if(-not $state.WindowedBounds.IsEmpty){$form.Bounds=$state.WindowedBounds}else{$form.Bounds=New-Object System.Drawing.Rectangle(100,100,620,420)}
  }
  $form.BeginInvoke([Action]{
    $style = [FishTankNative]::GetStyle($form.Handle, -20)
    $style = $style -band (-bnot (0x20 -bor 0x8000000))
    if($state.ClickThrough){$style=$style -bor 0x20}
    if($state.ClickThrough){$style=$style -bor 0x8000000}
    [FishTankNative]::SetStyle($form.Handle,-20,$style)
    if ($state.Follow) { [FishTankNative]::SetWindowPos($form.Handle,[IntPtr]::new(-1),$form.Left,$form.Top,$form.Width,$form.Height,0x10 -bor 0x40) | Out-Null }
    $tank.Invalidate()
  }) | Out-Null
})

$tank.Add_Paint({
  param($sender,$e)
  $g=$e.Graphics;$g.Clear($form.TransparencyKey);$g.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  & $script:refreshDrawingResources
  $drawResources=$script:drawResources
  $w=$sender.ClientSize.Width; $h=$sender.ClientSize.Height
  # Draw every selected fish with contrast sampled from the desktop behind it.
  if ($ambienceItem.Checked) {
    # Fine bubbles and soft glints drift gently through the transparent water.
    $p=$drawResources.BubblePen
    for($i=0;$i -lt 7;$i++) {
      $bx=[single](($i*137 + $state.Phase*(9+$i*2)) % [Math]::Max(1,$w))
      $by=[single]($h - (($state.Phase*(12+$i)+$i*53) % [Math]::Max(1,$h)))
      $r=3+($i%3)
      $g.DrawEllipse($p,$bx,$by,$r,$r)
    }
    $glint=$drawResources.GlintBrush
    for($i=0;$i -lt 4;$i++) { $x=[single](($i*179+$state.Phase*4)%[Math]::Max(1,$w)); $y=[single]($h-14-(($i*61)%[Math]::Max(1,$h-20))); $g.FillEllipse($glint,$x,$y,2,2) }
  }
  $fishFont=$drawResources.FishFont;$fishBrush=$drawResources.FishBrush;$hatBrush=$drawResources.HatBrush;$hatAccentBrush=$drawResources.HatAccentBrush;$hatOutlinePen=$drawResources.HatOutlinePen
  $partyBrushes=$drawResources.PartyBrushes;$angerFont=$drawResources.AngerFont;$angerBrush=$drawResources.AngerBrush;$blubFont=$drawResources.BlubFont;$blubBrush=$drawResources.BlubBrush
  for($fishIndex=0;$fishIndex -lt $state.FishCount;$fishIndex++){
    if($state.FishHidden){break}
    $fish=$fishies[$fishIndex];$fishInk=[System.Drawing.Color]::White

    $fishGlyphSet=$drawResources.FishGlyphs[$fish.Style];if(-not $fishGlyphSet){$fishGlyphSet=$drawResources.FishGlyphs['Classic']};$fishGlyph=$fishGlyphSet.Left;if($fish.Direction -gt 0){$fishGlyph=$fishGlyphSet.Right}
    $cx=[single]($fish.X+43);$cy=[single]($fish.Y+14)
    $drawX=[single]($fish.X+18);$drawY=[single]($fish.Y+7)
    $g.TranslateTransform($cx,$cy)
    $renderAngle=$fish.Angle; if($state.Tilt){$renderAngle=$fish.LookAngle}elseif($state.Follow -and -not ($fishIndex -eq 0 -and $state.PinnedCorner)){$renderAngle=0.0}; while($renderAngle -gt 180){$renderAngle-=360};while($renderAngle -lt -180){$renderAngle+=360}; if($renderAngle -gt 90){$renderAngle=180-$renderAngle};if($renderAngle -lt -90){$renderAngle=-180-$renderAngle}; $g.RotateTransform([single]$renderAngle)
    $g.TranslateTransform(-$cx,-$cy);$g.DrawImage($fishGlyph,$drawX,$drawY);$g.ResetTransform()
    if($state.HatsEnabled){
      $g.TranslateTransform($cx,$cy)
      $renderAngle=$fish.Angle; if($state.Tilt){$renderAngle=$fish.LookAngle}elseif($state.Follow -and -not ($fishIndex -eq 0 -and $state.PinnedCorner)){$renderAngle=0.0}; while($renderAngle -gt 180){$renderAngle-=360};while($renderAngle -lt -180){$renderAngle+=360}; if($renderAngle -gt 90){$renderAngle=180-$renderAngle};if($renderAngle -lt -90){$renderAngle=-180-$renderAngle}; $g.RotateTransform([single]$renderAngle)
      switch($state.HatStyle){
        'Traffic cone' {
          $g.FillPolygon($hatBrush,[System.Drawing.PointF[]]@([System.Drawing.PointF]::new(-8,-8),[System.Drawing.PointF]::new(0,-27),[System.Drawing.PointF]::new(8,-8)))
          $g.DrawPolygon($hatOutlinePen,[System.Drawing.PointF[]]@([System.Drawing.PointF]::new(-8,-8),[System.Drawing.PointF]::new(0,-27),[System.Drawing.PointF]::new(8,-8)))
          $g.FillPolygon($hatAccentBrush,[System.Drawing.PointF[]]@([System.Drawing.PointF]::new(-4,-16),[System.Drawing.PointF]::new(4,-16),[System.Drawing.PointF]::new(5,-13),[System.Drawing.PointF]::new(-5,-13)))
          $g.FillRectangle($hatBrush,-10,-9,20,3)
          $g.DrawRectangle($hatOutlinePen,-10,-9,20,3)
        }
        'Top hat' {
          $g.FillRectangle($hatBrush,-7,-23,14,14);$g.DrawRectangle($hatOutlinePen,-7,-23,14,14);$g.FillRectangle($hatBrush,-11,-10,22,3);$g.DrawRectangle($hatOutlinePen,-11,-10,22,3);$g.FillRectangle($hatAccentBrush,-7,-14,14,3)
        }
        'Beanie' {
          $g.FillEllipse($hatBrush,-9,-22,18,15);$g.DrawEllipse($hatOutlinePen,-9,-22,18,15);$g.FillRectangle($hatBrush,-9,-12,18,4);$g.DrawRectangle($hatOutlinePen,-9,-12,18,4);$g.FillEllipse($hatAccentBrush,-2,-25,4,4);$g.DrawEllipse($hatOutlinePen,-2,-25,4,4)
        }
        'Crown' {
          $g.FillPolygon($hatBrush,[System.Drawing.PointF[]]@([System.Drawing.PointF]::new(-10,-9),[System.Drawing.PointF]::new(-8,-23),[System.Drawing.PointF]::new(-3,-17),[System.Drawing.PointF]::new(0,-27),[System.Drawing.PointF]::new(3,-17),[System.Drawing.PointF]::new(8,-23),[System.Drawing.PointF]::new(10,-9)))
          $g.DrawPolygon($hatOutlinePen,[System.Drawing.PointF[]]@([System.Drawing.PointF]::new(-10,-9),[System.Drawing.PointF]::new(-8,-23),[System.Drawing.PointF]::new(-3,-17),[System.Drawing.PointF]::new(0,-27),[System.Drawing.PointF]::new(3,-17),[System.Drawing.PointF]::new(8,-23),[System.Drawing.PointF]::new(10,-9)))
          $g.FillRectangle($hatBrush,-10,-10,20,3);$g.DrawRectangle($hatOutlinePen,-10,-10,20,3);$g.FillEllipse($hatAccentBrush,-2,-15,4,4);$g.DrawEllipse($hatOutlinePen,-2,-15,4,4)
        }
        'Cowboy hat' {
          $g.FillEllipse($hatBrush,-15,-13,30,7);$g.DrawEllipse($hatOutlinePen,-15,-13,30,7);$g.FillEllipse($hatBrush,-8,-23,16,15);$g.DrawEllipse($hatOutlinePen,-8,-23,16,15);$g.FillRectangle($hatAccentBrush,-7,-13,14,2)
        }
        'Party hat' {
          $g.FillPolygon($hatBrush,[System.Drawing.PointF[]]@([System.Drawing.PointF]::new(-9,-9),[System.Drawing.PointF]::new(0,-28),[System.Drawing.PointF]::new(9,-9)))
          $g.DrawPolygon($hatOutlinePen,[System.Drawing.PointF[]]@([System.Drawing.PointF]::new(-9,-9),[System.Drawing.PointF]::new(0,-28),[System.Drawing.PointF]::new(9,-9)))
          if(-not $state.HatColorCustom){
            $g.FillPolygon($partyBrushes[0],[System.Drawing.PointF[]]@([System.Drawing.PointF]::new(-2,-25),[System.Drawing.PointF]::new(2,-25),[System.Drawing.PointF]::new(3,-23),[System.Drawing.PointF]::new(-3,-23)))
            $g.FillPolygon($partyBrushes[1],[System.Drawing.PointF[]]@([System.Drawing.PointF]::new(-3,-22),[System.Drawing.PointF]::new(3,-22),[System.Drawing.PointF]::new(4,-20),[System.Drawing.PointF]::new(-4,-20)))
            $g.FillPolygon($partyBrushes[2],[System.Drawing.PointF[]]@([System.Drawing.PointF]::new(-4,-19),[System.Drawing.PointF]::new(4,-19),[System.Drawing.PointF]::new(5,-17),[System.Drawing.PointF]::new(-5,-17)))
            $g.FillPolygon($partyBrushes[3],[System.Drawing.PointF[]]@([System.Drawing.PointF]::new(-5,-16),[System.Drawing.PointF]::new(5,-16),[System.Drawing.PointF]::new(6,-14),[System.Drawing.PointF]::new(-6,-14)))
            $g.FillPolygon($partyBrushes[4],[System.Drawing.PointF[]]@([System.Drawing.PointF]::new(-6,-13),[System.Drawing.PointF]::new(6,-13),[System.Drawing.PointF]::new(8,-11),[System.Drawing.PointF]::new(-8,-11)))
            $g.FillPolygon($partyBrushes[5],[System.Drawing.PointF[]]@([System.Drawing.PointF]::new(-8,-10),[System.Drawing.PointF]::new(8,-10),[System.Drawing.PointF]::new(9,-8),[System.Drawing.PointF]::new(-9,-8)))
          }else{$g.FillPolygon($hatAccentBrush,[System.Drawing.PointF[]]@([System.Drawing.PointF]::new(-2,-19),[System.Drawing.PointF]::new(2,-19),[System.Drawing.PointF]::new(3,-15),[System.Drawing.PointF]::new(-3,-15)))}
          $g.FillEllipse($hatAccentBrush,-2,-30,4,4);$g.DrawEllipse($hatOutlinePen,-2,-30,4,4);$g.FillRectangle($hatBrush,-10,-9,20,3);$g.DrawRectangle($hatOutlinePen,-10,-9,20,3)
        }
        'Dell logo' {
          & $script:refreshDellLogo
          $g.DrawImage($script:dellLogoBitmap,-11,-30,22,22)
          $g.DrawEllipse($hatOutlinePen,-11,-30,22,22)
        }
      }
      $g.ResetTransform()
    }
    if([datetime]::UtcNow -lt $fish.AngryUntil){& $drawOutlinedText $g '!!' $angerFont $angerBrush ([single]($fish.X+54)) ([single]($fish.Y-5)) ([single]1.4)}
    if([datetime]::UtcNow -lt $fish.BlubUntil){& $drawOutlinedText $g 'blub blub' $blubFont $blubBrush ([single]($fish.X+20)) ([single]([Math]::Max(2,$fish.Y-19))) ([single]1.2)}
  }
  if($state.PongActive){$scoreFont=$drawResources.ScoreFont;$scoreBrush=$drawResources.ScoreBrush;$scoreText="PONG  $($state.PongScoreLeft) : $($state.PongScoreRight)";$scoreSize=$g.MeasureString($scoreText,$scoreFont);& $drawOutlinedText $g $scoreText $scoreFont $scoreBrush ([single](($w-$scoreSize.Width)/2)) ([single]($h-$scoreSize.Height-5)) ([single]1.5)}
})

# The transparent canvas lets clicks pass through; the fish glyph itself remains draggable.
$tank.Add_MouseDown({
  param($sender,$e)
  $buddyHitX=$e.X-($buddy.X+43);$buddyHitY=$e.Y-($buddy.Y+14)
  $fishHitX=$e.X-($state.X+43);$fishHitY=$e.Y-($state.Y+14)
  if($e.Button -eq [System.Windows.Forms.MouseButtons]::Left -and -not $state.ClickThrough -and -not $state.FishHidden){
    $hitIndex=-1
    for($i=$state.FishCount-1;$i -ge 0;$i--){$f=$fishies[$i];$hx=$e.X-($f.X+43);$hy=$e.Y-($f.Y+14);if(($hx*$hx+$hy*$hy) -le 3600){$hitIndex=$i;break}}
    if($hitIndex -ge 0 -and (-not $state.Stealing -or $state.StealPhase -ne 'Carrying')){
      $state.DraggingFishIndex=$hitIndex;$picked=$fishies[$hitIndex]
      if($hitIndex -gt 0){$picked.Dragging=$true;$picked.DragOffsetX=$e.X-$picked.X;$picked.DragOffsetY=$e.Y-$picked.Y;$picked.LastDragX=$e.X;$picked.LastDragY=$e.Y;$sender.Capture=$true}
      else {
      $state.PinnedCorner=$false
      $state.IsDragging=$true; $state.DragOffsetX=$e.X-$state.X; $state.DragOffsetY=$e.Y-$state.Y
      $state.LastDragX=$e.X; $state.LastDragY=$e.Y; $sender.Capture=$true
      $state.Physics=$false;$state.VelX=0;$state.VelY=0;$state.DragAt=[datetime]::UtcNow
      $state.DragAxis='';$state.DragDir=0;$state.DragLeg=0;$state.DragPath=0;$state.DragReversals=0;$state.DragStarted=[datetime]::UtcNow
      $state.DragMin=0;$state.DragMax=0
      }
    }
  }
})
$tank.Add_MouseMove({
  param($sender,$e)
  if($state.DraggingFishIndex -gt 0 -and $fishies[$state.DraggingFishIndex].Dragging){
    $dragFish=$fishies[$state.DraggingFishIndex];$mx=$e.X-$dragFish.LastDragX;$my=$e.Y-$dragFish.LastDragY
    $dragFish.X=$e.X-$dragFish.DragOffsetX;$dragFish.Y=$e.Y-$dragFish.DragOffsetY
    if([Math]::Abs($mx)+[Math]::Abs($my) -gt 1){
      $dragFish.Direction=if($mx -lt 0){-1}else{1}
      $dragFish.Heading=[Math]::Atan2($my,$mx)
      $dragFish.Angle=$dragFish.Heading
      if($dragFish.Direction -lt 0){$dragFish.Angle-=180}
    }
    $dragFish.LastDragX=$e.X;$dragFish.LastDragY=$e.Y;$sender.Invalidate()
  } elseif($state.IsDragging){
    $mx=$e.X-$state.LastDragX; $my=$e.Y-$state.LastDragY
    $now=[datetime]::UtcNow;$dragDt=[Math]::Max(0.001,($now-$state.DragAt).TotalSeconds)
    $state.X=$e.X-$state.DragOffsetX; $state.Y=$e.Y-$state.DragOffsetY
    if([Math]::Abs($mx)+[Math]::Abs($my) -gt 1){
      $state.VelX=0.55*$state.VelX+0.45*[Math]::Max(-1800,[Math]::Min(1800,$mx/$dragDt))
      $state.VelY=0.55*$state.VelY+0.45*[Math]::Max(-1800,[Math]::Min(1800,$my/$dragDt))
      $state.Direction=if($mx -lt 0){-1}else{1}
      $state.Angle=[Math]::Atan2($my,$mx)*180/[Math]::PI
      if($state.Direction -lt 0){$state.Angle-=180}
      if($state.Follow -and ([Math]::Abs($mx)+[Math]::Abs($my) -ge 3)){
        $now=[datetime]::UtcNow;$axis=if([Math]::Abs($mx) -ge [Math]::Abs($my)){'X'}else{'Y'};$step=if($axis -eq 'X'){$mx}else{$my}
        $dir=[Math]::Sign($step);$distance=[Math]::Abs($step);$v=if($axis -eq 'X'){$e.X}else{$e.Y}
        if($state.DragAxis -ne $axis -or ($now-$state.DragStarted).TotalMilliseconds -gt 800){
          $state.DragAxis=$axis;$state.DragDir=$dir;$state.DragLeg=$distance;$state.DragPath=$distance;$state.DragMin=$v;$state.DragMax=$v;$state.DragReversals=0;$state.DragStarted=$now
        }else{
          $state.DragPath+=$distance;$state.DragMin=[Math]::Min($state.DragMin,$v);$state.DragMax=[Math]::Max($state.DragMax,$v)
          if($dir -ne $state.DragDir -and $state.DragLeg -ge 16){
            $state.DragReversals++;$state.DragDir=$dir;$state.DragLeg=$distance
            if($state.DragReversals -ge 2 -and $state.DragPath -ge 90 -and ($state.DragMax-$state.DragMin) -ge 38){$state.AngryUntil=$now.AddSeconds(5);$state.DragReversals=0;$state.DragPath=0}
          }elseif($dir -eq $state.DragDir){$state.DragLeg+=$distance}
        }
      }
    }
    $state.DragAt=$now;$state.LastDragX=$e.X; $state.LastDragY=$e.Y; $sender.Invalidate()
  }
})
$tank.Add_MouseUp({
  param($sender,$e)
  if($e.Button -eq [System.Windows.Forms.MouseButtons]::Left){
    if($state.DraggingFishIndex -gt 0){$dragFish=$fishies[$state.DraggingFishIndex];$dragFish.Dragging=$false;& $pickFishTarget $dragFish;$state.DraggingFishIndex=-1}
    elseif($state.IsDragging){$state.DraggingFishIndex=-1
      $state.IsDragging=$false
      if($state.Follow){
        $w=$tank.ClientSize.Width;$h=$tank.ClientSize.Height;$cx=$state.X+43;$cy=$state.Y+14
        $left=$cx -lt 60;$right=$cx -gt ($w-60);$top=$cy -lt 60;$bottom=$cy -gt ($h-60)
        if(($left -or $right) -and ($top -or $bottom)){
          $state.PinnedCorner=$true
          $state.X=if($left){12}else{$w-105};$state.Y=if($top){12}else{$h-48}
        }
      }
      if($state.PinnedCorner){$state.Physics=$false;$state.VelX=0;$state.VelY=0}
      elseif([Math]::Sqrt($state.VelX*$state.VelX+$state.VelY*$state.VelY) -gt 65){$state.Physics=$true}
      elseif(-not $state.Follow){& $pickRoamTarget}
    }
    $sender.Capture=$false
  }
})

$timer.Add_Tick({
  & $updateBackgroundOverlay
  $now=[datetime]::UtcNow;$stealJustFinished=$false
  if(($now-$state.LastRocketLeagueCheck).TotalSeconds -ge 1){
    $state.LastRocketLeagueCheck=$now;$rocketLeagueOpen=[bool](Get-Process -Name 'RocketLeague' -ErrorAction SilentlyContinue | Select-Object -First 1)
    if($rocketLeagueOpen -and -not $state.RocketLeaguePaused){$state.RocketLeaguePaused=$true;$state.RocketLeaguePauseStarted=$now}
    elseif(-not $rocketLeagueOpen -and $state.RocketLeaguePaused){
      $pausedFor=$now-$state.RocketLeaguePauseStarted
      foreach($pausedFish in $fishies){$pausedFish.NextBlub=$pausedFish.NextBlub.Add($pausedFor);if($pausedFish.BlubUntil -gt $state.RocketLeaguePauseStarted){$pausedFish.BlubUntil=$pausedFish.BlubUntil.Add($pausedFor)}}
      if($state.AutoBreedEnabled){$state.NextBreed=$state.NextBreed.Add($pausedFor)}
      $state.RocketLeaguePaused=$false;$state.RocketLeaguePauseStarted=[datetime]::MinValue;$state.RocketLeagueOverrideUntil=[datetime]::MinValue;$state.LastCursor=[System.Windows.Forms.Cursor]::Position;$state.CursorStillSince=$now;$tank.Invalidate()
    }
  }
  if($state.RocketLeaguePaused -and $now -ge $state.RocketLeagueOverrideUntil){
    # Even while the game suppresses the fish, keep watching the tank window for a real shake.
    $loc=$form.Location;$dx=$loc.X-$state.LastLoc.X;$dy=$loc.Y-$state.LastLoc.Y
    $leftHeld=(([System.Windows.Forms.Control]::MouseButtons -band [System.Windows.Forms.MouseButtons]::Left) -ne 0)
    $mouseInTank=$form.Bounds.Contains([System.Windows.Forms.Control]::MousePosition)
    $winDt=[Math]::Max(0.005,($now-$state.WindowAt).TotalSeconds)
    if(([Math]::Abs($dx)+[Math]::Abs($dy)) -gt 0 -and $leftHeld -and $mouseInTank){$state.WindowDragging=$true;$state.WindowPhysics=$false;$state.WindowVelX=[Math]::Max(-2200,[Math]::Min(2200,$dx/$winDt));$state.WindowVelY=[Math]::Max(-2200,[Math]::Min(2200,$dy/$winDt))}
    if($state.WindowDragging -and -not $leftHeld){$state.WindowDragging=$false;$state.WindowPhysics=([Math]::Sqrt($state.WindowVelX*$state.WindowVelX+$state.WindowVelY*$state.WindowVelY) -gt 90)}
    if(([Math]::Abs($dx)+[Math]::Abs($dy)) -ge 2 -and $leftHeld -and $mouseInTank){
      $axis=if([Math]::Abs($dx) -ge [Math]::Abs($dy)){'X'}else{'Y'};$step=if($axis -eq 'X'){$dx}else{$dy};$dir=[Math]::Sign($step);$distance=[Math]::Abs($step);$v=if($axis -eq 'X'){$loc.X}else{$loc.Y}
      if($state.ShakeAxis -ne $axis -or ($now-$state.ShakeStarted).TotalMilliseconds -gt 900){$state.ShakeAxis=$axis;$state.ShakeDir=$dir;$state.ShakeLeg=$distance;$state.ShakePath=$distance;$state.ShakeMin=$v;$state.ShakeMax=$v;$state.ShakeReversals=0;$state.ShakeStarted=$now}
      else{$state.ShakePath+=$distance;$state.ShakeMin=[Math]::Min($state.ShakeMin,$v);$state.ShakeMax=[Math]::Max($state.ShakeMax,$v);if($dir -ne $state.ShakeDir -and $state.ShakeLeg -ge 14){$state.ShakeReversals++;$state.ShakeDir=$dir;$state.ShakeLeg=$distance;if($state.ShakeReversals -ge 2 -and $state.ShakePath -ge 60 -and ($state.ShakeMax-$state.ShakeMin) -ge 24){$state.AngryUntil=$now.AddSeconds(5);$state.RocketLeagueOverrideUntil=$now.AddSeconds(5);$state.ShakeReversals=0;$state.ShakePath=0;$tank.Invalidate()}}elseif($dir -eq $state.ShakeDir){$state.ShakeLeg+=$distance}}
    }
    $state.LastLoc=$loc;$state.WindowAt=$now
    if($now -ge $state.RocketLeagueOverrideUntil){$tank.Invalidate();return}
  }
  if($state.AutoBreedEnabled -and -not $state.PongActive -and $state.FishCount -lt 1000 -and $now -ge $state.NextBreed){
    $newFish=$fishies[$state.FishCount];$parent=$fishies[$rng.Next($state.FishCount)]
    $newFish.X=[Math]::Max(8,[Math]::Min($tank.ClientSize.Width-92,$parent.X+($rng.NextDouble()-0.5)*28))
    $newFish.Y=[Math]::Max(30,[Math]::Min($tank.ClientSize.Height-60,$parent.Y+($rng.NextDouble()-0.5)*28))
    $newFish.Heading=$parent.Heading;$newFish.Direction=$parent.Direction;$newFish.Angle=$parent.Angle;$newFish.TargetX=0;$newFish.TargetY=0;$newFish.Dragging=$false;$newFish.BlubUntil=[datetime]::MinValue;$newFish.AngryUntil=[datetime]::MinValue;$newFish.NextBlub=$now.AddSeconds($rng.Next(8,19))
    & $setFishCount ($state.FishCount+1)
    if($state.FishCount -ge 1000){$state.AutoBreedEnabled=$false;$breedItem.Checked=$false;$state.NextBreed=[datetime]::MaxValue}
    else{$state.NextBreed=$now.AddSeconds($state.BreedInterval)}
  }
  if($state.KeepAwake -and ($now-$state.KeepAwakeRefresh).TotalSeconds -ge 30){& $applyKeepAwake}
  if(($now-$state.LastFocusCheck).TotalMilliseconds -ge 200){
    $state.TextFocused=$false
    try {
      $focused=[System.Windows.Automation.AutomationElement]::FocusedElement
      if($focused){$focusedType=$focused.Current.ControlType;$state.TextFocused=($focusedType -eq [System.Windows.Automation.ControlType]::Edit -or $focusedType -eq [System.Windows.Automation.ControlType]::Document)}
    } catch { $state.TextFocused=$false }
    $state.LastFocusCheck=$now
  }
  $winKeyDown=(([FishTankNative]::GetAsyncKeyState(0x5B) -band 0x8000) -ne 0 -or ([FishTankNative]::GetAsyncKeyState(0x5C) -band 0x8000) -ne 0)
  $altKeyDown=(([FishTankNative]::GetAsyncKeyState(0x12) -band 0x8000) -ne 0 -or ([FishTankNative]::GetAsyncKeyState(0xA4) -band 0x8000) -ne 0 -or ([FishTankNative]::GetAsyncKeyState(0xA5) -band 0x8000) -ne 0)
  $systemShortcutDown=$winKeyDown -or $altKeyDown
  if($systemShortcutDown){
    $state.TypingSuppressedUntil=$now.AddMilliseconds(650)
    if($state.TypingSteal){$state.Stealing=$false;$state.StealPhase='';$state.TypingSteal=$false;$state.Physics=$false;$stealJustFinished=$true;if($state.TypingForcedFollow){$state.TypingForcedFollow=$false;$followItem.PerformClick()}}
  }
  $typingNow=$false
  if($state.TypingGrabEnabled -and $now -ge $state.TypingSuppressedUntil){
    $typingNow=$state.TextFocused
    foreach($vk in $typingKeys){if(([FishTankNative]::GetAsyncKeyState($vk) -band 0x8000) -ne 0){$typingNow=$true;break}}
  }
  if($typingNow -and -not $state.PongActive){
    $state.LastTypingAt=$now
    if(-not $state.TypingSteal){
      if(-not $state.Follow){$state.TypingForcedFollow=$true;$followItem.PerformClick()}
      if(-not $state.Stealing){& $startCursorSteal}
      $state.TypingSteal=$true
    }
  }
  if($state.TypingSteal -and ($now-$state.LastTypingAt).TotalMilliseconds -gt 700){
    # Let go exactly where the fish is holding the cursor now.
    $state.Stealing=$false;$state.StealPhase='';$state.TypingSteal=$false;$state.Physics=$false;$stealJustFinished=$true
    if($state.TypingForcedFollow){$state.TypingForcedFollow=$false;$followItem.PerformClick()}
  }
  $endDown=($state.EndKeyVK -ne 0 -and (([FishTankNative]::GetAsyncKeyState([int]$state.EndKeyVK) -band 0x8000) -ne 0))
  if($endDown -and -not $state.EndWasDown -and -not $state.PongActive){& $startCursorSteal}
  $state.EndWasDown=$endDown
  $insertDown=($state.InsertKeyVK -ne 0 -and (([FishTankNative]::GetAsyncKeyState([int]$state.InsertKeyVK) -band 0x8000) -ne 0))
  if($insertDown -and -not $state.InsertWasDown){& $togglePong}
  $state.InsertWasDown=$insertDown
  $homeDown=(([FishTankNative]::GetAsyncKeyState(0x24) -band 0x8000) -ne 0)
  if($homeDown -and -not $state.HomeWasDown){
    $state.FishHidden=-not $state.FishHidden
    if($state.FishHidden -and $state.PongActive){$state.PongActive=$false;$state.PongMode=$false;$state.PongOnly=$false;$state.LastCursor=[System.Windows.Forms.Cursor]::Position;$state.CursorStillSince=$now}
    $tank.Invalidate()
  }
  $state.HomeWasDown=$homeDown
  $pgUpDown=($state.PageUpKeyVK -ne 0 -and (([FishTankNative]::GetAsyncKeyState([int]$state.PageUpKeyVK) -band 0x8000) -ne 0))
  $pgDownDown=($state.PageDownKeyVK -ne 0 -and (([FishTankNative]::GetAsyncKeyState([int]$state.PageDownKeyVK) -band 0x8000) -ne 0))
  if($pgUpDown){
    if(-not $state.PgUpWasDown){$state.PgUpStarted=$now;$state.PgUpLastAdjust=$now;& $setFishCount ($state.FishCount+1)}
    else{$heldMs=($now-$state.PgUpStarted).TotalMilliseconds;$repeatMs=if($heldMs -ge 1800){55}elseif($heldMs -ge 700){110}else{280};if(($now-$state.PgUpLastAdjust).TotalMilliseconds -ge $repeatMs){$state.PgUpLastAdjust=$now;& $setFishCount ($state.FishCount+1)}}
  }
  $state.PgUpWasDown=$pgUpDown
  if($pgDownDown){
    if(-not $state.PgDownWasDown){$state.PgDownStarted=$now;$state.PgDownLastAdjust=$now;& $setFishCount ($state.FishCount-1)}
    else{$heldMs=($now-$state.PgDownStarted).TotalMilliseconds;$repeatMs=if($heldMs -ge 1800){55}elseif($heldMs -ge 700){110}else{280};if(($now-$state.PgDownLastAdjust).TotalMilliseconds -ge $repeatMs){$state.PgDownLastAdjust=$now;& $setFishCount ($state.FishCount-1)}}
  }
  $state.PgDownWasDown=$pgDownDown
  $deleteDown=($state.DeleteKeyVK -ne 0 -and (([FishTankNative]::GetAsyncKeyState([int]$state.DeleteKeyVK) -band 0x8000) -ne 0))
  if($deleteDown -and -not $state.DeleteWasDown -and ($state.Stealing -or $state.PongActive)){
    if($state.PongActive){& $togglePong;$stealJustFinished=$true}
    else{$state.Stealing=$false;$state.StealPhase='';$state.PinnedCorner=$false;$state.TargetX=0;$state.TargetY=0;$state.Physics=$true;$state.VelX=[Math]::Cos($state.Heading)*680;$state.VelY=[Math]::Sin($state.Heading)*680;$state.AngryUntil=$now.AddSeconds(5);$stealJustFinished=$true}
  }
  $state.DeleteWasDown=$deleteDown
  for($blubIndex=0;$blubIndex -lt $state.FishCount;$blubIndex++){
    $blubFish=$fishies[$blubIndex]
    if($now -ge $blubFish.NextBlub){
      $blubFish.BlubUntil=$now.AddSeconds(1.35);$blubFish.NextBlub=$now.AddSeconds($rng.Next(8,19))
      $blubPlayer.Play()
      if($blubIndex -eq 0 -and $state.StealEnabled -and -not $state.PongActive -and $rng.Next(100) -lt $state.StealChance){& $startCursorSteal}
    }
  }
  if($state.IsDragging -and (([System.Windows.Forms.Control]::MouseButtons -band [System.Windows.Forms.MouseButtons]::Left) -eq 0)){
    $state.IsDragging=$false; $tank.Capture=$false
    if(-not $state.PinnedCorner -and [Math]::Sqrt($state.VelX*$state.VelX+$state.VelY*$state.VelY) -gt 65){$state.Physics=$true}
  }
  for($i=1;$i -lt $state.FishCount;$i++){if($fishies[$i].Dragging -and (([System.Windows.Forms.Control]::MouseButtons -band [System.Windows.Forms.MouseButtons]::Left) -eq 0)){$fishies[$i].Dragging=$false;& $pickFishTarget $fishies[$i];$state.DraggingFishIndex=-1}}
  $state.Phase+=0.035
  if($state.PongActive){
    $origin=$tank.PointToScreen([System.Drawing.Point]::Empty);$cursor=[System.Windows.Forms.Cursor]::Position
    $ballX=$cursor.X-$origin.X;$ballY=$cursor.Y-$origin.Y
    $leftCenter=$tank.ClientSize.Width*0.24;$rightCenter=$tank.ClientSize.Width*0.72;$topY=44.0;$bottomY=[Math]::Max($topY,$tank.ClientSize.Height-44.0);$span=[Math]::Max(1,$bottomY-$topY)
    # Keep the fish on opposite paddle lines; they only move vertically to intercept an incoming puck.
    for($i=0;$i -lt 2;$i++){
      $f=$fishies[$i];$paddleX=if($i -eq 0){$leftCenter}else{$rightCenter};$f.X=$paddleX-43;$f.Heading=if($i -eq 0){0.0}else{[Math]::PI};$f.Direction=if($i -eq 0){1}else{-1};$f.Angle=0.0
      $fishMinY=[Math]::Max(0,$topY-14);$fishMaxY=[Math]::Max($fishMinY,$bottomY-14)
      if([double]::IsNaN([double]$f.Y) -or [double]::IsInfinity([double]$f.Y) -or $f.Y -lt ($fishMinY-20) -or $f.Y -gt ($fishMaxY+20)){$f.Y=($topY+$bottomY)/2-14}
      $targetY=$f.Y+14
      $frames=[Math]::Abs($paddleX-$ballX)/[Math]::Max(0.1,[Math]::Abs($state.PongVX));$rawY=$ballY+$state.PongVY*$frames;$fold=($rawY-$topY)%(2*$span);if($fold -lt 0){$fold+=2*$span};if($fold -gt $span){$targetY=$bottomY-($fold-$span)}else{$targetY=$topY+$fold}
      if([double]::IsNaN([double]$targetY) -or [double]::IsInfinity([double]$targetY)){$targetY=($topY+$bottomY)/2}
      $verticalStep=[Math]::Max(-16.0,[Math]::Min(16.0,$targetY-($f.Y+14)));$f.Y += $verticalStep;$f.Y=[Math]::Max($fishMinY,[Math]::Min($fishMaxY,$f.Y))
    }
    $nextX=$ballX+$state.PongVX;$nextY=$ballY+$state.PongVY
    if($nextY -lt $topY){$nextY=$topY+($topY-$nextY);$state.PongVY=[Math]::Abs($state.PongVY)}elseif($nextY -gt $bottomY){$nextY=$bottomY-($nextY-$bottomY);$state.PongVY=-[Math]::Abs($state.PongVY)}
    # A missed paddle loses the point and serves again toward that side; the end walls never score as hits.
    $missedIndex=if($nextX -lt ($leftCenter-44)){0}elseif($nextX -gt ($rightCenter+44)){1}else{-1}
    if($missedIndex -ge 0){if($missedIndex -eq 0){$state.PongScoreRight++}else{$state.PongScoreLeft++};$nextX=($leftCenter+$rightCenter)/2;$nextY=($topY+$bottomY)/2;$state.PongLastHitIndex=1-$missedIndex;$state.PongVX=if($missedIndex -eq 0){-12.0}else{12.0};$state.PongVY=($rng.NextDouble()-0.5)*4.4}
    # A body hit aims the cursor puck at the opposite paddle, with its vertical offset setting the rebound angle.
    for($i=0;$i -lt 2;$i++){
      if($i -eq $state.PongLastHitIndex){continue}
      $f=$fishies[$i];$paddleX=if($i -eq 0){$leftCenter}else{$rightCenter};$bodyX=$nextX-($f.X+43);$bodyY=$nextY-($f.Y+14)
      if([Math]::Abs($nextX-$paddleX) -le 8 -and [Math]::Abs($bodyY) -le 13){
        if($rng.Next(100) -lt 5){$state.PongLastHitIndex=$i;continue}
        $verticalOffset=[Math]::Max(-1.0,[Math]::Min(1.0,$bodyY/13.0));$slope=$verticalOffset*0.78+($rng.NextDouble()-0.5)*0.82;$slope=[Math]::Max(-1.25,[Math]::Min(1.25,$slope));$speed=(6.4+$rng.NextDouble()*2.3)*2
        $outX=if($i -eq 0){1.0}else{-1.0};$normalizer=[Math]::Sqrt(1+$slope*$slope);$state.PongVX=$outX*$speed/$normalizer;$state.PongVY=$slope*$speed/$normalizer;$state.PongLastHitIndex=$i;$state.PongHits++
        break
      }
    }
    $px=[int]($origin.X+$nextX);$py=[int]($origin.Y+$nextY);[FishTankNative]::SetCursorPos($px,$py)|Out-Null
    $state.LastCursor=New-Object System.Drawing.Point($px,$py);$state.CursorStillSince=$now
  } elseif($state.Stealing){
    $screen=[System.Windows.Forms.Screen]::FromPoint([System.Windows.Forms.Cursor]::Position).Bounds
    $cursor=[System.Windows.Forms.Cursor]::Position
    if($state.StealPhase -eq 'Hunting'){
      # Chase the live pointer. It stays put until the fish reaches it.
      $targetX=$cursor.X-$tank.PointToScreen([System.Drawing.Point]::Empty).X
      $targetY=$cursor.Y-$tank.PointToScreen([System.Drawing.Point]::Empty).Y
      $carrier=$fishies[$state.CarrierIndex]
      $dx=$targetX-($carrier.X+43);$dy=$targetY-($carrier.Y+14)
      $desired=[Math]::Atan2($dy,$dx)
      $delta=[Math]::Atan2([Math]::Sin($desired-$carrier.Heading),[Math]::Cos($desired-$carrier.Heading))
      $carrier.Heading += [Math]::Max(-0.11,[Math]::Min(0.11,$delta))
      $carrier.Direction=if([Math]::Cos($carrier.Heading) -lt 0){-1}else{1}
      $huntSpeed=if([datetime]::UtcNow -lt $state.AngryUntil){10.5}else{7.2}
      $carrier.X += [Math]::Cos($carrier.Heading)*$huntSpeed;$carrier.Y += [Math]::Sin($carrier.Heading)*$huntSpeed
      # Keep the rotated glyph fully inside the canvas, including in a screen corner.
      $carrier.X=[Math]::Max(5,[Math]::Min($tank.ClientSize.Width-92,$carrier.X));$carrier.Y=[Math]::Max(30,[Math]::Min($tank.ClientSize.Height-60,$carrier.Y))
      $carrier.Angle=[Math]::Atan2([Math]::Sin($carrier.Heading),[Math]::Cos($carrier.Heading))*180/[Math]::PI
      if($carrier.Direction -lt 0){$carrier.Angle-=180}
      # A catch only happens when his nose reaches the pointer, not when his center does.
      $mouthX=$carrier.X+43+[Math]::Cos($carrier.Heading)*38
      $mouthY=$carrier.Y+14+[Math]::Sin($carrier.Heading)*38
      $mouthDx=$targetX-$mouthX;$mouthDy=$targetY-$mouthY
      $mouthDistance=[Math]::Sqrt($mouthDx*$mouthDx+$mouthDy*$mouthDy)
      if($mouthDistance -lt 18){
        $state.StealPhase='Carrying';$state.StealUntil=$now.AddSeconds($(if($state.PongMode){1.25}else{10}))
        & $pickStealTarget
      }
    } elseif($state.StealPhase -eq 'Carrying'){
      $carrier=$fishies[$state.CarrierIndex]
      if($now -ge $state.StealUntil){
        if($state.PongMode){
          if($state.PongPasses -gt 1){$state.PongPasses--;$state.CarrierIndex=1-$state.CarrierIndex;$state.StealPhase='Hunting';$state.StealUntil=[datetime]::MinValue}
          elseif($state.TypingSteal){$state.PongMode=$false;$state.PongOnly=$false;$state.PongPasses=0;$state.StealTurnsRemaining=$state.FishCount;$state.CarrierIndex=1-$state.CarrierIndex;$state.StealPhase='Hunting';$state.StealUntil=[datetime]::MinValue}
          else{$state.Stealing=$false;$state.StealPhase='';$state.PongMode=$false;$state.PongOnly=$false;$stealJustFinished=$true}
        }
        elseif($state.StealTurnsRemaining -gt 1){$state.StealTurnsRemaining--;$state.CarrierIndex=($state.CarrierIndex+1)%$state.FishCount;$state.StealPhase='Hunting';$state.StealUntil=[datetime]::MinValue}
        elseif($state.TypingSteal){$state.StealTurnsRemaining=$state.FishCount;$state.CarrierIndex=($state.CarrierIndex+1)%$state.FishCount;$state.StealPhase='Hunting';$state.StealUntil=[datetime]::MinValue}
        else{
          $working=[System.Windows.Forms.Screen]::FromPoint([System.Windows.Forms.Cursor]::Position).WorkingArea
          $px=$rng.Next($working.Left+30,$working.Right-30);$py=$rng.Next($working.Top+30,$working.Bottom-30)
          [FishTankNative]::SetCursorPos($px,$py) | Out-Null;$state.LastCursor=New-Object System.Drawing.Point($px,$py);$state.CursorStillSince=$now
          $state.Stealing=$false;$state.StealPhase='';$state.PongMode=$false;$stealJustFinished=$true
        }
      }
      if($state.Stealing -and $state.StealPhase -eq 'Carrying'){
        $dx=$state.StealTargetX-$carrier.X;$dy=$state.StealTargetY-$carrier.Y
        $distance=[Math]::Sqrt($dx*$dx+$dy*$dy)
        if($distance -lt 30){& $pickStealTarget;$dx=$state.StealTargetX-$carrier.X;$dy=$state.StealTargetY-$carrier.Y;$distance=[Math]::Sqrt($dx*$dx+$dy*$dy)}
        $desired=[Math]::Atan2($dy,$dx)
        $delta=[Math]::Atan2([Math]::Sin($desired-$carrier.Heading),[Math]::Cos($desired-$carrier.Heading))
        $carrier.Heading += [Math]::Max(-0.13,[Math]::Min(0.13,$delta))
        $carrier.Direction=if([Math]::Cos($carrier.Heading) -lt 0){-1}else{1}
        $carrier.X += [Math]::Cos($carrier.Heading)*12.0;$carrier.Y += [Math]::Sin($carrier.Heading)*12.0
        $carrier.X=[Math]::Max(5,[Math]::Min($tank.ClientSize.Width-92,$carrier.X));$carrier.Y=[Math]::Max(30,[Math]::Min($tank.ClientSize.Height-60,$carrier.Y))
        $carrier.Angle=[Math]::Atan2([Math]::Sin($carrier.Heading),[Math]::Cos($carrier.Heading))*180/[Math]::PI
        if($carrier.Direction -lt 0){$carrier.Angle-=180}
        # Keep the cursor at the fish's mouth while he runs off with it.
        $mouthX=$carrier.X+43+[Math]::Cos($carrier.Heading)*38;$mouthY=$carrier.Y+14+[Math]::Sin($carrier.Heading)*38
        $mouth=$tank.PointToScreen((New-Object System.Drawing.Point([int]$mouthX,[int]$mouthY)))
        [FishTankNative]::SetCursorPos($mouth.X,$mouth.Y) | Out-Null
      }
    }
  }
  if($state.PongActive) { }
  elseif($state.Stealing) { }
  elseif($stealJustFinished) { }
  elseif($state.Physics -and -not $state.IsDragging -and -not $state.PinnedCorner){
    $dt=0.03;$maxX=[Math]::Max(18,$tank.ClientSize.Width-105);$maxY=[Math]::Max(30,$tank.ClientSize.Height-48);$hit=0.0
    $state.VelY+=620*$dt
    $state.X+=$state.VelX*$dt;$state.Y+=$state.VelY*$dt
    if($state.X -lt 18){$state.X=18;$hit=[Math]::Max($hit,[Math]::Abs($state.VelX));$state.VelX=[Math]::Abs($state.VelX)*0.72}
    elseif($state.X -gt $maxX){$state.X=$maxX;$hit=[Math]::Max($hit,[Math]::Abs($state.VelX));$state.VelX=-[Math]::Abs($state.VelX)*0.72}
    if($state.Y -lt 18){$state.Y=18;$hit=[Math]::Max($hit,[Math]::Abs($state.VelY));$state.VelY=[Math]::Abs($state.VelY)*0.72}
    elseif($state.Y -gt $maxY){$state.Y=$maxY;$hit=[Math]::Max($hit,[Math]::Abs($state.VelY));$state.VelY=-[Math]::Abs($state.VelY)*0.72}
    if($hit -gt 350){$state.AngryUntil=[datetime]::UtcNow.AddSeconds(5)}
    $state.VelX*=0.97;$state.VelY*=0.97
    $state.Direction=if($state.VelX -lt 0){-1}else{1}
    $state.Angle=[Math]::Atan2($state.VelY,$state.VelX)*180/[Math]::PI
    if($state.Direction -lt 0){$state.Angle-=180}
    if($state.Angle -gt 180){$state.Angle-=360};if($state.Angle -lt -180){$state.Angle+=360}
    if([Math]::Sqrt($state.VelX*$state.VelX+$state.VelY*$state.VelY) -lt 70){$state.Physics=$false;$state.VelX=0;$state.VelY=0;if(-not $state.Follow){& $pickRoamTarget}}
  }
  if($state.Follow -and -not $state.PongActive -and -not $state.Stealing -and -not $stealJustFinished -and -not $state.IsDragging -and -not $state.PinnedCorner) {
    $screen=[System.Windows.Forms.Screen]::FromPoint([System.Windows.Forms.Cursor]::Position).Bounds
    if($form.Bounds -ne $screen){$form.Bounds=$screen}
    $cursor=[System.Windows.Forms.Cursor]::Position
    if([Math]::Abs($cursor.X-$state.LastCursor.X)+[Math]::Abs($cursor.Y-$state.LastCursor.Y) -gt 3){$state.CursorStillSince=[datetime]::UtcNow;$state.LastCursor=$cursor}
    $cursorMoving = ([datetime]::UtcNow-$state.CursorStillSince).TotalMilliseconds -le 500
    if($cursorMoving) {
      # While the user moves the pointer, swim toward it and keep looking at it.
      $tx=$cursor.X-$screen.Left; $ty=$cursor.Y-$screen.Top
      $followOffsetX=0;$followOffsetY=0;if($state.FishCount -eq 20){$followOffsetX=-36;$followOffsetY=-33};$dx=$tx+$followOffsetX-($state.X+43); $dy=$ty+$followOffsetY-($state.Y+14)
      $followStep=if([datetime]::UtcNow -lt $state.AngryUntil -or $state.Physics){12.0}else{5.0};if($state.FishCount -eq 20 -and [Math]::Sqrt($dx*$dx+$dy*$dy) -lt 12){$followStep=0.0}
      $state.X += [Math]::Max(-$followStep,[Math]::Min($followStep,$dx*0.035))
      $state.Y += [Math]::Max(-$followStep,[Math]::Min($followStep,$dy*0.035))
      if([Math]::Abs($dx)+[Math]::Abs($dy) -gt 3){$state.Direction=if($dx -lt 0){-1}else{1}}
      $heading=[Math]::Atan2($dy,$dx)*180/[Math]::PI
      $state.Angle=$heading
      if($state.Direction -lt 0){$state.Angle-=180}
    } else {
      # When the pointer rests, roam freely across the full desktop-sized surface.
      $tightTank=($tank.ClientSize.Width -lt 450 -or $tank.ClientSize.Height -lt 320)
      $maxX=[Math]::Max(32,$tank.ClientSize.Width-88); $maxY=[Math]::Max(30,$tank.ClientSize.Height-34)
      $arrivalRadius=if($tightTank){14.0}else{32.0}
      if($state.TargetX -le 0 -or [Math]::Sqrt([Math]::Pow($state.TargetX-$state.X,2)+[Math]::Pow($state.TargetY-$state.Y,2)) -lt $arrivalRadius){
        $state.TargetX=24+$rng.NextDouble()*[Math]::Max(1,$maxX-24)
        $state.TargetY=18+$rng.NextDouble()*[Math]::Max(1,$maxY-18)
      }
      $dx=$state.TargetX-$state.X; $dy=$state.TargetY-$state.Y
      $desired=[Math]::Atan2($dy,$dx)
      $delta=[Math]::Atan2([Math]::Sin($desired-$state.Heading),[Math]::Cos($desired-$state.Heading))
      if($tightTank){$state.Heading=$desired}else{$state.Heading += [Math]::Max(-0.075,[Math]::Min(0.075,$delta))}
      $roamSpeed=if([datetime]::UtcNow -lt $state.AngryUntil){6.8}else{3.2}
      $state.X += [Math]::Cos($state.Heading)*$roamSpeed
      $state.Y += [Math]::Sin($state.Heading)*$roamSpeed
      if($state.X -lt 18){$state.X=18;$state.TargetX=$maxX;$state.TargetY=18+$rng.Next([Math]::Max(1,[int]($maxY-18)))}
      elseif($state.X -gt $maxX){$state.X=$maxX;$state.TargetX=18;$state.TargetY=18+$rng.Next([Math]::Max(1,[int]($maxY-18)))}
      if($state.Y -lt 18){$state.Y=18;$state.TargetY=$maxY;$state.TargetX=24+$rng.Next([Math]::Max(1,[int]($maxX-24)))}
      elseif($state.Y -gt $maxY){$state.Y=$maxY;$state.TargetY=18;$state.TargetX=24+$rng.Next([Math]::Max(1,[int]($maxX-24)))}
      $vx=[Math]::Cos($state.Heading); $vy=[Math]::Sin($state.Heading)
      $state.Direction=if($vx -lt 0){-1}else{1}
      $state.Angle=[Math]::Atan2($vy,$vx)*180/[Math]::PI
      if($state.Direction -lt 0){$state.Angle-=180}
    }
    if($state.Angle -gt 180){$state.Angle-=360}
  } elseif($state.Follow -and -not $state.PongActive -and -not $state.Stealing -and -not $stealJustFinished -and $state.PinnedCorner) {
    $screen=[System.Windows.Forms.Screen]::FromPoint([System.Windows.Forms.Cursor]::Position).Bounds
    $cursor=[System.Windows.Forms.Cursor]::Position
    $dx=$cursor.X-$screen.Left-($state.X+43);$dy=$cursor.Y-$screen.Top-($state.Y+14)
    $state.Direction=if($dx -lt 0){-1}else{1}
    $state.Angle=[Math]::Atan2($dy,$dx)*180/[Math]::PI
    if($state.Direction -lt 0){$state.Angle-=180}
    if($state.Angle -gt 180){$state.Angle-=360};if($state.Angle -lt -180){$state.Angle+=360}
  } elseif(-not $state.PongActive -and -not $state.Stealing -and -not $stealJustFinished -and -not $state.Follow -and -not $state.Physics) {
    # A single nudge does not count: require repeated, sizable back-and-forth movement.
    $now=[datetime]::UtcNow; $loc=$form.Location
    $dx=$loc.X-$state.LastLoc.X; $dy=$loc.Y-$state.LastLoc.Y
    $leftHeld=(([System.Windows.Forms.Control]::MouseButtons -band [System.Windows.Forms.MouseButtons]::Left) -ne 0)
    $winDt=[Math]::Max(0.005,($now-$state.WindowAt).TotalSeconds)
    if(([Math]::Abs($dx)+[Math]::Abs($dy)) -gt 0 -and $leftHeld -and $form.Bounds.Contains([System.Windows.Forms.Control]::MousePosition)){
      $state.WindowDragging=$true;$state.WindowPhysics=$false
      $state.WindowVelX=[Math]::Max(-2200,[Math]::Min(2200,$dx/$winDt));$state.WindowVelY=[Math]::Max(-2200,[Math]::Min(2200,$dy/$winDt))
      $state.WindowBounds=[System.Windows.Forms.Screen]::FromPoint([System.Windows.Forms.Control]::MousePosition).WorkingArea
    }
    if($state.WindowDragging -and -not $leftHeld){
      $state.WindowDragging=$false;$state.WindowPhysics=([Math]::Sqrt($state.WindowVelX*$state.WindowVelX+$state.WindowVelY*$state.WindowVelY) -gt 90)
      $state.WindowBounds=[System.Windows.Forms.Screen]::FromPoint([System.Windows.Forms.Control]::MousePosition).WorkingArea
    }
    $state.WindowAt=$now
    if([Math]::Abs($dx)+[Math]::Abs($dy) -ge 2 -and $leftHeld -and $form.Bounds.Contains([System.Windows.Forms.Control]::MousePosition)) {
      $axis=if([Math]::Abs($dx) -ge [Math]::Abs($dy)){'X'}else{'Y'}
      $step=if($axis -eq 'X'){$dx}else{$dy}
      $dir=[Math]::Sign($step); $distance=[Math]::Abs($step)
      if($state.ShakeAxis -ne $axis -or ($now-$state.ShakeStarted).TotalMilliseconds -gt 900) {
        $state.ShakeAxis=$axis; $state.ShakeDir=$dir; $state.ShakeLeg=$distance; $state.ShakePath=$distance
        $state.ShakeMin=if($axis -eq 'X'){$loc.X}else{$loc.Y}; $state.ShakeMax=$state.ShakeMin
        $state.ShakeReversals=0; $state.ShakeStarted=$now
      } else {
        $state.ShakePath += $distance
        $v=if($axis -eq 'X'){$loc.X}else{$loc.Y}
        $state.ShakeMin=[Math]::Min($state.ShakeMin,$v); $state.ShakeMax=[Math]::Max($state.ShakeMax,$v)
        if($dir -ne $state.ShakeDir -and $state.ShakeLeg -ge 14) {
          $state.ShakeReversals++; $state.ShakeDir=$dir; $state.ShakeLeg=$distance
          if($state.ShakeReversals -ge 2 -and $state.ShakePath -ge 60 -and ($state.ShakeMax-$state.ShakeMin) -ge 24) {
            $state.AngryUntil=$now.AddSeconds(5); $state.ShakeReversals=0; $state.ShakePath=0;$tank.Invalidate()
          }
        } elseif($dir -eq $state.ShakeDir) { $state.ShakeLeg += $distance }
      }
    }
    $state.LastLoc=$loc
    if($state.WindowPhysics -and -not $state.WindowDragging){
      $bounds=$state.WindowBounds;$dt=0.03;$nextX=$form.Left+$state.WindowVelX*$dt;$nextY=$form.Top+$state.WindowVelY*$dt;$impact=0.0
      $maxLeft=$bounds.Left;$maxTop=$bounds.Top;$maxRight=$bounds.Right-$form.Width;$maxBottom=$bounds.Bottom-$form.Height
      if($nextX -lt $maxLeft){$nextX=$maxLeft;$impact=[Math]::Max($impact,[Math]::Abs($state.WindowVelX));$state.WindowVelX=[Math]::Abs($state.WindowVelX)*0.72}
      elseif($nextX -gt $maxRight){$nextX=$maxRight;$impact=[Math]::Max($impact,[Math]::Abs($state.WindowVelX));$state.WindowVelX=-[Math]::Abs($state.WindowVelX)*0.72}
      if($nextY -lt $maxTop){$nextY=$maxTop;$impact=[Math]::Max($impact,[Math]::Abs($state.WindowVelY));$state.WindowVelY=[Math]::Abs($state.WindowVelY)*0.72}
      elseif($nextY -gt $maxBottom){$nextY=$maxBottom;$impact=[Math]::Max($impact,[Math]::Abs($state.WindowVelY));$state.WindowVelY=-[Math]::Abs($state.WindowVelY)*0.72}
      if($impact -gt 350){$state.AngryUntil=$now.AddSeconds(5)}
      $form.Location=New-Object System.Drawing.Point([int]$nextX,[int]$nextY)
      $state.WindowVelX*=0.985;$state.WindowVelY*=0.985
      if([Math]::Sqrt($state.WindowVelX*$state.WindowVelX+$state.WindowVelY*$state.WindowVelY) -lt 35){$state.WindowPhysics=$false;$state.WindowVelX=0;$state.WindowVelY=0}
    }
    $maxX=[Math]::Max(32,$tank.ClientSize.Width-105); $maxY=[Math]::Max(30,$tank.ClientSize.Height-48)
    if([datetime]::UtcNow -lt $state.AngryUntil){$state.Speed=8.8}else{$state.Speed=3.2}
    if(-not $state.IsDragging){
      if($state.TargetX -le 0 -or [Math]::Sqrt([Math]::Pow($state.TargetX-$state.X,2)+[Math]::Pow($state.TargetY-$state.Y,2)) -lt 28){& $pickRoamTarget}
      $dx=$state.TargetX-$state.X; $dy=$state.TargetY-$state.Y
      $desired=[Math]::Atan2($dy,$dx)
      $delta=[Math]::Atan2([Math]::Sin($desired-$state.Heading),[Math]::Cos($desired-$state.Heading))
      $turn=[Math]::Max(-0.075,[Math]::Min(0.075,$delta))
      $state.Heading += $turn
      $state.X += [Math]::Cos($state.Heading)*$state.Speed
      $state.Y += [Math]::Sin($state.Heading)*$state.Speed
      if($state.X -lt 18){$state.X=18;$state.TargetX=$maxX;$state.TargetY=$rng.Next(24,[int]$maxY)}
      elseif($state.X -gt $maxX){$state.X=$maxX;$state.TargetX=18;$state.TargetY=$rng.Next(24,[int]$maxY)}
      if($state.Y -lt 18){$state.Y=18;$state.TargetY=$maxY;$state.TargetX=$rng.Next(24,[int]$maxX)}
      elseif($state.Y -gt $maxY){$state.Y=$maxY;$state.TargetY=24;$state.TargetX=$rng.Next(24,[int]$maxX)}
      $vx=[Math]::Cos($state.Heading); $vy=[Math]::Sin($state.Heading)
      $state.Direction=if($vx -lt 0){-1}else{1}
      $state.Angle=[Math]::Atan2($vy,$vx)*180/[Math]::PI
      if($state.Direction -lt 0){$state.Angle-=180}
      if($state.Angle -gt 180){$state.Angle-=360}; if($state.Angle -lt -180){$state.Angle+=360}
    }
  }
  for($angryIndex=1;$angryIndex -lt $state.FishCount;$angryIndex++){if($state.AngryUntil -gt $fishies[$angryIndex].AngryUntil){$fishies[$angryIndex].AngryUntil=$state.AngryUntil}}
  for($i=1;$i -lt $state.FishCount;$i++){$f=$fishies[$i];$twentyFishCursorChase=($state.Follow -and $state.FishCount -eq 20 -and ([datetime]::UtcNow-$state.CursorStillSince).TotalMilliseconds -le 500);if($state.Follow -and $state.FishCount -eq 20){if($twentyFishCursorChase){$followOrigin=$tank.PointToScreen([System.Drawing.Point]::Empty);$followCursor=[System.Windows.Forms.Cursor]::Position;$f.TargetX=$followCursor.X-$followOrigin.X-43+(($i%5)-2)*18;$f.TargetY=$followCursor.Y-$followOrigin.Y-14+([Math]::Floor($i/5)-1.5)*22}else{$f.TargetX=0;$f.TargetY=0}};if(-not $state.PongActive -and -not $f.Dragging){
    $tightTank=($tank.ClientSize.Width -lt 450 -or $tank.ClientSize.Height -lt 320);$maxX=[Math]::Max(32,$tank.ClientSize.Width-88);$maxY=[Math]::Max(30,$tank.ClientSize.Height-34)
    $arrivalRadius=if($tightTank){14.0}else{32.0}
    if(-not $twentyFishCursorChase -and ($f.TargetX -le 0 -or [Math]::Sqrt([Math]::Pow($f.TargetX-$f.X,2)+[Math]::Pow($f.TargetY-$f.Y,2)) -lt $arrivalRadius)){& $pickFishTarget $f}
    $dx=$f.TargetX-$f.X;$dy=$f.TargetY-$f.Y;$desired=[Math]::Atan2($dy,$dx);$delta=[Math]::Atan2([Math]::Sin($desired-$f.Heading),[Math]::Cos($desired-$f.Heading))
    if($tightTank){$f.Heading=$desired}else{$f.Heading += [Math]::Max(-0.07,[Math]::Min(0.07,$delta))};$followSpeed=if([datetime]::UtcNow -lt $f.AngryUntil){$f.Speed*2.4}else{$f.Speed};if($twentyFishCursorChase -and [Math]::Sqrt($dx*$dx+$dy*$dy) -lt 12){$followSpeed=0.0};$f.X += [Math]::Cos($f.Heading)*$followSpeed;$f.Y += [Math]::Sin($f.Heading)*$followSpeed
    $f.X=[Math]::Max(5,[Math]::Min($tank.ClientSize.Width-82,$f.X));$f.Y=[Math]::Max(18,[Math]::Min($tank.ClientSize.Height-34,$f.Y))
    if($f.X -le 5 -or $f.X -ge $tank.ClientSize.Width-82 -or $f.Y -le 18 -or $f.Y -ge $tank.ClientSize.Height-34){& $pickFishTarget $f}
    $f.Direction=if([Math]::Cos($f.Heading) -lt 0){-1}else{1};$f.Angle=[Math]::Atan2([Math]::Sin($f.Heading),[Math]::Cos($f.Heading))*180/[Math]::PI
    if($f.Direction -lt 0){$f.Angle-=180};if($f.Angle -gt 180){$f.Angle-=360};if($f.Angle -lt -180){$f.Angle+=360}
  }}
  if($state.Tilt){
    $cursorForTilt=[System.Windows.Forms.Cursor]::Position
    $tankOriginForTilt=$tank.PointToScreen([System.Drawing.Point]::Empty)
    for($tiltIndex=0;$tiltIndex -lt $state.FishCount;$tiltIndex++){
      $tiltFish=$fishies[$tiltIndex]
      $lookDx=$cursorForTilt.X-($tankOriginForTilt.X+$tiltFish.X+43)
      $lookDy=$cursorForTilt.Y-($tankOriginForTilt.Y+$tiltFish.Y+14)
      if(($lookDx*$lookDx+$lookDy*$lookDy) -gt 4){
        $cursorHeading=[Math]::Atan2($lookDy,$lookDx)*180/[Math]::PI
        $glyphHeading=if($tiltFish.Direction -gt 0){0.0}else{180.0}
        $tiltFish.LookAngle=$cursorHeading-$glyphHeading
        while($tiltFish.LookAngle -gt 180){$tiltFish.LookAngle-=360};while($tiltFish.LookAngle -lt -180){$tiltFish.LookAngle+=360}
        if($tiltFish.LookAngle -gt 90){$tiltFish.LookAngle=180-$tiltFish.LookAngle};if($tiltFish.LookAngle -lt -90){$tiltFish.LookAngle=-180-$tiltFish.LookAngle}
      }
    }
  }
  $tank.Invalidate()
})

$form.Add_Shown({
  $style=[FishTankNative]::GetStyle($form.Handle,-20)
  $style=$style -band (-bnot (0x20 -bor 0x8000000))
  if($state.ClickThrough){$style=$style -bor 0x20}
  if($state.ClickThrough){$style=$style -bor 0x8000000}
  [FishTankNative]::SetStyle($form.Handle,-20,$style)
  if($state.KeepAwake){& $applyKeepAwake}
  & $pickRoamTarget
  foreach($f in $fishies[1..3]){$f.X=[Math]::Max(18,[Math]::Min($tank.ClientSize.Width-105,$f.X));$f.Y=[Math]::Max(18,[Math]::Min($tank.ClientSize.Height-48,$f.Y));& $pickFishTarget $f}
  $timer.Start()
  if(Test-Path -LiteralPath $script:PendingWhatsNewPath){$pendingVersion=Get-Content -LiteralPath $script:PendingWhatsNewPath -Raw -ErrorAction SilentlyContinue;Remove-Item -LiteralPath $script:PendingWhatsNewPath -Force -ErrorAction SilentlyContinue;if($pendingVersion.Trim() -eq $script:FishTankVersion){$form.BeginInvoke([Action]{& $showWhatsNew})|Out-Null}}
})
$form.Add_FormClosed({ [FishTankNative]::SetThreadExecutionState([uint32]2147483648) | Out-Null;$timer.Stop();$timer.Dispose();$tray.Visible=$false;$tray.Dispose();$menu.Dispose();$colorDialog.Dispose();$hatColorDialog.Dispose();$backgroundOverlay.Close();$backgroundOverlay.Dispose();$blubPlayer.Stop();$blubPlayer.Dispose();$blubStream.Dispose();$writer.Dispose();$wav.Dispose();$screenSampleGraphics.Dispose();$screenSampleBitmap.Dispose();if($script:dellLogoBitmap){$script:dellLogoBitmap.Dispose()};if($script:drawResources){$script:drawResources.FishFont.Dispose();$script:drawResources.FishBrush.Dispose();$script:drawResources.FishOutlineBrush.Dispose();foreach($glyphSet in $script:drawResources.FishGlyphs.Values){$glyphSet.Left.Dispose();$glyphSet.Right.Dispose()};$script:drawResources.HatOutlinePen.Dispose();$script:drawResources.TextOutlineBrush.Dispose();$script:drawResources.HatBrush.Dispose();$script:drawResources.HatAccentBrush.Dispose();foreach($b in $script:drawResources.PartyBrushes){$b.Dispose()};$script:drawResources.AngerFont.Dispose();$script:drawResources.AngerBrush.Dispose();$script:drawResources.BlubFont.Dispose();$script:drawResources.BlubBrush.Dispose();$script:drawResources.BubblePen.Dispose();$script:drawResources.GlintBrush.Dispose();$script:drawResources.ScoreFont.Dispose();$script:drawResources.ScoreBrush.Dispose()} })
[void]$form.ShowDialog()


