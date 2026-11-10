param(
    [string]$Port = 'auto',
    [switch]$Preflight,
    [switch]$Load,
    [string]$Python,
    [int]$HttpPort = 8765
)
$ErrorActionPreference = 'Stop'
$variantRoot = Split-Path -Parent $PSScriptRoot
if (-not $Python) {
    $environmentFile = Join-Path $variantRoot 'build\banco_environment.json'
    if (Test-Path -LiteralPath $environmentFile) {
        $configuredPython = (Get-Content -Raw -LiteralPath $environmentFile | ConvertFrom-Json).python_executable
        if ($configuredPython -and (Test-Path -LiteralPath $configuredPython)) { $Python = $configuredPython }
    }
}
if (-not $Python) {
    $runtimeCandidates = @(Get-ChildItem -LiteralPath 'C:\Program Files\WindowsApps' -Directory -Filter 'OpenAI.CodexPrimaryRuntime*' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | ForEach-Object { Join-Path $_.FullName 'dependencies\python\python.exe' } |
        Where-Object { Test-Path -LiteralPath $_ })
    if ($runtimeCandidates.Count) { $Python = $runtimeCandidates[0] }
    else { throw 'Indica -Python con un Python que tenga numpy, Pillow y pyserial.' }
}
$runner = Join-Path $variantRoot 'pc\banco_doe.py'
& $Python -X utf8 $runner --preflight
if ($LASTEXITCODE) { throw 'Preflight fallo. No se programa la placa.' }
if ($Preflight) { exit 0 }
if ($Load) {
    $loadScript = Join-Path $PSScriptRoot 'load_capture.tcl'
    $hardwareTools = 'C:\AMDDesignTools\2025.2\Vivado\bin'
    $probe = [System.Net.Sockets.TcpClient]::new()
    try { $serverReady = $probe.ConnectAsync('127.0.0.1',3121).Wait(1000) -and $probe.Connected }
    catch { $serverReady = $false }
    finally { $probe.Dispose() }
    if (-not $serverReady) {
        Start-Process -FilePath (Join-Path $hardwareTools 'hw_server.bat') -ArgumentList '-s','tcp::3121' -WindowStyle Hidden
        Start-Sleep -Seconds 2
    }
    & 'C:\AMDDesignTools\2025.2\Vitis\bin\xsct.bat' $loadScript
    if ($LASTEXITCODE) { throw 'Carga JTAG fallo.' }
}
if ($Port -eq 'auto') {
    $portScript = @'
import sys
sys.path.insert(0,sys.argv[1])
from serial.tools.list_ports import comports
ports=list(comports())
if len(ports)!=1:
    print('Se requiere -Port: '+repr([(p.device,p.description) for p in ports]),file=sys.stderr)
    sys.exit(1)
print(ports[0].device)
'@
    $Port = & $Python -X utf8 -c $portScript (Join-Path $variantRoot 'build\python_deps')
    if ($LASTEXITCODE) { throw 'No se pudo elegir un unico puerto serie.' }
}
& $Python -X utf8 $runner --port $Port --http-port $HttpPort
exit $LASTEXITCODE
