# Baut die Brücke für KI-Werkzeuge, die MCP nur über stdio sprechen
# (bin/moocp_bruecke.dart, lib/mcp/bruecke.dart), und legt sie als
# moocp-bruecke.exe neben moocp.exe. Läuft im Installationsschritt jedes
# Baus, also bei `flutter build windows` wie bei `flutter run`; die Variablen
# BRUECKE_* setzt CMakeLists.txt.
#
# `dart build cli`, nicht `dart compile exe`: compile lehnt ein Projekt ab,
# sobald eine seiner Abhängigkeiten Build-Hooks hat (über die Flutter-Plugins
# etwa objective_c). Die Brücke braucht davon nichts; unter Windows enthält
# das Bündel nur die exe, ohne Bibliotheken.
#
# Ein KI-Werkzeug, das die Brücke gestartet hat, hält sie offen, solange es
# läuft. Überschreiben und Löschen gehen dann nicht, Umbenennen schon, und
# der laufende Prozess arbeitet mit der umbenannten Datei weiter. Also die
# alte beiseite, die neue an ihren Platz, und Beiseitegelegtes löschen,
# sobald es frei ist. Genauso macht es der Installer (installer/moocp.nsi).

set(zwischen "${BRUECKE_PROJEKT}/build/bruecke")
execute_process(
  COMMAND "${BRUECKE_DART}" build cli -t bin/moocp_bruecke.dart -o "${zwischen}" --verbosity=error
  WORKING_DIRECTORY "${BRUECKE_PROJEKT}"
  RESULT_VARIABLE fehler)
if(fehler)
  message(FATAL_ERROR "moocp-bruecke.exe nicht gebaut: dart build cli endete mit ${fehler}")
endif()

set(ziel "${BRUECKE_ORDNER}/moocp-bruecke.exe")
if(EXISTS "${ziel}")
  string(TIMESTAMP jetzt "%Y%m%d%H%M%S")
  file(RENAME "${ziel}" "${BRUECKE_ORDNER}/moocp-bruecke.${jetzt}.alt" RESULT fehler)
  if(fehler)
    message(FATAL_ERROR "moocp-bruecke.exe nicht ersetzt: ${fehler}")
  endif()
endif()
file(COPY_FILE "${zwischen}/bundle/bin/moocp_bruecke.exe" "${ziel}")
message(STATUS "Installing: ${ziel}")

file(GLOB reste "${BRUECKE_ORDNER}/moocp-bruecke.*.alt")
foreach(rest IN LISTS reste)
  # Noch in Gebrauch: Dann beim nächsten Bau.
  execute_process(COMMAND "${CMAKE_COMMAND}" -E rm -f "${rest}" RESULT_VARIABLE egal ERROR_QUIET)
endforeach()
