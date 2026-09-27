# _openchamber

Lanzar **OpenChamber** (Desktop nativa o UI web) contra el `opencode` que
corre dentro de WSL, apuntando a un proyecto concreto.

Existe porque esos scripts estaban copiados byte a byte en varios
proyectos, y cuando opencode se movió a `~/.opencode/bin` (config v2) **los
tres fellaron a la vez** con el mismo error. Aquí hay una sola copia.

## Requisitos

- WSL con `@openchamber/web` y `opencode` instalados:
  ```bash
  npm i -g @openchamber/web
  ```
- **OpenChamber Desktop** instalado en Windows (para el target `desktop`).
- Acceso por SSH a `github.com` si vas a clonar esto.

## Uso

Desde este repo, indicando el proyecto con `PROJECT=`:

```bash
make desktop PROJECT=~/projects/mi-proyecto   # ventana nativa
make web     PROJECT=~/projects/mi-proyecto   # navegador, http://localhost:3001
make stop                                       # detiene el server
make status                                     # qué instancias hay
make help
```

`PROJECT` es obligatorio en `desktop` y `web`: aquí "el directorio actual"
sería este repo, que no es un proyecto de opencode.

También funciona desde el Makefile de cada proyecto, sin salir de él:

```bash
cd ~/projects/mi-proyecto
make openchamber-desktop
```

## Targets

| Target | Qué hace |
|---|---|
| `desktop` | Genera el launcher, instala el `.bat` en Windows y abre la Desktop |
| `web` | Levanta el server y sirve la UI web |
| `stop` | Detiene el server de OpenChamber |
| `status` | Lista las instancias en ejecución |
| `help` | Ayuda |

## Por qué `OPENCODE_BINARY` (no lo quites)

El `.bat` arranca el server con `wsl.exe -e bash -lc`, es decir una shell
**no interactiva**. En ese modo `~/.bashrc` no se carga, así que el
directorio de opencode no está en el `PATH` y el server muere al instante:

```
Error: Unable to locate the opencode CLI on PATH (...)
```

Por eso la plantilla fija `OPENCODE_BINARY` de forma explícita. Los Makefiles
hacen lo mismo con `PATH` y `OPENCODE_BINARY` porque `make` también ejecuta
las recetas con `/bin/sh` no interactivo; sin eso, `openchamber: not found`
y el `|| true` de `status` lo disfraza de "no running instances".

## El `.bat` instalado

Se escribe en `%USERPROFILE%\.local\bin\openchamber-desktop-wsl.bat` y
**es un único fichero compartido**: el `PROJECT_DIR` que lleva grabado es el
del último `make desktop` ejecutado, no el de todos.

## Si algo falla

El server escribe su log aquí:

```bash
wsl -d Ubuntu -e tail -n 30 /tmp/openchamber-serve.log
```

Para comprobar si responde:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3001/health   # 200 = ok
```

Síntomas habituales:

| Síntoma | Causa |
|---|---|
| `/health` devuelve `000` | El server no arrancó. Mira el log de arriba. |
| `Unable to locate the opencode CLI` | Falta `OPENCODE_BINARY` en el `.bat`. |
| `openchamber: not found` | Target de Make ejecutado sin `PATH` explícito. |
| La Desktop abre sin sesiones | No está conectada al server de WSL: se abrió con su propio server de Windows. |
