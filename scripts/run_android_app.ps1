Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:ScriptArgs = @($args)
$script:DeviceId = ""
$script:ApiBaseUrlOverride = ""
$script:ApiPort = if ($env:API_PORT) { [int]$env:API_PORT } else { 8000 }
$script:SkipSeed = $false
$script:KeepBackground = $false
$script:WithOcr = $false
$script:PreferLan = $false
$script:BackendOnly = $false
$script:FlutterExtraArgs = @()

$script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:RootDir = (Resolve-Path (Join-Path $ScriptDir "..")).Path
$script:BackendDir = Join-Path $RootDir "apps/backend"
$script:MobileDir = Join-Path $RootDir "apps/mobile"
$script:BackendVenvDir = Join-Path $BackendDir ".venv"
$script:BackendPython = Join-Path $BackendVenvDir "Scripts/python.exe"
$script:ComposeFile = Join-Path $RootDir "infra/compose/docker-compose.yml"
$script:RuntimeDir = Join-Path $RootDir ".runtime/android-run-windows"
$script:LogDir = Join-Path $RuntimeDir "logs"
$script:PidDir = Join-Path $RuntimeDir "pids"

$script:StartedProcesses = New-Object System.Collections.Generic.List[System.Diagnostics.Process]
$script:AdbReverseActive = $false
$script:AdbPath = $null
$script:AndroidEmulator = $false
$script:AndroidDeviceName = ""

function Write-Info {
    param([string]$Message)
    Write-Host "[ClinDiary] $Message"
}

function Fail {
    param([string]$Message)
    throw "[ClinDiary] Errore: $Message"
}

function Show-Usage {
    @"
Uso:
  powershell -ExecutionPolicy Bypass -File scripts/run_android_app.ps1 [opzioni] [-- argomenti extra flutter]

Opzioni:
  --device-id ID        Usa uno specifico device Android collegato.
  --api-base-url URL    Forza un API_BASE_URL specifico per Flutter.
  --api-port PORT       Usa una porta backend diversa da 8000.
  --prefer-lan          Usa l'IP locale del PC invece di adb reverse.
  --backend-only        Avvia solo backend/worker/beat e non esegue flutter run.
  --skip-seed           Non eseguire il seed demo.
  --keep-background     Lascia attivi backend/worker/beat dopo l'uscita di Flutter.
  --with-ocr            Installa anche le dipendenze OCR opzionali del backend.
  --help                Mostra questo aiuto.

Esempi:
  powershell -ExecutionPolicy Bypass -File scripts/run_android_app.ps1
  powershell -ExecutionPolicy Bypass -File scripts/run_android_app.ps1 --device-id R58M123456A
  powershell -ExecutionPolicy Bypass -File scripts/run_android_app.ps1 --device-id R58M123456A --prefer-lan
  powershell -ExecutionPolicy Bypass -File scripts/run_android_app.ps1 --backend-only
  powershell -ExecutionPolicy Bypass -File scripts/run_android_app.ps1 --skip-seed --keep-background
  powershell -ExecutionPolicy Bypass -File scripts/run_android_app.ps1 -- --debug
"@ | Write-Host
}

function Parse-Args {
    param([string[]]$Arguments)

    for ($index = 0; $index -lt $Arguments.Count; $index++) {
        $current = $Arguments[$index]
        switch ($current) {
            "--device-id" {
                $index++
                if ($index -ge $Arguments.Count) {
                    Fail "Manca il valore per --device-id"
                }
                $script:DeviceId = $Arguments[$index]
            }
            "--api-base-url" {
                $index++
                if ($index -ge $Arguments.Count) {
                    Fail "Manca il valore per --api-base-url"
                }
                $script:ApiBaseUrlOverride = $Arguments[$index]
            }
            "--api-port" {
                $index++
                if ($index -ge $Arguments.Count) {
                    Fail "Manca il valore per --api-port"
                }
                try {
                    $script:ApiPort = [int]$Arguments[$index]
                }
                catch {
                    Fail "La porta passata con --api-port non e valida: $($Arguments[$index])"
                }
            }
            "--prefer-lan" {
                $script:PreferLan = $true
            }
            "--backend-only" {
                $script:BackendOnly = $true
                $script:KeepBackground = $true
            }
            "--skip-seed" {
                $script:SkipSeed = $true
            }
            "--keep-background" {
                $script:KeepBackground = $true
            }
            "--with-ocr" {
                $script:WithOcr = $true
            }
            "--help" {
                Show-Usage
                exit 0
            }
            "-h" {
                Show-Usage
                exit 0
            }
            "--" {
                if ($index + 1 -lt $Arguments.Count) {
                    $script:FlutterExtraArgs = $Arguments[($index + 1)..($Arguments.Count - 1)]
                }
                break
            }
            default {
                Fail "Opzione non riconosciuta: $current"
            }
        }
    }
}

function Require-Command {
    param([string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Fail "Comando richiesto non trovato: $Name"
    }
}

function Import-DotEnv {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return
    }

    foreach ($rawLine in Get-Content $Path) {
        $line = $rawLine.Trim()
        if (-not $line -or $line.StartsWith("#")) {
            continue
        }

        if ($line.StartsWith("export ")) {
            $line = $line.Substring(7).Trim()
        }

        $separatorIndex = $line.IndexOf("=")
        if ($separatorIndex -lt 1) {
            continue
        }

        $name = $line.Substring(0, $separatorIndex).Trim()
        $value = $line.Substring($separatorIndex + 1)

        if (
            ($value.StartsWith('"') -and $value.EndsWith('"')) -or
            ($value.StartsWith("'") -and $value.EndsWith("'"))
        ) {
            $value = $value.Substring(1, $value.Length - 2)
        }

        [System.Environment]::SetEnvironmentVariable($name, $value, "Process")
    }
}

function Load-EnvFiles {
    Import-DotEnv (Join-Path $RootDir ".env")
    Import-DotEnv (Join-Path $BackendDir ".env")

    if (-not $env:APP_NAME) {
        $env:APP_NAME = "ClinDiary API"
    }
    if (-not $env:ENVIRONMENT) {
        $env:ENVIRONMENT = "development"
    }
    if (-not $env:DEBUG) {
        $env:DEBUG = "true"
    }
    elseif ($env:DEBUG.ToLowerInvariant() -notin @("1", "0", "true", "false", "yes", "no", "on", "off")) {
        $env:DEBUG = "true"
    }
    if (-not $env:DATABASE_URL) {
        $env:DATABASE_URL = "postgresql+psycopg://clindiary:clindiary@localhost:5432/clindiary"
    }
    if (-not $env:REDIS_URL) {
        $env:REDIS_URL = "redis://localhost:6379/0"
    }
    if (-not $env:MINIO_ENDPOINT) {
        $env:MINIO_ENDPOINT = "localhost:9000"
    }
    if (-not $env:MINIO_ACCESS_KEY) {
        $env:MINIO_ACCESS_KEY = "minioadmin"
    }
    if (-not $env:MINIO_SECRET_KEY) {
        $env:MINIO_SECRET_KEY = "minioadmin"
    }
    if (-not $env:MINIO_BUCKET) {
        $env:MINIO_BUCKET = "clindiary"
    }
    if (-not $env:MINIO_SECURE) {
        $env:MINIO_SECURE = "false"
    }

    $env:PYTHONPATH = (Join-Path $RootDir "apps/backend")
}

function Invoke-CheckedCommand {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList = @(),
        [string]$WorkingDirectory = "",
        [string]$FailureMessage
    )

    $restoreLocation = $false
    if ($WorkingDirectory) {
        Push-Location $WorkingDirectory
        $restoreLocation = $true
    }

    try {
        & $FilePath @ArgumentList
        if ($LASTEXITCODE -ne 0) {
            Fail $FailureMessage
        }
    }
    finally {
        if ($restoreLocation) {
            Pop-Location
        }
    }
}

function Ensure-BackendEnvironment {
    if (-not (Test-Path $BackendPython)) {
        Write-Info "Creo il virtualenv backend..."
        Invoke-CheckedCommand `
            -FilePath "python" `
            -ArgumentList @("-m", "venv", $BackendVenvDir) `
            -FailureMessage "Creazione del virtualenv backend fallita."
    }

    cmd /c "`"$BackendPython`" -c `"import fastapi, celery, sqlalchemy`" >nul 2>nul"
    if ($LASTEXITCODE -eq 0) {
        return
    }

    $packageSpec = if ($WithOcr) { "apps/backend[dev,ocr]" } else { "apps/backend[dev]" }
    Write-Info "Installo dipendenze backend ($packageSpec)..."
    Invoke-CheckedCommand `
        -FilePath $BackendPython `
        -ArgumentList @("-m", "pip", "install", "-e", $packageSpec) `
        -WorkingDirectory $RootDir `
        -FailureMessage "Installazione dipendenze backend fallita."
}

function Ensure-MobileDependencies {
    Write-Info "Aggiorno dipendenze Flutter..."
    Invoke-CheckedCommand `
        -FilePath "flutter" `
        -ArgumentList @("pub", "get") `
        -WorkingDirectory $MobileDir `
        -FailureMessage "flutter pub get non riuscito. Verifica che la versione di Flutter/Dart soddisfi apps/mobile/pubspec.yaml."
}

function Get-DockerDesktopPath {
    $candidates = @(
        "C:\Program Files\Docker\Docker\Docker Desktop.exe",
        "C:\Program Files\Docker\Docker\frontend\Docker Desktop.exe"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    return $null
}

function Test-DockerEngineReady {
    cmd /c "docker info >nul 2>nul"
    return $LASTEXITCODE -eq 0
}

function Ensure-DockerEngine {
    if (Test-DockerEngineReady) {
        return
    }

    $dockerDesktopPath = Get-DockerDesktopPath
    if ($dockerDesktopPath) {
        Write-Info "Docker Desktop non risponde, provo ad avviarlo..."
        Start-Process -FilePath $dockerDesktopPath | Out-Null

        for ($attempt = 1; $attempt -le 40; $attempt++) {
            Start-Sleep -Seconds 3
            if (Test-DockerEngineReady) {
                Write-Info "Docker Desktop pronto."
                return
            }
        }
    }

    Fail "Docker Desktop non e disponibile. Avvialo e riprova."
}

function Start-Infrastructure {
    Ensure-DockerEngine
    Write-Info "Avvio postgres, redis e minio..."
    Invoke-CheckedCommand `
        -FilePath "docker" `
        -ArgumentList @("compose", "-f", $ComposeFile, "up", "-d", "postgres", "redis", "minio", "minio-init") `
        -WorkingDirectory $RootDir `
        -FailureMessage "Avvio dell'infrastruttura Docker fallito."
}

function Run-MigrationsAndSeed {
    Write-Info "Eseguo migration database..."
    Invoke-CheckedCommand `
        -FilePath $BackendPython `
        -ArgumentList @("-m", "alembic", "-c", (Join-Path $BackendDir "alembic.ini"), "upgrade", "head") `
        -WorkingDirectory $BackendDir `
        -FailureMessage "Migrazioni Alembic fallite."

    if (-not $SkipSeed) {
        Write-Info "Eseguo seed demo..."
        Invoke-CheckedCommand `
            -FilePath $BackendPython `
            -ArgumentList @("-c", "from app.seed import main; main()") `
            -WorkingDirectory $BackendDir `
            -FailureMessage "Seed demo fallito."
    }
}

function Test-BackendHealthy {
    try {
        $response = Invoke-RestMethod -Uri "http://127.0.0.1:$ApiPort/health" -Method Get -TimeoutSec 3
        return $response.status -eq "ok"
    }
    catch {
        return $false
    }
}

function Wait-ForBackend {
    for ($attempt = 1; $attempt -le 60; $attempt++) {
        if (Test-BackendHealthy) {
            Write-Info "Backend pronto su http://127.0.0.1:$ApiPort"
            return
        }
        Start-Sleep -Seconds 1
    }

    Fail "Il backend non e diventato raggiungibile su http://127.0.0.1:$ApiPort"
}

function Start-BackgroundService {
    param(
        [string]$Name,
        [string]$FilePath,
        [string[]]$ArgumentList,
        [string]$WorkingDirectory
    )

    $stdoutLog = Join-Path $LogDir "$Name.log"
    $stderrLog = Join-Path $LogDir "$Name.err.log"

    Remove-Item $stdoutLog -Force -ErrorAction SilentlyContinue
    Remove-Item $stderrLog -Force -ErrorAction SilentlyContinue

    Write-Info "Avvio $Name..."
    New-Item -ItemType Directory -Force -Path $PidDir | Out-Null
    $process = Start-Process `
        -FilePath $FilePath `
        -ArgumentList $ArgumentList `
        -WorkingDirectory $WorkingDirectory `
        -RedirectStandardOutput $stdoutLog `
        -RedirectStandardError $stderrLog `
        -WindowStyle Hidden `
        -PassThru

    $script:StartedProcesses.Add($process) | Out-Null
    Set-Content -Path (Join-Path $PidDir "$Name.pid") -Value $process.Id -NoNewline
    Write-Info "$Name attivo. Log: $stdoutLog"
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

function Stop-MatchingProcesses {
    param(
        [string]$Name,
        [string]$RegexPattern
    )

    $matches = @(Get-MatchingProcesses -RegexPattern $RegexPattern)
    foreach ($match in ($matches | Sort-Object ProcessId -Unique)) {
        try {
            & taskkill /PID $match.ProcessId /F /T | Out-Null
            Write-Info "$Name fermato (PID $($match.ProcessId)) per pulizia residui."
        }
        catch {
        }
    }
}

function Test-ProcessCommandLine {
    param([string]$RegexPattern)

    return (@(Get-MatchingProcesses -RegexPattern $RegexPattern)).Count -gt 0
}

function Ensure-BackendServices {
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
    $backendPattern = "uvicorn.+app\.main:app"
    $workerPattern = "app\.workers\.celery_app\.celery_app\s+worker(\s|$)"
    $beatPattern = "app\.workers\.celery_app\.celery_app\s+beat(\s|$)"

    if ((@(Get-MatchingProcesses -RegexPattern $backendPattern)).Count -gt 1) {
        Write-Info "Trovate piu istanze backend residue, riparto pulito."
        Stop-MatchingProcesses -Name "backend" -RegexPattern $backendPattern
    }
    if ((@(Get-MatchingProcesses -RegexPattern $workerPattern)).Count -gt 1) {
        Write-Info "Trovati piu Celery worker residui, riparto pulito."
        Stop-MatchingProcesses -Name "worker" -RegexPattern $workerPattern
    }
    if ((@(Get-MatchingProcesses -RegexPattern $beatPattern)).Count -gt 1) {
        Write-Info "Trovate piu istanze Celery beat residue, riparto pulito."
        Stop-MatchingProcesses -Name "beat" -RegexPattern $beatPattern
    }

    if (Test-BackendHealthy) {
        Write-Info "Backend gia attivo, non avvio una seconda istanza."
    }
    else {
        Start-BackgroundService `
            -Name "backend" `
            -FilePath $BackendPython `
            -ArgumentList @(
                "-m",
                "uvicorn",
                "app.main:app",
                "--app-dir",
                (Join-Path $RootDir "apps/backend"),
                "--host",
                "0.0.0.0",
                "--port",
                "$ApiPort"
            ) `
            -WorkingDirectory $RootDir
        Wait-ForBackend
    }

    if (Test-ProcessCommandLine $workerPattern) {
        Write-Info "Celery worker gia attivo, lo riuso."
    }
    else {
        Start-BackgroundService `
            -Name "worker" `
            -FilePath $BackendPython `
            -ArgumentList @(
                "-m",
                "celery",
                "-A",
                "app.workers.celery_app.celery_app",
                "worker",
                "--pool=solo",
                "--concurrency=1",
                "--loglevel=info"
            ) `
            -WorkingDirectory $RootDir
    }

    if (Test-ProcessCommandLine $beatPattern) {
        Write-Info "Celery beat gia attivo, lo riuso."
    }
    else {
        Start-BackgroundService `
            -Name "beat" `
            -FilePath $BackendPython `
            -ArgumentList @(
                "-m",
                "celery",
                "-A",
                "app.workers.celery_app.celery_app",
                "beat",
                "--loglevel=info"
            ) `
            -WorkingDirectory $RootDir
    }
}

function Get-AdbPath {
    $adbCommand = Get-Command "adb" -ErrorAction SilentlyContinue
    if ($adbCommand) {
        return $adbCommand.Source
    }

    $candidates = @()

    if ($env:ANDROID_HOME) {
        $candidates += (Join-Path $env:ANDROID_HOME "platform-tools\adb.exe")
    }
    if ($env:ANDROID_SDK_ROOT) {
        $candidates += (Join-Path $env:ANDROID_SDK_ROOT "platform-tools\adb.exe")
    }
    if ($env:LOCALAPPDATA) {
        $candidates += (Join-Path $env:LOCALAPPDATA "Android\sdk\platform-tools\adb.exe")
    }

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if ($candidate -and (Test-Path $candidate)) {
            return $candidate
        }
    }

    return $null
}

function Detect-AndroidDevice {
    $rawDevices = (& flutter devices --machine 2>$null | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) {
        Fail "Impossibile eseguire 'flutter devices --machine'."
    }
    if (-not $rawDevices) {
        Fail "Flutter non ha restituito alcun payload device in formato machine."
    }

    try {
        $devices = $rawDevices | ConvertFrom-Json
    }
    catch {
        Fail "L'output di 'flutter devices --machine' non e JSON valido."
    }

    $androidDevices = @($devices | Where-Object {
        $_.isSupported -and "$($_.targetPlatform)".StartsWith("android")
    })

    if ($androidDevices.Count -eq 0) {
        Fail "Nessun device Android collegato. Collega il telefono oppure avvia un emulatore."
    }

    $selected = $null
    if ($DeviceId) {
        $selected = $androidDevices | Where-Object { $_.id -eq $DeviceId } | Select-Object -First 1
        if (-not $selected) {
            Fail "Il device richiesto con --device-id non e disponibile."
        }
    }
    else {
        $selected = $androidDevices | Select-Object -First 1
    }

    $script:DeviceId = "$($selected.id)"
    $script:AndroidEmulator = [bool]$selected.emulator
    $script:AndroidDeviceName = if ($selected.name) { "$($selected.name)" } else { $script:DeviceId }

    Write-Info "Uso il device Android: $AndroidDeviceName ($DeviceId)"
}

function Get-LocalIpv4Address {
    try {
        $udpClient = New-Object System.Net.Sockets.UdpClient
        $udpClient.Connect("1.1.1.1", 53)
        $address = $udpClient.Client.LocalEndPoint.Address.IPAddressToString
        $udpClient.Dispose()
        if ($address) {
            return $address
        }
    }
    catch {
    }

    try {
        $fallback = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
            $_.IPAddress -ne "127.0.0.1" -and -not $_.IPAddress.StartsWith("169.254.")
        } | Select-Object -First 1
        if ($fallback) {
            return $fallback.IPAddress
        }
    }
    catch {
    }

    Fail "Non riesco a determinare l'IP locale del computer."
}

function Configure-AndroidNetworking {
    if ($ApiBaseUrlOverride) {
        return $ApiBaseUrlOverride
    }

    if ($PreferLan -and -not $AndroidEmulator) {
        $hostIp = Get-LocalIpv4Address
        Write-Info "Uso la rete locale del PC per non dipendere da adb reverse: $hostIp"
        return "http://${hostIp}:$ApiPort"
    }

    $script:AdbPath = Get-AdbPath
    if ($AdbPath) {
        & $AdbPath -s $DeviceId reverse "tcp:$ApiPort" "tcp:$ApiPort" *> $null
        if ($LASTEXITCODE -eq 0) {
            $script:AdbReverseActive = $true
            Write-Info "Networking Android configurato con adb reverse sulla porta $ApiPort."
            return "http://127.0.0.1:$ApiPort"
        }
    }

    if ($AndroidEmulator) {
        Write-Info "adb reverse non disponibile, uso 10.0.2.2 per l'emulatore."
        return "http://10.0.2.2:$ApiPort"
    }

    $hostIp = Get-LocalIpv4Address
    Write-Info "adb reverse non disponibile, uso l'IP locale del PC: $hostIp"
    return "http://${hostIp}:$ApiPort"
}

function Stop-StartedProcesses {
    foreach ($process in $StartedProcesses) {
        if (-not $process) {
            continue
        }

        try {
            if (-not $process.HasExited) {
                Stop-Process -Id $process.Id -Force
            }
        }
        catch {
        }
    }

    foreach ($name in @("backend", "worker", "beat")) {
        Remove-Item (Join-Path $PidDir "$name.pid") -Force -ErrorAction SilentlyContinue
    }
}

function Cleanup {
    if ($AdbReverseActive -and $AdbPath -and $DeviceId) {
        & $AdbPath -s $DeviceId reverse --remove "tcp:$ApiPort" *> $null
    }

    if (-not $KeepBackground) {
        Stop-StartedProcesses
    }
}

Parse-Args $ScriptArgs

try {
    Require-Command "python"
    Require-Command "docker"

    New-Item -ItemType Directory -Force -Path $RuntimeDir | Out-Null
    New-Item -ItemType Directory -Force -Path $PidDir | Out-Null

    Load-EnvFiles
    Start-Infrastructure
    Ensure-BackendEnvironment
    Run-MigrationsAndSeed
    Ensure-BackendServices

    if ($BackendOnly) {
        $apiBaseUrl = if ($ApiBaseUrlOverride) {
            $ApiBaseUrlOverride
        }
        else {
            $hostIp = Get-LocalIpv4Address
            "http://${hostIp}:$ApiPort"
        }
        Write-Info "Servizi backend attivi. Per il telefono usa API_BASE_URL: $apiBaseUrl"
        Write-Info "Apri l'app gia installata sul telefono dopo averla compilata almeno una volta con --prefer-lan o --api-base-url."
        exit 0
    }

    Require-Command "flutter"
    Ensure-MobileDependencies
    Detect-AndroidDevice

    $apiBaseUrl = Configure-AndroidNetworking
    Write-Info "API_BASE_URL usato da Flutter: $apiBaseUrl"
    Write-Info "Credenziali demo: demo@clindiary.app / ChangeMe123!"
    $googleAuthClientId = if ($env:GOOGLE_OAUTH_CLIENT_ID) { $env:GOOGLE_OAUTH_CLIENT_ID } else { "" }

    Push-Location $MobileDir
    try {
        & flutter run -d $DeviceId --dart-define="API_BASE_URL=$apiBaseUrl" --dart-define="GOOGLE_AUTH_CLIENT_ID=$googleAuthClientId" @FlutterExtraArgs
        if ($LASTEXITCODE -ne 0) {
            Fail "flutter run non riuscito."
        }
    }
    finally {
        Pop-Location
    }
}
finally {
    Cleanup
}
