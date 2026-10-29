#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <algorithm>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Die App läuft je Windows-Sitzung nur einmal. Eine zweite teilte
// Einstellungen und Arbeitsordner mit der ersten: Sie leerte den
// Arbeitsordner beim Start und beim Beenden (lib/arbeitsordner.dart), während
// die erste damit arbeitet, und fände den Port des MCP-Servers belegt. Das
// gilt genauso zwischen installierter App, eigenem Bau und flutter run: Alle
// nutzen dieselben Ordner.
//
// Geprüft wird hier, vor Flutter, damit die zweite gar nicht erst bis zum
// Dart-Code kommt. Den Mutex gibt Windows frei, wenn der Prozess endet, auch
// nach einem Absturz oder taskkill /F; eine Sperrdatei bliebe dann liegen.
// „Local\" heißt je Windows-Sitzung, so wie die Ordner je Benutzer liegen.
constexpr const wchar_t kSperre[] = L"Local\\moocp";

// Wie claudeEntfernenSchalter in lib/einrichtung.dart. Dieser Aufruf aus der
// Deinstallation bleibt ohne Sperre: Er fasst weder Arbeitsordner noch
// Einstellungen noch Port an. Mit Sperre endete er mit 0 („alles entfernt"),
// sobald irgendeine moocp läuft -- etwa ein eigener Bau, während die
// installierte deinstalliert wird --, und hätte nichts ausgetragen.
constexpr const char kClaudeEntfernen[] = "--claude-entfernen";

constexpr const wchar_t kTitel[] = L"moocp";

// Holt das Fenster der laufenden App nach vorn, aus der Minimierung auch.
// Liefert false, wenn sie (noch oder nicht mehr) keins hat. Die Klasse wie
// kWindowClassName in win32_window.cpp.
bool FensterNachVorn() {
  HWND fenster = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", kTitel);
  if (!fenster) {
    return false;
  }
  if (::IsIconic(fenster)) {
    ::ShowWindow(fenster, SW_RESTORE);
  }
  ::SetForegroundWindow(fenster);
  return true;
}

// Liefert, ob diese App starten soll. Läuft schon eine, holt sie deren
// Fenster nach vorn und liefert false. Hat die laufende kein Fenster, weil
// sie gerade erst startet oder schon beendet wird (Fenster zu, Prozess noch
// da), wartet sie bis zu fünf Sekunden: auf das Fenster oder darauf, dass
// der Mutex frei wird -- dann startet sie selbst. Sonst täte ein Doppelklick
// direkt nach dem Schließen nichts.
//
// Der Mutex gehört danach dem Hauptthread und bleibt bis zum Ende des
// Prozesses; das Handle wird absichtlich nie geschlossen.
bool AlleinStarten() {
  HANDLE sperre = ::CreateMutexW(nullptr, TRUE, kSperre);
  if (!sperre) {
    // Hält ihn eine App mit Administratorrechten, verweigert Windows den
    // Zugriff; auch das heißt: Sie läuft schon.
    if (::GetLastError() == ERROR_ACCESS_DENIED) {
      FensterNachVorn();
      return false;
    }
    return true;
  }
  if (::GetLastError() != ERROR_ALREADY_EXISTS) {
    return true;
  }
  for (int i = 0; i < 50; ++i) {
    if (FensterNachVorn()) {
      return false;
    }
    // WAIT_ABANDONED: Die erste endete, ohne ihn freizugeben -- der Normalfall.
    DWORD frei = ::WaitForSingleObject(sperre, 100);
    if (frei == WAIT_OBJECT_0 || frei == WAIT_ABANDONED) {
      return true;
    }
  }
  return false;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  if (std::find(command_line_arguments.begin(), command_line_arguments.end(),
                kClaudeEntfernen) == command_line_arguments.end() &&
      !AlleinStarten()) {
    return EXIT_SUCCESS;
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(kTitel, origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
