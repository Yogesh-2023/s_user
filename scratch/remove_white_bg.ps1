Add-Type -AssemblyName System.Drawing

function Remove-WhiteBackground {
    param (
        [string]$filePath,
        [int]$threshold = 230
    )

    $fullPath = (Get-Item $filePath).FullName
    $bmp = New-Object System.Drawing.Bitmap($fullPath)
    $width = $bmp.Width
    $height = $bmp.Height

    $newBmp = New-Object System.Drawing.Bitmap($width, $height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($newBmp)
    $g.DrawImage($bmp, 0, 0, $width, $height)
    $g.Dispose()
    $bmp.Dispose()

    $visited = New-Object 'bool[,]' $width, $height
    $queue = New-Object System.Collections.Queue

    # Add all 4 borders
    for ($x = 0; $x -lt $width; $x++) {
        foreach ($y in @(0, ($height - 1))) {
            $c = $newBmp.GetPixel($x, $y)
            if ($c.A -gt 100 -and $c.R -ge $threshold -and $c.G -ge $threshold -and $c.B -ge $threshold) {
                if (-not $visited[$x, $y]) {
                    $visited[$x, $y] = $true
                    $queue.Enqueue(@($x, $y))
                }
            }
        }
    }
    for ($y = 0; $y -lt $height; $y++) {
        foreach ($x in @(0, ($width - 1))) {
            $c = $newBmp.GetPixel($x, $y)
            if ($c.A -gt 100 -and $c.R -ge $threshold -and $c.G -ge $threshold -and $c.B -ge $threshold) {
                if (-not $visited[$x, $y]) {
                    $visited[$x, $y] = $true
                    $queue.Enqueue(@($x, $y))
                }
            }
        }
    }

    $dirs = @(
        @(-1, 0), @(1, 0), @(0, -1), @(0, 1)
    )

    $transparentColor = [System.Drawing.Color]::FromArgb(0, 0, 0, 0)
    $count = 0

    while ($queue.Count -gt 0) {
        $pt = $queue.Dequeue()
        $cx = $pt[0]
        $cy = $pt[1]

        $newBmp.SetPixel($cx, $cy, $transparentColor)
        $count++

        foreach ($d in $dirs) {
            $nx = $cx + $d[0]
            $ny = $cy + $d[1]

            if ($nx -ge 0 -and $nx -lt $width -and $ny -ge 0 -and $ny -lt $height) {
                if (-not $visited[$nx, $ny]) {
                    $c = $newBmp.GetPixel($nx, $ny)
                    if ($c.A -gt 100 -and $c.R -ge $threshold -and $c.G -ge $threshold -and $c.B -ge $threshold) {
                        $visited[$nx, $ny] = $true
                        $queue.Enqueue(@($nx, $ny))
                    }
                }
            }
        }
    }

    $tempPath = $fullPath + ".tmp.png"
    $newBmp.Save($tempPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $newBmp.Dispose()

    Remove-Item $fullPath -Force
    Move-Item $tempPath $fullPath -Force

    Write-Host "Processed $(Split-Path $fullPath -Leaf): Removed $count white pixels."
}

$targetFiles = @(
    "ridenew.png",
    "Intercity1.png",
    "Rental1.png",
    "truck.png",
    "1Favorites.png",
    "1History.png",
    "1Ride Now.png",
    "1Schedule.png"
)

foreach ($f in $targetFiles) {
    $p = Join-Path "assets\images" $f
    if (Test-Path $p) {
        $thresh = if ($f -eq "truck.png") { 215 } else { 230 }
        Remove-WhiteBackground -filePath $p -threshold $thresh
    }
}
