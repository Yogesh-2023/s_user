Add-Type -AssemblyName System.Drawing

$images = @("ridenew.png", "Intercity1.png", "Bike1.png", "rickshawnew.png", "suvnew.png", "rentalsnew.png", "Schedule1.png", "Rental1.png", "truck.png", "Parcel1.png")

foreach ($imgName in $images) {
    $filePath = Join-Path "assets\images" $imgName
    if (Test-Path $filePath) {
        $fullPath = (Get-Item $filePath).FullName
        $bmp = [System.Drawing.Bitmap]::FromFile($fullPath)
        $p0 = $bmp.GetPixel(0, 0)
        $pCenter = $bmp.GetPixel([int]($bmp.Width/2), [int]($bmp.Height/2))
        Write-Host "$imgName : Size=$($bmp.Width)x$($bmp.Height) | TopLeft (A=$($p0.A), R=$($p0.R), G=$($p0.G), B=$($p0.B)) | Center (A=$($pCenter.A), R=$($pCenter.R), G=$($pCenter.G), B=$($pCenter.B))"
        $bmp.Dispose()
    } else {
        Write-Host "$imgName : FILE NOT FOUND"
    }
}
