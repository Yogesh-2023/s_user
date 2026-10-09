Add-Type -AssemblyName System.Drawing

$files = Get-ChildItem "assets\images\*.png"

foreach ($file in $files) {
    try {
        $bmp = New-Object System.Drawing.Bitmap($file.FullName)
        $p00 = $bmp.GetPixel(0, 0)
        $pTopRight = $bmp.GetPixel($bmp.Width - 1, 0)
        $pBotLeft = $bmp.GetPixel(0, $bmp.Height - 1)
        $pBotRight = $bmp.GetPixel($bmp.Width - 1, $bmp.Height - 1)

        $isWhiteTopLeft = ($p00.A -gt 200) -and ($p00.R -gt 230) -and ($p00.G -gt 230) -and ($p00.B -gt 230)

        Write-Host "$($file.Name) : TopLeft=(A=$($p00.A), R=$($p00.R), G=$($p00.G), B=$($p00.B)) | isWhiteBg=$isWhiteTopLeft"
        $bmp.Dispose()
    } catch {
        Write-Host "Error reading $($file.Name): $_"
    }
}
