# Requiere ejecución como administrador
Start-Transcript -Path "$env:USERPROFILE\Desktop\instalacion_programas_log.txt" -Append
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Paso 1: Actualizar Winget y fuentes si es necesario
Write-Host "🔄 Verificando y actualizando Winget si es necesario..."
try {
    Invoke-WebRequest -Uri "https://aka.ms/getwinget" -OutFile "$env:TEMP\winget.msixbundle" -UseBasicParsing
    Add-AppxPackage -Path "$env:TEMP\winget.msixbundle"
    Write-Host "✅ Winget actualizado correctamente."
} catch {
    Write-Warning "⚠️ Error al intentar actualizar Winget: $_"
}
Write-Host "🔄 Actualizando fuentes de Winget..."
winget source update

# Funciones
function Esta-Instalado {
    param ([string]$id)
    $apps = winget list --id "$id" 2>$null
    return ($apps -match "$id")
}

function Tiene-Actualizacion {
    param ([string]$id)
    $updates = winget upgrade --id "$id" 2>$null
    return ($updates -match "$id")
}

function InstalarDesdeWeb {
    param (
        [string]$nombre,
        [string]$url,
        [string]$archivo
    )
    $ruta = "$env:TEMP\$archivo"
    Write-Host "🌐 Descargando instalador de $nombre desde: $url"
    try {
        Invoke-WebRequest -Uri $url -OutFile $ruta -UseBasicParsing
        if (Test-Path $ruta) {
            Write-Host "▶️ Ejecutando instalador de $nombre..."
            Start-Process -FilePath $ruta -Wait
            Write-Host "✅ Instalación de $nombre completada/manual."
        } else {
            Write-Warning "❌ No se descargó el instalador de $nombre."
        }
    } catch {
        Write-Warning "❌ Error al descargar o ejecutar instalador de $nombre."
    }
}

# Lista de programas (con fallback oficial si aplica)
$programas = @(
    @{ nombre = "WhatsApp"; id = "WhatsApp.WhatsApp"; fallbackUrl = "https://get.microsoft.com/installer/download/9NKSQGP7F2NH?cid=website_cta_psi"; archivo = "WhatsApp Installer.exe" },
    @{ nombre = "Google Chrome"; id = "Google.Chrome" },
    @{ nombre = "AnyDesk"; id = "AnyDeskSoftwareGmbH.AnyDesk"; fallbackUrl = "https://download.anydesk.com/AnyDesk.exe"; archivo = "AnyDesk.exe" },
    @{ nombre = "Thunderbird"; id = "Mozilla.Thunderbird" },
    @{ nombre = "Google Drive"; id = "Google.Drive"; fallbackUrl = "https://dl.google.com/drive-file-stream/GoogleDriveSetup.exe"; archivo = "GoogleDriveSetup.exe" },
    @{ nombre = "Lively Wallpaper"; id = "rocksdanister.LivelyWallpaper" },
    @{ nombre = "WinRAR"; id = "RARLab.WinRAR" },
    @{ nombre = "Adobe Acrobat Reader"; id = "Adobe.Acrobat.Reader.64-bit" },
    @{ nombre = "Microsoft Teams"; id = "Microsoft.Teams" },
    @{ nombre = "VLC Media Player"; id = "VideoLAN.VLC" }
)

$total = $programas.Count
$index = 0

foreach ($programa in $programas) {
    $index++
    $porcentaje = [math]::Round(($index / $total) * 100)
    Write-Host "`n🔄 [$porcentaje%] ($index de $total) → $($programa.nombre)"
    Write-Host "🔎 Verificando si $($programa.nombre) está instalado..."

    if (!(Esta-Instalado $programa.id)) {
        Write-Host "📥 No instalado. Intentando instalación con Winget..."
        winget install --id $($programa.id) --silent --accept-source-agreements --accept-package-agreements

        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ $($programa.nombre) instalado correctamente."
        } elseif ($programa.fallbackUrl) {
            Write-Warning "⚠️ Winget no pudo instalar $($programa.nombre). Usando instalador alternativo del proveedor oficial..."
            InstalarDesdeWeb -nombre $programa.nombre -url $programa.fallbackUrl -archivo $programa.archivo
        } else {
            Write-Warning "❌ Error al instalar $($programa.nombre). Código: $LASTEXITCODE"
        }
    } else {
        Write-Host "🟢 $($programa.nombre) ya está instalado."
        if (Tiene-Actualizacion $programa.id) {
            Write-Host "⬆️ Actualización disponible para $($programa.nombre). Aplicando..."
            winget upgrade --id $($programa.id) --silent --accept-source-agreements --accept-package-agreements

            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ $($programa.nombre) actualizado correctamente."
            } else {
                Write-Warning "❌ Error al actualizar $($programa.nombre). Código: $LASTEXITCODE"
            }
        } else {
            Write-Host "📌 $($programa.nombre) está actualizado."
        }
    }
}

Stop-Transcript
Read-Host "`n✅ Instalación y verificación completadas. Presiona ENTER para salir"
