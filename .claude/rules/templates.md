---
globs: ["**/*.tmpl"]
---
- All .tmpl files use Go template syntax
- Test template changes with ./render.sh before considering them done
- Never run chezmoi apply on the host — only test via render.sh or Docker
- Preserve whitespace carefully: {{- trims left, -}} trims right
