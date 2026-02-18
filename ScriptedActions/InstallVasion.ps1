# --- CONFIG: set these three values ---
$HomeUrl = "https://YOUR_INSTANCE_URL"         # Vasion/PrinterLogic HOMEURL
$AuthCode = "PASTE_AUTHORIZATION_CODE_HERE"    # Vasion/PrinterLogic AUTHORIZATION_CODE
$MsiSource = "https://downloads.printercloud.com/client/setup/PrinterInstallerClient.msi"  # Option A: UNC path to MSI
# $MsiSource = "https://your-internal-url/PrinterInstallerClient.msi" # Option B: HTTPS

# --- Optional logging ---
$LogDir = "C:\Temp"
$LogPath = Join-Path $LogDir "VasionClientInstall.log"

# --- Ensure log folder exists ---
if (-not (Test-Path $LogDir)) { New-Item -Path $LogDir -ItemType Directory -Force | Out-Null }

# --- Stage MSI locally (best practice for reliability) ---
$LocalMsi = Join-Path $env:TEMP "PrinterInstallerClient.msi"

try {
    if ($MsiSource -match '^https?://') {
        Invoke-WebRequest -Uri $MsiSource -OutFile $LocalMsi -UseBasicParsing
    } else {
        Copy-Item -Path $MsiSource -Destination $LocalMsi -Force
    }
}
catch {
    Write-Error "Failed to retrieve MSI from '$MsiSource'. $_"
    exit 1
}

# --- Run silent install (Vasion-documented properties) ---
$Args = "/i `"$LocalMsi`" /qn HOMEURL=$HomeUrl AUTHORIZATION_CODE=$AuthCode /l*v `"$LogPath`""

$proc = Start-Process -FilePath "msiexec.exe" -ArgumentList $Args -Wait -PassThru
if ($proc.ExitCode -ne 0) {
    Write-Error "Vasion client install failed with exit code $($proc.ExitCode). See log: $LogPath"
    exit $proc.ExitCode
}

Write-Output "Vasion client installed successfully. Log: $LogPath"
