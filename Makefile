# No package.json, no node_modules: Bun runs the sources directly and the browser
# loads htmx, Alpine and the UnoCSS runtime from CDNs (see src/views/layout.js).
.PHONY: setup dev start lint check

setup:      ## create the local config from the example (first run only)
	@test -f config/config.js || cp config/config.example.js config/config.js

dev: setup  ## http://localhost:3010, restarts on source changes
	bun --watch src/server/index.js

start: setup
	NODE_ENV=production bun src/server/index.js

lint:       ## biome lint + format check
	bunx --bun @biomejs/biome@2.5.11 check .

check:      ## biome format + lint, autofix
	bunx --bun @biomejs/biome@2.5.11 check --write .
