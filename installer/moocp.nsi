; Installer für moocp (NSIS 3). create_installer.bat baut erst die App
; und ruft dann dieses Skript auf; von Hand, nach `flutter build windows`:
;
;   makensis installer\moocp.nsi
;
; Für den angemeldeten Benutzer, ohne Administratorrechte: Die Daten der App
; und die Einrichtung der KI-Werkzeuge liegen ohnehin je Benutzer.
;
; Mit dem Schalter /UPDATE startet die App diesen Installer selbst, nachdem
; sie ihn von GitHub geholt hat: Dann wartet er still, bis die App zu ist,
; und lässt Hinweis- und Lizenzseite aus. Sichtbar bleibt er trotzdem -- wer
; ein Update installiert, soll sehen, was läuft.
;
; Die Datei ist UTF-8 mit BOM; ohne BOM liest makensis sie in der
; ANSI-Codepage, und die Umlaute gingen verloren.

Unicode true
SetCompressor /SOLID lzma

!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "FileFunc.nsh"
!include "nsDialogs.nsh"
!include "WinMessages.nsh"

!define NAME "moocp"
!define EXE "moocp.exe"
; Die Brücke für KI-Werkzeuge, die MCP nur über stdio sprechen
; (lib/mcp/bruecke.dart); gebaut von windows/bruecke.cmake.
!define BRUECKE "moocp-bruecke.exe"
!define HERAUSGEBER "Tobias Steinmann"
!define QUELLE "..\build\windows\x64\runner\Release"
; Der Eintrag unter „Installierte Apps". Der Name bleibt über alle Versionen
; gleich, damit eine neue Version die alte ersetzt.
!define UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\moocp"

; Sekunden, die die Hinweisseite auf „Weiter“ warten lässt. Der Hinweis ist
; der Grund, warum der Installer überhaupt eine eigene Seite hat: Er soll
; gelesen werden und nicht weggeklickt.
!define HINWEIS_SEKUNDEN 10

; Die Version steht in pubspec.yaml („1.0.0+1"); Flutter schreibt sie beim
; Bauen in die exe (Dateiversion 1.0.0.1). Von dort statt aus pubspec.yaml:
; So trägt der Installer immer die Version dessen, was er einpackt.
!getdllversion "${QUELLE}\${EXE}" V_
!define VERSION "${V_1}.${V_2}.${V_3}+${V_4}"
; Für den Dateinamen ohne Buildnummer: Die Update-Prüfung der App sucht im
; Release genau diese Datei, und ein „+" müsste in einer Adresse „%2B"
; heißen (lib/update/update.dart).
!define VERSION3 "${V_1}.${V_2}.${V_3}"

Name "${NAME}"
OutFile "moocp_setup_${VERSION3}.exe"
InstallDir "$LOCALAPPDATA\Programs\${NAME}"
InstallDirRegKey HKCU "${UNINST_KEY}" "InstallLocation"
RequestExecutionLevel user

; 1, wenn die App diesen Installer selbst gestartet hat (Schalter /UPDATE,
; lib/update/update.dart). Dann beendet sie sich gerade: AppBeendet wartet
; still auf das Freiwerden der exe, statt sofort zu fragen, und die
; Lizenzseite entfällt -- beim Update ist sie nur Lärm, die Version davor
; stand unter derselben Lizenz.
Var Update

; Halbe Sekunden, die AppBeendet im Update-Fall schon gewartet hat.
Var Gewartet

; Hinweisseite: 1, sobald der Countdown einmal abgelaufen ist -- dann wartet
; die Seite nicht erneut, wenn jemand von der Lizenzseite zurückgeht. Dazu
; die noch fehlenden Sekunden und das Fenster des Knopfes „Weiter“.
Var Hinweis
Var HinweisRest
Var WeiterKnopf

;--------------------------------
; Seiten

!define MUI_ICON "..\windows\runner\resources\app_icon.ico"
!define MUI_UNICON "..\windows\runner\resources\app_icon.ico"
!define MUI_ABORTWARNING

; Der Hinweis zur Nutzung steht vor der Lizenz: Er ist der wichtigere, und in
; der README steht er ebenso ganz oben. Eine eigene nsDialogs-Seite statt
; einer zweiten Lizenzseite, weil nur dort ein Timer laufen kann
; (nsDialogs::CreateTimer braucht einen eigenen Dialog) und sich einzelne
; Zeilen fett setzen lassen.
Page custom HinweisSeite HinweisSeiteEnde

; Die MIT-Lizenz verlangt keine Zustimmung; die Seite zeigt sie zur
; Kenntnis, mit „Weiter" statt „Annehmen".
!define MUI_LICENSEPAGE_BUTTON "$(^NextBtn)"
!define MUI_LICENSEPAGE_TEXT_BOTTOM "moocp steht unter der MIT-Lizenz: Sie dürfen die App frei benutzen, weitergeben und verändern. Eine Zustimmung ist nicht nötig."
!define MUI_PAGE_CUSTOMFUNCTION_PRE LizenzSeite
; LICENSE.md beginnt mit einem BOM, und das muss so bleiben: Eine Textdatei
; ohne BOM liest NSIS in der ANSI-Codepage, auch im Unicode-Installer -- aus
; „©“ würde „Â©“. Die App zeigt dieselbe Datei (lib/ueber.dart).
!insertmacro MUI_PAGE_LICENSE "..\LICENSE.md"
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\${EXE}"
!define MUI_FINISHPAGE_RUN_TEXT "${NAME} starten"
!insertmacro MUI_PAGE_FINISH

!define MUI_UNCONFIRMPAGE_TEXT_TOP "${NAME} wird entfernt, zusammen mit Einstellungen, Protokoll, gespeicherten Anmeldedaten und Arbeitsordner. Auch die Verbindung in Claude Code, Codex CLI und LM Studio und die Skills der App werden entfernt."
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "German"

VIProductVersion "${V_1}.${V_2}.${V_3}.${V_4}"
VIFileVersion "${V_1}.${V_2}.${V_3}.${V_4}"
VIAddVersionKey /LANG=${LANG_GERMAN} "ProductName" "${NAME}"
VIAddVersionKey /LANG=${LANG_GERMAN} "ProductVersion" "${VERSION}"
VIAddVersionKey /LANG=${LANG_GERMAN} "FileVersion" "${VERSION}"
VIAddVersionKey /LANG=${LANG_GERMAN} "FileDescription" "Installer für ${NAME}"
VIAddVersionKey /LANG=${LANG_GERMAN} "CompanyName" "${HERAUSGEBER}"
VIAddVersionKey /LANG=${LANG_GERMAN} "LegalCopyright" "© 2026 ${HERAUSGEBER}, MIT-Lizenz"

;--------------------------------
; Aufruf durch die App (Update)

Function .onInit
  ${GetParameters} $0
  ClearErrors
  ${GetOptions} $0 "/UPDATE" $1
  ${IfNot} ${Errors}
    StrCpy $Update 1
  ${EndIf}
FunctionEnd

Function LizenzSeite
  ${If} $Update == 1
    Abort ; überspringt die Seite, nicht die Installation
  ${EndIf}
FunctionEnd

;--------------------------------
; Hinweis zur Nutzung
;
; Derselbe Hinweis steht am Anfang der README; wer ihn dort ändert, ändert
; ihn hier mit (CLAUDE.md, Arbeitsregeln). Gekürzt ist er, weil alles ohne
; Scrollen auf die Seite passen soll -- ein Kasten, in dem man blättern muss,
; wird nicht gelesen. Die Seite ist 300 x 140 Dialogeinheiten groß; die
; Höhen unten sind in Zeilen gerechnet (eine Zeile dieser Schrift ~8u) und
; am gebauten Installer nachgesehen.
;
; „Weiter“ ist die ersten ${HINWEIS_SEKUNDEN} Sekunden gesperrt und zählt im
; eigenen Text herunter, damit niemand einen kaputten Knopf vor sich sieht.
; „Abbrechen“ bleibt die ganze Zeit möglich.

Function HinweisSeite
  ${If} $Update == 1
    Abort ; überspringt die Seite, nicht die Installation
  ${EndIf}
  !insertmacro MUI_HEADER_TEXT "Wichtiger Hinweis" "Bitte lesen Sie ihn. „Weiter“ wird nach ${HINWEIS_SEKUNDEN} Sekunden aktiv."

  nsDialogs::Create 1018
  Pop $0
  ${If} $0 == error
    Abort
  ${EndIf}

  ; Fett, aber in der Größe des Fließtextes: zwei Schriftgrößen auf der
  ; engen Seite wirken unruhig, und Farbe läse sich wie eine Fehlermeldung.
  CreateFont $1 "$(^Font)" "$(^FontSize)" 700

  ${NSD_CreateLabel} 0u 0u 300u 11u "Nutzung auf eigene Verantwortung"
  Pop $2
  SendMessage $2 ${WM_SETFONT} $1 1

  ${NSD_CreateLabel} 0u 10u 300u 33u "moocp ist ein privates Open-Source-Projekt, ohne Gewähr. Es wird weder von einer Schule, einem Land oder Schulträger noch von Moodle HQ oder KI-Anbietern angeboten, geprüft oder unterstützt. Die App liest und ändert Ihre Moodle-Kurse, und Fehler sind nicht ausgeschlossen: Probieren Sie sie zuerst in einem Testkurs aus."
  Pop $2

  ${NSD_CreateLabel} 0u 48u 300u 16u "Vor dem Einsatz klären – mit Schulleitung, Datenschutzbeauftragten und dem Betreiber Ihrer Moodle-Instanz:"
  Pop $2
  SendMessage $2 ${WM_SETFONT} $1 1

  ; Punkt und Text getrennt, damit die zweite Zeile eines Punktes einrückt.
  ${NSD_CreateLabel} 2u 67u 7u 10u "•"
  Pop $2
  ${NSD_CreateLabel} 9u 67u 291u 17u "ob Sie KI-Werkzeuge dienstlich einsetzen dürfen, und mit welchem Konto. Alles, was die KI liest, geht an den Anbieter des Modells."
  Pop $2

  ${NSD_CreateLabel} 2u 86u 7u 10u "•"
  Pop $2
  ${NSD_CreateLabel} 9u 86u 291u 17u "ob die Nutzungsbedingungen Ihrer Moodle-Instanz einen automatisierten Zugriff mit Ihrem Konto erlauben."
  Pop $2

  ${NSD_CreateLabel} 2u 105u 7u 10u "•"
  Pop $2
  ${NSD_CreateLabel} 9u 105u 291u 17u "ob Inhalte Dritter in Ihren Kursen, etwa Verlagsmaterial, an eine KI gegeben werden dürfen; manche Lizenzen schließen das aus."
  Pop $2

  ${NSD_CreateLabel} 0u 124u 300u 16u "moocp ist so gebaut, dass personenbezogene Daten gar nicht erst angefragt werden. Eine Garantie ist das nicht – auch darin können Fehler stecken."
  Pop $2

  GetDlgItem $WeiterKnopf $HWNDPARENT 1
  ${If} $Hinweis != 1
    EnableWindow $WeiterKnopf 0
    StrCpy $HinweisRest ${HINWEIS_SEKUNDEN}
    ${NSD_SetText} $WeiterKnopf "Weiter in $HinweisRest s"
    ${NSD_CreateTimer} HinweisTick 1000
  ${EndIf}

  nsDialogs::Show
FunctionEnd

Function HinweisTick
  IntOp $HinweisRest $HinweisRest - 1
  ${If} $HinweisRest > 0
    ${NSD_SetText} $WeiterKnopf "Weiter in $HinweisRest s"
  ${Else}
    ${NSD_KillTimer} HinweisTick
    StrCpy $Hinweis 1
    ${NSD_SetText} $WeiterKnopf "$(^NextBtn)"
    EnableWindow $WeiterKnopf 1
  ${EndIf}
FunctionEnd

Function HinweisSeiteEnde
  ; Ohne das liefe der Timer weiter und schriebe seinen Text später am Knopf
  ; „Installieren“ oder „Fertig stellen“.
  ${NSD_KillTimer} HinweisTick
FunctionEnd

;--------------------------------
; Gemeinsam für Installieren und Deinstallieren

; Läuft die App, ist die exe gesperrt: Öffnen zum Schreiben scheitert. Die
; App nicht beenden, sondern darum bitten -- nur beim regulären Schließen
; leert sie ihren Arbeitsordner (lib/main.dart). Die Brücke für LM Studio
; sperrt die exe nicht: Sie ist ein eigenes Programm (BrueckeBeiseite).
;
; Beim Update hat die App den Installer selbst gestartet und schließt sich
; in diesem Augenblick. Da ist Fragen sinnlos: bis zu 30 Sekunden still
; warten, bis die exe frei ist. Erst wenn sie dann noch hängt, kommt die
; Frage wie sonst auch.
!macro AppBeendet UN
Function ${UN}AppBeendet
  StrCpy $Gewartet 0
  ${Do}
    ${IfNot} ${FileExists} "$INSTDIR\${EXE}"
      ${Break}
    ${EndIf}
    ClearErrors
    FileOpen $0 "$INSTDIR\${EXE}" a
    ${IfNot} ${Errors}
      FileClose $0
      ${Break}
    ${EndIf}
    ${If} $Update == 1
    ${AndIf} $Gewartet < 60
      IntOp $Gewartet $Gewartet + 1
      Sleep 500
      ${Continue}
    ${EndIf}
    MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION "${NAME} läuft noch. Bitte die App schließen und dann „Wiederholen“ wählen." /SD IDCANCEL IDRETRY nochmal
    Abort
    nochmal:
  ${Loop}
FunctionEnd
!macroend
!insertmacro AppBeendet ""
!insertmacro AppBeendet "un."

; Die Brücke läuft, solange LM Studio (Bionic) mit ${NAME} verbunden ist, und
; ist dann gesperrt: Löschen geht nicht, Umbenennen schon, und Bionic
; arbeitet mit der umbenannten weiter, bis es neu verbindet. Darum beim
; Update nicht um das Schließen von Bionic bitten, sondern die laufende
; beiseitelegen. Was beiseite liegt, löscht ein späterer Lauf, sobald es
; frei ist. Genauso macht es der Bau (windows/bruecke.cmake).
!macro BrueckeBeiseite
  Delete "$INSTDIR\moocp-bruecke.*.alt"
  Delete "$INSTDIR\${BRUECKE}"
  ${If} ${FileExists} "$INSTDIR\${BRUECKE}"
    System::Call "kernel32::GetTickCount() i .r0"
    Rename "$INSTDIR\${BRUECKE}" "$INSTDIR\moocp-bruecke.$0.alt"
  ${EndIf}
!macroend

; Genau das, was der Installer hinlegt (der Inhalt von Release), nie den
; Ordner als Ganzes: Über /D= ließe sich ein beliebiger Ordner als Ziel
; angeben. Flutter baut data\ bei jedem Bau ganz neu; mitgelöscht, bleibt
; von einer älteren Version nichts liegen.
!macro ProgrammEntfernen
  !insertmacro BrueckeBeiseite
  Delete "$INSTDIR\${EXE}"
  Delete "$INSTDIR\*.dll"
  Delete "$INSTDIR\native_assets.json"
  RMDir /r "$INSTDIR\data"
!macroend

;--------------------------------
; Installieren. Über eine ältere Version: Deren Programmdateien werden
; ersetzt; Einstellungen, Anmeldedaten und die Einrichtung der KI-Werkzeuge
; bleiben. Ob die Skills zur neuen Version passen, prüft die App beim Start.

Section
  Call AppBeendet
  !insertmacro ProgrammEntfernen
  SetOutPath "$INSTDIR"
  ; Ohne Brücken, die der Bau beiseitegelegt hat (windows/bruecke.cmake).
  File /r /x *.alt "${QUELLE}\*"
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  CreateShortCut "$SMPROGRAMS\${NAME}.lnk" "$INSTDIR\${EXE}"
  CreateShortCut "$DESKTOP\${NAME}.lnk" "$INSTDIR\${EXE}"

  WriteRegStr HKCU "${UNINST_KEY}" "DisplayName" "${NAME}"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${UNINST_KEY}" "Publisher" "${HERAUSGEBER}"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayIcon" "$INSTDIR\${EXE}"
  WriteRegStr HKCU "${UNINST_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINST_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKCU "${UNINST_KEY}" "QuietUninstallString" '"$INSTDIR\Uninstall.exe" /S'
  WriteRegDWORD HKCU "${UNINST_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINST_KEY}" "NoRepair" 1
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  WriteRegDWORD HKCU "${UNINST_KEY}" "EstimatedSize" $0
SectionEnd

;--------------------------------
; Deinstallieren: die App, ihre Daten und ihre Einrichtung in den KI-Werkzeugen,
; damit weder Kursinhalte noch Anmeldedaten auf dem Rechner bleiben.

Section "Uninstall"
  Call un.AppBeendet

  ; Die Einrichtung in den KI-Werkzeugen entfernt die App selbst: Sie weiß,
  ; wo claude.exe liegt und wie die Einträge von Codex und LM Studio
  ; aussehen (lib/einrichtung.dart, einrichtungEntfernen). Exit-Code: Bit 1
  ; ein Eintrag „moodle" steht noch, Bit 2 Dateien der Skills sind noch da.
  DetailPrint "Entferne die Einrichtung in den KI-Werkzeugen …"
  ClearErrors
  ExecWait '"$INSTDIR\${EXE}" --claude-entfernen' $0
  ${If} ${Errors}
    StrCpy $0 3
  ${EndIf}
  StrCpy $1 ""
  IntOp $2 $0 & 1
  ${If} $2 <> 0
    StrCpy $1 "$1$\n$\n• Die Verbindung „moodle“ in einem KI-Werkzeug. Claude Code: in einer Eingabeaufforderung$\n    claude mcp remove moodle --scope user$\nCodex CLI: den Abschnitt [mcp_servers.moodle] in %USERPROFILE%\.codex\config.toml löschen.$\nLM Studio: in Bionic unter Einstellungen, MCP den Server moodle löschen."
  ${EndIf}
  IntOp $2 $0 & 2
  ${If} $2 <> 0
    StrCpy $1 "$1$\n$\n• Dateien der Skills. Das KI-Werkzeug beenden und unter %USERPROFILE%\.claude\skills, %USERPROFILE%\.codex\skills und %USERPROFILE%\.lmstudio\skills die Ordner moodle, moodle-fragen und lernsituation löschen, soweit vorhanden."
  ${EndIf}
  ${If} $1 != ""
    MessageBox MB_OK|MB_ICONEXCLAMATION "Nicht alles ließ sich entfernen:$1" /SD IDOK
  ${EndIf}

  ; Ist Bionic noch offen, läuft womöglich die Brücke. Ihr Eintrag ist jetzt
  ; ausgetragen, und sie hält nichts, was verloren ginge: beenden, damit
  ; sich der Ordner löschen lässt. Anders als die App (AppBeendet), die nur
  ; beim regulären Schließen ihren Arbeitsordner leert. Auch eine
  ; umbenannte trägt im Prozess noch ihren alten Namen.
  nsExec::Exec 'taskkill /F /IM ${BRUECKE}'
  Pop $0
  Sleep 500
  !insertmacro ProgrammEntfernen
  Delete "$INSTDIR\moocp-bruecke.*.alt"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"

  Delete "$SMPROGRAMS\${NAME}.lnk"
  Delete "$DESKTOP\${NAME}.lnk"
  DeleteRegKey HKCU "${UNINST_KEY}"

  ; Die Daten der App. Einstellungen mit Zugangsschlüssel und Protokoll
  ; (lib/einstellungen.dart), Benutzername und verschlüsseltes Passwort
  ; (lib/anmeldedaten.dart; der Ordner kommt aus CompanyName und ProductName
  ; in windows/runner/Runner.rc), der Arbeitsordner (lib/arbeitsordner.dart).
  ; Beides liegt unter %APPDATA%\moocp: CompanyName ist dort ebenfalls moocp.
  RMDir /r "$APPDATA\moocp"
  RMDir /r "$TEMP\moocp_arbeitsordner"
SectionEnd
