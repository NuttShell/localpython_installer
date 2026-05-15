@echo off
setlocal EnableDelayedExpansion
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "MYSELF=%~f0"
set "TMPSCRIPT=%TEMP%\pyembed_%RANDOM%.ps1"

set "start=" & set "end="
for /f "tokens=1,3 delims=:=>" %%a in ('findstr /N /B "</*resource" "%MYSELF%"') do (
    if not defined start (
        if "%%~b" equ "installer.ps1" set "start=%%a"
    ) else if not defined end set "end=%%a"
)

set "_PS_SRC=%MYSELF%"
set "_PS_DST=%TMPSCRIPT%"
set "_PS_S=%start%"
set "_PS_E=%end%"
powershell -NoProfile -Command "$s=[int]$env:_PS_S;$e=[int]$env:_PS_E;$enc=New-Object Text.UTF8Encoding($false);$lines=[IO.File]::ReadAllLines($env:_PS_SRC,[Text.Encoding]::UTF8);$block=$lines[$s..($e-2)];[IO.File]::WriteAllLines($env:_PS_DST,$block,$enc)"

powershell -NoProfile -ExecutionPolicy Bypass -File "%TMPSCRIPT%" -ScriptDir "%SCRIPT_DIR%"
set "EXIT=%ERRORLEVEL%"
del /f /q "%TMPSCRIPT%" 2>nul
exit /b %EXIT%

<resource name="installer.ps1">
param([string]$ScriptDir)

Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'
[Console.Window]::ShowWindow([Console.Window]::GetConsoleWindow(), 0)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$form                 = New-Object System.Windows.Forms.Form
$form.Text            = "Python Embed Installer"
$form.Size            = New-Object System.Drawing.Size(500, 350)
$form.StartPosition   = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox     = $false
$form.MinimizeBox     = $false
$form.TopMost         = $true
$form.BackColor       = [System.Drawing.Color]::White

$labelTitle           = New-Object System.Windows.Forms.Label
$labelTitle.Text      = "Python Embed Installer"
$labelTitle.Font      = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$labelTitle.ForeColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$labelTitle.AutoSize  = $true
$labelTitle.Location  = New-Object System.Drawing.Point(20, 20)

$labelStatus           = New-Object System.Windows.Forms.Label
$labelStatus.Text      = "Initializing..."
$labelStatus.Font      = New-Object System.Drawing.Font("Segoe UI", 10)
$labelStatus.ForeColor = [System.Drawing.Color]::FromArgb(50, 50, 50)
$labelStatus.AutoSize  = $false
$labelStatus.Size      = New-Object System.Drawing.Size(440, 30)
$labelStatus.Location  = New-Object System.Drawing.Point(20, 60)

$progressBar          = New-Object System.Windows.Forms.ProgressBar
$progressBar.Size     = New-Object System.Drawing.Size(440, 25)
$progressBar.Location = New-Object System.Drawing.Point(20, 100)
$progressBar.Minimum  = 0
$progressBar.Maximum  = 100
$progressBar.Style    = [System.Windows.Forms.ProgressBarStyle]::Continuous

$labelDetail             = New-Object System.Windows.Forms.Label
$labelDetail.Text        = ""
$labelDetail.Font        = New-Object System.Drawing.Font("Segoe UI", 9)
$labelDetail.ForeColor   = [System.Drawing.Color]::FromArgb(100, 100, 100)
$labelDetail.AutoSize    = $false
$labelDetail.Size        = New-Object System.Drawing.Size(440, 80)
$labelDetail.Location    = New-Object System.Drawing.Point(20, 140)
$labelDetail.MaximumSize = New-Object System.Drawing.Size(440, 80)

$buttonClose          = New-Object System.Windows.Forms.Button
$buttonClose.Text     = "Close"
$buttonClose.Size     = New-Object System.Drawing.Size(120, 35)
$buttonClose.Location = New-Object System.Drawing.Point(180, 250)
$buttonClose.Visible  = $false
$buttonClose.Font     = New-Object System.Drawing.Font("Segoe UI", 10)
$buttonClose.Add_Click({ $form.Close() })

$form.Controls.AddRange(@($labelTitle, $labelStatus, $progressBar, $labelDetail, $buttonClose))

$script:hasExpandArchive = [bool](Get-Command Expand-Archive -ErrorAction SilentlyContinue)
if (-not $script:hasExpandArchive) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
}

function Update-GUI {
    param([string]$Status, [int]$Progress = -1, [string]$Detail = "")
    if ($Status   -ne "") { $labelStatus.Text  = $Status   }
    if ($Progress -ge 0)  { $progressBar.Value = $Progress }
    if ($Detail   -ne "") { $labelDetail.Text  = $Detail   }
    $form.Refresh()
    [System.Windows.Forms.Application]::DoEvents()
}

function Show-Error {
    param([string]$Message)
    [System.Windows.Forms.MessageBox]::Show($form, $Message, "Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error)
}

function Show-Success {
    param([string]$Message)
    [System.Windows.Forms.MessageBox]::Show($form, $Message, "Success",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information)
}

function Test-InternetConnection {
    param([string]$HostName = "www.python.org", [int]$Port = 443, [int]$TimeoutMs = 5000)
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $ar  = $tcp.BeginConnect($HostName, $Port, $null, $null)
        $ok  = $ar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        $tcp.Close()
        return $ok
    } catch { return $false }
}

function Get-UserSelection {
    param([string]$Title, [string[]]$Options, [string]$Prompt = "Select")
    $fs                 = New-Object System.Windows.Forms.Form
    $fs.Text            = $Title
    $fs.Size            = New-Object System.Drawing.Size(400, 450)
    $fs.StartPosition   = "CenterParent"
    $fs.FormBorderStyle = "FixedDialog"
    $fs.TopMost         = $true

    $lbl          = New-Object System.Windows.Forms.Label
    $lbl.Text     = $Prompt
    $lbl.AutoSize = $true
    $lbl.Location = New-Object System.Drawing.Point(20, 15)
    $lbl.Font     = New-Object System.Drawing.Font("Segoe UI", 10)

    $lb          = New-Object System.Windows.Forms.ListBox
    $lb.Size     = New-Object System.Drawing.Size(340, 300)
    $lb.Location = New-Object System.Drawing.Point(20, 50)
    $lb.Items.AddRange($Options)
    $lb.Font     = New-Object System.Drawing.Font("Segoe UI", 9)

    $btn              = New-Object System.Windows.Forms.Button
    $btn.Text         = "OK"
    $btn.Size         = New-Object System.Drawing.Size(100, 35)
    $btn.Location     = New-Object System.Drawing.Point(140, 360)
    $btn.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $btn.Font         = New-Object System.Drawing.Font("Segoe UI", 10)

    $fs.Controls.AddRange(@($lbl, $lb, $btn))
    $fs.AcceptButton = $btn
    if ($fs.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
        return $lb.SelectedIndex + 1
    }
    return 0
}

function Read-Requirements {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return [string[]]@() }
    return @(Get-Content $Path -Encoding UTF8 -ErrorAction SilentlyContinue |
             Where-Object { $_ -and $_.Trim() -ne "" -and -not $_.TrimStart().StartsWith("#") } |
             ForEach-Object { $_.Trim() })
}

function Download-File {
    param(
        [string]$Url,
        [string]$DestinationPath,
        [string]$Description  = "File",
        [int]   $ProgressFrom = 50,
        [int]   $ProgressTo   = 60
    )
    $script:_dlFrom = $ProgressFrom
    $script:_dlTo   = $ProgressTo
    $script:_dlDesc = $Description

    try {
        Update-GUI -Status "Downloading..." -Progress $ProgressFrom -Detail "$Description`n$Url"

        $wc = New-Object System.Net.WebClient

        $wc.add_DownloadProgressChanged({
            param($sender, $evt)
            $pct = $script:_dlFrom + [int]($evt.ProgressPercentage / 100.0 * ($script:_dlTo - $script:_dlFrom))
            $dl  = [math]::Round($evt.BytesReceived / 1MB, 2)
            if ($evt.TotalBytesToReceive -gt 0) {
                $tot = "$([math]::Round($evt.TotalBytesToReceive / 1MB, 2)) MB"
            } else {
                $tot = "?"
            }
            Update-GUI -Status "Downloading... $($evt.ProgressPercentage)%" -Progress $pct `
                       -Detail "$($script:_dlDesc)`n$dl MB / $tot"
        })

        $script:dlDone  = $false
        $script:dlError = $null

        $wc.add_DownloadFileCompleted({
            param($sender, $evt)
            $script:dlError = $evt.Error
            $script:dlDone  = $true
        })

        $wc.DownloadFileAsync([Uri]$Url, $DestinationPath)
        while (-not $script:dlDone) {
            Start-Sleep -Milliseconds 50
            [System.Windows.Forms.Application]::DoEvents()
        }
        $wc.Dispose()

        if ($script:dlError) { throw $script:dlError }
        if ((Test-Path $DestinationPath) -and (Get-Item $DestinationPath).Length -gt 0) {
            Update-GUI -Progress $ProgressTo
            return $true
        }
        Remove-Item $DestinationPath -Force -ErrorAction SilentlyContinue
        return $false
    } catch {
        if (Test-Path $DestinationPath) { Remove-Item $DestinationPath -Force -ErrorAction SilentlyContinue }
        return $false
    }
}

function Extract-PythonZip {
    param([string]$ZipPath, [string]$ExtractPath)
    Update-GUI -Status "Extracting..." -Progress 68 -Detail "To: $ExtractPath"
    try {
        if (-not (Test-Path $ZipPath) -or (Get-Item $ZipPath).Length -eq 0) { return $false }
        if (Test-Path $ExtractPath) { Remove-Item $ExtractPath -Recurse -Force }
        New-Item $ExtractPath -ItemType Directory -Force | Out-Null
        if ($script:hasExpandArchive) {
            Expand-Archive -Path $ZipPath -DestinationPath $ExtractPath -Force
        } else {
            [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $ExtractPath)
        }
        return (Test-Path (Join-Path $ExtractPath "python.exe"))
    } catch {
        if (Test-Path $ExtractPath) { Remove-Item $ExtractPath -Recurse -Force -ErrorAction SilentlyContinue }
        return $false
    }
}

function Rename-PthFiles {
    param([string]$PythonPath)
    Update-GUI -Status "Configuring..." -Progress 72 -Detail "Renaming *._pth files..."
    foreach ($f in (Get-ChildItem $PythonPath -Filter "*._pth" -File -ErrorAction SilentlyContinue)) {
        $bak = "$($f.FullName).bak"
        if (-not (Test-Path $bak)) { Rename-Item $f.FullName "$($f.Name).bak" -Force }
    }
}

function Invoke-PythonWithOutput {
    param([string]$PythonExe, [string]$Arguments, [string]$StatusText, [int]$Progress)
    Update-GUI -Status $StatusText -Progress $Progress -Detail ""

    $psi                        = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName               = $PythonExe
    $psi.Arguments              = $Arguments
    $psi.UseShellExecute        = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.CreateNoWindow         = $true
    $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
    $psi.StandardErrorEncoding  = [Text.Encoding]::UTF8

    $proc           = [System.Diagnostics.Process]::new()
    $proc.StartInfo = $psi
    $proc.Start() | Out-Null

    $sigPat = "Collecting |Downloading |Installing |Successfully installed|[Ee]rror|ERRO"

    while (-not $proc.HasExited) {
        while ($proc.StandardOutput.Peek() -gt 0) {
            $line = $proc.StandardOutput.ReadLine()
            if ($line -and $line.Trim() -match $sigPat) {
                Update-GUI -Detail $line.Trim()
            }
        }
        while ($proc.StandardError.Peek() -gt 0) {
            $line = $proc.StandardError.ReadLine()
            if ($line -and $line.Trim() -match $sigPat) {
                Update-GUI -Detail $line.Trim()
            }
        }
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 100
    }

    while ($proc.StandardOutput.Peek() -gt 0) {
        $line = $proc.StandardOutput.ReadLine()
        if ($line -and $line.Trim() -match $sigPat) { Update-GUI -Detail $line.Trim() }
    }
    while ($proc.StandardError.Peek() -gt 0) {
        $line = $proc.StandardError.ReadLine()
        if ($line -and $line.Trim() -match $sigPat) { Update-GUI -Detail $line.Trim() }
    }

    $proc.WaitForExit()
    return $proc.ExitCode
}

function Install-PythonPackages {
    param([string]$PythonDir, [string]$DownloadDir, [string]$RequirementsFile)
    $py  = Join-Path $PythonDir "python.exe"
    $pip = Join-Path $DownloadDir "get-pip.py"

    if (-not (Test-Path $py)) { Show-Error "python.exe not found: $py"; return $false }

    $exit = Invoke-PythonWithOutput -PythonExe $py `
                -Arguments "`"$pip`" --no-warn-script-location" `
                -StatusText "Installing pip..." -Progress 86
    if ($exit -ne 0) { Show-Error "pip install failed (exit $exit)"; return $false }

    if ($RequirementsFile -ne "" -and (Test-Path $RequirementsFile)) {
        $exit = Invoke-PythonWithOutput -PythonExe $py `
                    -Arguments "-m pip install -r `"$RequirementsFile`" --no-warn-script-location" `
                    -StatusText "Installing packages..." -Progress 93
        if ($exit -ne 0) {
            Show-Error "requirements.txt install failed (exit $exit)"
            return $false
        }
    } else {
        Update-GUI -Status "No requirements.txt" -Progress 93 -Detail "Skipping extra packages"
    }
    return $true
}

$form.Add_Shown({
    $form.Activate()
    Update-GUI -Status "Starting..." -Progress 0 -Detail "Please wait..."

    $downloadDir      = Join-Path $ScriptDir "download"
    $pythonDir        = Join-Path $ScriptDir "python"
    $outputFile       = Join-Path $ScriptDir "python_embed_zips.txt"
    $requirementsFile = Join-Path $ScriptDir "requirements.txt"
    $baseUrl          = "https://www.python.org/ftp/python/"
    $getPipUrl        = "https://bootstrap.pypa.io/get-pip.py"
    $versionFolderPat = '^3\.(5|6|7|8|9|10|11|12|13|14)\.\d+/$'
    $embedZipPat      = 'python-(3\.(?:5|6|7|8|9|10|11|12|13|14)\.\d+)-embed-(amd64|win32)\.zip$'

    $reqPackages     = Read-Requirements -Path $requirementsFile
    $hasRequirements = $reqPackages.Count -gt 0

    try {
        Update-GUI -Status "Checking connection..." -Progress 5 -Detail "www.python.org:443"
        if (-not (Test-InternetConnection)) {
            Show-Error "No internet connection or python.org is unreachable"
            $buttonClose.Visible = $true
            return
        }

        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        Update-GUI -Status "Cleaning folders..." -Progress 8 -Detail "$downloadDir`n$pythonDir"
        if (Test-Path $downloadDir) { Remove-Item $downloadDir -Recurse -Force }
        New-Item $downloadDir -ItemType Directory -Force | Out-Null
        if (Test-Path $pythonDir) { Remove-Item $pythonDir -Recurse -Force }

        Update-GUI -Status "Scanning versions..." -Progress 12 -Detail $baseUrl
        $mainPage       = Invoke-WebRequest -Uri $baseUrl -UseBasicParsing -TimeoutSec 30
        $versionFolders = $mainPage.Links |
                            Where-Object { $_.href -match $versionFolderPat } |
                            Select-Object -ExpandProperty href -Unique |
                            Sort-Object { [Version]($_.TrimEnd('/')) } -Descending

        if ($versionFolders.Count -eq 0) {
            Show-Error "No Python version folders found on python.org"
            $buttonClose.Visible = $true
            return
        }

        $allFiles = [System.Collections.Generic.List[PSCustomObject]]::new()
        $total    = $versionFolders.Count
        $cur      = 0

        foreach ($folder in $versionFolders) {
            $cur++
            Update-GUI -Status "Scanning..." -Progress (12 + [int]($cur / $total * 23)) `
                       -Detail "Folder $cur/$total : $folder"
            try {
                $fp = Invoke-WebRequest -Uri "$baseUrl$folder" -UseBasicParsing -TimeoutSec 10
                foreach ($link in $fp.Links) {
                    if ($link.href -match $embedZipPat) {
                        $allFiles.Add([PSCustomObject]@{
                            Version  = $Matches[1]
                            Arch     = $Matches[2]
                            FileName = $link.href
                            Url      = "$baseUrl$folder$($link.href)"
                        })
                    }
                }
            } catch { }
        }

        if ($allFiles.Count -eq 0) {
            Show-Error "No embed zip files found"
            $buttonClose.Visible = $true
            return
        }

        $allFiles | Select-Object -ExpandProperty Url | Out-File $outputFile -Encoding UTF8

        Update-GUI -Status "Select version..." -Progress 37 -Detail "$($allFiles.Count) files found"
        $uniqVer = $allFiles | Select-Object -ExpandProperty Version -Unique |
                   Sort-Object { [Version]$_ } -Descending
        $vi = Get-UserSelection -Title "Select Python Version" -Options $uniqVer -Prompt "Select version:"
        if ($vi -eq 0) { $buttonClose.Visible = $true; return }
        $selVer   = $uniqVer[$vi - 1]
        $verFiles = $allFiles | Where-Object { $_.Version -eq $selVer }

        Update-GUI -Status "Select architecture..." -Progress 42 -Detail "Python $selVer"
        $uniqArch = $verFiles | Select-Object -ExpandProperty Arch -Unique | Sort-Object
        $ai = Get-UserSelection -Title "Select Architecture" -Options $uniqArch -Prompt "Select architecture:"
        if ($ai -eq 0) { $buttonClose.Visible = $true; return }
        $selArch = $uniqArch[$ai - 1]
        $selFile = $verFiles | Where-Object { $_.Arch -eq $selArch } | Select-Object -First 1
        if (-not $selFile) { Show-Error "File not found"; $buttonClose.Visible = $true; return }

        if ($hasRequirements) {
            Update-GUI -Status "requirements.txt found" -Progress 46 `
                       -Detail "Packages: $($reqPackages -join ', ')"
        } else {
            Update-GUI -Status "No requirements.txt -- pip only" -Progress 46 -Detail ""
        }

        $zipDest = Join-Path $downloadDir $selFile.FileName
        $ok = Download-File -Url $selFile.Url -DestinationPath $zipDest `
                            -Description "Python $($selFile.FileName)" `
                            -ProgressFrom 50 -ProgressTo 65
        if (-not $ok) { Show-Error "Python ZIP download failed"; $buttonClose.Visible = $true; return }
        Update-GUI -Status "Downloaded" -Progress 65 `
                   -Detail "Size: $([math]::Round((Get-Item $zipDest).Length / 1MB, 2)) MB"

        if (-not (Extract-PythonZip -ZipPath $zipDest -ExtractPath $pythonDir)) {
            Show-Error "Extraction failed or incomplete"
            $buttonClose.Visible = $true
            return
        }
        Rename-PthFiles -PythonPath $pythonDir

        $pipDest = Join-Path $downloadDir "get-pip.py"
        $ok = Download-File -Url $getPipUrl -DestinationPath $pipDest `
                            -Description "get-pip.py" `
                            -ProgressFrom 75 -ProgressTo 82
        if (-not $ok) {
            Show-Error "Failed to download get-pip.py"
            $buttonClose.Visible = $true
            return
        }

        if ($hasRequirements) {
            $reqArg = $requirementsFile
        } else {
            $reqArg = ""
        }
        $ok = Install-PythonPackages -PythonDir $pythonDir `
                                     -DownloadDir $downloadDir `
                                     -RequirementsFile $reqArg
        if (-not $ok) { $buttonClose.Visible = $true; return }

        Update-GUI -Status "COMPLETE!" -Progress 100 `
                   -Detail "Python $selVer ($selArch)`nInstallation finished"
        if ($hasRequirements) {
            $rep = "pip + requirements.txt ($($reqPackages.Count) packages)"
        } else {
            $rep = "pip only"
        }
        Show-Success "Done!`n`nPython : $pythonDir`nVersion: $selVer $selArch`nPackages: $rep"

    } catch {
        Update-GUI -Status "FATAL ERROR" -Progress 0 -Detail $_.Exception.Message
        Show-Error "FATAL ERROR`n`n$($_.Exception.Message)"
    }

    $buttonClose.Visible = $true
})

[System.Windows.Forms.Application]::Run($form)
</resource>