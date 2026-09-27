# _openchamber

Lanzar **OpenChamber** (Desktop nativa o UI web) contra el `opencode` que
corre dentro de WSL, apuntando a un proyecto concreto.

Existe porque esos scripts estaban copiados byte a byte en varios
proyectos, y cuando opencode se movió a `~/.opencode/bin` (config v2) **los
tres fellaron a la vez** con el mismo error. Aquí hay una sola copia.

## Requisitos

- WSL con `@openchamber/web` y `opencode` instalados:
  ```bash
  npm --prefix ~/.local i -g @openchamber/web
  ```
  `opencode` no viene del registry: es el binario nativo de `~/.opencode/bin`
  (config v2), y `upgrade.sh` lo actualiza con `opencode upgrade <tag>`.
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
| `upgrade` | Comprueba y aplica actualizaciones de opencode y openchamber |
| `help` | Ayuda |

## Actualizaciones automáticas

`desktop` y `web` ejecutan `scripts/upgrade.sh` antes de arrancar, así que
opencode y openchamber se mantienen al día sin que tengas que acordarte. Las
reglas, y el porqué de cada una:

- **No salta de versión mayor.** La Desktop y el server de WSL se comunican por
  un contrato (el bridge `isLocalSender`) que un cambio de major puede romper
  sin avisar. Cuando hay un major disponible, avisa e imprime el comando
  exacto, pero no lo aplica solo.
- **Nunca hace un downgrade.** En opencode esto es obligatorio: las v2 se
  publican como *prerelease*, así que el endpoint "latest release" de GitHub
  señala `v1.18.32` mientras el árbol de tags ya va por `v2.0.18`. Confiar en
  ese endpoint **bajaría** el binario. Por eso se lee el tag más alto de la
  lista completa y se compara antes de tocar nada.
- **Solo comprueba una vez cada 24 h.** Preguntar al registry en cada
  arranque haría el launch lento y dependiente de la red.
- **Nunca impide el arranque.** Sin red, sin permiso o con el registro caído,
  avisa y sigue. `upgrade.sh` siempre sale con 0.

```bash
make upgrade                          # a mano, respeta el enfriamiento
make upgrade UPGRADE_FLAGS=--check    # solo informa, no instala
make upgrade UPGRADE_FLAGS=--force    # ignora el enfriamiento
make upgrade UPGRADE_FLAGS=--allow-major
SKIP_UPGRADE=1 make web PROJECT=...   # desactivarlo para un arranque
```

> A openchamber se le habla con `npm --prefix ~/.local`, no con `npm i -g` a
> secas: el `npm prefix -g` de este WSL es `/usr/local`, pero openchamber vive
> en `~/.local/lib/node_modules`. Un `npm i -g` mal dirigido deja **dos
> copias** instaladas y el symlink apuntando a la vieja.

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
| `[ipc] rejected ... from non-local origin` en el log de la Desktop | Se cargó la UI remota en vez de la empaquetada. No uses `OPENCHAMBER_ELECTRON_LOAD_SERVER_UI=1`. |
| La Desktop va más nueva que el server (o al revés) | Se actualizó una mitad y no la otra. Súbelas a la misma versión: `make upgrade UPGRADE_FLAGS=--allow-major`. |
