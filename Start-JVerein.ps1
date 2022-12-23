#Requires -Version 5.1

# Start JVerein from a Cloud Drive
# nerdbridge e.V. (https://nerdbridge.de)
# (2022) MIT License

$ErrorActionPreference = "Stop"
Set-Location -Path "$PSScriptRoot"

function New-DateNowString {
    return get-date -Format "yyyy-MM-dd-HH-mm-ss"
}

function Remove-Lockfile {
    Write-Host "[*] Delete lockfile"
    Remove-Item -Path "$lockfile" -Force
}

function Exit-Script {
    param(
        [string]$message,
        [switch]$clearLockfile
    )
    
    Write-Host "[!] $message"
    Write-Host "[!] Abort."

    if ($clearLockfile) {
        Remove-Lockfile
    }

    exit 1
}

#-> configuration
$lockfile = "Lockfile-JVerein-Running.txt"
$localArchivesToKeep = 5
$remoteArchivesToKeep = 5
$appdata = "$env:APPDATA"
$workdir = "$appdata\Nerdbridge"
$manifestfile = "manifest.json"
$hashalgo = "SHA256"
$userId = "$env:USERNAME @ $env:COMPUTERNAME"
$userProfile = "$env:USERPROFILE"
$jameicaFile = "$userProfile\.jameica.properties"
$startNow = New-DateNowString

Write-Host "[i] Welcome to the helper script for JVerein of nerdbridge e.V."

#-> check for lockfile
if (Test-Path "$lockfile" -PathType Leaf) {
    Exit-Script -message "The application is already running on a another computer. Please align with your colleagues."
}

#-> create lockfile
Write-Host "[*] Create lockfile"
$userId | Out-File -FilePath "$lockfile"

#-> create working directory
Write-Host "[*] Ensure working directory '$workdir'"
New-Item -ItemType Directory -Force -Path "$workdir" | Out-Null

#-> Validate hash from manifest
Write-Host "[*] Checking manifest"

if (-not(Test-Path "$manifestfile" -PathType Leaf)) {
    Exit-Script -message "No manifest file was found. Unable to continue." -clearLockfile
}

# Parse manifest JSON
$manifestjson = Get-Content -Raw "$manifestfile" | ConvertFrom-Json

if (-not($manifestjson.hash) -or -not($manifestjson.filename)) {
    Exit-Script -message "Incomplete manifest data. Unable to continue." -clearLockfile
}

# Check archive
if (-not(Test-Path "$($manifestjson.filename)" -PathType Leaf)) {
    Write-Host "[i] Archive filename: $($manifestjson.filename)"
    Exit-Script -message "JVerein archive not found. Maybe it's uploading/downloading right now?" -clearLockfile
}

# Check archive hash
Write-Host "[*] Checking archive hash against manifest"
$currentHash = get-filehash "$($manifestjson.filename)" -Algorithm $hashalgo

if ($manifestjson.hash -ne $currentHash.Hash) {
    Write-Host "[i] Hash in manifest: $($manifestjson.hash)"
    Write-Host "[i] Archive hash:     $($currentHash.Hash)"
    Exit-Script -message "Hash is not matching. Maybe it's uploading/downloading right now?" -clearLockfile
}

#-> Unpack archive
Write-Host "[*] Extract archive to working directory"
Write-Host "[i] Archive: $($manifestjson.filename)"
Write-Host "[i] Working Directory: $workdir"

if (Test-Path "$workdir\JVerein" -PathType Container) {
    Exit-Script -message "Working copy '$workdir\JVerein' already exists. Please clean up." -clearLockfile
}

# Unzip archive
Expand-Archive -Path "$($manifestjson.filename)" -DestinationPath "$workdir"

#-> Write jameica configuration file
Write-Host "[*] Write jameica configuration file"
Write-Host "[i] Config location: $jameicaFile"

$javaPath = "$workdir\JVerein\data".Replace("\", "\\").Replace(":", "\:")

$javaProperties = @"
#created by Start-JVerein.ps1
#$startNow
ask=false
dir=$javaPath
history.0=$javaPath
"@

$javaProperties | Out-File -FilePath "$jameicaFile" -Encoding "default"

#-> Start JVerein
Write-Host "[*] Start JVerein and wait for exit"
Start-Process "$workdir\JVerein\jameica-2.10.2\jameica\jameica-win64.exe" -NoNewWindow -Wait
Start-Sleep -Seconds 5
Write-Host "[i] JVerein exited"

#-> ZIP JVerein folder
Write-Host "[*] Create a new JVerein archive"

$newNow = New-DateNowString
$newArchiveFileName = "nerdbridge-JVerein-$newNow.zip"

Compress-Archive -Path "$workdir\JVerein" -DestinationPath "$workdir\$newArchiveFileName" -CompressionLevel Optimal

#-> Create new manifest file
Write-Host "[*] Calculate $hashalgo hash from new archive"
$newHash = get-filehash "$workdir\$newArchiveFileName" -Algorithm $hashalgo

Write-Host "[*] Generate a new manifest"
$newManifestJson = @"
{
    "hash": "$($newHash.Hash)",
    "filename": "$newArchiveFileName"
}
"@

$newManifestJson | Out-File -FilePath "$manifestfile" -Encoding "default"

#-> Copy jVerein Archive into nextcloud
Write-Host "[*] Copy archive into nextcloud directory"
Copy-Item -Path "$workdir\$newArchiveFileName" -Destination "$newArchiveFileName"

#-> Cleanup

# delete local working copy
if (Test-Path "$workdir\JVerein" -PathType Container) {
    Write-Host "[*] Delete working directory"
    Remove-Item -Recurse -Force "$workdir\JVerein"
}

# delete old local backups
Write-Host "[*] Delete local archives, keep last $localArchivesToKeep"

Get-ChildItem -Path "$workdir" | `
    Select-Object -ExpandProperty Name | `
    Where-Object { $_ -match '^nerdbridge-JVerein-.+\.zip$' } | `
    Sort-Object -Descending | `
    Select-Object -Skip $localArchivesToKeep | `
    ForEach-Object { Remove-Item -Path "$workdir\$_" }

# delete old remote backups
Write-Host "[*] Delete remote archives, keep last $remoteArchivesToKeep"

Get-ChildItem | `
    Select-Object -ExpandProperty Name | `
    Where-Object { $_ -match '^nerdbridge-JVerein-.+\.zip$' } | `
    Sort-Object -Descending | `
    Select-Object -Skip $remoteArchivesToKeep | `
    ForEach-Object { Remove-Item -Path "$_" }

#-> Delete lockfile
Remove-Lockfile

#-> End
Write-Host "[i] Program complete. Bye."
Write-Host "[i] Please wait until nextcloud has synced properly!"
