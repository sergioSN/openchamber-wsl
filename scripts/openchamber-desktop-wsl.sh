#!/usr/bin/env bash
#
# openchamber-desktop-wsl.sh
# ============================================================
# Genera (e instala) el lanzador .bat de OpenChamber Desktop en
# modo "external server" conectado al server de OpenChamber que
# corre dentro de WSL. Tras generarlo, lo ejecuta.
#
# Uso:
#   make openchamber-desktop                 # genera, instala y lanza
#   make openchamber-desktop OPENCHAMBER_DESKTOP_PORT=4000
#   OPENCHAMBER_PROJECT_DIR=/ruta/al/proyecto ./openchamber-desktop-wsl.sh
#
# El proyecto es el directorio desde el que se invoca (pwd). Se puede
# forzar con OPENCHAMBER_PROJECT_DIR, que es lo que hace el Makefile de
# este repo para lanzar un proyecto que no es el directorio actual.
#
# Requiere: `openchamber` (npm i -g @openchamber/web) en WSL y
# OpenChamber Desktop instalado en Windows.
# ============================================================
set -euo pipefail

PORT="${OPENCHAMBER_DESKTOP_PORT:-3001}"
DISTRO="${WSL_DISTRO_NAME:-Ubuntu}"
if [ -z "$DISTRO" ]; then
  DISTRO="$(wsl.exe -l -q 2>/dev/null | tr -d '\0' | grep -iv "Windows" | grep -v '^[[:space:]]*$' | head -n1 | tr -d '[:space:]')"
fi
[ -z "$DISTRO" ] && DISTRO="Ubuntu"
PROJECT_DIR="${OPENCHAMBER_PROJECT_DIR:-$(pwd)}"
if [ ! -d "$PROJECT_DIR" ]; then
  echo "El proyecto no existe: $PROJECT_DIR" >&2
  echo "Indica uno válido con OPENCHAMBER_PROJECT_DIR=... o PROJECT=..." >&2
  exit 1
fi

WIN_PROFILE_RAW="$(cmd.exe /d /s /c "echo %USERPROFILE%" 2>/dev/null | tr -d '\0\r' | grep -E '^[A-Za-z]:\\' | head -n1 || true)"
if [ -z "$WIN_PROFILE_RAW" ]; then
  echo "No se pudo detectar %USERPROFILE% de Windows." >&2
  exit 1
fi
WIN_PROFILE="$(echo "$WIN_PROFILE_RAW" | sed 's/\\$//')"
WIN_DRIVE="$(echo "$WIN_PROFILE" | cut -c1 | tr 'A-Z' 'a-z')"
WIN_HOME="/mnt/${WIN_DRIVE}$(echo "$WIN_PROFILE" | sed 's#^[A-Za-z]:##' | tr '\\' '/')"
BIN_DIR="${WIN_HOME}/.local/bin"
BAT_NIX="${BIN_DIR}/openchamber-desktop-wsl.bat"
BAT_WIN="${WIN_PROFILE}\\.local\\bin\\openchamber-desktop-wsl.bat"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="${SCRIPT_DIR}/openchamber-desktop-wsl.bat"

if [ ! -f "$TEMPLATE" ]; then
  echo "No se encontro la plantilla: $TEMPLATE" >&2
  exit 1
fi

# Mantiene opencode y openchamber al dia antes de arrancar la Desktop.
# Se hace aqui, y no en el Makefile, para que tambien aplique cuando el
# launcher se invoca desde el Makefile de un proyecto. upgrade.sh siempre
# sale con 0: sin red o sin permiso, el arranque continua igual.
# SKIP_UPGRADE=1 lo desactiva.
if [ "${SKIP_UPGRADE:-0}" != "1" ] && [ -f "${SCRIPT_DIR}/upgrade.sh" ]; then
  bash "${SCRIPT_DIR}/upgrade.sh" || true
fi

mkdir -p "$BIN_DIR"
# Normaliza a LF, sustituye y vuelve a CRLF (el sed deja LF en las líneas
# modificadas, así que sin normalizar habría mezcla CRLF/LF).
tr -d '\r' < "$TEMPLATE" \
  | sed -e "s#^set DISTRO=.*#set DISTRO=${DISTRO}#" \
         -e "s#^set PROJECT_DIR=.*#set PROJECT_DIR=${PROJECT_DIR}#" \
         -e "s#^set OPENCHAMBER_PORT=.*#set OPENCHAMBER_PORT=${PORT}#" \
  | sed 's/$/\r/' > "$BAT_NIX"

echo "⚡ Lanzador instalado: ${BAT_WIN}"
echo "   Server de WSL en el puerto ${PORT} (proyecto: ${PROJECT_DIR})"
echo ""
echo "⚡ Abriendo OpenChamber Desktop (modo WSL)..."
echo "   Al cerrar la Desktop, el .bat detiene el server de WSL."
echo ""
# cmd.exe no admite rutas UNC como directorio actual. El proceso bash
# está en WSL (/home/...), que Windows traduce a \\wsl.localhost\... ;
# al invocar cmd.exe hereda ese cwd y falla. Cambiamos a un directorio
# de Windows válido (C:\Users\<usuario>) antes de lanzar.
( cd "$WIN_HOME" && cmd.exe /c start "" "$BAT_WIN" )
