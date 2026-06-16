param(
    [string]$Port = "COM6",
    [int]$Baud = 921600,
    [double]$Timeout = 10.0,
    [string]$OutputDir = "capturas",
    [string]$Stem = "frame_y"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script = Join-Path $scriptDir "capture_frame_uart.py"

function Resolve-Python {
    foreach ($cmd in @("python", "py")) {
        $found = Get-Command $cmd -ErrorAction SilentlyContinue
        if ($null -ne $found) {
            & $cmd --version *> $null
            if ($LASTEXITCODE -eq 0) {
                return $cmd
            }
        }
    }

    $pythonRoot = Join-Path $env:LocalAppData "Programs\Python"
    if (Test-Path $pythonRoot) {
        $candidates = Get-ChildItem $pythonRoot -Directory -Filter "Python*" -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending |
            ForEach-Object { Join-Path $_.FullName "python.exe" }

        foreach ($candidate in $candidates) {
            if (Test-Path $candidate) {
                & $candidate --version *> $null
                if ($LASTEXITCODE -eq 0) {
                    return $candidate
                }
            }
        }
    }

    throw "No se encontro una instalacion valida de Python."
}

$python = Resolve-Python
& $python $script --port $Port --baud $Baud --timeout $Timeout --output-dir $OutputDir --stem $Stem
exit $LASTEXITCODE
