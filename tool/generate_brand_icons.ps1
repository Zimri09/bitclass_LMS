param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$SourcePath
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$repoRoot = Split-Path -Parent $PSScriptRoot
$source = [System.Drawing.Image]::FromFile((Resolve-Path -LiteralPath $SourcePath))

function New-BrandPng {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Size,
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    $destination = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
        $OutputPath
    }
    else {
        Join-Path $repoRoot $OutputPath
    }
    $directory = Split-Path -Parent $destination
    [System.IO.Directory]::CreateDirectory($directory) | Out-Null

    $cropSize = [Math]::Min($source.Width, $source.Height)
    $cropX = [int](($source.Width - $cropSize) / 2)
    $cropY = [int](($source.Height - $cropSize) / 2)
    $sourceRect = [System.Drawing.Rectangle]::new(
        $cropX,
        $cropY,
        $cropSize,
        $cropSize
    )

    $bitmap = [System.Drawing.Bitmap]::new(
        $Size,
        $Size,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

    try {
        $graphics.Clear([System.Drawing.Color]::Black)
        $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.DrawImage(
            $source,
            [System.Drawing.Rectangle]::new(0, 0, $Size, $Size),
            $sourceRect,
            [System.Drawing.GraphicsUnit]::Pixel
        )
        $bitmap.Save($destination, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

function Get-BrandPngBytes {
    param([Parameter(Mandatory = $true)][int]$Size)

    $temporaryFile = Join-Path ([System.IO.Path]::GetTempPath()) (
        'bitclass-logo-{0}-{1}.png' -f $Size, [System.Guid]::NewGuid()
    )
    try {
        New-BrandPng -Size $Size -OutputPath $temporaryFile
        return [System.IO.File]::ReadAllBytes($temporaryFile)
    }
    finally {
        Remove-Item -LiteralPath $temporaryFile -Force -ErrorAction SilentlyContinue
    }
}

function New-WindowsIcon {
    param([Parameter(Mandatory = $true)][string]$OutputPath)

    $sizes = @(16, 32, 48, 256)
    $images = foreach ($size in $sizes) {
        [pscustomobject]@{
            Size = $size
            Data = @(Get-BrandPngBytes -Size $size)
        }
    }

    $destination = Join-Path $repoRoot $OutputPath
    [System.IO.Directory]::CreateDirectory((Split-Path -Parent $destination)) | Out-Null
    $stream = [System.IO.File]::Create($destination)
    $writer = [System.IO.BinaryWriter]::new($stream)

    try {
        $writer.Write([uint16]0)
        $writer.Write([uint16]1)
        $writer.Write([uint16]$images.Count)

        $offset = 6 + (16 * $images.Count)
        foreach ($image in $images) {
            $dimension = if ($image.Size -eq 256) { 0 } else { $image.Size }
            $writer.Write([byte]$dimension)
            $writer.Write([byte]$dimension)
            $writer.Write([byte]0)
            $writer.Write([byte]0)
            $writer.Write([uint16]1)
            $writer.Write([uint16]32)
            $writer.Write([uint32]$image.Data.Count)
            $writer.Write([uint32]$offset)
            $offset += $image.Data.Count
        }

        foreach ($image in $images) {
            $writer.Write([byte[]]$image.Data)
        }
    }
    finally {
        $writer.Dispose()
        $stream.Dispose()
    }
}

try {
    New-BrandPng -Size 1024 -OutputPath 'assets/branding/bitclass_logo.png'
    New-BrandPng -Size 1024 -OutputPath 'apps/admin_web/assets/branding/bitclass_logo.png'

    foreach ($webRoot in @('web', 'apps/admin_web/web')) {
        New-BrandPng -Size 64 -OutputPath "$webRoot/favicon.png"
        New-BrandPng -Size 192 -OutputPath "$webRoot/icons/Icon-192.png"
        New-BrandPng -Size 512 -OutputPath "$webRoot/icons/Icon-512.png"
        New-BrandPng -Size 192 -OutputPath "$webRoot/icons/Icon-maskable-192.png"
        New-BrandPng -Size 512 -OutputPath "$webRoot/icons/Icon-maskable-512.png"
    }

    $androidIcons = [ordered]@{
        'android/app/src/main/res/mipmap-mdpi/ic_launcher.png' = 48
        'android/app/src/main/res/mipmap-hdpi/ic_launcher.png' = 72
        'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png' = 96
        'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png' = 144
        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png' = 192
    }
    foreach ($entry in $androidIcons.GetEnumerator()) {
        New-BrandPng -Size $entry.Value -OutputPath $entry.Key
    }

    $iosIcons = [ordered]@{
        'Icon-App-20x20@1x.png' = 20
        'Icon-App-20x20@2x.png' = 40
        'Icon-App-20x20@3x.png' = 60
        'Icon-App-29x29@1x.png' = 29
        'Icon-App-29x29@2x.png' = 58
        'Icon-App-29x29@3x.png' = 87
        'Icon-App-40x40@1x.png' = 40
        'Icon-App-40x40@2x.png' = 80
        'Icon-App-40x40@3x.png' = 120
        'Icon-App-60x60@2x.png' = 120
        'Icon-App-60x60@3x.png' = 180
        'Icon-App-76x76@1x.png' = 76
        'Icon-App-76x76@2x.png' = 152
        'Icon-App-83.5x83.5@2x.png' = 167
        'Icon-App-1024x1024@1x.png' = 1024
    }
    $iosRoot = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    foreach ($entry in $iosIcons.GetEnumerator()) {
        New-BrandPng -Size $entry.Value -OutputPath "$iosRoot/$($entry.Key)"
    }

    foreach ($size in @(16, 32, 64, 128, 256, 512, 1024)) {
        New-BrandPng -Size $size -OutputPath (
            "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$size.png"
        )
    }

    New-WindowsIcon -OutputPath 'windows/runner/resources/app_icon.ico'
}
finally {
    $source.Dispose()
}

Write-Output 'BitClass brand icons generated successfully.'
