Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:RootDir = (Resolve-Path (Join-Path $ScriptDir "..")).Path
$script:RuntimeDir = Join-Path $RootDir ".runtime/android-run-windows"
$script:PidDir = Join-Path $RuntimeDir "pids"
$script:ComposeFile = Join-Path $RootDir "infra/compose/docker-compose.yml"
$script:DownInfra = $false

function Write-Info {
    param([string]$Message)
    Write-Host "[ClinDiary] $Message"
}

function Show-Usage {
    @"
Uso:
  powershell -ExecutionPolicy Bypass -File scripts/stop_android_backend.ps1 [opzioni]

Opzioni:
  --down-infra    Ferma anche postgres, redis e minio.
  --help          Mostra questo aiuto.
"@ | Write-Host
}

function Parse-Args {
    param([string[]]$Arguments)

    foreach ($argument in $Arguments) {
        switch ($argument) {
            "--down-infra" {
                $script:DownInfra = $true
            }
            "--help" {
                Show-Usage
                exit 0
            }
            "-h" {
                Show-Usage
                exit 0
            }
            default {
                throw "[ClinDiary] Errore: Opzione non riconosciuta: $argument"
            }
        }
    }
}

function Get-MatchingProcesses {
    param([string]$RegexPattern)

    try {
        return @(Get-CimInstance Win32_Process | Where-Object {
            $_.CommandLine -and $_.CommandLine -match $RegexPattern
        })
    }
    catch {
        return @()
    }
}

function Stop-ServiceByName {
    param(
        [string]$Name,
        [string]$RegexPattern
    )

    $pidFile = Join-Path $PidDir "$Name.pid"
    $processIds = New-Object System.Collections.Generic.HashSet[int]

    if (Test-Path $pidFile) {
        $processId = Get-Content $pidFile -ErrorAction SilentlyContinue
        if ($processId) {
            try {
                [void]$processIds.Add([int]$processId)
            }
            catch {
            }
        }
        Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
    }

    $matches = @(Get-MatchingProcesses -RegexPattern $RegexPattern)

    foreach ($match in $matches) {
        [void]$processIds.Add([int]$match.ProcessId)
    }

    foreach ($processId in ($processIds | Sort-Object -Unique)) {
        try {
            & taskkill /PID $processId /F /T | Out-Null
            Write-Info "$Name fermato (PID $processId)."
        }
        catch {
        }
    }
}

Parse-Args @($args)

if (Test-Path $PidDir) {
    Stop-ServiceByName -Name "backend" -RegexPattern "uvicorn.+app\.main:app"
    Stop-ServiceByName -Name "worker" -RegexPattern "app\.workers\.celery_app\.celery_app\s+worker(\s|$)"
    Stop-ServiceByName -Name "beat" -RegexPattern "app\.workers\.celery_app\.celery_app\s+beat(\s|$)"
}
else {
    Stop-ServiceByName -Name "backend" -RegexPattern "uvicorn.+app\.main:app"
    Stop-ServiceByName -Name "worker" -RegexPattern "app\.workers\.celery_app\.celery_app\s+worker(\s|$)"
    Stop-ServiceByName -Name "beat" -RegexPattern "app\.workers\.celery_app\.celery_app\s+beat(\s|$)"
}

if ($DownInfra) {
    Write-Info "Fermo anche l'infrastruttura Docker..."
    & docker compose -f $ComposeFile stop postgres redis minio minio-init
}
