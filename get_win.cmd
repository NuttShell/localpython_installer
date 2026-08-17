@echo off
setlocal EnableDelayedExpansion
set "SCRIPTDIR=%~dp0"
set "SCRIPTDIR=%SCRIPTDIR:~0,-1%"
set "PS1FILE=%TEMP%\pspython_%RANDOM%.ps1"
set "version=26.0817"

powershell -NoProfile -Command "$c = Get-Content -LiteralPath '%~f0' -Raw -Encoding UTF8; $idx = $c.LastIndexOf('REM_PS1_CODE_START'); $code = $c.Substring($idx + 18).TrimStart([char]13,[char]10); Set-Content -LiteralPath '%PS1FILE%' -Value $code -Encoding UTF8 -NoNewline"

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1FILE%" -ScriptDir "%SCRIPTDIR%"

set "RC=%errorlevel%"

del "%PS1FILE%" >nul 2>&1

if not "%RC%"=="0" pause
exit /b %RC%

REM_PS1_CODE_START

param(
    [string]$ScriptDir
)

$DEFAULT_PACKAGES = @(
    "pyinstaller"
)

Add-Type -Name WinUtil -Namespace PyEmbed -MemberDefinition '
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]   public static extern bool   ShowWindow(IntPtr h, int n);
'
[PyEmbed.WinUtil]::ShowWindow([PyEmbed.WinUtil]::GetConsoleWindow(), 0) | Out-Null

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.Windows.Forms.Application]::EnableVisualStyles()

[Net.ServicePointManager]::SecurityProtocol  = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
[Net.ServicePointManager]::DefaultConnectionLimit = 8

$form                 = New-Object System.Windows.Forms.Form
$form.Text            = "Python Embed Installer"
$form.Size            = New-Object System.Drawing.Size(520, 380)
$form.StartPosition   = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox     = $false
$form.MinimizeBox     = $false
$form.TopMost         = $true
$form.BackColor       = [System.Drawing.Color]::White

$lblTitle           = New-Object System.Windows.Forms.Label
$lblTitle.Text      = "Python Embed Installer"
$lblTitle.Font      = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$lblTitle.AutoSize  = $true
$lblTitle.Location  = New-Object System.Drawing.Point(20, 18)

$lblStatus           = New-Object System.Windows.Forms.Label
$lblStatus.Text      = "Initializing..."
$lblStatus.Font      = New-Object System.Drawing.Font("Segoe UI", 10)
$lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(40, 40, 40)
$lblStatus.AutoSize  = $false
$lblStatus.Size      = New-Object System.Drawing.Size(460, 26)
$lblStatus.Location  = New-Object System.Drawing.Point(20, 58)

$progressBar          = New-Object System.Windows.Forms.ProgressBar
$progressBar.Size     = New-Object System.Drawing.Size(460, 22)
$progressBar.Location = New-Object System.Drawing.Point(20, 92)
$progressBar.Minimum  = 0
$progressBar.Maximum  = 100
$progressBar.Style    = [System.Windows.Forms.ProgressBarStyle]::Continuous

$lblDetail             = New-Object System.Windows.Forms.Label
$lblDetail.Text        = ""
$lblDetail.Font        = New-Object System.Drawing.Font("Segoe UI", 9)
$lblDetail.ForeColor   = [System.Drawing.Color]::FromArgb(80, 80, 80)
$lblDetail.AutoSize    = $false
$lblDetail.Size        = New-Object System.Drawing.Size(460, 180)
$lblDetail.Location    = New-Object System.Drawing.Point(20, 124)
$lblDetail.MaximumSize = New-Object System.Drawing.Size(460, 180)

$btnClose          = New-Object System.Windows.Forms.Button
$btnClose.Text     = "Close"
$btnClose.Size     = New-Object System.Drawing.Size(120, 34)
$btnClose.Location = New-Object System.Drawing.Point(190, 308)
$btnClose.Visible  = $false
$btnClose.Font     = New-Object System.Drawing.Font("Segoe UI", 10)
$btnClose.Add_Click({ $form.Close() })

$form.Controls.AddRange(@($lblTitle, $lblStatus, $progressBar, $lblDetail, $btnClose))

$script:_guiBusy = $false

function Update-GUI {
    param([string]$Status = "", [int]$Progress = -1, [string]$Detail = "")
    if ($Status   -ne "")     { $lblStatus.Text    = $Status   }
    if ($Progress -in 0..100) { $progressBar.Value = $Progress }
    if ($Detail   -ne "")     { $lblDetail.Text    = $Detail   }
    if ($script:_guiBusy) { return }
    $script:_guiBusy = $true
    try {
        $form.Refresh()
        [System.Windows.Forms.Application]::DoEvents()
    } finally {
        $script:_guiBusy = $false
    }
}

function Show-Error {
    param([string]$Message)
    [System.Windows.Forms.MessageBox]::Show($form, $Message, "Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
}

function Show-ExistingInstall {
    param([string]$PythonDir)

    $pyExe = Join-Path $PythonDir "python.exe"
    if (-not (Test-Path $pyExe)) { return $true }

    $verLine = ((& $pyExe --version) 2>&1 | Out-String).Trim()

    $pkgLines = @()
    try {
        $pkgLines = @(& $pyExe -m pip list --format=freeze --disable-pip-version-check 2>$null)
    } catch { $pkgLines = @() }

    $maxShown = 25
    if ($pkgLines.Count -eq 0) {
        $pkgText = "(none found, or pip is not available)"
    } elseif ($pkgLines.Count -gt $maxShown) {
        $pkgText = ($pkgLines[0..($maxShown - 1)] -join "`n") + "`n...and $($pkgLines.Count - $maxShown) more"
    } else {
        $pkgText = $pkgLines -join "`n"
    }

    $msg = "An existing installation was found:`n`n" +
           "Location: $PythonDir`n" +
           "Version : $verLine`n`n" +
           "Installed packages ($($pkgLines.Count)):`n$pkgText`n`n" +
           "Reinstall this version?`n(Yes = reinstall, No = cancel and leave it as is)"

    $result = [System.Windows.Forms.MessageBox]::Show($form, $msg, "Existing Installation Found",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question)

    return ($result -eq [System.Windows.Forms.DialogResult]::Yes)
}

function Test-TcpConnect {
    param([string]$HostName, [int]$Port = 443, [int]$TimeoutMs = 5000)
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $ar  = $tcp.BeginConnect($HostName, $Port, $null, $null)
        $ok  = $ar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        try { $tcp.EndConnect($ar) } catch { }
        $tcp.Close()
        return $ok
    } catch { return $false }
}

function Get-UserSelection {
    param([string]$Title, [string[]]$Options, [string]$Prompt = "Select")
    $fs                 = New-Object System.Windows.Forms.Form
    $fs.Text            = $Title
    $fs.Size            = New-Object System.Drawing.Size(440, 520)
    $fs.StartPosition   = "CenterParent"
    $fs.FormBorderStyle = "FixedDialog"
    $fs.MaximizeBox     = $false
    $fs.TopMost         = $true

    $lbl          = New-Object System.Windows.Forms.Label
    $lbl.Text     = $Prompt
    $lbl.AutoSize = $true
    $lbl.Location = New-Object System.Drawing.Point(20, 14)
    $lbl.Font     = New-Object System.Drawing.Font("Segoe UI", 10)

    $lb                = New-Object System.Windows.Forms.ListBox
    $lb.Size           = New-Object System.Drawing.Size(380, 380)
    $lb.Location       = New-Object System.Drawing.Point(20, 44)
    $lb.Font           = New-Object System.Drawing.Font("Segoe UI", 9)
    $lb.IntegralHeight = $false
    $lb.Items.AddRange($Options)
    $lb.SelectedIndex  = 0
    $lb.Add_DoubleClick({
        $fs.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $fs.Close()
    })

    $btn              = New-Object System.Windows.Forms.Button
    $btn.Text         = "OK"
    $btn.Size         = New-Object System.Drawing.Size(100, 32)
    $btn.Location     = New-Object System.Drawing.Point(160, 440)
    $btn.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $btn.Font         = New-Object System.Drawing.Font("Segoe UI", 10)

    $fs.Controls.AddRange(@($lbl, $lb, $btn))
    $fs.AcceptButton = $btn

    $result = $fs.ShowDialog($form)
    $idx    = $lb.SelectedIndex
    $fs.Dispose()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK -and $idx -ge 0) {
        return $idx
    }
    return -1
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
        [string]$Dest,
        [string]$Description  = "File",
        [int]   $ProgressFrom = 50,
        [int]   $ProgressTo   = 60,
        [int]   $Retries      = 3
    )
    for ($attempt = 1; $attempt -le $Retries; $attempt++) {
        if ($attempt -gt 1) {
            Update-GUI -Status "Retry $attempt/$Retries..." -Progress $ProgressFrom `
                       -Detail "$Description`n$Url"
            Start-Sleep -Seconds 2
        }
        try {
            if (Test-Path $Dest) { Remove-Item $Dest -Force }
            $script:_dlFrom = $ProgressFrom
            $script:_dlTo   = $ProgressTo
            $script:_dlDesc = $Description
            Update-GUI -Status "Downloading..." -Progress $ProgressFrom `
                       -Detail "$Description`n$Url"
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
            $script:dlDone = $false; $script:dlError = $null
            $wc.add_DownloadFileCompleted({
                param($sender, $evt)
                $script:dlError = $evt.Error; $script:dlDone = $true
            })
            $wc.DownloadFileAsync([Uri]$Url, $Dest)
            while (-not $script:dlDone) {
                Start-Sleep -Milliseconds 50
                [System.Windows.Forms.Application]::DoEvents()
            }
            $wc.Dispose()
            if ($script:dlError) { throw $script:dlError }
            if ((Test-Path $Dest) -and (Get-Item $Dest).Length -gt 0) {
                Update-GUI -Progress $ProgressTo
                return $true
            }
            throw "File is empty or missing after download"
        } catch {
            if (Test-Path $Dest) { Remove-Item $Dest -Force -ErrorAction SilentlyContinue }
            Update-GUI -Detail "Attempt $attempt failed: $($_.Exception.Message)"
        }
    }
    return $false
}

function Get-EmbedBuilds {
    param([string]$BaseUrl)
    Update-GUI -Status "Fetching version list..." -Progress 10 -Detail $BaseUrl
    try {
        $page = Invoke-WebRequest -Uri $BaseUrl -UseBasicParsing -TimeoutSec 30
    } catch {
        throw "Cannot fetch python.org index: $($_.Exception.Message)"
    }
    $versions = @(
        $page.Links |
        Where-Object { $_.href -match '^(3\.\d+\.\d+)/$' } |
        ForEach-Object { $Matches[1] } |
        Sort-Object { [Version]$_ } -Descending
    )
    if ($versions.Count -eq 0) { throw "No Python 3.x versions found on python.org" }

    $builds = [System.Collections.Generic.List[PSCustomObject]]::new()
    $total  = $versions.Count
    $cur    = 0
    foreach ($ver in $versions) {
        $cur++
        Update-GUI -Status "Scanning builds..." -Progress (10 + [int]($cur / $total * 22)) `
                   -Detail "Version $cur/$total : $ver"
        try {
            $vpage = Invoke-WebRequest -Uri "$BaseUrl$ver/" -UseBasicParsing -TimeoutSec 10
            foreach ($link in $vpage.Links) {
                if ($link.href -match '^python-(\d+\.\d+\.\d+)-embed-(amd64|win32)\.zip$') {
                    $builds.Add([PSCustomObject]@{
                        Label    = "Python $($Matches[1])  [$($Matches[2])]"
                        Version  = $Matches[1]
                        Arch     = $Matches[2]
                        FileName = $link.href
                        Url      = "$BaseUrl$ver/$($link.href)"
                    })
                }
            }
        } catch { }
        [System.Windows.Forms.Application]::DoEvents()
    }
    return $builds
}

function Invoke-Python {
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
    $sigPat  = "Collecting |Downloading |Installing |Successfully installed|[Ee]rror|Traceback|ImportError|ModuleNotFound"
    $lastErr = ""
    while (-not $proc.HasExited) {
        while ($proc.StandardOutput.Peek() -gt 0) {
            $line = $proc.StandardOutput.ReadLine()
            if ($line -and $line.Trim() -match $sigPat) { Update-GUI -Detail $line.Trim() }
        }
        while ($proc.StandardError.Peek() -gt 0) {
            $line = $proc.StandardError.ReadLine()
            if ($line -and $line.Trim() -ne "") {
                $lastErr = $line.Trim()
                if ($line.Trim() -match $sigPat) { Update-GUI -Detail $line.Trim() }
            }
        }
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 80
    }
    while ($proc.StandardOutput.Peek() -gt 0) {
        $line = $proc.StandardOutput.ReadLine()
        if ($line -and $line.Trim() -match $sigPat) { Update-GUI -Detail $line.Trim() }
    }
    while ($proc.StandardError.Peek() -gt 0) {
        $line = $proc.StandardError.ReadLine()
        if ($line -and $line.Trim() -ne "") { $lastErr = $line.Trim() }
    }
    $proc.WaitForExit()
    $script:_lastErr = $lastErr
    return $proc.ExitCode
}

function Install-Pip {
    param([string]$PythonDir, [string]$DownloadDir)
    $py         = Join-Path $PythonDir "python.exe"
    $getPipDest = Join-Path $DownloadDir "get-pip.py"

    $ok = Download-File -Url "https://bootstrap.pypa.io/get-pip.py" `
                        -Dest $getPipDest -Description "get-pip.py" `
                        -ProgressFrom 75 -ProgressTo 80

    if ($ok) {
        foreach ($f in (Get-ChildItem $PythonDir -Filter "*._pth" -File -ErrorAction SilentlyContinue)) {
            Rename-Item $f.FullName "$($f.FullName).bak" -Force -ErrorAction SilentlyContinue
        }
        $exit = Invoke-Python -PythonExe $py `
                    -Arguments "`"$getPipDest`" --no-warn-script-location" `
                    -StatusText "Installing pip via get-pip.py..." -Progress 86
        if ($exit -eq 0) {
            Update-GUI -Status "pip installed" -Progress 90 -Detail ""
            return $true
        }
        Update-GUI -Status "get-pip.py failed, trying pip wheel..." -Progress 87 `
                   -Detail $script:_lastErr
    } else {
        Update-GUI -Status "get-pip.py unavailable, trying pip wheel..." -Progress 80 -Detail ""
    }

    Update-GUI -Status "Fetching pip wheel URL..." -Progress 81 -Detail "pypi.org/pypi/pip/json"
    try {
        $json   = Invoke-WebRequest -Uri "https://pypi.org/pypi/pip/json" -UseBasicParsing -TimeoutSec 15
        $whlUrl = ($json.Content | ConvertFrom-Json).urls |
                  Where-Object { $_.filename -match '^pip-[\d.]+-py3-none-any\.whl$' } |
                  Select-Object -ExpandProperty url -First 1
    } catch { $whlUrl = "" }

    if (-not $whlUrl) {
        $progressBar.Visible = $false
        Show-Error "Failed to get pip wheel URL from PyPI"
        return $false
    }

    $whlDest = Join-Path $DownloadDir "pip.whl"
    $ok = Download-File -Url $whlUrl -Dest $whlDest `
                        -Description "pip wheel" -ProgressFrom 82 -ProgressTo 86
    if (-not $ok) {
        $progressBar.Visible = $false
        Show-Error "Failed to download pip wheel"
        return $false
    }

    Update-GUI -Status "Unpacking pip wheel..." -Progress 87 -Detail ""
    $siteDir = Join-Path $PythonDir "site-packages"
    New-Item $siteDir -ItemType Directory -Force | Out-Null
    try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($whlDest, $siteDir)
    } catch {
        $progressBar.Visible = $false
        Show-Error "Failed to unpack pip wheel: $($_.Exception.Message)"
        return $false
    }

    $pthFile = Get-ChildItem $PythonDir -Filter "*._pth*" -File -ErrorAction SilentlyContinue |
               Select-Object -First 1
    if ($pthFile) {
        $pthPath = $pthFile.FullName -replace '\.bak$', ''
        $txt = Get-Content $pthFile.FullName -Encoding UTF8
        $txt = @($txt | ForEach-Object {
            if ($_ -match '^#\s*import site') { "import site" } else { $_ }
        })
        if (-not ($txt -contains "import site")) { $txt = @("import site") + $txt }
        if (-not ($txt -contains "site-packages")) { $txt = $txt + @("site-packages") }
        [System.IO.File]::WriteAllLines($pthPath, $txt, (New-Object Text.UTF8Encoding($false)))
    }

    $exit = Invoke-Python -PythonExe $py -Arguments "-m pip --version" `
                -StatusText "Verifying pip..." -Progress 88
    if ($exit -ne 0) {
        $progressBar.Visible = $false
        Show-Error "pip verification failed`n`n$($script:_lastErr)"
        return $false
    }
    Update-GUI -Status "pip installed via wheel" -Progress 90 -Detail ""
    return $true
}

function Install-Requirements {
    param([string]$PythonDir, [string]$RequirementsFile)
    $py   = Join-Path $PythonDir "python.exe"
    $exit = Invoke-Python -PythonExe $py `
                -Arguments "-m pip install -r `"$RequirementsFile`" --no-warn-script-location --no-cache-dir" `
                -StatusText "Installing packages..." -Progress 93
    if ($exit -ne 0) {
        $progressBar.Visible = $false
        Show-Error "requirements.txt install failed (exit $exit)`n`n$($script:_lastErr)"
        return $false
    }
    return $true
}

function Install-Packages {
    param([string]$PythonDir, [string[]]$Packages)
    if ($Packages.Count -eq 0) { return $true }
    $py      = Join-Path $PythonDir "python.exe"
    $pkgList = $Packages -join " "
    $exit    = Invoke-Python -PythonExe $py `
                   -Arguments "-m pip install $pkgList --no-warn-script-location --no-cache-dir" `
                   -StatusText "Installing packages: $pkgList" -Progress 93
    if ($exit -ne 0) {
        $progressBar.Visible = $false
        Show-Error "Package install failed (exit $exit)`n`n$($script:_lastErr)"
        return $false
    }
    return $true
}

$form.Add_Shown({
    $form.Activate()
    Update-GUI -Status "Starting..." -Progress 0 -Detail "Please wait..."

    $downloadDir      = Join-Path $ScriptDir "download"
    $pythonDir        = Join-Path $ScriptDir "python"
    $requirementsFile = Join-Path $ScriptDir "requirements.txt"
    $baseUrl          = "https://www.python.org/ftp/python/"

    $reqPackages     = Read-Requirements -Path $requirementsFile
    $hasRequirements = $reqPackages.Count -gt 0

    try {
        $proceed = Show-ExistingInstall -PythonDir $pythonDir
        if (-not $proceed) {
            Update-GUI -Status "Cancelled" -Detail "Existing installation left untouched: $pythonDir"
            $progressBar.Visible = $false
            $btnClose.Visible = $true
            return
        }

        Update-GUI -Status "Checking connection..." -Progress 4 -Detail "www.python.org:443"
        if (-not (Test-TcpConnect -HostName "www.python.org")) {
            Show-Error "No internet connection or python.org is unreachable"
            $progressBar.Visible = $false
            $btnClose.Visible = $true
            return
        }

        foreach ($dir in @($downloadDir, $pythonDir)) {
            if (Test-Path $dir) { Remove-Item $dir -Recurse -Force -ErrorAction Stop }
        }
        New-Item $downloadDir -ItemType Directory -Force | Out-Null

        $builds = Get-EmbedBuilds -BaseUrl $baseUrl
        if ($builds.Count -eq 0) {
            Show-Error "No embed builds found on python.org"
            $progressBar.Visible = $false
            $btnClose.Visible = $true
            return
        }

        $sorted = @(
            $builds | Sort-Object @{ Expression = { [Version]$_.Version }; Descending = $true },
                                  @{ Expression = { $_.Arch };             Descending = $true }
        )

        Update-GUI -Status "Select Python build..." -Progress 35 `
                   -Detail "$($sorted.Count) builds available"
        $labels = @($sorted | ForEach-Object { $_.Label })
        $idx    = Get-UserSelection -Title "Python Embed Installer" -Options $labels `
                                    -Prompt "Choose version and architecture:"
        if ($idx -lt 0) { $btnClose.Visible = $true; return }
        $sel = $sorted[$idx]

        if ($hasRequirements) {
            Update-GUI -Status "requirements.txt found" -Progress 46 `
                       -Detail ($reqPackages -join "`n")
        } else {
            Update-GUI -Status "No requirements.txt -- installing defaults" -Progress 46 `
                       -Detail ($DEFAULT_PACKAGES -join "`n")
        }

        $zipDest = Join-Path $downloadDir $sel.FileName
        $ok = Download-File -Url $sel.Url -Dest $zipDest `
                            -Description "Python $($sel.Version) [$($sel.Arch)]" `
                            -ProgressFrom 50 -ProgressTo 68
        if (-not $ok) {
            Show-Error "Python ZIP download failed"
            $progressBar.Visible = $false
            $btnClose.Visible = $true
            return
        }

        Update-GUI -Status "Extracting..." -Progress 68 -Detail "To: $pythonDir"
        try {
            New-Item $pythonDir -ItemType Directory -Force | Out-Null
            [System.IO.Compression.ZipFile]::ExtractToDirectory($zipDest, $pythonDir)
        } catch {
            Show-Error "Extraction failed: $($_.Exception.Message)"
            $progressBar.Visible = $false
            $btnClose.Visible = $true
            return
        }
        if (-not (Test-Path (Join-Path $pythonDir "python.exe"))) {
            Show-Error "python.exe not found after extraction"
            $progressBar.Visible = $false
            $btnClose.Visible = $true
            return
        }

        $ok = Install-Pip -PythonDir $pythonDir -DownloadDir $downloadDir
        if (-not $ok) { $btnClose.Visible = $true; return }

        if ($hasRequirements) {
            $ok = Install-Requirements -PythonDir $pythonDir -RequirementsFile $requirementsFile
        } else {
            $ok = Install-Packages -PythonDir $pythonDir -Packages $DEFAULT_PACKAGES
        }
        if (-not $ok) { $btnClose.Visible = $true; return }

        Remove-Item $downloadDir -Recurse -Force -ErrorAction SilentlyContinue

        if ($hasRequirements) {
            $rep = "pip + $($reqPackages.Count) package(s)"
        } else {
            $rep = "pip + $($DEFAULT_PACKAGES -join ', ')"
        }
        Update-GUI -Status "COMPLETE!" -Detail "Location : $pythonDir`nVersion  : $($sel.Version) [$($sel.Arch)]`nInstalled: $rep"
        $progressBar.Visible = $false

    } catch {
        $progressBar.Visible = $false
        Update-GUI -Status "FATAL ERROR" -Detail $_.Exception.Message
        Show-Error "FATAL ERROR`n`n$($_.Exception.Message)"
    }

    $btnClose.Visible = $true
})

[System.Windows.Forms.Application]::Run($form)
