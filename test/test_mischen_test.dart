import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/moodle/moodle_zugang.dart';
import 'package:moocp/moodle/test.dart';
import 'package:moocp/protokoll.dart';

void main() {
  test('Fragen mischen: je Testabschnitt vom Kästchen gelesen, nicht von der Kursnavigation', () {
    const seite = '''<html><body><script>M.cfg = {"courseId":43};</script><script>var x = {"quizid":"77"};</script>
<ul><li class="section" id="section-900">Kursnavigation, kein Testabschnitt</li></ul>
<ul class="slots">
<li id="section-374" class="section main clearfix" data-sectionname="">
<input type="checkbox" id="shuffle-374" value="1" data-action="shuffle_questions" class="cm-edit-action">
<ul><li class="pagenumber" id="page-1">Seite 1</li>
<li class="activity slot qtype_truefalse" id="slot-501"><span class="activityname">ZZ Ja/Nein</span><span class="instancemaxmark">1,00</span></li></ul></li>
<li id="section-375" class="section main clearfix" data-sectionname="Teil B">
<input type="checkbox" id="shuffle-375" value="1" data-action="shuffle_questions" class="cm-edit-action" checked="checked">
</li></ul><p>Summe der Punkte: 1,00</p><input name="maxgrade" value="1,00"></body></html>''';
    final t = testAuswerten(15449, seite);
    expect([for (final a in t.abschnitte) '${a.id}:${a.name}:${a.mischen}'], ['374::false', '375:Teil B:true']);
    expect(t.text(), allOf(contains('Fragen mischen: aus (Testabschnitt 374)'), contains('an (Testabschnitt 375 „Teil B")')));
  });

  test('edit_rest.php: Mischen erlaubt, aber nur mit 0/1 und nur an Testabschnitten', () {
    final z = MoodleZugang(Protokoll());
    bool post(Map<String, String> f) => z.erlaubt('POST', Uri.parse('https://m.example/mod/quiz/edit_rest.php'),
        [for (final e in {...f, 'sesskey': 'abc', 'courseid': '43', 'quizid': '77'}.entries) e]);
    expect(post({'class': 'section', 'field': 'updateshufflequestions', 'id': '374', 'newshuffle': '1'}), isTrue);
    expect(post({'class': 'section', 'field': 'updateshufflequestions', 'id': '374', 'newshuffle': '2'}), isFalse);
    expect(post({'class': 'section', 'field': 'updatesectiontitle', 'id': '374', 'newshuffle': '1'}), isFalse);
    expect(post({'class': 'resource', 'field': 'updatemaxmark', 'id': '501', 'maxmark': '2'}), isTrue);
    expect(post({'class': 'resource', 'field': 'updatemaxmark', 'id': '501', 'newshuffle': '1'}), isFalse);
    expect(post({'class': 'resource', 'action': 'DELETE', 'id': '501'}), isTrue);
  });
}
