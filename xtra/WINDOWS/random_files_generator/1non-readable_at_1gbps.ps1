<#
.SYNOPSIS
    Random File Generator For Windows
.DESCRIPTION
    Creates random files with random sizes and extensions until total size is reached.
    Small files use random bytes; large files use zero-filled (dummy) data for performance.
    reach upto 1 Gbps
#>
Write-Host "                 if prompt not appears then see in taskbar with flashing icon of"
Write-Host "                 POWERSHELL click on that and choose directory for files generation."
# # M1-give full path in terminal

<# --- Default output directory: where the script runs ---
$DefaultOutputDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# --- Ask user for output directory ---
$OutputDirInput = Read-Host "Enter output directory (press Enter for default: $DefaultOutputDir)"

# --- Use default if input is empty ---
if ([string]::IsNullOrWhiteSpace($OutputDirInput)) {
    $OutputDir = $DefaultOutputDir
} else {
    $OutputDir = $OutputDirInput
}
#>

# # M2-opens selection bar
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# Default folder is where the script runs
$DefaultOutputDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# --- Create a temporary topmost PowerShell window to bring File Explorer in front ---
$topmostWindow = New-Object System.Windows.Forms.Form
$topmostWindow.TopMost = $true
$topmostWindow.Show()
$topmostWindow.Focus()
Start-Sleep -Milliseconds 100  # allow it to grab focus

# --- Create full-size File Explorer–style folder selector ---
$folderDialog = New-Object Microsoft.Win32.OpenFileDialog
$folderDialog.CheckFileExists = $false
$folderDialog.CheckPathExists = $true
$folderDialog.ValidateNames = $false
$folderDialog.FileName = "Select this folder"
$folderDialog.Title = "Select where to generate random files"
$folderDialog.InitialDirectory = $DefaultOutputDir

# --- Show dialog ---
$result = $folderDialog.ShowDialog()

# --- Dispose the topmost window ---
$topmostWindow.Close()
$topmostWindow.Dispose()

# --- Process selection ---
if ($result -eq $true) {
    $OutputDir = Split-Path $folderDialog.FileName
} else {
    # User cancelled → ask for full path in CMD
    $OutputDirInput = Read-Host "No folder selected. Enter output directory (press Enter to use default: $DefaultOutputDir)"
    if ([string]::IsNullOrWhiteSpace($OutputDirInput)) {
        $OutputDir = $DefaultOutputDir
    } else {
        $OutputDir = $OutputDirInput
    }
}

# --- Make timestamped subfolder ---
$OutputDir = Join-Path $OutputDir ("files_{0:yyyyMMdd_HHmmss}" -f (Get-Date))
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
Write-Host "Files will be created in: $OutputDir"
Write-Host ""

## SHOW DISK DETAILS
Write-Host "Available Storage:" -ForegroundColor Cyan
Write-Host "-------------------------------------------------------------"
$header = "{0,-10} {1,-15} {2,-20} {3,-20} {4,-20} {5,-10}"
Write-Host ($header -f "Drive", "Label", "Total", "Used", "Free", "FS") -ForegroundColor Yellow
Write-Host "-------------------------------------------------------------"

Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    try {
        $volume = Get-Volume -DriveLetter $_.Name -ErrorAction Stop

        $total = [math]::Round($volume.Size / 1GB, 2)
        $free  = [math]::Round($volume.SizeRemaining / 1GB, 2)
        $used  = [math]::Round(($volume.Size - $volume.SizeRemaining) / 1GB, 2)


        # Choose color based on free space
        $color = if ($free -lt 5) { "Red" } elseif ($free -lt 20) { "Yellow" } else { "Green" }

        $output = "{0,-10} {1,-15} {2,-20} {3,-20} {4,-20} {5,-10}" -f `
            $_.Name, $volume.VolumeLabel, "$total GB", "$used GB", "$free GB", $volume.FileSystem

        Write-Host $output -ForegroundColor $color
    }
    catch {
        Write-Host ("{0,-10} {1,-15} {2,-20} {3,-20} {4,-20} {5,-10}" -f `
            $_.Name, "N/A", "N/A", "N/A", "N/A", "N/A") -ForegroundColor DarkGray
    }
}
Write-Host "-------------------------------------------------------------`n"

<# # SHOW DISK DETAILS
# Print headers with fixed column width
$header = "{0,-15} {1,-10} {2,-25} {3,-25} {4,-25} {5,-10}"
Write-Host ($header -f "Mounted at", "Label", "Total", "Used", "Left", "Filesystem")

# Fetch disk details and display
Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    $drive = $_

    # Get disk details using Get-Volume
    $volume = Get-Volume -DriveLetter $drive.Name

    $label = $volume.VolumeLabel
    $filesystem = $volume.FileSystem
    $total_size = $volume.Size
    $used_space = $volume.UsedSpace
    $free_space = $volume.SizeRemaining
    
    # Convert bytes to GB and MB
    $total_size_gb = [math]::round($total_size / 1GB, 2)
    $used_gb = [math]::round($used_space / 1GB, 2)
    $free_gb = [math]::round($free_space / 1GB, 2)

    $total_size_mb = [math]::round($total_size / 1MB, 2)
    $used_mb = [math]::round($used_space / 1MB, 2)
    $free_mb = [math]::round($free_space / 1MB, 2)

    # Print disk data in aligned columns with both GB and MB
    $output = "{0,-15} {1,-10} {2,-25} {3,-25} {4,-25} {5,-10}"
    Write-Host ($output -f $drive.Name, $label, "$total_size_gb GB ($total_size_mb MB)", "$used_gb GB ($used_mb MB)", "$free_gb GB ($free_mb MB)", $filesystem)
}#>

write-Host ""
$osDrive = $env:SystemDrive  # Usually "C:"

$volume = Get-Volume -DriveLetter $osDrive.TrimEnd(':')
$totalGB = [math]::Round($volume.Size / 1GB, 2)
$freeGB  = [math]::Round($volume.SizeRemaining / 1GB, 2)
$usedGB  = [math]::Round(($volume.Size - $volume.SizeRemaining) / 1GB, 2)

Write-Host "          Total space in $osDrive Drive = $totalGB GB"
Write-Host "         Free space in $osDrive Drive = $freeGB GB | Used space = $usedGB GB"

Write-Host ""
# --- User Input ---
$TotalSize = Read-Host "Enter total size to generate (e.g. 10MB, 1GB)"
$MinSize   = Read-Host "Enter minimum file size (e.g. 10KB, 100KB)"
$MaxSize   = Read-Host "Enter maximum file size (e.g. 100KB, 10MB)"

# --- Convert sizes to bytes ---
function Convert-ToBytes($size) {
    $size = $size.Trim().ToUpper()
    if ($size -match '^(\d+)\s*([KMG][B]?)$') {
        $n = [int]$matches[1]
        switch ($matches[2]) {
            'K'  { return $n * 1KB }
            'KB' { return $n * 1KB }
            'M'  { return $n * 1MB }
            'MB' { return $n * 1MB }
            'G'  { return $n * 1GB }
            'GB' { return $n * 1GB }
        }
    } else {
        throw "Invalid size format '$size'. Use 10KB, 10MB, 1GB, etc."
    }
}

try {
    $TotalBytes = Convert-ToBytes $TotalSize
    $MinBytes   = Convert-ToBytes $MinSize
    $MaxBytes   = Convert-ToBytes $MaxSize
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

if ($MinBytes -gt $MaxBytes) {
    Write-Host "Error: Minimum file size cannot be greater than maximum file size." -ForegroundColor Red
    exit 1
}
if ($TotalBytes -lt $MinBytes) {
    Write-Host "Error: Total size must be larger than the minimum file size." -ForegroundColor Red
    exit 1
}

# --- File extensions ---
$FileTypes = @(
    "txt","csv","log","md","rtf","pdf","doc","docx","odt","xls","xlsx","ods","ppt","pptx","odp","html","htm","xml","json","yaml","yml","tex",
    "sh","bat","exe","apk","jar","py","pl","rb","js","php",
    "png","jpg","jpeg","gif","bmp","tiff","svg","webp","ico","heic",
    "mp3","wav","flac","aac","ogg","m4a","wma",
    "mp4","mov","avi","mkv","webm","flv","wmv","mpeg","3gp",
    "zip","tar","gz","bz2","7z","rar","xz","iso",
    "dat","bin","tmp","cfg","ini"
)

# --- Counters ---
$CurrentBytes = 0
$FileCount = 0
$StartTime = Get-Date

Write-Host "`nGenerating random files..."

# --- Helper: readable sizes ---
function Format-Size($bytes) {
    if ($bytes -ge 1GB) { return ("{0:N2} GB" -f ($bytes / 1GB)) }
    elseif ($bytes -ge 1MB) { return ("{0:N2} MB" -f ($bytes / 1MB)) }
    elseif ($bytes -ge 1KB) { return ("{0:N2} KB" -f ($bytes / 1KB)) }
    else { return "$bytes bytes" }
}

# --- Threshold for hybrid behavior (anything <= 5MB = random bytes) ---
$RandomThreshold = 5MB
$RandomGen = [System.Random]::new()

# --- Main Loop ---
while ($CurrentBytes -lt $TotalBytes) {
    # Random name + extension
    $FileName = -join ((48..57 + 65..90 + 97..122) | Get-Random -Count 8 | ForEach-Object {[char]$_})
    $Extension = Get-Random -InputObject $FileTypes
    $Path = Join-Path $OutputDir "$FileName.$Extension"

    # Random file size
    $FileSize = Get-Random -Minimum $MinBytes -Maximum $MaxBytes
    $Remaining = $TotalBytes - $CurrentBytes
    if ($FileSize -gt $Remaining) { $FileSize = $Remaining }

    # content creation
    if ($FileSize -le $RandomThreshold) {
        # Small file → random bytes
        $bytes = New-Object byte[] $FileSize
        $RandomGen.NextBytes($bytes)
        [System.IO.File]::WriteAllBytes($Path, $bytes)
    } else {
        # Large file → zero-filled dummy
        $stream = [System.IO.File]::Create($Path)
        $stream.SetLength($FileSize)
        $stream.Close()
    }

    # Update counters
    $CurrentBytes += $FileSize
    $FileCount++

    # Progress bar
    $percent = [math]::Round(($CurrentBytes / $TotalBytes) * 100, 2)
    Write-Progress -Activity "Generating files..." -Status "$percent% Complete ($FileName.$Extension, $(Format-Size $FileSize))" -PercentComplete $percent
}

# --- Done ---
$Elapsed = (Get-Date) - $StartTime
Write-Progress -Activity "Generating files..." -Completed -Status "Done!"
Write-Host "`n--------------------------------------------"
Write-Host "Finished!"
Write-Host "Files created: $FileCount"
Write-Host "Total size   : $(Format-Size $CurrentBytes)"
Write-Host "Output dir   : $OutputDir"
Write-Host ("Time elapsed : {0:hh\:mm\:ss}" -f $Elapsed)
Write-Host "--------------------------------------------"
