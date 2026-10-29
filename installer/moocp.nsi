; Installer für moocp (NSIS 3). create_installer.bat baut erst die App
; und ruft dann dieses Skript auf; von Hand, nach `flutter build windows`:
;
;   makensis installer\moocp.nsi
;
; Für den angemeldeten Benutzer, ohne Administratorrechte: Die Daten der App
; und die Einrichtung von Claude Code liegen ohnehin je Benutzer.
;
; Mit dem Schalter /UPDATE startet die App diesen Installer selbst, nachdem
; sie ihn von GitHub geholt hat: Dann wartet er still, bis die App zu ist,
; und lässt die Lizenzseite aus. Sichtbar bleibt er trotzdem -- wer ein
; Update installiert, soll sehen, was läuft.
;
; Die Datei ist UTF-8 mit BOM; ohne BOM liest makensis sie in der
; ANSI-Codepage, und die Umlaute gingen verloren.

Unicode true
SetCompressor /SOLID lzma

!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "FileFunc.nsh"

!define NAME "moocp"
!define EXE "moocp.exe"
!define HERAUSGEBER "Tobias Steinmann"
!define QUELLE "..\build\windows\x64\runner\Release"
; Der Eintrag unter „Installierte Apps". Der Name bleibt über alle Versionen
; gleich, damit eine neue Fassung die alte ersetzt.
!define UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\moocp"

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
; Lizenzseite entfällt -- beim Update ist sie nur Lärm, die Fassung davor
; stand unter derselben Lizenz.
Var Update

; Halbe Sekunden, die AppBeendet im Update-Fall schon gewartet hat.
Var Gewartet

;--------------------------------
; Seiten

!define MUI_ICON "..\windows\runner\resources\app_icon.ico"
!define MUI_UNICON "..\windows\runner\resources\app_icon.ico"
!define MUI_ABORTWARNING

; Die MIT-Lizenz verlangt keine Zustimmung; die Seite zeigt sie zur
; Kenntnis, mit „Weiter" statt „Annehmen".
!define MUI_LICENSEPAGE_BUTTON "$(^NextBtn)"
!define MUI_LICENSEPAGE_TEXT_BOTTOM "moocp steht unter der MIT-Lizenz: Sie dürfen die App frei benutzen, weitergeben und verändern. Eine Zustimmung ist nicht nötig."
!define MUI_PAGE_CUSTOMFUNCTION_PRE LizenzSeite
!insertmacro MUI_PAGE_LICENSE "..\LICENSE.md"
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\${EXE}"
!define MUI_FINISHPAGE_RUN_TEXT "${NAME} starten"
!insertmacro MUI_PAGE_FINISH

!define MUI_UNCONFIRMPAGE_TEXT_TOP "${NAME} wird entfernt, zusammen mit Einstellungen, Protokoll, gespeicherten Anmeldedaten und Arbeitsordner. Auch die Verbindung in Claude Code und die Skills der App werden entfernt."
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
; Gemeinsam für Installieren und Deinstallieren

; Läuft die App, ist die exe gesperrt: Öffnen zum Schreiben scheitert. Die
; App nicht beenden, sondern darum bitten -- nur beim regulären Schließen
; leert sie ihren Arbeitsordner (lib/main.dart).
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

; Genau das, was der Installer hinlegt (der Inhalt von Release), nie den
; Ordner als Ganzes: Über /D= ließe sich ein beliebiger Ordner als Ziel
; angeben. Flutter baut data\ bei jedem Bau ganz neu; mitgelöscht, bleibt
; von einer älteren Fassung nichts liegen.
!macro ProgrammEntfernen
  Delete "$INSTDIR\${EXE}"
  Delete "$INSTDIR\*.dll"
  Delete "$INSTDIR\native_assets.json"
  RMDir /r "$INSTDIR\data"
!macroend

;--------------------------------
; Installieren. Über eine ältere Fassung: Deren Programmdateien werden
; ersetzt; Einstellungen, Anmeldedaten und die Einrichtung von Claude Code
; bleiben. Ob die Skills zur neuen Fassung passen, prüft die App beim Start.

Section
  Call AppBeendet
  !insertmacro ProgrammEntfernen
  SetOutPath "$INSTDIR"
  File /r "${QUELLE}\*"
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
; Deinstallieren: die App, ihre Daten und ihre Einrichtung in Claude Code,
; damit weder Kursinhalte noch Anmeldedaten auf dem Rechner bleiben.

Section "Uninstall"
  Call un.AppBeendet

  ; Die Einrichtung in Claude Code entfernt die App selbst: Sie weiß, wo
  ; claude.exe liegt, und trägt nur über dessen Kommandozeile aus
  ; (lib/einrichtung.dart, einrichtungEntfernen). Exit-Code: Bit 1 der
  ; Eintrag „moodle" steht noch, Bit 2 Dateien der Skills sind noch da.
  DetailPrint "Entferne die Einrichtung in Claude Code …"
  ClearErrors
  ExecWait '"$INSTDIR\${EXE}" --claude-entfernen' $0
  ${If} ${Errors}
    StrCpy $0 3
  ${EndIf}
  StrCpy $1 ""
  IntOp $2 $0 & 1
  ${If} $2 <> 0
    StrCpy $1 "$1$\n$\n• Die Verbindung „moodle“ in Claude Code. Entfernen in einer Eingabeaufforderung mit:$\n    claude mcp remove moodle --scope user"
  ${EndIf}
  IntOp $2 $0 & 2
  ${If} $2 <> 0
    StrCpy $1 "$1$\n$\n• Dateien der Skills. Claude beenden und unter %USERPROFILE%\.claude\skills die Ordner moodle, moodle-fragen und lernsituation löschen, soweit vorhanden."
  ${EndIf}
  ${If} $1 != ""
    MessageBox MB_OK|MB_ICONEXCLAMATION "Nicht alles ließ sich entfernen:$1" /SD IDOK
  ${EndIf}

  !insertmacro ProgrammEntfernen
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
