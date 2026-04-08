Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:ScriptArgs = @($args)
$script:PairAddress = ""
$script:PairCode = ""
$script:ConnectAddress = ""
$script:DeviceId = ""
$script:RunBackendOnly = $false
$script:ForwardedArgs = New-Object System.Collections.Generic.List[string]

$script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:LauncherScript = Join-Path $ScriptDir "run_android_app.ps1"

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
  powershell -ExecutionPolicy Bypass -File scripts/run_android_app_wifi.ps1 --connect-address HOST:PORT [opzioni]
  powershell -ExecutionPolicy Bypass -File scripts/run_android_app_wifi.ps1 --pair-address HOST:PAIR_PORT --pair-code CODE --connect-address HOST:PORT [opzioni]
  powershell -ExecutionPolicy Bypass -File scripts/run_android_app_wifi.ps1 --device-id HOST:PORT [opzioni]

Opzioni Wi-Fi:
  --pair-address HOST:PORT     Indirizzo mostrato in Wireless debugging per adb pair.
  --pair-code CODE             Codice numerico mostrato in Wireless debugging.
  --connect-address HOST:PORT  Indirizzo Wi-Fi del device da usare con adb connect.
  --device-id ID               Serial ADB gia connesso via Wi-Fi.

Le altre opzioni vengono passate a scripts/run_android_app.ps1:
  --skip-seed
  --keep-background
  --backend-only
  --with-ocr
  --api-port PORT
  --api-base-url URL
  -- --debug

Esempi:
  powershell -ExecutionPolicy Bypass -File scripts/run_android_app_wifi.ps1 --pair-address 192.168.1.42:37123 --pair-code 123456 --connect-address 192.168.1.42:5555
  powershell -ExecutionPolicy Bypass -File scripts/run_android_app_wifi.ps1 --connect-address 192.168.1.42:5555
  powershell -ExecutionPolicy Bypass -File scripts/run_android_app_wifi.ps1 --device-id 192.168.1.42:5555 --skip-seed
"@ | Write-Host
}

function Parse-Args {
    param([string[]]$Arguments)

    for ($index = 0; $index -lt $Arguments.Count; $index++) {
        $current = $Arguments[$index]
        switch ($current) {
            "--pair-address" {
                $index++
                if ($index -ge $Arguments.Count) {
                    Fail "Manca il valore per --pair-address"
                }
                $script:PairAddress = $Arguments[$index]
            }
            "--pair-code" {
                $index++
                if ($index -ge $Arguments.Count) {
                    Fail "Manca il valore per --pair-code"
                }
                $script:PairCode = $Arguments[$index]
            }
            "--connect-address" {
                $index++
                if ($index -ge $Arguments.Count) {
                    Fail "Manca il valore per --connect-address"
                }
                $script:ConnectAddress = $Arguments[$index]
            }
            "--device-id" {
                $index++
                if ($index -ge $Arguments.Count) {
                    Fail "Manca il valore per --device-id"
                }
                $script:DeviceId = $Arguments[$index]
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
                    for ($restIndex = $index; $restIndex -lt $Arguments.Count; $restIndex++) {
                        $script:ForwardedArgs.Add($Arguments[$restIndex]) | Out-Null
                    }
                }
                return
            }
            "--backend-only" {
                $script:RunBackendOnly = $true
                $script:ForwardedArgs.Add($current) | Out-Null
            }
            default {
                $script:ForwardedArgs.Add($current) | Out-Null
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

function Ensure-FlutterOnPath {
    if (Get-Command "flutter" -ErrorAction SilentlyContinue) {
        return
    }

    $candidates = @()
    if ($env:FLUTTER_ROOT) {
        $candidates += $env:FLUTTER_ROOT
    }
    if ($env:LOCALAPPDATA) {
        $candidates += (Join-Path $env:LOCALAPPDATA "flutter")
    }
    $candidates += "C:\Users\Nicola\tools\flutter"

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        $flutterBin = Join-Path $candidate "bin"
        $flutterExecutable = Join-Path $flutterBin "flutter.bat"
        if (Test-Path $flutterExecutable) {
            $env:PATH = "$flutterBin;$env:PATH"
            return
        }
    }

    Fail "Flutter non trovato nella PATH o in C:\Users\Nicola\tools\flutter. Apri un terminale con Flutter disponibile oppure imposta FLUTTER_ROOT."
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
        $candidates += (Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe")
    }

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if ($candidate -and (Test-Path $candidate)) {
            return $candidate
        }
    }

    return $null
}

function Connect-WifiDebugDevice {
    if ($PairAddress -and -not $PairCode) {
        Fail "Specifica --pair-code insieme a --pair-address."
    }

    if ($PairAddress -and -not $ConnectAddress) {
        Fail "Con il pairing Wi-Fi devi specificare anche --connect-address."
    }

    if ($DeviceId -and $ConnectAddress -and $DeviceId -ne $ConnectAddress) {
        Fail "--device-id e --connect-address devono riferirsi allo stesso seriale oppure usa solo uno dei due."
    }

    if (-not $PairAddress -and -not $ConnectAddress -and -not $DeviceId) {
        Fail "Specifica almeno --device-id oppure --connect-address."
    }

    $adbPath = Get-AdbPath
    if (-not $adbPath) {
        Fail "adb non trovato. Installa Android SDK platform-tools o verifica la PATH."
    }

    if ($PairAddress) {
        Write-Info "Eseguo adb pair con $PairAddress..."
        & $adbPath pair $PairAddress $PairCode
        if ($LASTEXITCODE -ne 0) {
            Fail "Pairing adb fallito. Controlla indirizzo, porta e codice mostrati nel pannello Wireless debugging."
        }
    }

    if ($ConnectAddress) {
        Write-Info "Eseguo adb connect con $ConnectAddress..."
        & $adbPath connect $ConnectAddress
        if ($LASTEXITCODE -ne 0) {
            Fail "Connessione adb fallita. Verifica che telefono e PC siano sulla stessa Wi-Fi e che Wireless debugging sia attivo."
        }

        Write-Info "Attendo la disponibilita del device Wi-Fi..."
        & $adbPath -s $ConnectAddress wait-for-device
        if ($LASTEXITCODE -ne 0) {
            Fail "Il device Wi-Fi non e diventato disponibile dopo adb connect."
        }

        if (-not $DeviceId) {
            $script:DeviceId = $ConnectAddress
        }
    }
}

function Invoke-Launcher {
    $launcherArgs = @()

    if ($DeviceId) {
        $launcherArgs += @("--device-id", $DeviceId)
    }

    $launcherArgs += "--prefer-lan"

    if ($ForwardedArgs.Count -gt 0) {
        $launcherArgs += $ForwardedArgs.ToArray()
    }

    Write-Info "Avvio backend + app tramite Wi-Fi debugging..."
    & $LauncherScript @launcherArgs
    if ($LASTEXITCODE -ne 0) {
        Fail "scripts/run_android_app.ps1 non e riuscito."
    }
}

Parse-Args $ScriptArgs
Require-Command "python"
Require-Command "docker"

if (-not $RunBackendOnly) {
    Ensure-FlutterOnPath
    Connect-WifiDebugDevice
}

Invoke-Launcher