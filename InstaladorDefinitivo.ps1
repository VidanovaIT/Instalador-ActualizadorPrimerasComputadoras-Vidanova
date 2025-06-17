# Ejecutar como Administrador
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File '$PSCommandPath'" -Verb RunAs
    exit
}

# Iniciar Logs
Start-Transcript -Path "$env:USERPROFILE\Desktop\actualizacion_instalacion_log.txt" -Append
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function VerificarConectividad {
    try {
        if (-not (Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet)) {
            throw "Sin acceso a Internet."
        }
    }
    catch {
        Write-Error "Error de red: $_"
        Stop-Transcript
        exit 1
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
    Write-Host "Winget no detectado. Intentando instalarlo..."
    try {
        Invoke-WebRequest -Uri "https://aka.ms/getwinget" -OutFile "$env:TEMP\winget.msixbundle" -UseBasicParsing
        Add-AppxPackage -Path "$env:TEMP\winget.msixbundle"
        Write-Host "Winget instalado correctamente."
    }
    catch {
        Write-Warning "Error al instalar Winget: $_"
        Stop-Transcript
        exit 1
    }
}

function InstalarSoporteFabricante {
    param ([string]$fab)
    $instalado = $false
    Write-Host "`nVerificando soporte del fabricante..."

    switch -Regex ($fab) {
        "innotek|VMware|VirtualBox|Microsoft Corporation|QEMU" {
            Write-Warning "Entorno virtual detectado. Omitiendo soporte fabricante."
            $instalado = $true
        }
        "Dell" { Start-Process "https://www.dell.com/support/home/es-es/drivers/driversdetails?driverid=0K9T7"; $instalado = $true }
        "HP" { Start-Process "https://support.hp.com/ec-es/help/hp-support-assistant"; $instalado = $true }
        "Lenovo" { Start-Process "https://support.lenovo.com/ec/es/solutions/ht037099"; $instalado = $true }
        "Acer" { Start-Process "https://www.acer.com/ar-es/support/drivers-and-manuals"; $instalado = $true }
        "ASUS" { Start-Process "https://www.asus.com/support/Download-Center/"; $instalado = $true }
        "Gigabyte" { Start-Process "https://www.gigabyte.com/Consumer/Software/GIGABYTE-Control-Center/global/"; $instalado = $true }
        "MSI" { Start-Process "https://www.msi.com/Landing/MSI-Center"; $instalado = $true }
        "Samsung" { Start-Process "https://www.samsung.com/latin/support/downloadcenter/"; $instalado = $true }
        Default {
            Write-Warning "Fabricante no reconocido. Visite sitio oficial."
        }
    }

    return $instalado
}

function UsarSDILite {
    $downloadPage = "https://sdi-tool.org/download/"
    $zipPath = "$env:TEMP\SDI_Lite.zip"
    $extractPath = "$env:TEMP\SDI_Lite"

    Write-Host "`nBuscando SDI Lite..."

    try {
        $html = Invoke-WebRequest -Uri $downloadPage -UseBasicParsing
        $matches = [regex]::Matches($html.Content, 'https://sdi-tool\.org/releases/SDI_R\d+\.zip')
        if ($matches.Count -eq 0) {
            Write-Warning "No se encontro enlace de descarga."
            return
        }

        $latestUrl = $matches[0].Value
        Write-Host "Descargando desde: $latestUrl"
        Invoke-WebRequest -Uri $latestUrl -OutFile $zipPath

        Write-Host "Extrayendo..."
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

        $sdiExe = Get-ChildItem -Path $extractPath -Recurse -Filter "SDI_Relaxed.exe" | Select-Object -First 1
        if ($sdiExe) {
            Write-Host "Ejecutando SDI Lite..."
            Start-Process -FilePath $sdiExe.FullName -ArgumentList "/autoinstall"
        }
        else {
            Write-Warning "Ejecutable no encontrado."
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

function AbrirEnNavegador {
    param([string]$url)
    $browser = GetBrowserPath
    if ($browser) {
        Write-Host "Abriendo en navegador: $browser"
        Start-Process -FilePath $browser -ArgumentList $url
    } else {
        Write-Host "No se detecto navegador moderno, abriendo con el predeterminado (Edge/IE)."
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
    Write-Host "Descargando $nombre desde: $url"
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
                Write-Host "Lanzando instalador de $nombre ($archivo, tam: $([Math]::Round($tam/1MB,2)) MB)..."
                try {
                    $proc = Start-Process -FilePath $ruta -PassThru
                    Start-Sleep -Seconds 7
                    if (!$proc.HasExited) {
                        Write-Host "$nombre sigue ejecutandose. Continuando sin esperar..."
                    }
                }
                catch {
                    Write-Warning "No se pudo ejecutar el instalador de $nombre."
                    if ($fallbackPage) {
                        Write-Host "Abriendo pagina oficial para instalacion manual de $nombre..."
                        AbrirEnNavegador $fallbackPage
                        Write-Host "Si no se abre automaticamente, copie y pegue la URL: $fallbackPage"
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
                    Write-Host "Abriendo pagina oficial para instalacion manual de $nombre..."
                    AbrirEnNavegador $fallbackPage
                    Write-Host "Si no se abre automaticamente, copie y pegue la URL: $fallbackPage"
                    Read-Host "Presione ENTER para continuar..."
                }
            }
        }
        else {
            Write-Warning "No se descargo el instalador de $nombre."
            if ($fallbackPage) {
                Write-Host "Abriendo pagina oficial para instalacion manual de $nombre..."
                AbrirEnNavegador $fallbackPage
                Write-Host "Si no se abre automaticamente, copie y pegue la URL: $fallbackPage"
                Read-Host "Presione ENTER para continuar..."
            }
        }
    }
    catch {
        Write-Warning "Error descargando/ejecutando $nombre."
        if ($fallbackPage) {
            Write-Host "Abriendo pagina oficial para instalacion manual de $nombre..."
            AbrirEnNavegador $fallbackPage
            Write-Host "Si no se abre automaticamente, copie y pegue la URL: $fallbackPage"
            Read-Host "Presione ENTER para continuar..."
        }
    }
}

# INICIO DE PROCESO
Write-Host "`nIniciando mantenimiento del sistema..."
VerificarConectividad

if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
    InstalarWinget
    if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Error "Winget no disponible tras intento de instalacion."
        Stop-Transcript
        exit 1
    }
}

$fabricante = DetectarFabricante
Write-Host "`nFabricante: $fabricante"

$soporteInstalado = InstalarSoporteFabricante -fab $fabricante
if (-not $soporteInstalado) { UsarSDILite }

# Lista de programas
$programas = @(
    @{ nombre = "Google Chrome"; id = "Google.Chrome" },
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
    Write-Host "`n[$porcentaje%] $($programa.nombre)..."

    if (!(EstaInstalado $programa.id)) {
        Write-Host "No instalado. Usando Winget..."
        winget install --id $($programa.id) --silent --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Host "$($programa.nombre) instalado."
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
        Write-Host "Ya instalado."
        if (TieneActualizacion $programa.id) {
            Write-Host "Actualizando..."
            winget upgrade --id $($programa.id) --silent --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Actualizado correctamente."
            }
            else {
                Write-Warning "Error actualizando $($programa.nombre)."
            }
        }
        else {
            Write-Host "$($programa.nombre) esta actualizado."
        }
    }
}

Stop-Transcript
Read-Host "`nMantenimiento completado. Presione ENTER para salir"
