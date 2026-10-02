// Der Dialog „Über moocp": Version, eigene Lizenz, deutsche Knöpfe,
// und die Lizenzseite führt die App mit ihrer Lizenz.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moocp/ueber.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  testWidgets('Version, Lizenz und Lizenzseite', (tester) async {
    PackageInfo.setMockInitialValues(
        appName: 'moocp', packageName: 'moocp', version: '1.2.3', buildNumber: '4', buildSignature: '');
    lizenzAnmelden();
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('de'),
      supportedLocales: const [Locale('de')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Builder(
        builder: (context) => TextButton(onPressed: () => ueberZeigen(context), child: const Text('Info')),
      ),
    ));
    await tester.tap(find.text('Info'));
    await tester.pumpAndSettle();
    expect(find.text('Version 1.2.3+4'), findsOneWidget);
    expect(find.textContaining('MIT-Lizenz'), findsOneWidget);

    await tester.tap(find.text('Lizenzen ansehen'));
    await tester.pumpAndSettle();
    expect(find.text('moocp'), findsWidgets);
    await tester.tap(find.text('moocp').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Permission is hereby granted'), findsOneWidget);
  });

  test('Version ohne Buildnummer', () {
    final info = PackageInfo(appName: '', packageName: '', version: '1.0.0', buildNumber: '');
    expect(versionText(info), '1.0.0');
  });
}
