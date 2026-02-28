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
// The engine uses argv[0] as the Lua script path (not the program name).
// This entry point resolves the location of Launch.lua and passes it as
// argv[0] to the engine.
//
// Resolution order:
//   1. Explicit argument: ./PathOfBuilding Launch.lua
//      (argc > 1 → shift argv so argv[1] becomes argv[0])
//   2. App bundle: Contents/Resources/Launch.lua
//      (detected by the MacOS/ → Resources/ relative path)
//   3. Alongside executable: <exe_dir>/Launch.lua
//
// macOS run loop notes:
//   GLFW handles the Cocoa NSApplication + run loop internally when called from
//   the main thread here.  No additional NSApp setup is required.
//

#include <cstdlib>
#include <cstring>
#include <string>
#include <libproc.h>
#include <unistd.h>
#include <filesystem>

// Exported by SimpleGraphic.dylib (win/entry.cpp, compiled cross-platform)
extern "C" int RunLuaFileAsWin(int argc, char** argv);

static std::string findLaunchScript()
{
    // Locate the directory containing this executable.
    // Note: proc_pidpath(getpid(), ...) returns the path of the currently
    // running process image.  This is safe here because main() is the first
    // C++ code to run and no execve() has occurred.  Do not call this after
    // a fork/exec-based restart — use a re-exec pattern instead.
    char pathBuf[PROC_PIDPATHINFO_MAXSIZE]{};
    proc_pidpath(getpid(), pathBuf, sizeof(pathBuf));
    std::filesystem::path exePath(pathBuf);
    auto exeDir = exePath.parent_path();

    // App bundle layout: Contents/MacOS/<exe>  →  Contents/Resources/src/Launch.lua
    if (exeDir.filename() == "MacOS") {
        auto resourcesDir = exeDir.parent_path() / "Resources";
        // Primary: src/Launch.lua (matches the PoB dist layout)
        auto candidate = resourcesDir / "src" / "Launch.lua";
        if (std::filesystem::exists(candidate))
            return candidate.string();
        // Fallback: Launch.lua directly in Resources
        candidate = resourcesDir / "Launch.lua";
        if (std::filesystem::exists(candidate))
            return candidate.string();
    }

    // Flat layout: Launch.lua next to the executable
    auto candidate = exeDir / "Launch.lua";
    if (std::filesystem::exists(candidate))
        return candidate.string();

    // Fallback: let the engine figure it out (will likely fail)
    return "Launch.lua";
}

int main(int argc, char** argv)
{
    if (argc > 1) {
        // Explicit script argument: e.g. ./PathOfBuilding Launch.lua [extra args...]
        // The engine resolves relative paths against basePath (exe dir),
        // but the user expects resolution against CWD.  Make it absolute.
        std::filesystem::path scriptArg(argv[1]);
        std::string absScript;
        if (scriptArg.is_relative()) {
            absScript = std::filesystem::absolute(scriptArg).string();
            argv[1] = const_cast<char*>(absScript.c_str());
        }
        return RunLuaFileAsWin(argc - 1, argv + 1);
    }

    // No explicit script argument — resolve Launch.lua automatically.
    std::string scriptPath = findLaunchScript();

    // Build a synthetic argv with scriptPath as argv[0].
    char* syntheticArgv[] = { const_cast<char*>(scriptPath.c_str()), nullptr };
    return RunLuaFileAsWin(1, syntheticArgv);
}
