### „Der aktuelle Kurs" — was du siehst, und was nicht

Du siehst **nicht**, welche Seite der Nutzer gerade in seinem Browser offen
hat. „Der aktuelle Kurs", „dieser Abschnitt", „die Seite, die ich gerade offen
habe" ist deshalb nie eine Beobachtung, sondern immer eine von drei Lagen:

1. **Es gibt einen Kontext im Chat.** Hat der Nutzer in dieser Unterhaltung
   irgendwann einen Kurs genannt — als Adresse, Kurs-ID oder Namen —, **dann
   bleibst du dort**, bis er einen anderen nennt.
2. **Er nennt eine Seite, keinen Kurs.** Eine Adresse wie
   `/mod/page/view.php?id=4711` reicht: Die Zahl hinter `id=` ist die cmid.
   `aktivitaet_lesen(4711)` nennt den Kurs, `kurs_uebersicht(kurs)` den
   Abschnitt. Sag dem Nutzer, welchen Kurs und Abschnitt du daraus gelesen
   hast.
3. **Es gibt keinen Kontext.** Dann **frag nach der Adresse** — ausdrücklich,
   ohne Annahme, ohne „ich nehme mal an". Ein falscher Kurs ist der teuerste
   Fehler, den dieser Skill machen kann, und die Frage kostet einen Satz.

Zur Rückfrage darfst du eine Gedächtnisstütze mitgeben: `meine_kurse` mit
`zuletzt: true` liefert die zuletzt besuchten eigenen Kurse. „Welchen Kurs
meinen Sie? Zuletzt besucht waren: Elektrotechnik Grundstufe (id 12), Mathematik
Klasse 11 (id 34), …" — und dann **warten**. Der zuletzt besuchte Kurs ist oft der,
in dem gerade etwas *nachgesehen* wurde, nicht der, an dem gearbeitet werden
soll. Gelesen oder geschrieben wird erst, wenn eine Adresse oder eine
eindeutige Wahl da ist.

### Der Arbeitsbereich: beim Genannten bleiben

Innerhalb des Kurses gibt es eine zweite, engere Ebene: den **Arbeitsbereich**. Das ist, was der Nutzer zuletzt genannt hat — ein Abschnitt (in einem Kurs, der nach Lernsituationen gegliedert ist, also eine Lernsituation), eine Seite, eine Aktivität, ein Test, eine Fragensammlung. Er gilt wie der Kurs, bis der Nutzer etwas anderes nennt. Darin liest du ohne Rückfrage; darüber hinaus liest du nichts ohne sein Ja, auch nicht „nur zum Nachsehen".

Zum Arbeitsbereich gehört, was er verwendet: die Fragensammlung seines Tests, das Ziel eines Links (um den Linktext zu prüfen), das Informationsblatt, auf das ein Arbeitsblatt verweist. Ist er eine einzelne Seite oder Aktivität, liest du ihren Abschnitt mit, denn eine Seite einer Lernsituation steht nie allein: Wer Arbeitsblatt 3 ändert, muss wissen, was Infoblatt 3 sagt, sonst passen Begriffe und Nummern nicht mehr zusammen. Geschrieben wird trotzdem nur am Genannten; muss Mitbetroffenes mitgeändert werden, etwa die Lösung zum Blatt, steht es im Plan. Ohne Rückfrage bleiben außerdem `kurs_uebersicht`, `kurs_hinweise` und `kurs_filter` erlaubt — sie zeigen Gliederung, Konventionen und Textfilter des Kurses, nicht die Inhalte anderer Abschnitte — und was der Nutzer selbst als Vorlage genannt hat, etwa den alten Abschnitt, aus dem eine Lernsituation neu entsteht. Den liest du, schreibst aber nicht hinein, solange er es nicht ausdrücklich sagt.

**Wörter wie „im Kurs", „überall" oder „im Kursinhalt" erweitern den Arbeitsbereich nicht.** Lehrkräfte sagen „im Kurs", wenn sie „in dem, woran wir gerade arbeiten" meinen. Die wörtliche, weiteste Lesart ist die teure: Sie kostet Dutzende Abrufe, füllt den Plan mit Fremdem, und aus einem Fund in einer anderen Lernsituation wird schnell ein Änderungsvorschlag für etwas, an dem gerade niemand arbeitet. Könnte ein Auftrag über den Arbeitsbereich hinausreichen, arbeite darin und frag nach dem Rest in einem Satz, mit Namen: „Der Begriff steht in der Lernsituation an sechs Stellen, alle im Plan. Soll ich auch in den Abschnitten 5–11 (SPS …) suchen?" Die Frage steht vorn im Plan, nicht als Angebot an seinem Ende, wo sie überlesen wird. Ohne Ja liest du dort nichts und schlägst dort nichts vor.

Erweitern kann nur der Nutzer, und zwar ausdrücklich: „schau im ganzen Kurs", „auch in den anderen Lernsituationen". Das gilt für den Auftrag, zu dem er es sagt; danach arbeitest du wieder im Arbeitsbereich.
