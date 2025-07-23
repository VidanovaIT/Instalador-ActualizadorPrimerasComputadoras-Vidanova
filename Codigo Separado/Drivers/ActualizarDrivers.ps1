# Requiere ejecución como administrador
# Ejecutar como Administrador
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File '$PSCommandPath'" -Verb RunAs
    exit
}

# Definir ruta log
$scriptPath = Split-Path -Parent $PSCommandPath
$global:LogFile = "$scriptPath\actualizacion_instalacion_log.txt"

$ErrorActionPreference = "Stop"

# =================== TODAS LAS FUNCIONES AQUi =====================

function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp [$Level] $Message"

    switch ($Level) {
        "ERROR"   { Write-Host $line -ForegroundColor Red } 
        "WARNING" { Write-Host $line -ForegroundColor Yellow }
        default   { Write-Host $line }
    }

    if ($global:LogFile) {
        Add-Content -Path $global:LogFile -Value $line
    }
}

function VerificarConectividad {
    Write-Log "Verificando conectividad a Internet..." "INFO"
    try {
        $response = Invoke-WebRequest -Uri "https://www.google.com" -UseBasicParsing -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            Write-Log "Conectividad verificada." "INFO"
        } else {
            Write-Warning "Conectividad fallida. Codigo de estado: $($response.StatusCode)"
        }
    }
    catch {
        Write-Warning "Error al verificar conectividad: $_"
    }
}

function DetectarFabricante {
    try {
        $fab = (Get-CimInstance -Class Win32_ComputerSystem).Manufacturer
        return $fab.Trim()
    }
    catch {
        Write-Warning "No se pudo detectar el fabricante: $_"
        return "Desconocido"
    }
}

function InstalarSoporteFabricante {
    param ([string]$fab)

    Write-Log "Verificando soporte del fabricante..." "INFO"
    Write-Log "Valor de fabricante detectado: '$fab'" "DEBUG"

    # Normalización de fabricante (alias comunes)
    $fab = $fab.Trim().ToLower()
    switch -Regex ($fab) {
        "hewlett-packard|hp inc|hp"                { $fab = "HP"; break }
        "dell inc|dell"                            { $fab = "Dell"; break }
        "lenovo"                                   { $fab = "Lenovo"; break }
        "acer"                                     { $fab = "Acer"; break }
        "asus|asustek"                             { $fab = "ASUS"; break }
        "gigabyte"                                 { $fab = "Gigabyte"; break }
        "msi"                                      { $fab = "MSI"; break }
        "samsung"                                  { $fab = "Samsung"; break }
        "fujitsu"                                  { $fab = "Fujitsu"; break }
        "toshiba|dynabook"                         { $fab = "Toshiba"; break }
        "sony|vaio"                                { $fab = "Sony"; break }
        "panasonic|let's note"                     { $fab = "Panasonic"; break }
        "hewlett-packard enterprise|hpe"           { $fab = "HPE"; break }
        "apple inc|apple"                          { $fab = "Apple"; break }
        "microsoft corporation"                    { $fab = "Microsoft"; break }
        "google"                                   { $fab = "Google"; break }
        "lg electronics|lg"                        { $fab = "LG"; break }
        "archos"                                   { $fab = "Archos"; break }
        default                                    { $fab = $fab } # sin cambio si no coincide
    }

    Write-Log "Fabricante normalizado: '$fab'" "DEBUG"

    $urls = @{
        "Dell"       = "https://www.dell.com/support/home/es-es/drivers/driversdetails?driverid=0K9T7"
        "HP"         = "https://support.hp.com/ec-es/help/hp-support-assistant"
        "Lenovo"     = "https://support.lenovo.com/ec/es/solutions/ht037099"
        "Acer"       = "https://www.acer.com/ar-es/support/drivers-and-manuals"
        "ASUS"       = "https://www.asus.com/support/Download-Center/"
        "Gigabyte"   = "https://www.gigabyte.com/Consumer/Software/GIGABYTE-Control-Center/global/"
        "MSI"        = "https://www.msi.com/Landing/MSI-Center"
        "Samsung"    = "https://www.samsung.com/latin/support/downloadcenter/"
        "Fujitsu"    = "https://www.fujitsu.com/global/support/products/"
        "Toshiba"    = "https://support.dynabook.com/"
        "Sony"       = "https://www.sony.com/electronics/support"
        "Panasonic"  = "https://www.panasonic.com/global/support/computer/download.html"
        "Apple"      = "https://support.apple.com/downloads"
        "Microsoft"  = "https://support.microsoft.com/es-es/downloads"
        "LG"         = "https://www.lg.com/us/support/software-firmware"
        "Google"     = "https://support.google.com/chromebook/answer/177889?hl=es"
        "Archos"     = "https://www.archos.com/fr/support/"
        "VAIO"       = "https://www.vaio.com/en/support"
        "Dynabook"   = "https://support.dynabook.com/"
        "HPE"        = "https://support.hpe.com/hpesc/public/home"
    }

    if ($fab -match "innotek|vmware|virtualbox|microsoft corporation|qemu") {
        Write-Warning "Entorno virtual detectado. Omitiendo soporte de fabricante."
        return
    }

    if ($urls.ContainsKey($fab)) {
        Write-Log "¡Nota importante sobre drivers!" 
        Write-Log " - Se recomienda descargar e instalar los controladores más actualizados directamente desde el fabricante:"
        Write-Log "   $($urls[$fab])"
        Write-Log " - Sin embargo, se procederá a instalar drivers usando SDI Lite, los cuales pueden no ser los más recientes." "INFO"
    }
    else {
        Write-Warning "Fabricante no reconocido. Se recomienda revisar manualmente la página oficial para drivers."
    }

    UsarSDILite
}

function UsarSDILite {
    $downloadPage = "https://sdi-tool.org/download/"
    $zipPath = "$env:TEMP\SDI_Lite.zip"
    $extractPath = "$env:TEMP\SDI_Lite"

    Write-Log "Buscando SDI Lite..." "INFO"

    try {
        $html = Invoke-WebRequest -Uri $downloadPage -UseBasicParsing
        $matches = [regex]::Matches($html.Content, 'https://sdi-tool\.org/releases/SDI_R\d+\.zip')
        if ($matches.Count -eq 0) {
            Write-Warning "No se encontró enlace de descarga."
            return
        }

        $latestUrl = $matches[0].Value
        Write-Log "Iniciando descarga desde: $latestUrl" "INFO"
        Write-Log "Descargando SDI Lite (esto puede tardar unos minutos)..." "INFO"
        Invoke-WebRequest -Uri $latestUrl -OutFile $zipPath

        if (Test-Path $zipPath) {
            Write-Log "Descarga completada. Preparando extracción..." "INFO"

            if (Test-Path $extractPath) {
                Write-Log "Limpiando carpeta temporal existente antes de extraer..." "INFO"
                Remove-Item -Path $extractPath -Recurse -Force
            }

            Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
            Write-Log "Extracción completada. Buscando ejecutable..." "INFO"

            $sdiExe = Get-ChildItem -Path $extractPath -Recurse -Filter "SDI_x64_*.exe" | Select-Object -First 1

            if (-not $sdiExe) {
                $sdiExe = Get-ChildItem -Path $extractPath -Recurse -Filter "SDI_R*.exe" | Select-Object -First 1
            }

            if ($sdiExe) {
                Write-Log "Agregando reglas de firewall para SDI Lite..." "INFO"
                New-NetFirewallRule -DisplayName "SDI Lite (Privada)" -Direction Inbound -Program $sdiExe.FullName -Action Allow -Profile Private -ErrorAction SilentlyContinue
                New-NetFirewallRule -DisplayName "SDI Lite (Pública)" -Direction Inbound -Program $sdiExe.FullName -Action Allow -Profile Public -ErrorAction SilentlyContinue

                # Paso 1: Descargar DriverPacks
                Write-Log "Paso 1: Ejecutando autoupdate para descargar solo lo necesario..." "INFO"
                Start-Process -FilePath $sdiExe.FullName `
                    -ArgumentList "-autoupdate","-connections:200","-autoclose" `
                    -Wait
                Write-Log "DriverPacks descargados correctamente." "INFO"

                # Paso 2: Abrir interfaz gráfica para instalación manual
                Write-Log "Paso 2: Abriendo SDI Lite en modo gráfico para instalación manual." "INFO"
                Start-Process -FilePath $sdiExe.FullName -WindowStyle Normal
                Write-Log "SDI Lite se está ejecutando de forma independiente para instalación manual. Puedes continuar con el resto del mantenimiento." "INFO"

            }
            else {
                Write-Warning "No se encontró el ejecutable principal en la carpeta extraída."
            }
        }
        else {
            Write-Warning "El archivo ZIP no se descargó correctamente. No se encontró: $zipPath"
        }
    }
    catch {
        Write-Warning "Error SDI Lite: $_"
    }
}

# =================== BLOQUE PRINCIPAL AQUi =====================
try {
    Write-Log "`nIniciando mantenimiento del sistema..." "INFO"
    VerificarConectividad

    $fabricante = DetectarFabricante
    Write-Log "`nFabricante: $fabricante" "INFO"
    InstalarSoporteFabricante -fab $fabricante
    Write-Log "`nMantenimiento del sistema completado." "INFO"
    
}
catch {
    Write-Log "Error critico: $_" "ERROR"
}
finally {
    Read-Host "`nMantenimiento completado o detenido. Presione ENTER para salir"
}