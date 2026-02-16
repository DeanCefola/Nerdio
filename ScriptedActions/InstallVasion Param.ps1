param(
    [Parameter(Mandatory = $true)]
    [string]$HomeUrl,

    [Parameter(Mandatory = $true)]
    [string]$AuthCode,

    [Parameter(Mandatory = $true)]
    [string]$MsiSource
)

$ErrorActionPreference = "Stop"

# --- Logging ---
$LogDir  = "C:\Temp"
$LogPath = Join-Path $LogDir "VasionClientInstall.log"
if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

# --- Stage MSI locally ---
$LocalMsi = Join-Path $env:TEMP "PrinterInstallerClient.msi"

Write-Output "Starting Vasion client deployment..."
Write-Output "HomeUrl: $HomeUrl"
Write-Output "MsiSource: $MsiSource"
Write-Output "LocalMsi: $LocalMsi"
Write-Output "LogPath: $LogPath"

try {
    if ($MsiSource -match '^https?://') {
        Write-Output "Downloading MSI from HTTPS..."
        Invoke-WebRequest -Uri $MsiSource -OutFile $LocalMsi -UseBasicParsing
    }
    else {
        Write-Output "Copying MSI from UNC path..."
        Copy-Item -Path $MsiSource -Destination $LocalMsi -Force
    }
}
catch {
    Write-Error "Failed to retrieve MSI from '$MsiSource'. $($_.Exception.Message)"
    exit 1
}

if (-not (Test-Path $LocalMsi)) {
    Write-Error "MSI was not found at staged path: $LocalMsi"
    exit 1
}

# --- Optional: basic install detection (registry-based, safer than Win32_Product) ---
# NOTE: We don't know the exact DisplayName string in your MSI, so this is a best-effort check.
# If you can provide the exact DisplayName as it appears in Programs & Features, we can make this exact.
$UninstallRoots = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$PossibleNames = @(
    "*PrinterInstallerClient*",
    "*PrinterLogic*",
    "*Vasion*"
)

$AlreadyInstalled = $false
foreach ($root in $UninstallRoots) {
    foreach ($name in $PossibleNames) {
        $hit = Get-ItemProperty -Path $root -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like $name } |
            Select-Object -First 1

        if ($hit) {
            Write-Output "Detected existing install: $($hit.DisplayName)"
            $AlreadyInstalled = $true
            break
        }
    }
    if ($AlreadyInstalled) { break }
}

if ($AlreadyInstalled) {
    Write-Output "Client appears to already be installed. Exiting successfully."
    exit 0
}

# --- Run silent install using Vasion-documented properties HOMEURL and AUTHORIZATION_CODE ---
# Build arguments as an array to avoid quote/escape issues.
$msiArgs = @(
    "/i", $LocalMsi,
    "/qn",
    "HOMEURL=$HomeUrl",
    "AUTHORIZATION_CODE=$AuthCode",
    "/l*v", $LogPath
)

Write-Output "Running: msiexec.exe $($msiArgs -join ' ')"

try {
    $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru
}
catch {
    Write-Error "Failed to start msiexec. $($_.Exception.Message)"
    exit 1
}

if ($proc.ExitCode -ne 0) {
    Write-Error "Vasion client install failed with exit code $($proc.ExitCode). See log: $LogPath"
    exit $proc.ExitCode
}

Write-Output "Vasion client installed successfully. Log: $LogPath"
exit 0
