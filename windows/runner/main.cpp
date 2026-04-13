#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <cstdlib>
#include <string>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // ---- Low-end GPU compatibility ----
  // Disable Impeller and use Skia instead.  Impeller requires DirectX 11+
  // via ANGLE, which is not available on Intel HD Graphics 3000 (Sandy Bridge,
  // DX 10.1 only).  Skia uses OpenGL 3.1 which HD 3000 does support.
  _putenv_s("FLUTTER_ENGINE_SWITCHES", "1");
  _putenv_s("FLUTTER_ENGINE_SWITCH_1", "no-enable-impeller");

  // If even OpenGL fails (broken driver), the user can launch the app with
  // --software flag to force CPU-based software rendering.
  std::wstring cmd(command_line);
  if (cmd.find(L"--software") != std::wstring::npos) {
    _putenv_s("FLUTTER_ENGINE_SWITCHES", "2");
    _putenv_s("FLUTTER_ENGINE_SWITCH_2", "enable-software-rendering");
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Digitex POS Terminal", origin, size)) {
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
