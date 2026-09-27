#!/usr/bin/env bash
# ============================================================
# upgrade.sh — mantiene al día opencode y openchamber
# ------------------------------------------------------------
# Pensado para ejecutarse ANTES de lanzar OpenChamber, así que
# nunca debe impedir el arranque: cualquier fallo (sin red, registro
# caído, permiso denegado) se avisa y se sigue. Por eso NO usa
# `set -e` y siempre termina con exit 0.
#
# Decisiones que parecen arbitrarias y no lo son:
#
# * opencode: NO se usa "latest release" de GitHub. Ese endpoint marca
#   v1.18.32 como latest mientras el tree de tags ya va por v2.0.18,
#   porque las v2 se publican como prerelease. Consultar "latest" y
#   actualizar a ciegas BAJARÍA el binario. Por eso se lee el tag más
#   alto de la lista de tags y nunca se hace downgrade.
#
# * openchamber: se instala con `npm --prefix ~/.local`, no con
#   `npm i -g`. El `npm prefix -g` de este WSL es /usr/local, pero
#   openchamber vive en ~/.local/lib/node_modules; un `npm i -g` a
#   secas deja dos copias y el symlink ~/.local/bin/openchamber
#   apuntando a la vieja.
#
# * No se salta de versión mayor automáticamente. Un cambio de major
#   puede alterar flags o el contrato con la Desktop, y eso falla en
#   silencio. Se avisa y se deja la decisión en manos de quien lanza.
#
# Uso:
#   upgrade.sh              # respeta el enfriamiento (24 h por defecto)
#   upgrade.sh --force      # comprueba y actualiza ignorando el enfriamiento
#   upgrade.sh --allow-major # permite saltar de major
#   upgrade.sh --check      # solo informa, no instala nada
# ============================================================
set -uo pipefail

OPENCHAMBER_PKG="@openchamber/web"
OPENCODE_REPO="sst/opencode"
STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/openchamber/upgrade-check"
COOLDOWN_HOURS="${UPGRADE_COOLDOWN_HOURS:-24}"
FORCE=0
ALLOW_MAJOR="${ALLOW_MAJOR:-0}"
CHECK_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --force)       FORCE=1 ;;
    --allow-major) ALLOW_MAJOR=1 ;;
    --check)       CHECK_ONLY=1 ;;
    -h|--help)     sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "upgrade.sh: opción desconocida: $arg" >&2; exit 0 ;;
  esac
done

OPENCHAMBER_BIN="${OPENCHAMBER_BIN:-$HOME/.local/bin/openchamber}"
OPENCODE_BIN="${OPENCODE_BIN:-$HOME/.opencode/bin/opencode}"
NPM_PREFIX="${NPM_PREFIX:-$HOME/.local}"

say()  { printf '   %s\n' "$*"; }
warn() { printf '   ⚠ %s\n' "$*" >&2; }

major_of() { printf '%s' "${1#v}" | cut -d. -f1; }

# --- enfriamiento ------------------------------------------------------------
# Preguntar al registry en cada arranque hace el launch lento y dependent
# de red. Se comprueba como maximo una vez cada COOLDOWN_HOURS.
cooldown_active() {
  [ "$FORCE" -eq 1 ] && return 1
  [ -f "$STATE_FILE" ] || return 1
  local last now
  last="$(cat "$STATE_FILE" 2>/dev/null || echo 0)"
  now="$(date +%s)"
  [ $(( now - last )) -lt $(( COOLDOWN_HOURS * 3600 )) ]
}

touch_state() {
  mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null && date +%s > "$STATE_FILE" 2>/dev/null
  return 0
}

# --- consultas de version ----------------------------------------------------
latest_opencode() {
  # Tag mas alto de la lista completa (incluye prereleases). Sin esto se
  # veria v1.18.32 y se "actualizaria" hacia atras.
  curl -fsSL --max-time 20 \
    "https://api.github.com/repos/${OPENCODE_REPO}/tags?per_page=100" 2>/dev/null \
    | grep -oE '"name": *"v?[0-9]+\.[0-9]+\.[0-9]+[^"]*"' \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+[^"]*' \
    | sort -V \
    | tail -n1
}

latest_openchamber() {
  npm view "$OPENCHAMBER_PKG" version 2>/dev/null | tr -d '[:space:]'
}

local_opencode() {
  [ -x "$OPENCODE_BIN" ] || return 1
  # `opencode --version` imprime "opencode v2.0.18". No se puede usar
  # tr -d '[:space:]' aqui: se llevaria por delante el espacio y el
  # resultado seria "opencodev2.0.18".
  "$OPENCODE_BIN" --version 2>/dev/null \
    | grep -oE 'v?[0-9]+\.[0-9]+\.[0-9]+[^[:space:]]*' \
    | head -n1 | sed 's/^v//'
}

local_openchamber() {
  [ -x "$OPENCHAMBER_BIN" ] || return 1
  "$OPENCHAMBER_BIN" --version 2>/dev/null | tr -d '[:space:]'
}

# --- logica ------------------------------------------------------------------
upgrade_opencode() {
  local cur lat
  cur="$(local_opencode)" || { say "opencode: no encontrado en $OPENCODE_BIN"; return 0; }
  lat="$(latest_opencode)"

  if [ -z "$lat" ]; then
    warn "opencode: no se pudo consultar la ultima version (sin red?). Se deja como esta."
    return 0
  fi

  if [ "$cur" = "$lat" ]; then
    say "opencode $cur (al dia)"
    return 0
  fi

  # Nunca hacia atras: "latest release" de GitHub va por v1.18.32.
  if [ "$(printf '%s\n%s\n' "$lat" "$cur" | sort -V | head -n1)" = "$lat" ] \
     && [ "$lat" != "$cur" ]; then
    say "opencode $cur (al dia; el tag mas alto sigue siendo v$lat)"
    return 0
  fi

  if [ "$(major_of "$cur")" != "$(major_of "$lat")" ] && [ "$ALLOW_MAJOR" -eq 0 ]; then
    warn "opencode: hay major disponible (v$cur -> v$lat)."
    warn "  No se salta de major automaticamente. Usa: upgrade.sh --allow-major"
    return 0
  fi

  say "opencode $cur -> v$lat"
  [ "$CHECK_ONLY" -eq 1 ] && return 0
  # Se pasa el target explicito: un `opencode upgrade` a secas seguiria el
  # canal "latest" y podria devolver el binario a 1.x.
  "$OPENCODE_BIN" upgrade "v$lat" >/dev/null 2>&1 \
    && say "opencode actualizado a v$lat" \
    || warn "opencode: la actualizacion fallo; se mantiene v$cur"
  return 0
}

upgrade_openchamber() {
  local cur lat
  cur="$(local_openchamber)" || { say "openchamber: no encontrado en $OPENCHAMBER_BIN"; return 0; }
  lat="$(latest_openchamber)"

  if [ -z "$lat" ]; then
    warn "openchamber: no se pudo consultar la ultima version (sin red?). Se deja como esta."
    return 0
  fi

  if [ "$cur" = "$lat" ]; then
    say "openchamber $cur (al dia)"
    return 0
  fi

  if [ "$(major_of "$cur")" != "$(major_of "$lat")" ] && [ "$ALLOW_MAJOR" -eq 0 ]; then
    warn "openchamber: hay major disponible ($cur -> $lat)."
    warn "  No se salta de major automaticamente. Sube a mano si lo aceptas:"
    warn "  npm --prefix $NPM_PREFIX i -g $OPENCHAMBER_PKG@$lat"
    return 0
  fi

  say "openchamber $cur -> $lat"
  [ "$CHECK_ONLY" -eq 1 ] && return 0
  npm --prefix "$NPM_PREFIX" i -g "$OPENCHAMBER_PKG@$lat" >/dev/null 2>&1 \
    && say "openchamber actualizado a $lat" \
    || warn "openchamber: la actualizacion fallo; se mantiene $cur"
  return 0
}

main() {
  if cooldown_active; then
    return 0   # en silencio: no molestar en cada arranque
  fi
  touch_state

  if [ "$CHECK_ONLY" -eq 0 ]; then
    printf '   \033[2m· buscando actualizaciones...\033[0m\n'
  fi
  upgrade_opencode
  upgrade_openchamber
  return 0
}

main
exit 0
