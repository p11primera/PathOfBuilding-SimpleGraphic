// SimpleGraphic Engine
//
// Entry Point
// Platform: macOS
//
// This file is compiled into the standalone "Path of Building-PoE2" Mach-O
// executable that lives in Contents/MacOS/ of the .app bundle.
//
// It links directly against SimpleGraphic.dylib (rather than using dlopen)
// and calls RunLuaFileAsWin — the same C export used by the Windows launcher.
//
// macOS run loop notes:
//   GLFW handles the Cocoa NSApplication + run loop internally when called from
//   the main thread here.  No additional NSApp setup is required.
//

#include <cstdlib>

// Exported by SimpleGraphic.dylib (win/entry.cpp, compiled cross-platform)
extern "C" int RunLuaFileAsWin(int argc, char** argv);

int main(int argc, char** argv)
{
    return RunLuaFileAsWin(argc, argv);
}
