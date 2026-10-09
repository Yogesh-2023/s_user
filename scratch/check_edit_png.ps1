Add-Type -AssemblyName System.Drawing

$filePath = Join-Path "assets\images" "edit.png"
if (Test-Path $filePath) {
    $fullPath = (Get-Item $filePath).FullName
    $bmp = [System.Drawing.Bitmap]::FromFile($fullPath)
    $p0 = $bmp.GetPixel(0, 0)
    Write-Host "edit.png Size=$($bmp.Width)x$($bmp.Height) | TopLeft (A=$($p0.A), R=$($p0.R), G=$($p0.G), B=$($p0.B))"
    $bmp.Dispose()
}
