# _openchamber

Scripts compartidos para lanzar **OpenChamber Desktop** contra el server de
OpenChamber que corre dentro de WSL.

Este repo existe porque esos scripts estaban copiados byte a byte en
varios proyectos. Varias copias del mismo bug: cuando opencode se movió a
`~/.opencode/bin` (config v2), todos los `.bat` siguieron buscando `opencode`
en el PATH de una shell no interactiva, donde no está.

## Contenido

- `scripts/openchamber-desktop-wsl.sh` — genera, instala y lanza el launcher.
- `scripts/openchamber-desktop-wsl.bat` — plantilla del launcher (CRLF).

## Uso

Desde el Makefile de cualquier proyecto:

```make
OPENCHAMBER_COMMON ?= $(HOME)/projects/_openchamber

openchamber-desktop:
	@bash $(OPENCHAMBER_COMMON)/scripts/openchamber-desktop-wsl.sh
```

Se invoca **desde el directorio del proyecto**: el script usa `$(pwd)` como
`PROJECT_DIR` y lo graba en el `.bat` generado.

## Requisitos

- WSL con `npm i -g @openchamber/web` (aporta `openchamber`).
- El binario `opencode` accesible. El launcher lo pasa explícitamente con
  `OPENCODE_BINARY=$HOME/.opencode/bin/opencode`, porque `~/.bashrc` no se
  carga en shells no interactivas y por eso el PATH no lo incluye.
- OpenChamber Desktop instalado en Windows.

## Instalar

El launcher se escribe en `%USERPROFILE%\.local\bin\openchamber-desktop-wsl.bat`.
Ojo: **es un único fichero compartido**. Lanzar el launcher de un proyecto
sobrescribe el del anterior, así que el `PROJECT_DIR` grabado siempre es el del
último `make openchamber-desktop` ejecutado.
