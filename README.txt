# Instalador y Actualizador Automático de Software para Windows

Este proyecto automatiza la instalación y actualización de software esencial, además de herramientas del fabricante y controladores, en equipos con Windows 10 o superior.

---

## 🧰 Funcionalidad General

El sistema está compuesto por dos archivos principales:

- `InstaladorDefinitivo.bat`: ejecuta las tareas previas, eleva privilegios, fuerza la aceptación de términos de Winget y lanza el instalador.
- `InstaladorDefinitivo.ps1`: contiene toda la lógica de verificación, descarga e instalación automatizada.

---

## 🔐 Características Detalladas

- **Ejecución con privilegios elevados**: el `.bat` solicita permisos de administrador automáticamente si no los tiene.
- **Verificación de conectividad a Internet**: antes de continuar con cualquier descarga o actualización.
- **Detección y/o instalación de Winget** si no está disponible en el sistema.
- **Forzado de aceptación de términos de Winget**: una ventana se abre y solicita al usuario aceptar los términos (solo la primera vez).
- **Registro de toda la ejecución** en un archivo de log ubicado en el escritorio del usuario.
- **Detección del fabricante del equipo** para abrir el soporte oficial (Dell, HP, Lenovo, ASUS, etc.).
- **Alternativa SDI Lite para controladores** si no hay soporte oficial o si el equipo es virtual.
- **Descarga de instaladores manuales** si Winget falla, accediendo a URLs oficiales con validación de integridad.
- **Instalación y actualización inteligente de software**: se detecta si el programa está instalado, si requiere actualización, y actúa en consecuencia.

---

## 📦 Lista de Aplicaciones Instaladas o Actualizadas

- Google Chrome
- WhatsApp Desktop
- AnyDesk
- Mozilla Thunderbird
- Google Drive
- Lively Wallpaper
- WinRAR
- Adobe Acrobat Reader
- Microsoft Teams
- VLC Media Player

> Si una aplicación no puede instalarse con Winget, el script intenta descargarla directamente desde su sitio oficial.

---

## 🛠 Requisitos del Sistema

- **Sistema Operativo**: Windows 10 o superior
- **PowerShell**: 5.1 o posterior
- **Permisos de administrador**
- **Conexión a Internet activa**

---

## 🚀 Instrucciones de Uso

1. Haz doble clic en `InstaladorDefinitivo.bat`.
2. Si es la primera vez que usas `winget`, se abrirá una ventana para aceptar los términos de uso. Presiona `Y` y luego `ENTER`.
3. Una vez cerrada esa ventana, el instalador continuará automáticamente con el mantenimiento.

---

## 🗂 Registro de Actividades (Logs)

Se crea automáticamente un archivo de log que almacena cada acción realizada por el script:

```
%USERPROFILE%\Desktop\actualizacion_instalacion_log.txt
```

Este archivo contiene errores, resultados y cualquier evento útil para depuración.

---

## ℹ️ Consideraciones Especiales

- Si se detecta que el equipo está virtualizado (VirtualBox, VMware, QEMU, etc.), se omite el paso de soporte del fabricante.
- Si el fabricante es conocido, se abre automáticamente la página de soporte recomendada.
- Si no se encuentra soporte, se descarga y ejecuta SDI Lite para detectar e instalar controladores actualizados.

---

## 📌 Archivos Incluidos

- `InstaladorDefinitivo.bat`: archivo de entrada que eleva privilegios, verifica Winget y lanza el script principal.
- `InstaladorDefinitivo.ps1`: script con toda la lógica de instalación, actualizaciones y soporte.

---

## 🧾 Licencia

Este script puede ser adaptado libremente para uso interno en organizaciones o soporte técnico. Se distribuye sin garantías.

