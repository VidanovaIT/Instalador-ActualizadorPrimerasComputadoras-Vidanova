# Instalador y Actualizador de Software para Primeras Computadoras Vidanova
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

function EstaInstalado {
    param ([string]$id)
    $apps = winget list --id "$id" 2>$null
    return ($apps -match "$id")
}

function TieneActualizacion {
    param ([string]$id)
    $updates = winget upgrade --id "$id" 2>$null
    return ($updates -match "$id")
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

function InstalarWinget {
    Write-Log "Winget no detectado. Intentando instalarlo..." "INFO"
    try {
        Invoke-WebRequest -Uri "https://aka.ms/getwinget" -OutFile "$env:TEMP\winget.msixbundle" -UseBasicParsing
        Add-AppxPackage -Path "$env:TEMP\winget.msixbundle"
        Write-Log "Winget instalado correctamente." "INFO"
    }
    catch {
        Write-Warning "Error al instalar Winget: $_"
        Stop-Transcript
        exit 1
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


function GetBrowserPath {
    $edgePaths = @(
        "$env:ProgramFiles (x86)\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
    )
    $chromePaths = @(
        "$env:ProgramFiles (x86)\Google\Chrome\Application\chrome.exe",
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
    )
    $firefoxPaths = @(
        "$env:ProgramFiles (x86)\Mozilla Firefox\firefox.exe",
        "$env:ProgramFiles\Mozilla Firefox\firefox.exe"
    )

    foreach ($exe in $edgePaths)   { if (Test-Path $exe) { return $exe } }
    foreach ($exe in $chromePaths) { if (Test-Path $exe) { return $exe } }
    foreach ($exe in $firefoxPaths){ if (Test-Path $exe) { return $exe } }
    return $null # Default
}

function DescargarFondosYProtectorDePantalla {
    Write-Log "Iniciando descarga de fondos y protector..." "INFO"
    try {
        # Carpeta de Fondos
        $pictures = [Environment]::GetFolderPath("MyPictures")
        $fondosPath = Join-Path $pictures "Fondos"

        $fondos = @(
            @{ url = "https://drive.usercontent.google.com/download?id=1O2drBdLD7aPkpIdIGPB4hhUC6OH1LIh5&export=download"; nombre = "Fondo de Escritorio.png" },
            @{ url = "https://drive.usercontent.google.com/download?id=1tOv6xbWirAet1gdMtESQYjaqTBK9RqI8&export=download"; nombre = "Fondo de Zoom.png" }
        )

        $videos = [Environment]::GetFolderPath("MyVideos")
        $videoDestino = Join-Path $videos "PROTECTOR-1.mp4"

        # Verificar si ya existen todos los archivos
        $fondosInstalados = $true
        foreach ($fondo in $fondos) {
            $destino = Join-Path $fondosPath $fondo.nombre
            if (!(Test-Path $destino)) { $fondosInstalados = $false }
        }
        $videoInstalado = Test-Path $videoDestino

        if ($fondosInstalados -and $videoInstalado) {
            Write-Log "Fondos y protector ya instalados. Omitiendo descarga." "INFO"
            return
        }

        if (!(Test-Path $pictures)) {
            New-Item -ItemType Directory -Path $pictures | Out-Null
            Write-Log "Carpeta de Imágenes creada: $pictures" "INFO"
        }

        if (!(Test-Path $fondosPath)) {
            New-Item -ItemType Directory -Path $fondosPath | Out-Null
            Write-Log "Carpeta de Fondos creada: $fondosPath" "INFO"
        }

        foreach ($fondo in $fondos) {
            $destino = Join-Path $fondosPath $fondo.nombre
            Write-Log "Descargando $($fondo.nombre)..." "INFO"
            Invoke-WebRequest -Uri $fondo.url -OutFile $destino -UseBasicParsing
        }

        Write-Log "Fondos descargados correctamente en $fondosPath" "INFO"

        if (!(Test-Path $videos)) {
            New-Item -ItemType Directory -Path $videos | Out-Null
            Write-Log "Carpeta de Videos creada: $videos" "INFO"
        }

        $videoUrl = "https://drive.usercontent.google.com/download?id=1bZyh8AuVB9I_ezN1bEHdtypxR5uXCCoB&export=download"

        Write-Log "Descargando PROTECTOR-1.mp4..." "INFO"
        Write-Log "Descargando PROTECTOR-1.mp4..." "INFO"
        Start-BitsTransfer -Source $videoUrl -Destination $videoDestino

        Write-Log "Protector descargado correctamente en $videos" "INFO"
    }
    catch {
        Write-Warning "Error al descargar fondos o protector: $_"
    }
}

function ConfigurarLivelyProtectorYFondo {
    Write-Log "Iniciando configuración SOLO del protector de pantalla Lively..." "INFO"
    try {
        $livelyPaths = @(
            "C:\Program Files\Lively Wallpaper\Lively.exe",
            "C:\Program Files\Lively\Lively.exe",
            "C:\Program Files (x86)\Lively Wallpaper\Lively.exe",
            "C:\Program Files (x86)\Lively\Lively.exe"
        )
        $livelyExe = $null
        foreach ($path in $livelyPaths) {
            if (Test-Path $path) {
                $livelyExe = $path
                break
            }
        }
        if (-not $livelyExe) {
            $found = Get-ChildItem -Path "C:\Program Files", "C:\Program Files (x86)" -Recurse -ErrorAction SilentlyContinue -Filter "Lively.exe" | Select-Object -First 1
            if ($found) { $livelyExe = $found.FullName }
        }
        if (-not $livelyExe) {
            Write-Warning "No se encontró Lively.exe en una ruta conocida."
            return
        }

        $videoPath = Join-Path ([Environment]::GetFolderPath("MyVideos")) "PROTECTOR-1.mp4"
        $fondoPath = Join-Path ([Environment]::GetFolderPath("MyPictures")) "Fondos\Fondo de Escritorio.png"
        $destScr = "C:\Windows\Lively.scr"

        # 0. Establecer fondo clásico de Windows primero (respaldo visual inmediato)
        if (Test-Path $fondoPath) {
            Write-Log "Estableciendo fondo clásico de Windows como respaldo..." "INFO"
            Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name wallpaper -Value $fondoPath
            RUNDLL32.EXE user32.dll,UpdatePerUserSystemParameters
            Write-Log "Fondo clásico aplicado exitosamente como base." "INFO"
        } else {
            Write-Warning "No se encontró la imagen de fondo clásico en: $fondoPath"
        }

        # 1. Importar el video a la biblioteca de Lively
        if (Test-Path $videoPath) {
            Write-Log "Importando video a la biblioteca de Lively..." "INFO"
            Start-Process -FilePath $livelyExe -ArgumentList "addwallpaper", "`"$videoPath`""
        } else {
            Write-Warning "No se encontró el archivo de video en: $videoPath"
            return
        }

        # 2. Registrar Lively.scr como protector de pantalla
        if (Test-Path $destScr) {
            Write-Log "Configurando Lively como protector de pantalla en Windows..." "INFO"
            Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "SCRNSAVE.EXE" -Value $destScr
            Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "ScreenSaveTimeOut" -Value 300
            Write-Log "Protector de pantalla configurado correctamente (5 minutos)." "INFO"

            # 3. Aplicar el video como fondo temporalmente para activar el protector
            Write-Log "Aplicando video como fondo temporalmente para el protector..." "INFO"
            Start-Process -FilePath $livelyExe -ArgumentList "setwp", "--file", "`"$videoPath`""
            Start-Sleep -Seconds 5

            # 4. Cerrar el fondo activo (el protector ya tomó el video)
            Write-Log "Cerrando fondo activo de Lively..." "INFO"
            Start-Process -FilePath $livelyExe -ArgumentList "closewp", "-1"
            Start-Sleep -Seconds 2

            Write-Log "Proceso de configuración del protector completado exitosamente." "INFO"
        } else {
            Write-Warning "No se encontró Lively.scr en $destScr"
        }
    }
    catch {
        Write-Warning "Error en configuración de Lively protector: $_"
    }
}



function AbrirEnNavegador {
    param([string]$url)
    $browser = GetBrowserPath
    if ($browser) {
        Write-Log "Abriendo en navegador: $browser" "INFO"
        Start-Process -FilePath $browser -ArgumentList $url
    } else {
        Write-Log "No se detecto navegador moderno, abriendo con el predeterminado (Edge/IE)." "WARNING"
        Start-Process $url
    }
}

function InstalarDesdeWeb {
    param (
        [string]$nombre,
        [string]$url,
        [string]$archivo,
        [string]$fallbackPage
    )
    $ruta = "$env:TEMP\$archivo"
    Write-Log "Descargando $nombre desde: $url" "INFO"
    try {
        $headers = @{
            "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
        }
        $resp = Invoke-WebRequest -Uri $url -OutFile $ruta -Headers $headers -UseBasicParsing -ErrorAction Stop

        if (Test-Path $ruta) {
            $tam = (Get-Item $ruta).Length
            $firma = ""
            $esExe = $false

            if ($tam -gt 512) {
                $stream = [System.IO.File]::OpenRead($ruta)
                $bytes = New-Object byte[] 2
                $stream.Read($bytes, 0, 2) | Out-Null
                $firma = [System.Text.Encoding]::ASCII.GetString($bytes)
                $stream.Close()
                if ($firma -eq "MZ") { $esExe = $true }
            }
            if ($esExe -or ($archivo.ToLower().EndsWith(".exe") -and $tam -gt 800000)) {
                Write-Log "Lanzando instalador de $nombre ($archivo, tam: $([Math]::Round($tam/1MB,2)) MB)..." "INFO"
                try {
                    $proc = Start-Process -FilePath $ruta -PassThru
                    Start-Sleep -Seconds 7
                    if (!$proc.HasExited) {
                        Write-Log "$nombre sigue ejecutandose. Continuando sin esperar..." "INFO"
                    }
                }
                catch {
                    Write-Warning "No se pudo ejecutar el instalador de $nombre."
                    if ($fallbackPage) {
                        Write-Log "Abriendo pagina oficial para instalacion manual de $nombre..." "INFO"
                        AbrirEnNavegador $fallbackPage
                        Write-Log "Si no se abre automaticamente, copie y pegue la URL: $fallbackPage" "INFO"
                        Read-Host "Presione ENTER para continuar..."
                    }
                }
            }
            else {
                $content = Get-Content $ruta -TotalCount 1
                if ($content -like "<*" -or $content -like "<?*") {
                    Write-Warning "La descarga de $nombre no es ejecutable (posible HTML, tam: $([Math]::Round($tam/1KB,2)) KB)."
                } else {
                    Write-Warning "Descarga de $nombre parece incompleta o corrupta (tam: $([Math]::Round($tam/1KB,2)) KB, firma: $firma)."
                }
                Remove-Item $ruta -Force
                if ($fallbackPage) {
                    Write-Log "Abriendo pagina oficial para instalacion manual de $nombre..." "INFO"
                    AbrirEnNavegador $fallbackPage
                    Write-Log "Si no se abre automaticamente, copie y pegue la URL: $fallbackPage" "INFO"
                    Read-Host "Presione ENTER para continuar..."
                }
            }
        }
        else {
            Write-Warning "No se descargo el instalador de $nombre." "WARNING"
            if ($fallbackPage) {
                Write-Log "Abriendo pagina oficial para instalacion manual de $nombre..." "INFO"
                AbrirEnNavegador $fallbackPage
                Write-Log "Si no se abre automaticamente, copie y pegue la URL: $fallbackPage" "INFO"
                Read-Host "Presione ENTER para continuar..."
            }
        }
    }
    catch {
        Write-Warning "Error descargando/ejecutando $nombre."
        if ($fallbackPage) {
            Write-Log "Abriendo pagina oficial para instalacion manual de $nombre..." "INFO"
            AbrirEnNavegador $fallbackPage
            Write-Log "Si no se abre automaticamente, copie y pegue la URL: $fallbackPage" "INFO"
            Read-Host "Presione ENTER para continuar..."
        }
    }
}

# =================== BLOQUE PRINCIPAL AQUi =====================
try {
    Write-Log "`nIniciando mantenimiento del sistema..." "INFO"
    VerificarConectividad

    if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
        InstalarWinget
        if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
            throw "Winget no disponible tras intento de instalacion."
        }
    }

    Write-Host "`nVerificacion inicial de Winget."
    Write-Host "`nMostrando lista de paquetes (winget list)."
    Write-Host "Si es la primera vez, puede pedir aceptar terminos. Presiona Y y ENTER si corresponde."


    winget list --accept-source-agreements --upgrade-available

    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Winget no pudo listar los paquetes. Verifica tu conexion a Internet o la instalacion de Winget."
        Read-Host "Presiona ENTER para continuar..."
        exit 1
    }

    $fabricante = DetectarFabricante
    Write-Log "`nFabricante: $fabricante" "INFO"
    InstalarSoporteFabricante -fab $fabricante

    $total = $programas.Count
    $index = 0

    foreach ($programa in $programas) {
        $index++
        $porcentaje = [math]::Round(($index / $total) * 100)
        Write-Log "`n[$porcentaje%] $($programa.nombre)..." "INFO"

        if (!(EstaInstalado $programa.id)) {
            Write-Log "No instalado. Usando Winget..." "INFO"
            winget install --id $($programa.id) --silent --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -eq 0) {
                Write-Log "$($programa.nombre) instalado." "INFO"
            }
            elseif ($programa.fallbackUrl) {
                Write-Warning "Winget fallo. Usando metodo alternativo..."
                InstalarDesdeWeb -nombre $programa.nombre -url $programa.fallbackUrl -archivo $programa.archivo -fallbackPage $programa.fallbackPage
            }
            else {
                Write-Warning "Error instalando $($programa.nombre)."
            }
        } 
        else {
            Write-Log "Ya instalado." "INFO"
            if (TieneActualizacion $programa.id) {
                Write-Log "Actualizando..." "INFO"
                winget upgrade --id $($programa.id) --silent --accept-source-agreements --accept-package-agreements
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "Actualizado correctamente." "INFO"
                }
                else {
                    Write-Warning "Error actualizando $($programa.nombre)."
                }
            }
            else {
                Write-Log "$($programa.nombre) esta actualizado." "INFO"
            }
        }
    }

}
catch {
    Write-Log "Error critico: $_" "ERROR"
}
finally {
    Read-Host "`nMantenimiento completado o detenido. Presione ENTER para salir"
}

# Lista de programas
$programas = @(
    @{ nombre = "Google Chrome"; id = "Google.Chrome" }
    @{ nombre = "WhatsApp"; id = "WhatsApp.WhatsApp"; fallbackUrl = "https://get.microsoft.com/installer/download/9NKSQGP7F2NH?cid=website_cta_psi"; archivo = "WhatsAppInstaller.exe"; fallbackPage = "https://www.whatsapp.com/download/windows" },    
    @{ nombre = "AnyDesk"; id = "AnyDesk.AnyDesk"; fallbackUrl = "https://download.anydesk.com/AnyDesk.exe"; archivo = "AnyDesk.exe"; fallbackPage = "https://anydesk.com/es/downloads/windows" },
    @{ nombre = "Thunderbird"; id = "Mozilla.Thunderbird" },
    @{ nombre = "Google Drive"; id = "Google.GoogleDrive"; fallbackUrl = "https://dl.google.com/drive-file-stream/GoogleDriveSetup.exe"; archivo = "GoogleDriveSetup.exe"; fallbackPage = "https://www.google.com/drive/download/" },
    @{ nombre = "Lively Wallpaper"; id = "rocksdanister.LivelyWallpaper" },
    @{ nombre = "WinRAR"; id = "RARLab.WinRAR"; fallbackUrl = "https://www.win-rar.com/fileadmin/winrar-versions/winrar/winrar-x64-711es.exe"; archivo = "WinRAR-x64.exe"; fallbackPage = "https://www.win-rar.com/download.html" },
    @{ nombre = "Adobe Acrobat Reader"; id = "Adobe.Acrobat.Reader.64-bit"; fallbackPage = "https://get.adobe.com/es/reader/" },
    @{ nombre = "Microsoft Teams"; id = "Microsoft.Teams"; fallbackUrl = "https://statics.teams.cdn.office.net/evergreen-assets/DesktopClient/MSTeamsSetup.exe"; archivo = "MSTeamsSetup.exe"; fallbackPage = "https://www.microsoft.com/es-es/microsoft-teams/download-app" },
    @{ nombre = "VLC Media Player"; id = "VideoLAN.VLC"; fallbackUrl = "https://get.videolan.org/vlc/3.0.21/win32/vlc-3.0.21-win32.exe"; archivo = "vlc-3.0.21-win32.exe"; fallbackPage = "https://www.videolan.org/vlc/download-windows.html" }
)

$total = $programas.Count
$index = 0

foreach ($programa in $programas) {
    $index++
    $porcentaje = [math]::Round(($index / $total) * 100)
    Write-Log "`n[$porcentaje%] $($programa.nombre)..." "INFO"

    if (!(EstaInstalado $programa.id)) {
        Write-Log "No instalado. Usando Winget..." "INFO"
        winget install --id $($programa.id) --silent --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Log "$($programa.nombre) instalado." "INFO"
        }
        elseif ($programa.fallbackUrl) {
            Write-Warning "Winget fallo. Usando metodo alternativo..."
            InstalarDesdeWeb -nombre $programa.nombre -url $programa.fallbackUrl -archivo $programa.archivo -fallbackPage $programa.fallbackPage
        }
        else {
            Write-Warning "Error instalando $($programa.nombre)."
        }
    } 
    else {
        Write-Log "Ya instalado." "INFO"
        if (TieneActualizacion $programa.id) {
            Write-Log "Actualizando..." "INFO"
            winget upgrade --id $($programa.id) --silent --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Actualizado correctamente." "INFO"
            }
            else {
                Write-Warning "Error actualizando $($programa.nombre)."
            }
        }
        else {
            Write-Log "$($programa.nombre) esta actualizado." "INFO"
        }
    }
}

# Descargar fondos y video de protector de pantalla
DescargarFondosYProtectorDePantalla

# Configurar Lively, fondo y protector de pantalla
ConfigurarLivelyProtectorYFondo

Read-Host "`nMantenimiento completado. Presione ENTER para salir"
