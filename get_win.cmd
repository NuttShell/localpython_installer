@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "MYSELF=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$f=$env:MYSELF; $x=(Get-Content $f -Raw); $p=$x.Split([Environment]::NewLine); $s=0; for($i=0;$i-lt$p.Count;$i++){if($p[$i].Trim()-eq'#PS'){ $s=$i+1; break}}; $code=$p[$s..($p.Count-1)]-join[Environment]::NewLine; $t=\"$env:TEMP\_$RANDOM.ps1\"; $code|Out-File $t -Encoding utf8; &$t; exit $LASTEXITCODE"
goto :eof
#PS
# ==================== GUI SETUP ====================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object System.Windows.Forms.Form
$form.Text = "Python Embed Installer"
$form.Size = New-Object System.Drawing.Size(500, 350)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.TopMost = $true
$form.BackColor = [System.Drawing.Color]::White

$labelTitle = New-Object System.Windows.Forms.Label
$labelTitle.Text = "Python Embed Installer"
$labelTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$labelTitle.ForeColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$labelTitle.AutoSize = $true
$labelTitle.Location = New-Object System.Drawing.Point(20, 20)

$labelStatus = New-Object System.Windows.Forms.Label
$labelStatus.Text = "Initializing..."
$labelStatus.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$labelStatus.ForeColor = [System.Drawing.Color]::FromArgb(50, 50, 50)
$labelStatus.AutoSize = $false
$labelStatus.Size = New-Object System.Drawing.Size(440, 30)
$labelStatus.Location = New-Object System.Drawing.Point(20, 60)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Size = New-Object System.Drawing.Size(440, 25)
$progressBar.Location = New-Object System.Drawing.Point(20, 100)
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$progressBar.Step = 1
$progressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous

$labelDetail = New-Object System.Windows.Forms.Label
$labelDetail.Text = ""
$labelDetail.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$labelDetail.ForeColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
$labelDetail.AutoSize = $false
$labelDetail.Size = New-Object System.Drawing.Size(440, 80)
$labelDetail.Location = New-Object System.Drawing.Point(20, 140)
$labelDetail.MaximumSize = New-Object System.Drawing.Size(440, 80)

$buttonClose = New-Object System.Windows.Forms.Button
$buttonClose.Text = "Close"
$buttonClose.Size = New-Object System.Drawing.Size(120, 35)
$buttonClose.Location = New-Object System.Drawing.Point(180, 250)
$buttonClose.Visible = $false
$buttonClose.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$buttonClose.Add_Click({ $form.Close() })

$form.Controls.Add($labelTitle)
$form.Controls.Add($labelStatus)
$form.Controls.Add($progressBar)
$form.Controls.Add($labelDetail)
$form.Controls.Add($buttonClose)

$form.Add_Shown({ $form.Activate() })

$global:progress = 0
$global:status = ""
$global:detail = ""
$global:done = $false

function Update-GUI {
    param([string]$Status, [int]$Progress = -1, [string]$Detail = "")
    if ($Status -ne "") { $global:status = $Status }
    if ($Progress -ge 0) { $global:progress = $Progress }
    if ($Detail -ne "") { $global:detail = $Detail }
    
    $labelStatus.Text = $global:status
    $progressBar.Value = $global:progress
    $labelDetail.Text = $global:detail
    $form.Refresh()
    [System.Windows.Forms.Application]::DoEvents()
}

function Show-Error {
    param([string]$Message)
    [System.Windows.Forms.MessageBox]::Show($form, $Message, "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
}

function Show-Success {
    param([string]$Message)
    [System.Windows.Forms.MessageBox]::Show($form, $Message, "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
}

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
    param([string]$Title, [string[]]$Options, [string]$Prompt = "Select")
    $formSel = New-Object System.Windows.Forms.Form
    $formSel.Text = $Title
    $formSel.Size = New-Object System.Drawing.Size(400, 450)
    $formSel.StartPosition = "CenterParent"
    $formSel.FormBorderStyle = "FixedDialog"
    $formSel.TopMost = $true
    
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $Prompt
    $lbl.AutoSize = $true
    $lbl.Location = New-Object System.Drawing.Point(20, 15)
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    
    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Size = New-Object System.Drawing.Size(340, 300)
    $listBox.Location = New-Object System.Drawing.Point(20, 50)
    $listBox.Items.AddRange($Options)
    $listBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "OK"
    $btnOK.Size = New-Object System.Drawing.Size(100, 35)
    $btnOK.Location = New-Object System.Drawing.Point(140, 360)
    $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $btnOK.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    
    $formSel.Controls.Add($lbl)
    $formSel.Controls.Add($listBox)
    $formSel.Controls.Add($btnOK)
    $formSel.AcceptButton = $btnOK
    
    if ($formSel.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
        return $listBox.SelectedIndex + 1
    }
    return 0
}

function Download-File {
    param([string]$Url, [string]$DestinationPath, [string]$Description = "File")
    try {
        Update-GUI -Status "Downloading..." -Detail "$Description`n$Url"
        Invoke-WebRequest -Uri $Url -OutFile $DestinationPath -UseBasicParsing -TimeoutSec 120 -ErrorAction Stop
        if (Test-Path $DestinationPath) {
            $size = (Get-Item $DestinationPath).Length
            if ($size -gt 0) { return $true } else { Remove-Item $DestinationPath -Force -ErrorAction SilentlyContinue; return $false }
        }
        return $false
    } catch {
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
    Update-GUI -Status "Extracting..." -Detail "From: $ZipPath`nTo: $ExtractPath" -Progress 70
    try {
        if (-not (Test-Path $ZipPath)) { return $false }
        $zipSize = (Get-Item $ZipPath).Length
        if ($zipSize -eq 0) { return $false }
        if (Test-Path $ExtractPath) { Remove-Item -Path $ExtractPath -Recurse -Force -ErrorAction Stop }
        New-Item -Path $ExtractPath -ItemType Directory -Force | Out-Null
        if (Get-Command Expand-Archive -ErrorAction SilentlyContinue) {
            Expand-Archive -Path $ZipPath -DestinationPath $ExtractPath -Force -ErrorAction Stop
        } else {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $ExtractPath)
        }
        $pythonExe = Join-Path $ExtractPath "python.exe"
        if (Test-Path $pythonExe) { return $true } else { return $false }
    } catch {
        if (Test-Path $ExtractPath) { Remove-Item -Path $ExtractPath -Recurse -Force -ErrorAction SilentlyContinue }
        return $false
    }
}

function Rename-PthFiles {
    param([string]$PythonPath)
    Update-GUI -Status "Configuring..." -Detail "Renaming *._pth files..." -Progress 85
    $pthFiles = Get-ChildItem -Path $PythonPath -Filter "*._pth" -File -ErrorAction SilentlyContinue
    if ($pthFiles.Count -eq 0) { return $true }
    foreach ($file in $pthFiles) {
        $backupPath = "$($file.FullName).bak"
        if (-not (Test-Path $backupPath)) {
            Rename-Item -Path $file.FullName -NewName "$($file.Name).bak" -Force
        }
    }
    return $true
}

function Install-PythonPackages {
    param([string]$PythonDir, [string]$DownloadDir)
    Update-GUI -Status "Installing packages..." -Detail "pip, pyinstaller, fonttools" -Progress 90
    $pythonExe = Join-Path $PythonDir "python.exe"
    $scriptsDir = Join-Path $PythonDir "Scripts"
    $getPipPath = Join-Path $DownloadDir "get-pip.py"
    $env:PATH = "$PythonDir;$scriptsDir;$env:PATH"
    if (-not (Test-Path $pythonExe)) { return $false }
    if (Test-Path $getPipPath) {
        $proc = Start-Process -FilePath $pythonExe -ArgumentList "`"$getPipPath`" --no-warn-script-location" -Wait -PassThru -NoNewWindow
    }
    $proc = Start-Process -FilePath $pythonExe -ArgumentList "-m pip install --upgrade pip --no-warn-script-location" -Wait -PassThru -NoNewWindow
    $proc = Start-Process -FilePath $pythonExe -ArgumentList "-m pip install pyinstaller fonttools --no-warn-script-location" -Wait -PassThru -NoNewWindow
    return $true
}

# ==================== MAIN ====================
$form.Show()
$form.Refresh()
Update-GUI -Status "Starting..." -Progress 0 -Detail "Please wait..."

$scriptDir = $env:SCRIPT_DIR.TrimEnd('\')
$downloadDir = Join-Path $scriptDir "download"
$pythonDir = Join-Path $scriptDir "python"
$outputFile = Join-Path $scriptDir "python_embed_zips.txt"
$baseUrl = "https://www.python.org/ftp/python/"
$testHost = "https://www.python.org"
$getPipUrl = "https://bootstrap.pypa.io/get-pip.py"
$versionFolderPattern = '^([1-4])\.([0-9]|1[0-9]|20)\.([0-9]|10)/$'
$embedZipPattern = '^python-([1-4]\.(?:[0-9]|1[0-9]|20)\.(?:[0-9]|10))-embed-(amd64|win32)\.zip$'

try {
    Update-GUI -Status "Checking connection..." -Progress 5 -Detail $testHost
    if (-not (Test-InternetConnection -TestUrl $testHost -TimeoutSec 10)) {
        Update-GUI -Status "ERROR" -Progress 0 -Detail "No internet connection"
        Show-Error "No internet connection or python.org is unreachable"
        $buttonClose.Visible = $true
        $form.Refresh()
        while (-not $global:done) { Start-Sleep -Milliseconds 100; [System.Windows.Forms.Application]::DoEvents() }
        exit 1
    }
    
    if ([Net.ServicePointManager]::SecurityProtocol -notmatch 'Tls12') {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }
    
    Update-GUI -Status "Cleaning folders..." -Progress 10 -Detail "$downloadDir`n$pythonDir"
    if (Test-Path $downloadDir) { Remove-Item -Path $downloadDir -Recurse -Force -ErrorAction Stop }
    New-Item -Path $downloadDir -ItemType Directory -Force | Out-Null
    if (Test-Path $pythonDir) { Remove-Item -Path $pythonDir -Recurse -Force -ErrorAction Stop }
    
    Update-GUI -Status "Scanning versions..." -Progress 15 -Detail $baseUrl
    $mainPage = Invoke-WebRequest -Uri $baseUrl -UseBasicParsing -TimeoutSec 30
    $versionFolders = $mainPage.Links | Where-Object { $_.href -and $_.href -match $versionFolderPattern } | Select-Object -ExpandProperty href -Unique | Sort-Object { [Version]($_.TrimEnd('/')) } -Descending
    
    $allFiles = @()
    $total = $versionFolders.Count
    $current = 0
    foreach ($folder in $versionFolders) {
        $current++
        $pct = 15 + [int]($current / $total * 20)
        Update-GUI -Status "Scanning..." -Progress $pct -Detail "Folder $current/$total : $folder"
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
    
    if ($allFiles.Count -eq 0) {
        Update-GUI -Status "ERROR" -Progress 0 -Detail "No files found"
        Show-Error "No embed zip files found matching version filter"
        $buttonClose.Visible = $true
        $form.Refresh()
        while (-not $global:done) { Start-Sleep -Milliseconds 100; [System.Windows.Forms.Application]::DoEvents() }
        exit 0
    }
    
    $allFiles.Url | Out-File -FilePath $outputFile -Encoding UTF8
    
    Update-GUI -Status "Select version..." -Progress 40 -Detail "$($allFiles.Count) files found"
    $uniqueVersions = $allFiles.Version | Sort-Object { [Version]$_ } -Descending | Get-Unique
    $versionChoice = Get-UserSelection -Title "Select Python Version" -Options $uniqueVersions -Prompt "Select version:"
    if ($versionChoice -eq 0) { 
        Update-GUI -Status "Cancelled" -Progress 0
        $buttonClose.Visible = $true
        $form.Refresh()
        while (-not $global:done) { Start-Sleep -Milliseconds 100; [System.Windows.Forms.Application]::DoEvents() }
        exit 0 
    }
    $selectedVersion = $uniqueVersions[$versionChoice - 1]
    $versionFiles = $allFiles | Where-Object { $_.Version -eq $selectedVersion }
    
    Update-GUI -Status "Select architecture..." -Progress 45 -Detail "Python $selectedVersion"
    $uniqueArchs = $versionFiles.Arch | Sort-Object -Unique
    $archChoice = Get-UserSelection -Title "Select Architecture" -Options $uniqueArchs -Prompt "Select architecture:"
    if ($archChoice -eq 0) { 
        Update-GUI -Status "Cancelled" -Progress 0
        $buttonClose.Visible = $true
        $form.Refresh()
        while (-not $global:done) { Start-Sleep -Milliseconds 100; [System.Windows.Forms.Application]::DoEvents() }
        exit 0 
    }
    $selectedArch = $uniqueArchs[$archChoice - 1]
    $selectedFile = $versionFiles | Where-Object { $_.Arch -eq $selectedArch } | Select-Object -First 1
    if (-not $selectedFile) { 
        Show-Error "File not found"
        $buttonClose.Visible = $true
        $form.Refresh()
        while (-not $global:done) { Start-Sleep -Milliseconds 100; [System.Windows.Forms.Application]::DoEvents() }
        exit 1 
    }
    
    $destinationPath = Join-Path $downloadDir $selectedFile.FileName
    
    Update-GUI -Status "Downloading Python..." -Progress 50 -Detail "$($selectedFile.FileName)"
    $result = Download-File -Url $selectedFile.Url -DestinationPath $destinationPath -Description "Python embed ZIP"
    if ($result -and (Test-Path $destinationPath)) {
        $fileSize = [math]::Round((Get-Item $destinationPath).Length / 1MB, 2)
        Update-GUI -Status "Download complete" -Progress 60 -Detail "Size: $fileSize MB"
    } else {
        Update-GUI -Status "ERROR" -Progress 0 -Detail "Download failed"
        Show-Error "Python embed ZIP download failed"
        $buttonClose.Visible = $true
        $form.Refresh()
        while (-not $global:done) { Start-Sleep -Milliseconds 100; [System.Windows.Forms.Application]::DoEvents() }
        exit 1
    }
    
    $extractResult = Extract-PythonZip -ZipPath $destinationPath -ExtractPath $pythonDir
    if (-not $extractResult) {
        Update-GUI -Status "WARNING" -Progress 70 -Detail "Extraction failed"
        Show-Error "Extraction failed or incomplete"
    }
    
    Rename-PthFiles -PythonPath $pythonDir
    
    Update-GUI -Status "Downloading get-pip.py..." -Progress 80 -Detail "bootstrap.pypa.io"
    $getPipPath = Join-Path $downloadDir "get-pip.py"
    $getPipResult = Download-File -Url $getPipUrl -DestinationPath $getPipPath -Description "get-pip.py"
    
    Install-PythonPackages -PythonDir $pythonDir -DownloadDir $downloadDir
    
    Update-GUI -Status "COMPLETE!" -Progress 100 -Detail "Python $selectedVersion ($selectedArch)`nAll packages installed"
    Show-Success "Installation complete!`n`nPython: $pythonDir`nVersion: $selectedVersion $selectedArch`n`nPackages: pip, pyinstaller, fonttools"
    $buttonClose.Visible = $true
    $form.Refresh()
    
} catch {
    Update-GUI -Status "FATAL ERROR" -Progress 0 -Detail $_.Exception.Message
    Show-Error "FATAL ERROR`n`n$($_.Exception.Message)"
    $buttonClose.Visible = $true
    $form.Refresh()
}

$global:done = $true

# Держим окно открытым пока пользователь не нажмёт Close
while ($buttonClose.Visible -eq $true -and $form.Visible) {
    Start-Sleep -Milliseconds 100
    [System.Windows.Forms.Application]::DoEvents()
}