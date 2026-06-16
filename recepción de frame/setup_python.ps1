$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$requirements = Join-Path $scriptDir "requirements.txt"

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

    throw "No se encontro una instalacion valida de Python. Instala Python y marca 'Add python.exe to PATH'."
}

$python = Resolve-Python
Write-Host "Usando Python: $python"

& $python -m pip install --upgrade pip
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $python -m pip install -r $requirements
exit $LASTEXITCODE
