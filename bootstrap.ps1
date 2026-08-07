# bootstrap.ps1
#
# Удалённый запуск get_con.cmd одной командой, без скачивания файла на диск:
#
#   irm https://raw.githubusercontent.com/<user>/<repo>/main/bootstrap.ps1 | iex
#
# Если нужно передать -PyVer/-Arch, "чистый" iex это не умеет (Invoke-Expression не
# принимает параметры) - используйте вариант со scriptblock:
#
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/<user>/<repo>/main/bootstrap.ps1))) -PyVer 3.14.1 -Arch amd64
#
# Как это работает: скрипт скачивает актуальный get_con.cmd из репозитория, вырезает из
# него PowerShell-часть (всё после метки REM_PS1_CODE_START - той же самой, что использует
# сам .cmd при локальном запуске) и выполняет её. Один источник правды - сам get_con.cmd,
# этот загрузчик ничего не дублирует и почти никогда не должен меняться.
#
# ВАЖНО: замените CON_CMD_URL ниже на реальный raw-адрес вашего get_con.cmd на GitHub.

param(
    [string]$PyVer = "",
    [string]$Arch  = ""
)

$CON_CMD_URL = "https://raw.githubusercontent.com/<user>/<repo>/main/get_con.cmd"

$raw  = Invoke-RestMethod -Uri $CON_CMD_URL
$idx  = $raw.LastIndexOf('REM_PS1_CODE_START')
if ($idx -lt 0) {
    throw "REM_PS1_CODE_START marker not found in $CON_CMD_URL - is this really get_con.cmd?"
}
$code = $raw.Substring($idx + 18).TrimStart([char]13, [char]10)

& ([scriptblock]::Create($code)) -PyVer $PyVer -Arch $Arch
