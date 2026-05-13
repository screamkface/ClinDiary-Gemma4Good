Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:ScriptArgs = @($args)
$script:SkipSeed = $false
$script:KeepBackground = $false
$script:BackendOnly = $false
$script:LocalOnly = $true
$script:WithOcr = $false
$script:ApiPort = if ($env:API_PORT) { [int]$env:API_PORT } else { 8000 }
$script:PreferLan = $false
$script:UseLocalGemma = $false
$script:ShowHelp = $false

$script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:LauncherScript = Join-Path $ScriptDir "run_android_app.ps1"

function Write-Info {
    param([string]$Message)
    Write-Host "[ClinDiary Auto USB] $Message"
}

function Fail {
    param([string]$Message)
    Write-Host "[ClinDiary Auto USB] ERRORE: $Message" -ForegroundColor Red
    exit 1
}

function Show-Usage {
    @"
Uso:
  powershell -ExecutionPolicy Bypass -File scripts/run_android_app_auto_usb.ps1 [opzioni]

Opzioni:
  --skip-seed       Non eseguire il seed demo.
  --keep-background Lascia attivi backend/worker/beat dopo l'uscita di Flutter.
    --local-only      Modalita predefinita: avvia solo Flutter in locale, senza backend.
    --with-backend    Disattiva local-only e riattiva backend + Docker.
  --backend-only    Avvia solo il backend senza Flutter.
  --with-ocr        Installa le dipendenze OCR opzionali del backend.
  --api-port PORT   Usa una porta backend diversa da 8000.
  --prefer-lan      Usa l'IP locale del PC invece di adb reverse.
  --local-gemma     Applica l'overlay env locale per Gemma (ollama).
  --help            Mostra questo aiuto.

Descrizione:
  Questo script rileva automaticamente qualsiasi dispositivo Android USB collegato
    e avvia l'app Flutter in modalita locale su di esso. Se nessun device e trovato, esce con errore.
    Usa --with-backend se vuoi riattivare backend + Docker.
  Se ci sono più dispositivi, usa il primo disponibile.

Esempi:
  powershell -ExecutionPolicy Bypass -File scripts/run_android_app_auto_usb.ps1
  powershell -ExecutionPolicy Bypass -File scripts/run_android_app_auto_usb.ps1 --skip-seed --keep-background
  powershell -ExecutionPolicy Bypass -File scripts/run_android_app_auto_usb.ps1 --prefer-lan --api-port 8080
  powershell -ExecutionPolicy Bypass -File scripts/run_android_app_auto_usb.ps1 --backend-only
"@ | Write-Host
}

function Parse-Args {
    param([string[]]$Arguments)

    for ($index = 0; $index -lt $Arguments.Count; $index++) {
        $current = $Arguments[$index]
        switch ($current) {
            "--skip-seed" {
                $script:SkipSeed = $true
            }
            "--keep-background" {
                $script:KeepBackground = $true
            }
            "--local-only" {
                $script:LocalOnly = $true
            }
            "--with-backend" {
                $script:LocalOnly = $false
            }
            "--backend-only" {
                $script:BackendOnly = $true
                $script:KeepBackground = $true
                $script:LocalOnly = $false
            }
            "--with-ocr" {
                $script:WithOcr = $true
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
                    Fail "La porta passata con --api-port non è valida: $($Arguments[$index])"
                }
            }
            "--prefer-lan" {
                $script:PreferLan = $true
            }
            "--local-gemma" {
                $script:UseLocalGemma = $true
            }
            "--help" {
                $script:ShowHelp = $true
            }
            "-h" {
                $script:ShowHelp = $true
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

function Get-FirstConnectedAndroidDevice {
    Write-Info "Rilevamento dispositivi Android collegati..."
    
    Require-Command "flutter"
    
    try {
        $rawDevices = flutter devices --machine 2>$null
        $devices = $rawDevices | ConvertFrom-Json
    }
    catch {
        Fail "Errore nel rilevamento dispositivi. Esegui 'flutter doctor' per diagnosticare il problema."
    }

    $androidDevices = @($devices | Where-Object {
        $_.isSupported -and "$($_.targetPlatform)".StartsWith("android") -and -not $_.emulator
    })

    if ($androidDevices.Count -eq 0) {
        Fail "Nessun dispositivo Android USB collegato. Collega il telefono tramite USB e assicurati che il debug USB sia abilitato."
    }

    $selected = $androidDevices | Select-Object -First 1
    $deviceId = "$($selected.id)"
    $deviceName = if ($selected.name) { "$($selected.name)" } else { $deviceId }
    
    Write-Info "Dispositivo rilevato: $deviceName ($deviceId)"
    return $deviceId
}

# Parse arguments
Parse-Args $ScriptArgs

if ($script:ShowHelp) {
    Show-Usage
    exit 0
}

# Rileva il device USB
$detectedDeviceId = Get-FirstConnectedAndroidDevice

# Costruisci gli argomenti per il launcher script
$launcherArgs = @("--device-id", $detectedDeviceId)

if ($script:SkipSeed) {
    $launcherArgs += "--skip-seed"
}

if ($script:KeepBackground) {
    $launcherArgs += "--keep-background"
}

if ($script:LocalOnly) {
    $launcherArgs += "--local-only"
}

if ($script:BackendOnly) {
    $launcherArgs += "--backend-only"
}

if ($script:WithOcr) {
    $launcherArgs += "--with-ocr"
}

if ($script:ApiPort -ne 8000) {
    $launcherArgs += "--api-port", $script:ApiPort
}

if ($script:PreferLan) {
    $launcherArgs += "--prefer-lan"
}

if ($script:UseLocalGemma) {
    $launcherArgs += "--local-gemma"
}

Write-Info "Avvio launcher script con device: $detectedDeviceId"
& powershell -ExecutionPolicy Bypass -File $LauncherScript @launcherArgs
