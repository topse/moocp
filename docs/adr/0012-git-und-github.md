# E12 Git; auf GitHub ein Stand je Version

Status: gilt. Die Regeln dazu stehen im Index der [CLAUDE.md](../../CLAUDE.md).

## Entscheidung

Entwickelt wird in einem eigenen Repository. Auf GitHub erscheint je Version ein Commit mit dem Stand des Tags (`publish_tag_to_github.sh`), die Nachricht aus CHANGELOG.md. Pull Requests auf GitHub werden deshalb nicht zusammengeführt, sondern von Hand übernommen. Was auf GitHub selbst an main entsteht, etwa aus einer Cloud-Sitzung, holt `import_from_github.sh` auf den Zweig `github-import` herein, gemergt wird von Hand; die nächste Version setzt dann auf diese Commits auf, und `publish_tag_to_github.sh` bricht ab, solange einer davon im Tag fehlt. main auf GitHub wird nie überschrieben, das Hochladen geht ohne Force.

Lokal führt die KI keine Git-Aktionen aus, das macht ausschließlich der Benutzer; in einer Cloud-Sitzung dagegen wird committet und direkt auf main gepusht, ohne Force und ohne eigenen Zweig, weil `import_from_github.sh` nur main hereinholt. Wer mit anderen Git-Regeln arbeitet (Fork, Feature-Zweige), legt das für sich in einer nicht eingecheckten `CLAUDE.local.md` fest.

Zeilenenden LF, nur Batch-Dateien CRLF (`.gitattributes`).

## Verworfen

Die neue Version wie zuvor auf die letzte Version zu setzen und main zu überschreiben (die Commits verschwänden aus der Geschichte auf GitHub, und eine Cloud-Sitzung, die auf ihnen weiterarbeitet, liefe auseinander).
