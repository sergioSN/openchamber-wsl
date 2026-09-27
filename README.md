# openchamber-wsl — movido

Este repo se fusionó con la configuración global de opencode y ya no se
mantiene. Todo lo que había aquí está ahora, junto a los agents, las skills, los
comandos y los lanzadores de `opencode`, en:

**https://github.com/sergioSN/opencode-harness**

```sh
git clone https://github.com/sergioSN/opencode-harness.git
cd opencode-harness
make setup
make openchamber-web PROJECT=~/projects/mi-proyecto
```

Si vienes de aquí y ya tienes proyectos con `OPENCHAMBER_COMMON` apuntando a
`~/projects/_openchamber`, `make setup` deja un symlink y siguen funcionando sin
que toques sus Makefiles.

Los tags de este repo no se han movido: el historial se queda donde estaba, y
el nuevo repo arranca desde un commit único.

Archivado. No abras issues aquí.
