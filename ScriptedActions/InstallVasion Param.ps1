param(
    [Parameter(Mandatory=$true)]
    [string]$HomeUrl,

    [Parameter(Mandatory=$true)]
    [string]$AuthCode,

    [Parameter(Mandatory=$true)]
    [string]$MsiSource
)

# --- Configuration ---
$LogDir  = "C:\Temp"
$LogPath = Join-Path $LogDir "VasionClientInstall.log"
$LocalMsi = Join-Path $env:TEMP "PrinterInstallerClient.msi"

Write-Output "Starting Vasion client deployment..."
Write-Output "HomeUrl: $HomeUrl"
Write-Output "MSI Source: $MsiSource"

# --- Ensure log directory exists ---
if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

# --- Stage MSI locally ---
try {
    if ($MsiSource -match '^https?://') {
        Write-Output "Downloading MSI from HTTPS source..."
        Invoke-WebRequest -Uri $MsiSource -OutFile $LocalMsi -UseBasicParsing
    }
    else {
        Write-Output "Copying MSI from UNC path..."
        Copy-Item -Path $MsiSource -Destination $LocalMsi -Force
    }
}
catch {
    Write-Error "Failed to retrieve MSI from '$MsiSource'. $_"
    exit 1
}

# --- Check if already installed ---
$ExistingInstall = Get-WmiObject -Class Win32_Product |
    Where-Object { $_.Name -like "*PrinterInstallerClient*" }

if ($ExistingInstall) {
    Write-Output "Vasion client appears to already be installed. Skipping installation."
    exit 0
}

# --- Execute silent install ---
$Arguments = "/i `"$LocalMsi`" /qn HOMEURL=$HomeUrl AUTHORIZATION_CODE=$AuthCode /l*v `"$LogPath`""

Write-Output "Running silent installation..."
$Process = Start-Process -FilePath "msiexec.exe" -ArgumentList $Arguments -Wait -PassThru

if ($Process.ExitCode -ne 0) {
    Write-Error "Installation failed with exit code $($Process.ExitC
