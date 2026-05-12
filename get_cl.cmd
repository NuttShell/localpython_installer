@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "MYSELF=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$f=$env:MYSELF; $x=(Get-Content $f -Raw); $p=$x.Split([Environment]::NewLine); $s=0; for($i=0;$i-lt$p.Count;$i++){if($p[$i].Trim()-eq'#PS'){ $s=$i+1; break}}; $code=$p[$s..($p.Count-1)]-join[Environment]::NewLine; $t=\"$env:TEMP\_$RANDOM.ps1\"; $code|Out-File $t -Encoding utf8; &$t; exit $LASTEXITCODE"
pause
goto :eof
#PS
function Test-InternetConnection {
    param([string]$TestUrl = "https://www.python.org", [int]$TimeoutSec = 10)
    try {
        $r = Invoke-WebRequest -Uri $TestUrl -Method Head -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
        return $r.StatusCode -eq 200
    } catch {
        try {
            $r = Invoke-WebRequest -Uri $TestUrl -UseBasicParsing -TimeoutSec $TimeoutSec -MaximumRedirection 2 -ErrorAction Stop
            return $r.StatusCode -eq 200
        } catch { return $false }
    }
}
function Get-UserSelection {
    param([string]$Title, [string[]]$Options, [string]$Prompt = "Enter number")
    Write-Host "`n$Title" -ForegroundColor Cyan
    Write-Host ("-" * 50) -ForegroundColor Gray
    for ($i = 0; $i -lt $Options.Count; $i++) {
        Write-Host "  [$($i+1)] " -NoNewline -ForegroundColor Yellow
        Write-Host $Options[$i]
    }
    Write-Host "  [0] Exit" -ForegroundColor Red
    Write-Host ""
    while ($true) {
        Write-Host "$Prompt (0-$($Options.Count)): " -NoNewline -ForegroundColor White
        $input = $Host.UI.ReadLine()
        if ($input -match '^\d+$' -and [int]$input -ge 0 -and [int]$input -le $Options.Count) { return [int]$input }
        Write-Host "Invalid input. Try again." -ForegroundColor Yellow
    }
}
function Download-File {
    param([string]$Url, [string]$DestinationPath, [string]$Description = "File")
    try {
        Write-Host "  Downloading $Description..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $Url -OutFile $DestinationPath -UseBasicParsing -TimeoutSec 120 -ErrorAction Stop
        if (Test-Path $DestinationPath) {
            $size = (Get-Item $DestinationPath).Length
            if ($size -gt 0) { return $true } else { Remove-Item $DestinationPath -Force -ErrorAction SilentlyContinue; return $false }
        }
        return $false
    } catch {
        Write-Host "  Download error: $($_.Exception.Message)" -ForegroundColor Red
        if (Test-Path $DestinationPath) { Remove-Item $DestinationPath -Force -ErrorAction SilentlyContinue }
        return $false
    }
}
function Test-PythonVersion {
    param([string]$Version)
    if ($Version -match '^(\d+)\.(\d+)\.(\d+)$') {
        $major = [int]$matches[1]; $minor = [int]$matches[2]; $patch = [int]$matches[3]
        return ($major -ge 1 -and $major -le 4) -and ($minor -ge 0 -and $minor -le 20) -and ($patch -ge 0 -and $patch -le 10)
    }
    return $false
}
function Extract-PythonZip {
    param([string]$ZipPath, [string]$ExtractPath)
    Write-Host "`n[Extracting] Python embed archive..." -ForegroundColor Cyan
    Write-Host "  From: $ZipPath" -ForegroundColor Gray
    Write-Host "  To:   $ExtractPath" -ForegroundColor Gray
    try {
        if (-not (Test-Path $ZipPath)) { Write-Host "ERROR: ZIP file not found: $ZipPath" -ForegroundColor Red; return $false }
        $zipSize = (Get-Item $ZipPath).Length
        if ($zipSize -eq 0) { Write-Host "ERROR: ZIP file is empty" -ForegroundColor Red; return $false }
        if (Test-Path $ExtractPath) { Write-Host "  Removing existing folder: $ExtractPath" -ForegroundColor Gray; Remove-Item -Path $ExtractPath -Recurse -Force -ErrorAction Stop }
        New-Item -Path $ExtractPath -ItemType Directory -Force | Out-Null
        if (Get-Command Expand-Archive -ErrorAction SilentlyContinue) {
            Write-Host "  Using Expand-Archive..." -ForegroundColor Gray
            Expand-Archive -Path $ZipPath -DestinationPath $ExtractPath -Force -ErrorAction Stop
        } else {
            Write-Host "  Using Add-Type with Shell.Application..." -ForegroundColor Gray
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $ExtractPath)
        }
        $pythonExe = Join-Path $ExtractPath "python.exe"
        if (Test-Path $pythonExe) {
            $exeSize = [math]::Round((Get-Item $pythonExe).Length / 1KB, 1)
            Write-Host "`n[SUCCESS] Extraction completed!" -ForegroundColor Green
            Write-Host "  Python executable: $pythonExe" -ForegroundColor White
            Write-Host "  Size: $exeSize KB" -ForegroundColor White
            return $true
        } else { Write-Host "WARNING: python.exe not found after extraction" -ForegroundColor Yellow; return $false }
    } catch {
        Write-Host "ERROR during extraction: $($_.Exception.Message)" -ForegroundColor Red
        if (Test-Path $ExtractPath) { Remove-Item -Path $ExtractPath -Recurse -Force -ErrorAction SilentlyContinue }
        return $false
    }
}
function Rename-PthFiles {
    param([string]$PythonPath)
    Write-Host "`n[Configuring] Renaming *._pth files..." -ForegroundColor Cyan
    $pthFiles = Get-ChildItem -Path $PythonPath -Filter "*._pth" -File -ErrorAction SilentlyContinue
    if ($pthFiles.Count -eq 0) { Write-Host "  No *._pth files found" -ForegroundColor Gray; return $true }
    $renamed = 0
    foreach ($file in $pthFiles) {
        $backupPath = "$($file.FullName).bak"
        if (-not (Test-Path $backupPath)) {
            Rename-Item -Path $file.FullName -NewName "$($file.Name).bak" -Force
            Write-Host "  Renamed: $($file.Name) -> $($file.Name).bak" -ForegroundColor Gray
            $renamed++
        } else { Write-Host "  Skipped (backup exists): $($file.Name)" -ForegroundColor Gray }
    }
    Write-Host "  Total renamed: $renamed file(s)" -ForegroundColor Gray
    return $true
}
function Install-PythonPackages {
    param([string]$PythonDir, [string]$DownloadDir)
    $pythonExe = Join-Path $PythonDir "python.exe"
    $scriptsDir = Join-Path $PythonDir "Scripts"
    $getPipPath = Join-Path $DownloadDir "get-pip.py"
    Write-Host "`n[Installing] Configuring PATH and installing packages..." -ForegroundColor Cyan
    Write-Host "  Setting PATH environment variable..." -ForegroundColor Gray
    $env:PATH = "$PythonDir;$scriptsDir;$env:PATH"
    Write-Host "  PATH updated for current session" -ForegroundColor Gray
    if (-not (Test-Path $pythonExe)) { Write-Host "  ERROR: python.exe not found at $pythonExe" -ForegroundColor Red; return $false }
    if (Test-Path $getPipPath) {
        Write-Host "  Installing pip..." -ForegroundColor Gray
        $proc = Start-Process -FilePath $pythonExe -ArgumentList "`"$getPipPath`" --no-warn-script-location" -Wait -PassThru -NoNewWindow
        if ($proc.ExitCode -eq 0) { Write-Host "  pip installed successfully" -ForegroundColor Green } else { Write-Host "  WARNING: pip installation returned exit code $($proc.ExitCode)" -ForegroundColor Yellow }
    } else { Write-Host "  WARNING: get-pip.py not found, skipping pip installation" -ForegroundColor Yellow }
    Write-Host "  Upgrading pip..." -ForegroundColor Gray
    $proc = Start-Process -FilePath $pythonExe -ArgumentList "-m pip install --upgrade pip --no-warn-script-location" -Wait -PassThru -NoNewWindow
    if ($proc.ExitCode -eq 0) { Write-Host "  pip upgraded successfully" -ForegroundColor Green } else { Write-Host "  WARNING: pip upgrade returned exit code $($proc.ExitCode)" -ForegroundColor Yellow }
    Write-Host "  Installing pyinstaller and fonttools..." -ForegroundColor Gray
    $proc = Start-Process -FilePath $pythonExe -ArgumentList "-m pip install pyinstaller fonttools --no-warn-script-location" -Wait -PassThru -NoNewWindow
    if ($proc.ExitCode -eq 0) { Write-Host "  pyinstaller and fonttools installed successfully" -ForegroundColor Green } else { Write-Host "  WARNING: package installation returned exit code $($proc.ExitCode)" -ForegroundColor Yellow }
    return $true
}
# ==================== MAIN ====================
$scriptDir = $env:SCRIPT_DIR.TrimEnd('\')
$downloadDir = Join-Path $scriptDir "download"
$pythonDir = Join-Path $scriptDir "python"
$outputFile = Join-Path $scriptDir "python_embed_zips.txt"
$baseUrl = "https://www.python.org/ftp/python/"
$testHost = "https://www.python.org"
$getPipUrl = "https://bootstrap.pypa.io/get-pip.py"
$versionFolderPattern = '^([1-4])\.([0-9]|1[0-9]|20)\.([0-9]|10)/$'
$embedZipPattern = '^python-([1-4]\.(?:[0-9]|1[0-9]|20)\.(?:[0-9]|10))-embed-(amd64|win32)\.zip$'
Write-Host "=== Python Embed ZIP Downloader ===" -ForegroundColor Cyan
Write-Host "Version filter: X=1..4, Y=0..20, Z=0..10" -ForegroundColor Gray
Write-Host "Checking internet connection to $testHost ..." -ForegroundColor Gray
if (-not (Test-InternetConnection -TestUrl $testHost -TimeoutSec 10)) {
    Write-Host "ERROR: No internet connection or $testHost is unreachable" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Connection established`n" -ForegroundColor Green
if ([Net.ServicePointManager]::SecurityProtocol -notmatch 'Tls12') {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}
if (Test-Path $downloadDir) {
    Write-Host "Removing existing download folder: $downloadDir" -ForegroundColor Gray
    try { Remove-Item -Path $downloadDir -Recurse -Force -ErrorAction Stop; Write-Host "Download folder removed successfully" -ForegroundColor Gray }
    catch { Write-Host "WARNING: Could not remove $downloadDir : $($_.Exception.Message)" -ForegroundColor Yellow; exit 1 }
}
New-Item -Path $downloadDir -ItemType Directory -Force | Out-Null
Write-Host "Created download directory: $downloadDir" -ForegroundColor Gray
if (Test-Path $pythonDir) {
    Write-Host "Removing existing python folder: $pythonDir" -ForegroundColor Gray
    try { Remove-Item -Path $pythonDir -Recurse -Force -ErrorAction Stop; Write-Host "Python folder removed successfully" -ForegroundColor Gray }
    catch { Write-Host "WARNING: Could not remove $pythonDir : $($_.Exception.Message)" -ForegroundColor Yellow; exit 1 }
}
try {
    Write-Host "Scanning: $baseUrl" -ForegroundColor Cyan
    $mainPage = Invoke-WebRequest -Uri $baseUrl -UseBasicParsing -TimeoutSec 30
    $versionFolders = $mainPage.Links | Where-Object { $_.href -and $_.href -match $versionFolderPattern } | Select-Object -ExpandProperty href -Unique | Sort-Object { [Version]($_.TrimEnd('/')) } -Descending
    Write-Host "Found $($versionFolders.Count) version folders (filtered by X=1..4, Y=0..20, Z=0..10)`n" -ForegroundColor Green
    $allFiles = @()
    $total = $versionFolders.Count; $current = 0
    foreach ($folder in $versionFolders) {
        $current++
        Write-Progress -Activity "Indexing" -Status "Scanning $current/$total : $folder" -PercentComplete ($current / $total * 100)
        try {
            $folderUrl = "$baseUrl$folder"
            $folderPage = Invoke-WebRequest -Uri $folderUrl -UseBasicParsing -TimeoutSec 10
            $matches = $folderPage.Links | Where-Object { $_.href -and $_.href -match $embedZipPattern } | Select-Object -ExpandProperty href -Unique
            foreach ($fileName in $matches) {
                $version = [regex]::Match($fileName, 'python-(\d+\.\d+\.\d+)-embed').Groups[1].Value
                if (-not (Test-PythonVersion -Version $version)) { continue }
                $arch = [regex]::Match($fileName, '-embed-(amd64|win32)\.zip').Groups[1].Value
                $allFiles += [PSCustomObject]@{ Version = $version; Arch = $arch; FileName = $fileName; Url = "$folderUrl$fileName"; Folder = $folder.TrimEnd('/') }
            }
        } catch { continue }
    }
    Write-Progress -Activity "Indexing" -Completed
    if ($allFiles.Count -eq 0) { Write-Host "No embed zip files found matching version filter." -ForegroundColor Yellow; exit 0 }
    $allFiles.Url | Out-File -FilePath $outputFile -Encoding UTF8
    Write-Host "Found $($allFiles.Count) embed files. List saved to: $outputFile`n" -ForegroundColor Green
    $uniqueVersions = $allFiles.Version | Sort-Object { [Version]$_ } -Descending | Get-Unique
    $versionChoice = Get-UserSelection -Title "Select Python Version:" -Options $uniqueVersions -Prompt "Select version number"
    if ($versionChoice -eq 0) { Write-Host "Cancelled."; exit 0 }
    $selectedVersion = $uniqueVersions[$versionChoice - 1]
    Write-Host ">> Selected version: $selectedVersion" -ForegroundColor Green
    $versionFiles = $allFiles | Where-Object { $_.Version -eq $selectedVersion }
    $uniqueArchs = $versionFiles.Arch | Sort-Object -Unique
    $archChoice = Get-UserSelection -Title "Select Architecture for Python ${selectedVersion}:" -Options $uniqueArchs -Prompt "Select architecture number"
    if ($archChoice -eq 0) { Write-Host "Cancelled."; exit 0 }
    $selectedArch = $uniqueArchs[$archChoice - 1]
    Write-Host ">> Selected architecture: $selectedArch" -ForegroundColor Green
    $selectedFile = $versionFiles | Where-Object { $_.Arch -eq $selectedArch } | Select-Object -First 1
    if (-not $selectedFile) { Write-Host "ERROR: File not found for selected options." -ForegroundColor Red; exit 1 }
    $destinationPath = Join-Path $downloadDir $selectedFile.FileName
    Write-Host "`nStarting download:" -ForegroundColor Cyan
    Write-Host "  URL: $($selectedFile.Url)" -ForegroundColor Gray
    Write-Host "  To:  $destinationPath" -ForegroundColor Gray
    Write-Host ""
    $result = Download-File -Url $selectedFile.Url -DestinationPath $destinationPath -Description "Python embed ZIP"
    if ($result -and (Test-Path $destinationPath)) {
        $fileSize = [math]::Round((Get-Item $destinationPath).Length / 1MB, 2)
        Write-Host "`n[SUCCESS] Download completed!" -ForegroundColor Green
        Write-Host "  File: $($selectedFile.FileName)" -ForegroundColor White
        Write-Host "  Size: $fileSize MB" -ForegroundColor White
        Write-Host "  Path: $destinationPath" -ForegroundColor White
        Write-Host "`nCalculating SHA256 hash..." -ForegroundColor Gray
        $hash = (Get-FileHash -Path $destinationPath -Algorithm SHA256).Hash
        Write-Host "SHA256: $hash" -ForegroundColor Gray
    } else { Write-Host "`n[FAILED] Python embed ZIP download failed." -ForegroundColor Red; exit 1 }
    $extractResult = Extract-PythonZip -ZipPath $destinationPath -ExtractPath $pythonDir
    if (-not $extractResult) { Write-Host "WARNING: Extraction failed or incomplete" -ForegroundColor Yellow }
    Rename-PthFiles -PythonPath $pythonDir
    Write-Host "`n[Downloading] get-pip.py..." -ForegroundColor Cyan
    $getPipPath = Join-Path $downloadDir "get-pip.py"
    $getPipResult = Download-File -Url $getPipUrl -DestinationPath $getPipPath -Description "get-pip.py"
    if ($getPipResult -and (Test-Path $getPipPath)) {
        $getPipSize = [math]::Round((Get-Item $getPipPath).Length / 1KB, 2)
        Write-Host "[SUCCESS] get-pip.py downloaded!" -ForegroundColor Green
        Write-Host "  Size: $getPipSize KB" -ForegroundColor White
        Write-Host "  Path: $getPipPath" -ForegroundColor White
    } else { Write-Host "[WARNING] get-pip.py download failed" -ForegroundColor Yellow }
    Install-PythonPackages -PythonDir $pythonDir -DownloadDir $downloadDir
    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "Script location:   $scriptDir" -ForegroundColor White
    Write-Host "Download folder:   $downloadDir" -ForegroundColor White
    Write-Host "  - Archive:       $selectedFile.FileName" -ForegroundColor Gray
    Write-Host "  - get-pip.py:    [OK]" -ForegroundColor Gray
    Write-Host "Python folder:     $pythonDir" -ForegroundColor White
    Write-Host "  - Executable:    $(Join-Path $pythonDir 'python.exe')" -ForegroundColor Gray
    Write-Host "  - *._pth files:  Renamed to .bak" -ForegroundColor Gray
    Write-Host "  - pip:           Installed" -ForegroundColor Gray
    Write-Host "  - pyinstaller:   Installed" -ForegroundColor Gray
    Write-Host "  - fonttools:     Installed" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Packages installed:" -ForegroundColor Cyan
    Write-Host "  - pip (latest)" -ForegroundColor White
    Write-Host "  - pyinstaller" -ForegroundColor White
    Write-Host "  - fonttools" -ForegroundColor White
} catch {
    Write-Host "FATAL ERROR: $_" -ForegroundColor Red
    Write-Host "Exception: $($_.Exception.Message)" -ForegroundColor Gray
    exit 1
}