$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$requirements = Join-Path $scriptDir "requirements.txt"

function Resolve-Python {
    function Test-PythonCommand {
        param(
            [string]$Exe,
            [string[]]$Args = @()
        )

        $found = Get-Command $Exe -ErrorAction SilentlyContinue
        if ($null -ne $found) {
            try {
                $version = & $Exe @Args --version 2>&1
                if (($LASTEXITCODE -eq 0) -and (($version -join " ") -match "Python 3")) {
                    return $true
                }
            } catch {
                return $false
            }
        }

        return $false
    }

    $commands = @(
        @{ Exe = "py"; Args = @("-3") },
        @{ Exe = "python"; Args = @() }
    )

    foreach ($cmd in $commands) {
        if (Test-PythonCommand -Exe $cmd.Exe -Args $cmd.Args) {
            return [PSCustomObject]@{
                Exe = $cmd.Exe
                Args = $cmd.Args
            }
        }
    }

    $directCandidates = @(
        (Join-Path $env:LocalAppData "Python\bin\python.exe")
    )

    foreach ($candidate in $directCandidates) {
        if ((Test-Path $candidate) -and (Test-PythonCommand -Exe $candidate)) {
            return [PSCustomObject]@{
                Exe = $candidate
                Args = @()
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
                if (Test-PythonCommand -Exe $candidate) {
                    return [PSCustomObject]@{
                        Exe = $candidate
                        Args = @()
                    }
                }
            }
        }
    }

    throw "No se encontro una instalacion valida de Python. Instala Python y marca 'Add python.exe to PATH'."
}

$python = Resolve-Python
Write-Host ("Usando Python: {0} {1}" -f $python.Exe, ($python.Args -join " "))

& $python.Exe @($python.Args) -m pip install --upgrade pip
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $python.Exe @($python.Args) -m pip install -r $requirements
exit $LASTEXITCODE
