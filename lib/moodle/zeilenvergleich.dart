// Zeilenvergleich zweier Texte (längste gemeinsame Teilfolge).
//
// Für die Freigabe genügt das: Seiten-HTML hat einige hundert Zeilen. Wird es
// zu gross für die Tabelle, gibt es statt des Vergleichs eine Zählung.

enum ZeilenArt { gleich, weg, neu, ausgelassen }

class Zeile {
  const Zeile(this.art, this.text);
  final ZeilenArt art;
  final String text;
}

class Vergleichsergebnis {
  Vergleichsergebnis(this.zeilen, this.weg, this.neu);
  final List<Zeile> zeilen;
  final int weg;
  final int neu;
  bool get gleich => weg == 0 && neu == 0;
}

/// Vergleicht [vorher] und [nachher] zeilenweise. Unveränderte Abschnitte
/// werden bis auf [kontext] Zeilen vor und nach einer Änderung ausgelassen.
Vergleichsergebnis zeilenVergleich(String vorher, String nachher, {int kontext = 2}) {
  final a = vorher.split('\n'), b = nachher.split('\n');
  final n = a.length, m = b.length;
  if (n * m > 4000000) {
    return Vergleichsergebnis(
        [Zeile(ZeilenArt.ausgelassen, 'zu gross für den Zeilenvergleich ($n / $m Zeilen)')],
        n, m);
  }
  // Tabelle der längsten gemeinsamen Teilfolge, von hinten.
  final l = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      l[i][j] = a[i] == b[j] ? l[i + 1][j + 1] + 1 : (l[i + 1][j] >= l[i][j + 1] ? l[i + 1][j] : l[i][j + 1]);
    }
  }
  final roh = <Zeile>[];
  var i = 0, j = 0, weg = 0, neu = 0;
  while (i < n && j < m) {
    if (a[i] == b[j]) {
      roh.add(Zeile(ZeilenArt.gleich, a[i]));
      i++;
      j++;
    } else if (l[i + 1][j] >= l[i][j + 1]) {
      roh.add(Zeile(ZeilenArt.weg, a[i++]));
      weg++;
    } else {
      roh.add(Zeile(ZeilenArt.neu, b[j++]));
      neu++;
    }
  }
  while (i < n) {
    roh.add(Zeile(ZeilenArt.weg, a[i++]));
    weg++;
  }
  while (j < m) {
    roh.add(Zeile(ZeilenArt.neu, b[j++]));
    neu++;
  }

  // Unverändertes zusammenfalten.
  final zeigen = List<bool>.filled(roh.length, false);
  for (var k = 0; k < roh.length; k++) {
    if (roh[k].art != ZeilenArt.gleich) {
      for (var d = -kontext; d <= kontext; d++) {
        final x = k + d;
        if (x >= 0 && x < roh.length) zeigen[x] = true;
      }
    }
  }
  final aus = <Zeile>[];
  var ausgelassen = 0;
  for (var k = 0; k < roh.length; k++) {
    if (zeigen[k]) {
      if (ausgelassen > 0) {
        aus.add(Zeile(ZeilenArt.ausgelassen, '… $ausgelassen unveränderte Zeile(n) …'));
        ausgelassen = 0;
      }
      aus.add(roh[k]);
    } else {
      ausgelassen++;
    }
  }
  if (ausgelassen > 0) aus.add(Zeile(ZeilenArt.ausgelassen, '… $ausgelassen unveränderte Zeile(n) …'));
  return Vergleichsergebnis(aus, weg, neu);
}
