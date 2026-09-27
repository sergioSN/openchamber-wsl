# ============================================================
# _openchamber — punto de entrada único para lanzar OpenChamber
# ------------------------------------------------------
# Aquí no hace falta `cd` a ningún proyecto: se indica con PROJECT=.
#
#   make desktop PROJECT=~/projects/sergio/huracan-vila
#   make web     PROJECT=~/projects/sergio/mipenya
#   make stop
#
# También funciona desde el Makefile de cada proyecto, que es lo que
# hace `make openchamber-desktop` sin salir de él.
# ============================================================

.PHONY: help desktop web stop status

# Proyecto al que apunta OpenChamber. Es obligatorio en desktop/web:
# aquí no tiene sentido "el directorio actual", que sería este repo.
PROJECT ?=

OPENCHAMBER_PORT ?= 3001

# Los targets se ejecutan con /bin/sh NO interactivo, donde ~/.bashrc no se
# carga, así que el PATH no incluye ni ~/.local/bin (openchamber) ni el
# directorio de opencode. Se pasan explícitamente para que los targets
# funcionen también desde scripts, CI o `wsl -e make`.
OPENCHAMBER_BIN ?= $(HOME)/.local/bin
OPENCODE_BIN ?= $(HOME)/.opencode/bin/opencode

# Guarda común de desktop/web. $@ es el target que la invoca.
CHECK_PROJECT = @test -n "$(PROJECT)" || { \
	echo "❌ Falta PROJECT. Uso: make $@ PROJECT=/ruta/al/proyecto"; \
	exit 1; \
}; \
test -d "$(PROJECT)" || { \
	echo "❌ El proyecto no existe: $(PROJECT)"; \
	exit 1; \
}

help: ## Muestra esta ayuda
	@echo "⚡ _openchamber — lanza OpenChamber contra un proyecto de WSL"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[33m%-12s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "   PROJECT es obligatorio en desktop y web."
	@echo "   Ej:  make desktop PROJECT=~/projects/mi-proyecto"

desktop: ## Abre OpenChamber Desktop (ventana nativa) sobre PROJECT
	$(CHECK_PROJECT)
	@echo "⚡ OpenChamber Desktop sobre $(PROJECT)"
	@OPENCHAMBER_PROJECT_DIR="$(PROJECT)" \
		bash "$(CURDIR)/scripts/openchamber-desktop-wsl.sh"

web: ## Sirve la UI web de OpenChamber sobre PROJECT
	$(CHECK_PROJECT)
	@echo "⚡ OpenChamber web sobre $(PROJECT)"
	@echo "   Abre http://localhost:$(OPENCHAMBER_PORT) en el navegador"
	@echo ""
	@PATH="$(OPENCHAMBER_BIN):$$PATH" OPENCODE_BINARY="$(OPENCODE_BIN)" \
		OPENCHAMBER_OPENCODE_CWD="$(PROJECT)" \
		openchamber serve --host 127.0.0.1 --port $(OPENCHAMBER_PORT)

stop: ## Detiene el server de OpenChamber
	@PATH="$(OPENCHAMBER_BIN):$$PATH" openchamber stop --port $(OPENCHAMBER_PORT) || true

status: ## Muestra las instancias de OpenChamber en ejecución
	@PATH="$(OPENCHAMBER_BIN):$$PATH" openchamber status || true
