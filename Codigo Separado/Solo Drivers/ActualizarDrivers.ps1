# Requiere ejecución como administrador
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process powershell "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Start-Transcript -Path "$env:USERPROFILE\Desktop\actualizacion_log.txt" -Append

function Verificar-Conectividad {
    try {
        if (-not (Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet)) {
            throw "Sin acceso a Internet."
        }
    } catch {
        Write-Error "❌ Error de red: $_"
        Stop-Transcript
        exit 1
    }
}

function Esta-Instalado {
    param ([string]$id)
    $apps = winget list --id "$id" 2>$null
    return ($apps -match "$id")
}

function Detectar-Fabricante {
    try {
        $fabricante = (Get-CimInstance -Class Win32_ComputerSystem).Manufacturer
        return $fabricante.Trim()
    } catch {
        Write-Warning "⚠️ No se pudo detectar el fabricante: $_"
        return "Desconocido"
    }
}

function Instalar-Winget {
    Write-Host "🔧 Winget no detectado. Intentando instalarlo desde Microsoft Store..."
    try {
        # Descarga el instalador del App Installer desde el sitio oficial de Microsoft
        Start-Process "https://apps.microsoft.com/store/detail/app-installer/9NBLGGH4NNS1" -Wait
        Read-Host "🛈 Instala Winget manualmente desde la Microsoft Store. Presiona ENTER cuando esté listo para continuar..."
    } catch {
        Write-Error "❌ No se pudo abrir el instalador de Winget: $_"
        Stop-Transcript
        exit 1
    }
}

function Instalar-SoporteFabricante {
    param ([string]$fabricante)
    $instalado = $false

    Write-Host "`n🔧 Verificando soporte del fabricante..."

    switch -Regex ($fabricante) {
        "innotek|VMware|VirtualBox|Microsoft Corporation|QEMU" {
            Write-Warning "🖥️ Entorno virtual detectado. Se omite instalación del software del fabricante."
            $instalado = $true
        }
        "Dell" {
            Write-Warning "⚠️ Dell.SupportAssist no puede instalarse automáticamente."
            Start-Process "https://www.dell.com/support/home/es-es/?app=drivers"
            $instalado = $true
        }
        "HP" {
            Write-Warning "⚠️ HP Support Assistant no se puede instalar automáticamente."
            Start-Process "https://support.hp.com/ec-es/help/hp-support-assistant"
            $instalado = $true
        }
        "Lenovo" {
            Write-Warning "⚠️ Lenovo Vantage requiere instalación manual."
            Start-Process "https://support.lenovo.com/ec/es/solutions/ht037099"
            $instalado = $true
        }
        "Acer" {
            Write-Warning "⚠️ Acer Care Center debe instalarse manualmente."
            Start-Process "https://www.acer.com/ar-es/support/drivers-and-manuals"
            $instalado = $true
        }
        "ASUS" {
            Write-Warning "⚠️ MyASUS requiere descarga manual."
            Start-Process "https://www.asus.com/support/Download-Center/"
            $instalado = $true
        }
        "Gigabyte" {
            Write-Warning "⚠️ GIGABYTE Control Center debe descargarse manualmente."
            Start-Process "https://www.gigabyte.com/Consumer/Software/GIGABYTE-Control-Center/global/"
            $instalado = $true
        }
        "MSI" {
            Write-Warning "⚠️ MSI Center requiere instalación manual."
            Start-Process "https://www.msi.com/Landing/MSI-Center"
            $instalado = $true
        }
        "Samsung" {
            Write-Warning "⚠️ Samsung Update debe descargarse manualmente."
            Start-Process "https://www.samsung.com/latin/support/downloadcenter/"
            $instalado = $true
        }
        Default {
            Write-Warning "⚠️ Fabricante no reconocido. Visita el sitio web oficial del fabricante para soporte."
        }
    }

    return $instalado
}

function Usar-SDILite {
    $downloadPage = "https://sdi-tool.org/download/"
    $zipPath = "$env:TEMP\SDI_Lite.zip"
    $extractPath = "$env:TEMP\SDI_Lite"

    Write-Host "`n🔍 Buscando la última versión de SDI Lite..."

    try {
        $html = Invoke-WebRequest -Uri $downloadPage -UseBasicParsing
        $matches = [regex]::Matches($html.Content, 'https://sdi-tool\.org/releases/SDI_R\d+\.zip')
        if ($matches.Count -eq 0) {
            Write-Warning "⚠️ No se encontró enlace de descarga."
            return
        }

        $latestUrl = $matches[0].Value
        Write-Host "⬇️ Descargando desde: $latestUrl"
        Invoke-WebRequest -Uri $latestUrl -OutFile $zipPath

        Write-Host "📦 Extrayendo SDI Lite..."
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

        $sdiExe = Get-ChildItem -Path $extractPath -Recurse -Filter "SDI_Relaxed.exe" | Select-Object -First 1
        if ($sdiExe) {
            Write-Host "🚀 Ejecutando SDI Lite..."
            Start-Process -FilePath $sdiExe.FullName -ArgumentList "/autoinstall"
        } else {
            Write-Warning "❌ No se encontró el ejecutable."
        }
    } catch {
        Write-Warning "❌ Error en descarga o extracción de SDI Lite: $_"
    }
}

# MAIN
Write-Host "`n🚀 Iniciando actualización del sistema..."
Verificar-Conectividad

if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
    Instalar-Winget
    if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Error "❌ Winget sigue sin estar disponible después del intento de instalación."
        Stop-Transcript
        exit 1
    }
}

Write-Host "🔄 Actualizando orígenes de Winget..."
winget source update

$fabricante = Detectar-Fabricante
Write-Host "`n🏷️ Fabricante detectado: $fabricante"

$soporteInstalado = Instalar-SoporteFabricante -fabricante $fabricante

if (-not $soporteInstalado) {
    Usar-SDILite
}

Stop-Transcript
Read-Host "✅ Actualización completada. Presiona ENTER para salir"
