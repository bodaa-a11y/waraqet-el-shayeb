param(
  [string]$SourceImage = (Join-Path $PSScriptRoot "..\assets\images\logo\waraqet_el_shayeb_logo.png"),
  [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

function New-RoundedRectPath([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = $r * 2
  $path.AddArc($x, $y, $d, $d, 180, 90)
  $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
  $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
  $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
  $path.CloseFigure()
  return $path
}

function Save-MaskedLogoPng {
  param(
    [System.Drawing.Image]$Src,
    [string]$OutPath,
    [int]$CanvasSize,
    [int]$ContentSize,
    [ValidateSet("rounded", "circle")]$MaskShape = "rounded",
    [string]$BgHex = "",
    [bool]$GoldBorder = $false
  )
  $dir = Split-Path -Parent $OutPath
  if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }

  $bmp = New-Object System.Drawing.Bitmap($CanvasSize, $CanvasSize, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  try {
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

    if ([string]::IsNullOrEmpty($BgHex)) {
      $g.Clear([System.Drawing.Color]::Transparent)
    } else {
      $bgColor = [System.Drawing.ColorTranslator]::FromHtml($BgHex)
      $g.Clear($bgColor)
    }

    $margin = ($CanvasSize - $ContentSize) / 2.0
    # Slight inset from source JPG corners (4px on 1024px) prevents black bleed-through.
    $srcInset = 4.0
    $srcRect = New-Object System.Drawing.RectangleF($srcInset, $srcInset, ($Src.Width - 2 * $srcInset), ($Src.Height - 2 * $srcInset))
    $dstRect = New-Object System.Drawing.RectangleF($margin, $margin, $ContentSize, $ContentSize)

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    if ($MaskShape -eq "circle") {
      $path.AddEllipse($margin, $margin, $ContentSize, $ContentSize)
    } else {
      $path.Dispose()
      $radius = [float]($ContentSize * 0.185)
      $path = New-RoundedRectPath $margin $margin $ContentSize $ContentSize $radius
    }

    $state = $g.Save()
    $g.SetClip($path)
    $g.DrawImage($Src, $dstRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    $g.Restore($state)

    if ($GoldBorder) {
      $penWidth = [Math]::Max(1.5, ($ContentSize * 0.02))
      $gold = [System.Drawing.Color]::FromArgb(245, 217, 164, 65)
      $pen = New-Object System.Drawing.Pen($gold, $penWidth)
      $g.DrawPath($pen, $path)
      $pen.Dispose()
    }
    $path.Dispose()

    $bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
  } finally {
    $g.Dispose()
    $bmp.Dispose()
  }
}

$srcImg = [System.Drawing.Image]::FromFile($SourceImage)
try {
  # 1. Flutter hero & splash logo asset (transparent rounded corners)
  Save-MaskedLogoPng -Src $srcImg -OutPath (Join-Path $ProjectRoot "assets\images\logo\waraqet_el_shayeb_logo.png") -CanvasSize 768 -ContentSize 764 -MaskShape "rounded" -GoldBorder $false

  # 2. Android legacy icons (5 densities) — square rounded & circular
  $densities = @{
    "mipmap-mdpi"    = 48
    "mipmap-hdpi"    = 72
    "mipmap-xhdpi"   = 96
    "mipmap-xxhdpi"  = 144
    "mipmap-xxxhdpi" = 192
  }
  foreach ($d in $densities.GetEnumerator()) {
    $sz = $d.Value
    $resDir = Join-Path $ProjectRoot "android\app\src\main\res\$($d.Key)"
    Save-MaskedLogoPng -Src $srcImg -OutPath (Join-Path $resDir "ic_launcher.png") -CanvasSize $sz -ContentSize ([int][Math]::Round($sz * 0.94)) -MaskShape "rounded" -GoldBorder $false
    Save-MaskedLogoPng -Src $srcImg -OutPath (Join-Path $resDir "ic_launcher_round.png") -CanvasSize $sz -ContentSize ([int][Math]::Round($sz * 0.94)) -MaskShape "circle" -GoldBorder $true
  }

  # 3. Android 8.0+ Adaptive Icon foreground (66% safe zone inside 432x432) & native splash
  Save-MaskedLogoPng -Src $srcImg -OutPath (Join-Path $ProjectRoot "android\app\src\main\res\drawable\ic_launcher_foreground.png") -CanvasSize 432 -ContentSize 292 -MaskShape "rounded" -GoldBorder $false
  Save-MaskedLogoPng -Src $srcImg -OutPath (Join-Path $ProjectRoot "android\app\src\main\res\drawable\splash_logo.png") -CanvasSize 320 -ContentSize 308 -MaskShape "rounded" -GoldBorder $false

  # 4. Web / PWA icons
  Save-MaskedLogoPng -Src $srcImg -OutPath (Join-Path $ProjectRoot "web\favicon.png") -CanvasSize 64 -ContentSize 62 -MaskShape "rounded" -GoldBorder $false
  Save-MaskedLogoPng -Src $srcImg -OutPath (Join-Path $ProjectRoot "web\icons\Icon-192.png") -CanvasSize 192 -ContentSize 186 -MaskShape "rounded" -GoldBorder $false
  Save-MaskedLogoPng -Src $srcImg -OutPath (Join-Path $ProjectRoot "web\icons\Icon-512.png") -CanvasSize 512 -ContentSize 496 -MaskShape "rounded" -GoldBorder $false
  Save-MaskedLogoPng -Src $srcImg -OutPath (Join-Path $ProjectRoot "web\icons\Icon-maskable-192.png") -CanvasSize 192 -ContentSize 150 -MaskShape "rounded" -BgHex "#170B06" -GoldBorder $false
  Save-MaskedLogoPng -Src $srcImg -OutPath (Join-Path $ProjectRoot "web\icons\Icon-maskable-512.png") -CanvasSize 512 -ContentSize 400 -MaskShape "rounded" -BgHex "#170B06" -GoldBorder $false

  Write-Output "Branding PNG assets generated successfully."
} finally {
  $srcImg.Dispose()
}
