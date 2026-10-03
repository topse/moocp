// Was die Update-Prüfung anfragen darf (update.dart).
//
// Nach demselben Muster wie die Positivliste für Moodle (moodle_zugang.dart)
// und die Liste für Bildschirmfotos (browserliste.dart): nicht „alles außer
// Verbotenem", sondern genau die zwei Adressen, die die Prüfung braucht --
// und jede davon einzeln geprüft, auch jedes Umleitungsziel. GitHub schickt
// den Download auf einen Speicherdienst weiter, mit einer unterschriebenen
// Adresse; ohne Prüfung des Ziels wäre die Liste wertlos.
//
// Mehr als diese Liste gibt es nicht: keine Einstellung für eine andere
// Herkunft, kein Herunterladen beliebiger Adressen. Was hier nicht steht,
// fragt die App nicht an. Und was hier steht, bekommt nichts von Moodle zu
// sehen -- die Prüfung hat ihre eigene Verbindung, ohne das Sitzungscookie
// (update.dart).

/// Benutzer und Repository auf GitHub, aus denen die Fassungen kommen.
const String herkunft = 'topse/moocp';

/// Die einzige Abfrage: das neueste Release. GitHub lässt Entwürfe und
/// Vorabfassungen dabei von selbst aus, die Prüfung muss nicht filtern.
final Uri releaseAbfrage = Uri.parse('https://api.github.com/repos/$herkunft/releases/latest');

/// Prüft eine Adresse der Update-Prüfung -- vor jeder Anfrage und für jedes
/// Umleitungsziel. Rückgabe: null, wenn sie erlaubt ist, sonst der Grund
/// für Protokoll und Meldung.
///
/// [download] trennt die beiden Fälle: die Abfrage der Fassung (genau eine
/// Adresse) und das Holen der Datei (das Release dieses Repositorys und die
/// Speicherdienste, auf die GitHub dabei umleitet).
String? updateGesperrt(Uri uri, {required bool download}) {
  if (uri.scheme != 'https') return 'kein https';
  if (uri.userInfo.isNotEmpty) return 'Adresse mit Anmeldedaten';
  if (!download) {
    return uri == releaseAbfrage ? null : 'nicht die Abfrage des neuesten Releases';
  }
  if (uri.host == 'github.com') {
    return uri.path.startsWith('/$herkunft/releases/download/')
        ? null
        : 'kein Download eines Releases von $herkunft';
  }
  // Die Speicherdienste, auf die GitHub weiterleitet (objects…,
  // release-assets…). Der Punkt vor dem Namen gehört dazu: Sonst passte
  // auch „githubusercontent.com.beispiel.test".
  if (uri.host.endsWith('.githubusercontent.com')) return null;
  return 'fremder Rechner (${uri.host})';
}
