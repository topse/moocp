# E28 Bildschirmfotos nur über den Browser der App

Status: gilt. Ergänzt [E18](0018-bildschirmfotos.md). Die Regeln dazu stehen im Index der [CLAUDE.md](../../CLAUDE.md).

## Entscheidung

`bildschirmfoto` startet Microsoft Edge oder Google Chrome selbst, ohne Fenster, und steuert ihn über das DevTools-Protokoll. Ein Browser, den das KI-Werkzeug mitbringt, wird dafür nicht benutzt. Das gilt auf allen Plattformen und für alle KI-Werkzeuge gleich. Fehlt der Browser oder ist er nicht steuerbar, gibt es keine Bildschirmfotos; ein Browserfehler ist eine fehlende Voraussetzung, kein Anlass für einen anderen Browserzugang.

Gründe: Jede Anfrage des Browsers geht durch die App, mit Freigabe je Bild und Eintrag im Protokoll ([E18](0018-bildschirmfotos.md), A4). Die Anmeldung bei Moodle bleibt in der Sitzung der App ([E23](0023-kein-moodle-plugin.md)). Ein Browser, den die KI steuert, stünde außerhalb dieser Grenzen und hätte die Sitzung der Lehrkraft in Reichweite; A1 und A2 schließen das für die Werkzeuge der App aus. Die Grenze ist gewollt: Sie hält den KI-Zugriff auf die Seiten, die das Werkzeug zulässt.

Für einen Browser, den ein KI-Werkzeug selbst mitbringt (etwa bei Codex), gilt A2 in der [CLAUDE.md](../../CLAUDE.md): Moodle wird ausschließlich über moocp angesprochen, nie darüber. Die App schaltet solche Werkzeuge nicht ab, denn das griffe in die Konfiguration ein, über die die Lehrkraft entscheidet; die Skills lassen die KI darüber nicht arbeiten und vor dem Datenschutz warnen.

## Verworfen

Den eingebauten Browser der Desktop-App oder den Vorschaubrowser von T3 Code zu nutzen. Beide sind bequem, weil sie ohne eigene Anbindung laufen. Sie umgehen aber Freigabe und Protokoll der App, und die Lehrkraft meldete sich in einem KI-steuerbaren Browser bei Moodle an. Ebenso verworfen: die Anbindung an die Chrome-Erweiterung (siehe [E1](0001-werkzeugschicht-und-skills.md)).
