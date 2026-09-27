@echo off
setlocal enabledelayedexpansion
rem ============================================================
rem  OpenChamber Desktop + opencode WSL (modo external server)
rem  ----------------------------------------------------------
rem  Lanza `openchamber serve` DENTRO de WSL y abre la app de
rem  Desktop conectada a ese server. Asi el proxy corre en Linux
rem  (realpath de Linux) y el historial de sesiones se ve dentro
rem  de la propia ventana de Desktop, con toda la config de WSL
rem  (skills, MCPs, tokens).
rem
rem  La Desktop carga su UI empaquetada (openchamber-ui://app) con
rem  el server de WSL como API: es el unico origen que el bridge de
rem  escritorio (isLocalSender) considera local. NO usar
rem  OPENCHAMBER_ELECTRON_LOAD_SERVER_UI=1: al cargar la UI remota
rem  (http://localhost:3001) la Desktop rechaza comandos IPC como
rem  desktop_ssh_*, desktop_get_installed_apps y check_for_updates
rem  (se ven "[ipc] rejected ... from non-local origin").
rem
rem  Verificado con openchamber 2.0.2 (Desktop 2.0.2 + server 2.0.2).
rem  El requisito no es una version concreta: es usar la UI empaquetada
rem  y no la remota. Si un upgrade rompe el bridge, el sintoma sera el
rem  "[ipc] rejected ... from non-local origin" de arriba.
rem
rem  Si la Desktop ya esta abierta, la CIERRA primero (restart) para
rem  que no se quede con su server de Windows (sin historial).
rem
rem  Requisitos (una sola vez, en WSL):
rem    npm i -g opencode-ai @openchamber/web
rem ============================================================

set DISTRO=Ubuntu
rem PROJECT_DIR y OPENCHAMBER_PORT los sobrescribe el generador al instalar.
set PROJECT_DIR=/path/to/project
set OPENCHAMBER_PORT=3001
set OC_EXE=%LOCALAPPDATA%\Programs\@openchamberelectron\OpenChamber.exe

if not exist "%OC_EXE%" (
  echo [ERROR] No se encontro OpenChamber.exe en: %OC_EXE%
  goto :end
)

rem ----------------------------------------------------------
rem [0/4] Cerrar la Desktop si ya esta abierta (restart limpio)
rem ----------------------------------------------------------
tasklist /FI "IMAGENAME eq OpenChamber.exe" 2>nul | findstr /i "OpenChamber.exe" >nul
if not errorlevel 1 goto :killit
echo [0/4] Desktop no estaba abierta.
goto :launch

:killit
echo [0/4] Cerrando OpenChamber Desktop abierto (restart)...
taskkill /IM "OpenChamber.exe" /F >nul 2>&1
set /a killtries=0
:killwait
timeout /t 1 /nobreak >nul
tasklist /FI "IMAGENAME eq OpenChamber.exe" 2>nul | findstr /i "OpenChamber.exe" >nul
if errorlevel 1 goto :killed
set /a killtries+=1
if !killtries! lss 10 goto :killwait
:killed
echo       Desktop cerrada.

:launch
rem ----------------------------------------------------------
rem [1/4] Lanzar el server de OpenChamber en WSL (background)
rem ----------------------------------------------------------
echo [1/4] Lanzando OpenChamber server en WSL (puerto %OPENCHAMBER_PORT%)...
start "OpenChamber-WSL-Server" /b wsl.exe -d %DISTRO% -e bash -lc "OPENCODE_BINARY=$HOME/.opencode/bin/opencode OPENCHAMBER_OPENCODE_CWD=%PROJECT_DIR% openchamber serve --host 127.0.0.1 --port %OPENCHAMBER_PORT% > /tmp/openchamber-serve.log 2>&1"

rem ----------------------------------------------------------
rem [2/4] Esperar a que el server responda (probe /health)
rem ----------------------------------------------------------
echo [2/4] Esperando al server...
set /a tries=0
:waitloop
timeout /t 1 /nobreak >nul
curl -s -o nul -w "%%{http_code}" http://127.0.0.1:%OPENCHAMBER_PORT%/health 2>nul | findstr /b 200 >nul
if not errorlevel 1 goto :ready
set /a tries+=1
if !tries! lss 30 goto :waitloop
echo [ERROR] El server de WSL no respondio tras 30s.
echo Revisa el log:  wsl.exe -d %DISTRO% -e tail -n 30 /tmp/openchamber-serve.log
goto :cleanup

:ready
echo       Server listo.
rem ----------------------------------------------------------
rem [3/4] Arrancar la Desktop en modo external server (WSL)
rem ----------------------------------------------------------
echo [3/4] Arrancando OpenChamber Desktop (modo WSL)...
rem UI empaquetada (openchamber-ui://app) + server WSL como API.
rem No usar OPENCHAMBER_ELECTRON_LOAD_SERVER_UI=1 (ver cabecera).
set OPENCHAMBER_SKIP_LOCAL_SERVER=1
set OPENCHAMBER_SERVER_URL=http://localhost:%OPENCHAMBER_PORT%
start /wait "" "%OC_EXE%"

rem ----------------------------------------------------------
rem [4/4] Al cerrar la Desktop, detener el server de WSL
rem ----------------------------------------------------------
:cleanup
echo [4/4] Deteniendo el server de WSL...
wsl.exe -d %DISTRO% -e bash -lc "openchamber stop --port %OPENCHAMBER_PORT%" >nul 2>&1

:end
endlocal
