// Was die Update-Prüfung anfragen darf (update.dart).
//
// Nach demselben Muster wie die Positivliste für Moodle (moodle_zugang.dart)
// und die Liste für Bildschirmfotos (browserliste.dart): nicht „alles außer
// Verbotenem", sondern genau die Abfrage des neuesten Releases und der
// Download daraus -- und jede Adresse einzeln geprüft, auch jedes
// Umleitungsziel. GitHub schickt den Download auf einen Speicherdienst weiter,
// mit einer unterschriebenen Adresse; ohne Prüfung des Ziels wäre die Liste
// wertlos.
//
// Mehr als diese Liste gibt es nicht: keine Einstellung für eine andere
// Herkunft, kein Herunterladen beliebiger Adressen. Was hier nicht steht,
// fragt die App nicht an. Und was hier steht, bekommt nichts von Moodle zu
// sehen -- die Prüfung hat ihre eigene Verbindung, ohne das Sitzungscookie
// (update.dart).

/// Die Repositorys auf GitHub, aus denen die Versionen kommen, in der
/// Reihenfolge der Abfrage. Eine spätere Herkunft wird nur gefragt, wenn es
/// unter den früheren kein Release gibt (E19). Die höchste Version über alle
/// zu nehmen, wäre gefährlich: Der Installer ist nicht signiert, und wer eine
/// einzige dieser Adressen übernähme, könnte mit einer hohen Versionsnummer
/// ein Update unterschieben.
const List<String> herkuenfte = ['Moodle-in-Niedersachsene-V/moocp', 'topse/moocp'];

/// Die Abfrage des neuesten Releases einer Herkunft. GitHub lässt Entwürfe und
/// Vorabversionen dabei von selbst aus, die Prüfung muss nicht filtern.
Uri releaseAbfrage(String herkunft) =>
    Uri.parse('https://api.github.com/repos/$herkunft/releases/latest');

/// Prüft eine Adresse der Update-Prüfung -- vor jeder Anfrage und für jedes
/// Umleitungsziel. Rückgabe: null, wenn sie erlaubt ist, sonst der Grund
/// für Protokoll und Meldung.
///
/// [download] trennt die beiden Fälle: die Abfrage der Version (je Herkunft
/// genau eine Adresse) und das Holen der Datei (das Release einer Herkunft und
/// die Speicherdienste, auf die GitHub dabei umleitet).
String? updateGesperrt(Uri uri, {required bool download}) {
  if (uri.scheme != 'https') return 'kein https';
  if (uri.userInfo.isNotEmpty) return 'Adresse mit Anmeldedaten';
  if (!download) {
    return herkuenfte.any((h) => uri == releaseAbfrage(h))
        ? null
        : 'nicht die Abfrage des neuesten Releases';
  }
  if (uri.host == 'github.com') {
    return herkuenfte.any((h) => uri.path.startsWith('/$h/releases/download/'))
        ? null
        : 'kein Download eines Releases von moocp';
  }
  // Die Speicherdienste, auf die GitHub weiterleitet (objects…,
  // release-assets…). Der Punkt vor dem Namen gehört dazu: Sonst passte
  // auch „githubusercontent.com.beispiel.test".
  if (uri.host.endsWith('.githubusercontent.com')) return null;
  return 'fremder Rechner (${uri.host})';
}
