# E6 Nur lokal

Status: gilt. Die Regeln dazu stehen im Index der [CLAUDE.md](../../CLAUDE.md).

## Entscheidung

MCP über Streamable HTTP auf `127.0.0.1`, Zugangsschlüssel als Bearer-Token, Host- und Origin-Prüfung. Dass der Schlüssel im Klartext in den Einstellungen und in der Konfiguration von Claude Code und Codex steht (E21), ist für ein lokales Werkzeug in Kauf genommen. Jedes Instanzprofil hat einen eigenen Schlüssel ([E31](0031-mcp-server-je-instanz.md)). Der Server wird nie von außen erreichbar gemacht (siehe in [E21](0021-drei-ki-werkzeuge.md) verworfen: die ChatGPT-App über einen Tunnel).
