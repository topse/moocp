@echo off
rem Baut den Installer: Skills, Prüfungen, App, dann NSIS. Ergebnis:
rem installer\moocp_setup<Version>.exe, die Version aus pubspec.yaml.
rem
rem Voraussetzungen: Flutter mit Windows-Desktop, Python 3, NSIS 3 (makensis
rem im Suchpfad oder unter %ProgramFiles(x86)%\NSIS).
rem
rem Die Datei ist UTF-8 mit CRLF; chcp 65001 lässt cmd die Umlaute der
rem Meldungen richtig lesen. CRLF, weil cmd Sprungmarken in Dateien mit LF
rem nicht zuverlässig findet.
setlocal
cd /d "%~dp0"
for /f "tokens=2 delims=:." %%c in ('chcp') do set "ALTE_CODEPAGE=%%c"
chcp 65001 >nul

rem Läuft die App, ist moocp.exe gesperrt, und der Bau scheitert erst
rem spät mit einer wenig sprechenden Meldung.
tasklist /fi "imagename eq moocp.exe" | find /i "moocp.exe" >nul
if not errorlevel 1 (
  echo moocp läuft noch. Bitte die App schließen.
  goto fehler
)

rem Außerhalb von Klammern: Die Klammern in "(x86)" beendeten sonst den Block.
set "MAKENSIS=%ProgramFiles(x86)%\NSIS\makensis.exe"
where makensis >nul 2>&1 && set "MAKENSIS=makensis"
if not "%MAKENSIS%"=="makensis" if not exist "%MAKENSIS%" (
  echo NSIS 3 nicht gefunden: https://nsis.sourceforge.io
  goto fehler
)

echo.
echo [1/5] Skills bauen
python skills\build.py
if errorlevel 1 goto fehler

echo.
echo [2/5] flutter analyze
call flutter analyze
if errorlevel 1 goto fehler

echo.
echo [3/5] flutter test
call flutter test
if errorlevel 1 goto fehler

echo.
echo [4/5] App bauen
call flutter build windows --release
if errorlevel 1 goto fehler

echo.
echo [5/5] Installer bauen
"%MAKENSIS%" /V2 installer\moocp.nsi
if errorlevel 1 goto fehler

for /f "delims=" %%f in ('dir /b /o-d installer\moocp_setup*.exe') do (
  echo.
  echo Fertig: installer\%%f
  goto ende
)

:ende
chcp %ALTE_CODEPAGE% >nul
exit /b 0

:fehler
echo.
echo Abgebrochen.
chcp %ALTE_CODEPAGE% >nul
exit /b 1
