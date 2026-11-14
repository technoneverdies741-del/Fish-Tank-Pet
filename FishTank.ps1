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
  public static long GetStyle(IntPtr h, int n) { return IntPtr.Size == 8 ? GetWindowLongPtr64(h,n).ToInt64() : GetWindowLong32(h,n); }
  public static void SetStyle(IntPtr h, int n, long v) { if (IntPtr.Size == 8) SetWindowLongPtr64(h,n,new IntPtr(v)); else SetWindowLong32(h,n,(int)v); }
}
'@
Add-Type -TypeDefinition $native

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Fish Tank'
$form.StartPosition = 'CenterScreen'
$form.ClientSize = New-Object System.Drawing.Size(620, 390)
$form.MinimumSize = New-Object System.Drawing.Size(300, 220)
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
$form.TopMost = $true
$form.BackColor = [System.Drawing.Color]::FromArgb(18,18,18)
$form.Opacity = 0.9
$form.TransparencyKey = $form.BackColor
$form.KeyPreview = $true

$tank = New-Object System.Windows.Forms.Panel
$tank.Dock = [System.Windows.Forms.DockStyle]::Fill
$tank.BackColor = $form.TransparencyKey
$form.Controls.Add($tank)
$screenSampleBitmap=New-Object System.Drawing.Bitmap(1,1)
$screenSampleGraphics=[System.Drawing.Graphics]::FromImage($screenSampleBitmap)

$state = [pscustomobject]@{ X=260.0; Y=120.0; Direction=1; Phase=0.0; Speed=3.2; Angle=0.0; Heading=0.0; TargetX=0.0; TargetY=0.0; Follow=$false; TypingForcedFollow=$false; WindowedBounds=[System.Drawing.Rectangle]::Empty; TextFocused=$false; LastFocusCheck=[datetime]::MinValue; KeepAwake=$true; Tilt=$true; ClickThrough=$false; IsDragging=$false; DraggingFishIndex=-1; FishCount=1; CarrierIndex=0; StealTurnsRemaining=0; PongActive=$false; PongVX=0.0; PongVY=0.0; PongHits=0; PongHitLimit=8; PongEndsAt=[datetime]::MinValue; PongLastHitIndex=1; PongMode=$false; PongOnly=$false; PongPasses=0; Physics=$false; VelX=0.0; VelY=0.0; DragAt=[datetime]::UtcNow; PinnedCorner=$false; Stealing=$false; StealPhase=''; TypingSteal=$false; TypingGrabEnabled=$true; LastTypingAt=[datetime]::MinValue; StealOriginX=0; StealOriginY=0; StealEnabled=$true; StealChance=5; StealUntil=[datetime]::MinValue; StealTargetX=0.0; StealTargetY=0.0; EndWasDown=$false; DeleteWasDown=$false; BlubUntil=[datetime]::MinValue; NextBlub=[datetime]::UtcNow.AddSeconds(8); DragOffsetX=0.0; DragOffsetY=0.0; LastDragX=0.0; LastDragY=0.0; DragAxis=''; DragDir=0; DragLeg=0.0; DragPath=0.0; DragMin=0.0; DragMax=0.0; DragReversals=0; DragStarted=[datetime]::MinValue; AngryUntil=[datetime]::MinValue; LastLoc=$form.Location; LastMove=[datetime]::MinValue; WindowDragging=$false; WindowPhysics=$false; WindowVelX=0.0; WindowVelY=0.0; WindowBounds=[System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea; WindowAt=[datetime]::UtcNow; ShakeAxis=''; ShakeDir=0; ShakeLeg=0.0; ShakePath=0.0; ShakeMin=0; ShakeMax=0; ShakeReversals=0; ShakeStarted=[datetime]::MinValue; LastCursor=[System.Windows.Forms.Cursor]::Position; CursorStillSince=[datetime]::UtcNow }
$makeFish = { param($x,$y,$speed) [pscustomobject]@{ X=[double]$x; Y=[double]$y; Direction=1; Angle=0.0; Heading=0.0; TargetX=0.0; TargetY=0.0; Speed=[double]$speed; Dragging=$false; DragOffsetX=0.0; DragOffsetY=0.0; LastDragX=0.0; LastDragY=0.0 } }
$buddy = & $makeFish 400 230 2.8
$fish3 = & $makeFish 180 260 2.5
$fish4 = & $makeFish 340 80 2.6
$fishies=@($state,$buddy,$fish3,$fish4)
$rng = New-Object System.Random
$pickRoamTarget = {
  $left=24.0; $right=[Math]::Max($left+1,$tank.ClientSize.Width-118.0)
  $top=24.0; $bottom=[Math]::Max($top+1,$tank.ClientSize.Height-58.0)
  $state.TargetX=$left+$rng.NextDouble()*($right-$left)
  $state.TargetY=$top+$rng.NextDouble()*($bottom-$top)
}
$pickBuddyTarget = {
  $left=24.0;$right=[Math]::Max($left+1,$tank.ClientSize.Width-118.0)
  $top=24.0;$bottom=[Math]::Max($top+1,$tank.ClientSize.Height-58.0)
  $buddy.TargetX=$left+$rng.NextDouble()*($right-$left)
  $buddy.TargetY=$top+$rng.NextDouble()*($bottom-$top)
}
$pickFishTarget = { param($fish)
  $left=24.0;$right=[Math]::Max($left+1,$tank.ClientSize.Width-118.0)
  $top=24.0;$bottom=[Math]::Max($top+1,$tank.ClientSize.Height-58.0)
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
  foreach($item in $fishCountItems){$item.Checked=([int]$item.Tag -eq 2)}
  if($buddy.TargetX -le 0){& $pickFishTarget $buddy}
  for($i=0;$i -lt 2;$i++){$f=$fishies[$i];$f.X=[Math]::Max(5,[Math]::Min($tank.ClientSize.Width-92,$f.X));$f.Y=[Math]::Max(30,[Math]::Min($tank.ClientSize.Height-60,$f.Y));$f.Dragging=$false}
  $state.Stealing=$false;$state.StealPhase='';$state.IsDragging=$false;$state.Physics=$false;$state.PinnedCorner=$false;$state.PongMode=$false;$state.PongOnly=$false
  $state.PongActive=$true;$state.PongHits=0;$state.PongHitLimit=8;$state.PongEndsAt=[datetime]::UtcNow.AddSeconds(30);$state.PongLastHitIndex=1
  $cx0=$state.X+43;$cy0=$state.Y+14;$cx1=$buddy.X+43;$cy1=$buddy.Y+14
  $ballX=($cx0+$cx1)/2;$ballY=($cy0+$cy1)/2
  $dx=$cx0-$ballX;$dy=$cy0-$ballY;$distance=[Math]::Max(1,[Math]::Sqrt($dx*$dx+$dy*$dy))
  $state.PongVX=($dx/$distance)*8.5;$state.PongVY=($dy/$distance)*8.5
  $origin=$tank.PointToScreen([System.Drawing.Point]::Empty);$px=[int]($origin.X+$ballX);$py=[int]($origin.Y+$ballY)
  [FishTankNative]::SetCursorPos($px,$py)|Out-Null;$state.LastCursor=New-Object System.Drawing.Point($px,$py);$state.CursorStillSince=[datetime]::UtcNow
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
foreach($count in 1..4){
  $countItem=New-Object System.Windows.Forms.ToolStripMenuItem("$count fish")
  $countItem.Tag=$count;$countItem.Checked=($count -eq 1)
  [void]$fishCountMenu.DropDownItems.Add($countItem);$fishCountItems+=$countItem
  $countItem.Add_Click({
    $state.FishCount=[int]$this.Tag
    foreach($item in $fishCountItems){$item.Checked=([int]$item.Tag -eq $state.FishCount)}
    for($i=1;$i -lt $state.FishCount;$i++){if($fishies[$i].TargetX -le 0){& $pickFishTarget $fishies[$i]}}
    if($state.CarrierIndex -ge $state.FishCount){$state.CarrierIndex=0}
    if($state.Stealing -and $state.StealPhase -eq 'Carrying' -and $state.CarrierIndex -ge $state.FishCount){$state.StealPhase='Hunting'}
    $tank.Invalidate()
  })
}
$playPongItem=New-Object System.Windows.Forms.ToolStripMenuItem('Play cursor pong now (uses 2 fish)')
$exitItem = New-Object System.Windows.Forms.ToolStripMenuItem('Quit Fish Tank')
[void]$menu.Items.Add($awakeItem); [void]$menu.Items.Add($followItem); [void]$menu.Items.Add($clickItem); [void]$menu.Items.Add($tiltItem); [void]$menu.Items.Add($ambienceItem); [void]$menu.Items.Add($typingGrabItem); [void]$menu.Items.Add($mischiefItem); [void]$menu.Items.Add($chanceMenu); [void]$menu.Items.Add($fishCountMenu); [void]$menu.Items.Add($playPongItem)
[void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)); [void]$menu.Items.Add($exitItem)
$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Text = 'Fish Tank settings'
$tray.Icon = [System.Drawing.SystemIcons]::Information
$tray.ContextMenuStrip = $menu
$tray.Visible = $true
$tray.Add_Click({ if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) { $menu.Show([System.Windows.Forms.Cursor]::Position) } })
$exitItem.Add_Click({ $form.Close() })
$applyKeepAwake = { if($state.KeepAwake){[FishTankNative]::SetThreadExecutionState([uint32]2147483649) | Out-Null}else{[FishTankNative]::SetThreadExecutionState([uint32]2147483648) | Out-Null} }
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
  # The one-click game uses the real cursor as a puck and leaves it where the last body hit sends it.
  if($state.TypingSteal){$state.TypingSteal=$false;if($state.TypingForcedFollow){$state.TypingForcedFollow=$false;$followItem.PerformClick()}}
  & $startPongGame
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
  $g=$e.Graphics; $g.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $w=$sender.ClientSize.Width; $h=$sender.ClientSize.Height
  # Draw every selected fish with contrast sampled from the desktop behind it.
  if ($ambienceItem.Checked) {
    # Fine bubbles and soft glints drift gently through the transparent water.
    for($i=0;$i -lt 7;$i++) {
      $bx=[single](($i*137 + $state.Phase*(9+$i*2)) % [Math]::Max(1,$w))
      $by=[single]($h - (($state.Phase*(12+$i)+$i*53) % [Math]::Max(1,$h)))
      $r=3+($i%3)
      $p=New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(95,205,205,205),1)
      $g.DrawEllipse($p,$bx,$by,$r,$r); $p.Dispose()
    }
    $glint=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(85,224,224,224))
    for($i=0;$i -lt 4;$i++) { $x=[single](($i*179+$state.Phase*4)%[Math]::Max(1,$w)); $y=[single]($h-14-(($i*61)%[Math]::Max(1,$h-20))); $g.FillEllipse($glint,$x,$y,2,2) }
    $glint.Dispose()
  }
  $fishFont=New-Object System.Drawing.Font('Consolas',23,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
  for($fishIndex=0;$fishIndex -lt $state.FishCount;$fishIndex++){
    $fish=$fishies[$fishIndex];$fishInk=[System.Drawing.Color]::White
    try {
      $sampleAngle=$fish.Angle*[Math]::PI/180.0;$perpX=-[Math]::Sin($sampleAngle)*52;$perpY=[Math]::Cos($sampleAngle)*52
      $luminance=0.0;$sampleCount=0
      foreach($side in @(1,-1)){
        $sample=$tank.PointToScreen((New-Object System.Drawing.Point([int]($fish.X+43+$perpX*$side),[int]($fish.Y+14+$perpY*$side))))
        $visible=$false;foreach($monitor in [System.Windows.Forms.Screen]::AllScreens){if($monitor.Bounds.Contains($sample)){$visible=$true;break}}
        if($visible){$screenSampleGraphics.CopyFromScreen($sample,[System.Drawing.Point]::Empty,(New-Object System.Drawing.Size(1,1)));$pixel=$screenSampleBitmap.GetPixel(0,0);$luminance+=0.2126*$pixel.R+0.7152*$pixel.G+0.0722*$pixel.B;$sampleCount++}
      }
      if($sampleCount -gt 0 -and ($luminance/$sampleCount) -ge 128){$fishInk=[System.Drawing.Color]::Black}
    } catch { $fishInk=[System.Drawing.Color]::White }
    $fishBrush=New-Object System.Drawing.SolidBrush($fishInk)
    $fishText='<o))><';if($fish.Direction -gt 0){$fishText='><((o>'}
    $cx=[single]($fish.X+43);$cy=[single]($fish.Y+14)
    $g.TranslateTransform($cx,$cy)
    if(-not $state.Follow -or $state.Tilt -or ($fishIndex -eq 0 -and $state.PinnedCorner)){$g.RotateTransform([single]$fish.Angle)}
    $g.TranslateTransform(-$cx,-$cy);$g.DrawString($fishText,$fishFont,$fishBrush,[single]$fish.X,[single]$fish.Y);$g.ResetTransform();$fishBrush.Dispose()
    if($fishIndex -eq 0 -and [datetime]::UtcNow -lt $state.AngryUntil){$angerFont=New-Object System.Drawing.Font('Consolas',15,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel);$angerBrush=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::OrangeRed);$g.DrawString('!!',$angerFont,$angerBrush,[single]($fish.X+54),[single]($fish.Y-5));$angerFont.Dispose();$angerBrush.Dispose()}
    if($fishIndex -eq 0 -and [datetime]::UtcNow -lt $state.BlubUntil){$blubFont=New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold);$blubBrush=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(190,$fishInk.R,$fishInk.G,$fishInk.B));$g.DrawString('blub blub',$blubFont,$blubBrush,[single]($fish.X+20),[single]([Math]::Max(2,$fish.Y-19)));$blubFont.Dispose();$blubBrush.Dispose()}
  }
  $fishFont.Dispose()
})

# The transparent canvas lets clicks pass through; the fish glyph itself remains draggable.
$tank.Add_MouseDown({
  param($sender,$e)
  $buddyHitX=$e.X-($buddy.X+43);$buddyHitY=$e.Y-($buddy.Y+14)
  $fishHitX=$e.X-($state.X+43);$fishHitY=$e.Y-($state.Y+14)
  if($e.Button -eq [System.Windows.Forms.MouseButtons]::Left -and -not $state.ClickThrough){
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
  $now=[datetime]::UtcNow;$stealJustFinished=$false
  if(($now-$state.LastFocusCheck).TotalMilliseconds -ge 200){
    $state.TextFocused=$false
    try {
      $focused=[System.Windows.Automation.AutomationElement]::FocusedElement
      if($focused){$focusedType=$focused.Current.ControlType;$state.TextFocused=($focusedType -eq [System.Windows.Automation.ControlType]::Edit -or $focusedType -eq [System.Windows.Automation.ControlType]::Document)}
    } catch { $state.TextFocused=$false }
    $state.LastFocusCheck=$now
  }
  $typingNow=$false
  if($state.TypingGrabEnabled){
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
  $endDown=(([FishTankNative]::GetAsyncKeyState(0x23) -band 0x8000) -ne 0)
  if($endDown -and -not $state.EndWasDown -and -not $state.PongActive){& $startCursorSteal}
  $state.EndWasDown=$endDown
  $deleteDown=(([FishTankNative]::GetAsyncKeyState(0x2E) -band 0x8000) -ne 0)
  if($deleteDown -and -not $state.DeleteWasDown -and ($state.Stealing -or $state.PongActive)){
    if($state.PongActive){$state.PongActive=$false;$state.PongMode=$false;$state.PongOnly=$false;$stealJustFinished=$true}
    else{$state.Stealing=$false;$state.StealPhase='';$state.Physics=$true;$state.VelX=[Math]::Cos($state.Heading)*680;$state.VelY=[Math]::Sin($state.Heading)*680;$state.AngryUntil=$now.AddSeconds(5);$stealJustFinished=$true}
  }
  $state.DeleteWasDown=$deleteDown
  if($now -ge $state.NextBlub){
    $state.BlubUntil=$now.AddSeconds(1.35);$state.NextBlub=$now.AddSeconds($rng.Next(8,19))
    $blubPlayer.Play()
    if($state.StealEnabled -and -not $state.PongActive -and $rng.Next(100) -lt $state.StealChance){& $startCursorSteal}
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
    # Both fish swim toward the live cursor and rotate to match their actual travel direction.
    for($i=0;$i -lt 2;$i++){
      $f=$fishies[$i];$dx=$ballX-($f.X+43);$dy=$ballY-($f.Y+14);$desired=[Math]::Atan2($dy,$dx)
      $delta=[Math]::Atan2([Math]::Sin($desired-$f.Heading),[Math]::Cos($desired-$f.Heading));$f.Heading += [Math]::Max(-0.12,[Math]::Min(0.12,$delta))
      $f.Direction=if([Math]::Cos($f.Heading) -lt 0){-1}else{1};$distance=[Math]::Sqrt($dx*$dx+$dy*$dy);$speed=5.2+[Math]::Min(2.8,$distance*0.006)
      $f.X += [Math]::Cos($f.Heading)*$speed;$f.Y += [Math]::Sin($f.Heading)*$speed
      $f.X=[Math]::Max(5,[Math]::Min($tank.ClientSize.Width-92,$f.X));$f.Y=[Math]::Max(30,[Math]::Min($tank.ClientSize.Height-60,$f.Y))
      $f.Angle=[Math]::Atan2([Math]::Sin($f.Heading),[Math]::Cos($f.Heading))*180/[Math]::PI;if($f.Direction -lt 0){$f.Angle-=180}
    }
    $nextX=$ballX+$state.PongVX;$nextY=$ballY+$state.PongVY
    if($nextX -lt 8){$nextX=8;$state.PongVX=[Math]::Abs($state.PongVX)}elseif($nextX -gt $tank.ClientSize.Width-8){$nextX=$tank.ClientSize.Width-8;$state.PongVX=-[Math]::Abs($state.PongVX)}
    if($nextY -lt 8){$nextY=8;$state.PongVY=[Math]::Abs($state.PongVY)}elseif($nextY -gt $tank.ClientSize.Height-8){$nextY=$tank.ClientSize.Height-8;$state.PongVY=-[Math]::Abs($state.PongVY)}
    # The fish's long body is the paddle. Contact knocks the cursor puck toward the other fish.
    for($i=0;$i -lt 2;$i++){
      if($i -eq $state.PongLastHitIndex){continue}
      $f=$fishies[$i];$rx=$nextX-($f.X+43);$ry=$nextY-($f.Y+14);$along=$rx*[Math]::Cos($f.Heading)+$ry*[Math]::Sin($f.Heading);$across=-$rx*[Math]::Sin($f.Heading)+$ry*[Math]::Cos($f.Heading)
      if(([Math]::Pow($along/38.0,2)+[Math]::Pow($across/16.0,2)) -le 1){
        $opponent=$fishies[1-$i];$aimX=($opponent.X+43)-($f.X+43);$aimY=($opponent.Y+14)-($f.Y+14)+($rng.NextDouble()-0.5)*45;$aimLength=[Math]::Max(1,[Math]::Sqrt($aimX*$aimX+$aimY*$aimY));$speed=[Math]::Min(15.5,[Math]::Max(8.5,[Math]::Sqrt($state.PongVX*$state.PongVX+$state.PongVY*$state.PongVY)*1.06))
        $state.PongVX=($aimX/$aimLength)*$speed;$state.PongVY=($aimY/$aimLength)*$speed;$state.PongLastHitIndex=$i;$state.PongHits++
        if($state.PongHits -ge $state.PongHitLimit){$state.PongActive=$false;$state.PongMode=$false;$state.PongOnly=$false}
        break
      }
    }
    $px=[int]($origin.X+$nextX);$py=[int]($origin.Y+$nextY);[FishTankNative]::SetCursorPos($px,$py)|Out-Null
    $state.LastCursor=New-Object System.Drawing.Point($px,$py);$state.CursorStillSince=$now
    if($now -ge $state.PongEndsAt){$state.PongActive=$false;$state.PongMode=$false;$state.PongOnly=$false}
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
        $state.StealPhase='Carrying';$state.StealUntil=$now.AddSeconds($(if($state.PongMode){1.25}else{10}));$state.AngryUntil=$now.AddSeconds(2)
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
    $cursorMoving = ([datetime]::UtcNow-$state.CursorStillSince).TotalMilliseconds -le 600
    if($cursorMoving) {
      # While the user moves the pointer, swim toward it and keep looking at it.
      $tx=$cursor.X-$screen.Left; $ty=$cursor.Y-$screen.Top
      $dx=$tx-($state.X+43); $dy=$ty-($state.Y+14)
      $followStep=if([datetime]::UtcNow -lt $state.AngryUntil -or $state.Physics){12.0}else{5.0}
      $state.X += [Math]::Max(-$followStep,[Math]::Min($followStep,$dx*0.035))
      $state.Y += [Math]::Max(-$followStep,[Math]::Min($followStep,$dy*0.035))
      if([Math]::Abs($dx)+[Math]::Abs($dy) -gt 3){$state.Direction=if($dx -lt 0){-1}else{1}}
      $heading=[Math]::Atan2($dy,$dx)*180/[Math]::PI
      $state.Angle=$heading
      if($state.Direction -lt 0){$state.Angle-=180}
    } else {
      # When the pointer rests, roam freely across the full desktop-sized surface.
      $maxX=[Math]::Max(32,$tank.ClientSize.Width-105); $maxY=[Math]::Max(30,$tank.ClientSize.Height-48)
      if($state.TargetX -le 0 -or [Math]::Sqrt([Math]::Pow($state.TargetX-$state.X,2)+[Math]::Pow($state.TargetY-$state.Y,2)) -lt 32){
        $state.TargetX=24+$rng.NextDouble()*[Math]::Max(1,$maxX-24)
        $state.TargetY=24+$rng.NextDouble()*[Math]::Max(1,$maxY-24)
      }
      $dx=$state.TargetX-$state.X; $dy=$state.TargetY-$state.Y
      $desired=[Math]::Atan2($dy,$dx)
      $delta=[Math]::Atan2([Math]::Sin($desired-$state.Heading),[Math]::Cos($desired-$state.Heading))
      $state.Heading += [Math]::Max(-0.075,[Math]::Min(0.075,$delta))
      $roamSpeed=if([datetime]::UtcNow -lt $state.AngryUntil){6.8}else{3.2}
      $state.X += [Math]::Cos($state.Heading)*$roamSpeed
      $state.Y += [Math]::Sin($state.Heading)*$roamSpeed
      if($state.X -lt 18){$state.X=18;$state.TargetX=$maxX;$state.TargetY=24+$rng.Next([Math]::Max(1,[int]($maxY-24)))}
      elseif($state.X -gt $maxX){$state.X=$maxX;$state.TargetX=18;$state.TargetY=24+$rng.Next([Math]::Max(1,[int]($maxY-24)))}
      if($state.Y -lt 18){$state.Y=18;$state.TargetY=$maxY;$state.TargetX=24+$rng.Next([Math]::Max(1,[int]($maxX-24)))}
      elseif($state.Y -gt $maxY){$state.Y=$maxY;$state.TargetY=24;$state.TargetX=24+$rng.Next([Math]::Max(1,[int]($maxX-24)))}
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
  for($i=1;$i -lt $state.FishCount;$i++){$f=$fishies[$i];if(-not $state.PongActive -and -not $f.Dragging){
    $maxX=[Math]::Max(32,$tank.ClientSize.Width-105);$maxY=[Math]::Max(30,$tank.ClientSize.Height-48)
    if($f.TargetX -le 0 -or [Math]::Sqrt([Math]::Pow($f.TargetX-$f.X,2)+[Math]::Pow($f.TargetY-$f.Y,2)) -lt 32){& $pickFishTarget $f}
    $dx=$f.TargetX-$f.X;$dy=$f.TargetY-$f.Y;$desired=[Math]::Atan2($dy,$dx);$delta=[Math]::Atan2([Math]::Sin($desired-$f.Heading),[Math]::Cos($desired-$f.Heading))
    $f.Heading += [Math]::Max(-0.07,[Math]::Min(0.07,$delta));$f.X += [Math]::Cos($f.Heading)*$f.Speed;$f.Y += [Math]::Sin($f.Heading)*$f.Speed
    $f.X=[Math]::Max(5,[Math]::Min($tank.ClientSize.Width-92,$f.X));$f.Y=[Math]::Max(30,[Math]::Min($tank.ClientSize.Height-60,$f.Y))
    if($f.X -le 5 -or $f.X -ge $tank.ClientSize.Width-92 -or $f.Y -le 30 -or $f.Y -ge $tank.ClientSize.Height-60){& $pickFishTarget $f}
    $f.Direction=if([Math]::Cos($f.Heading) -lt 0){-1}else{1};$f.Angle=[Math]::Atan2([Math]::Sin($f.Heading),[Math]::Cos($f.Heading))*180/[Math]::PI
    if($f.Direction -lt 0){$f.Angle-=180};if($f.Angle -gt 180){$f.Angle-=360};if($f.Angle -lt -180){$f.Angle+=360}
  }}
  $tank.Invalidate()
})

$form.Add_Shown({
  $style=[FishTankNative]::GetStyle($form.Handle,-20)
  $style=$style -band (-bnot (0x20 -bor 0x8000000))
  if($state.ClickThrough){$style=$style -bor 0x20}
  if($state.ClickThrough){$style=$style -bor 0x8000000}
  [FishTankNative]::SetStyle($form.Handle,-20,$style)
  if($state.KeepAwake){[FishTankNative]::SetThreadExecutionState([uint32]2147483649) | Out-Null}
  & $pickRoamTarget
  foreach($f in $fishies[1..3]){$f.X=[Math]::Max(18,[Math]::Min($tank.ClientSize.Width-105,$f.X));$f.Y=[Math]::Max(18,[Math]::Min($tank.ClientSize.Height-48,$f.Y));& $pickFishTarget $f}
  $timer.Start()
})
$form.Add_FormClosed({ [FishTankNative]::SetThreadExecutionState([uint32]2147483648) | Out-Null;$timer.Stop();$timer.Dispose();$tray.Visible=$false;$tray.Dispose();$menu.Dispose();$blubPlayer.Stop();$blubPlayer.Dispose();$blubStream.Dispose();$writer.Dispose();$wav.Dispose();$screenSampleGraphics.Dispose();$screenSampleBitmap.Dispose() })
[void]$form.ShowDialog()

