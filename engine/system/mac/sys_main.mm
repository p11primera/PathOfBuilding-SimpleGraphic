// SimpleGraphic Engine
//
// Module: System Main — macOS Objective-C++ helpers
// Platform: macOS
//
// This file provides the Objective-C++ pieces that sys_main.cpp
// (compiled as plain C++) cannot express directly:
//
//   • SysMac_FindUserPath  — returns ~/Library/Application Support/<AppName>
//   • SysMac_SpawnProcess  — launches a subprocess via NSTask
//
// Clipboard notes:
//   GLFW's glfwSetClipboardString / glfwGetClipboardString already call
//   NSPasteboard internally, so sys_main_c::ClipboardCopy/Paste need no
//   macOS-specific changes.
//
// Run loop notes:
//   GLFW's event loop (glfwPollEvents / glfwWaitEvents) drives the Cocoa
//   run loop on macOS.  No additional NSRunLoop integration is needed.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>

#include <cstring>
#include <cassert>

// ── User data path ───────────────────────────────────────────────────────────

// Returns the macOS Application Support base directory:
//   ~/Library/Application Support
//
// This mirrors the Windows behaviour where FindUserPath returns the Documents
// folder. The Lua caller (Modules/Main.lua) appends the application-specific
// subdirectory name ("Path of Building (PoE2)") on top of the returned base.
//
// The caller-supplied buffer is filled with a NUL-terminated UTF-8 path
// without a trailing slash.
// Returns true on success; false if the buffer is too small or the OS call
// fails.
//
// Called from sys_main_c (FindUserPath) in sys_main.cpp when __APPLE__.
extern "C" bool SysMac_FindUserPath(char* buf, size_t bufSize)
{
    assert(buf != nullptr && bufSize > 0);

    NSArray<NSString*>* dirs = NSSearchPathForDirectoriesInDomains(
        NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString* appSupport = dirs.firstObject;
    if (!appSupport)
        return false;

    const char* utf8 = appSupport.UTF8String;
    if (std::strlen(utf8) >= bufSize)
        return false;

    std::strncpy(buf, utf8, bufSize - 1);
    buf[bufSize - 1] = '\0';
    return true;
}

// ── Process spawning ─────────────────────────────────────────────────────────

// Launches cmdName (UTF-8 path, must exist) with a single argument string.
// argList is passed as a /bin/sh -c argument so spaces are honoured.
// Mirrors the Windows ShellExecuteEx behaviour used for self-restart.
//
// Called from sys_main_c::SpawnProcess in sys_main.cpp when __APPLE__.
extern "C" void SysMac_SpawnProcess(const char* cmdName, const char* argList)
{
    NSString* cmd = [NSString stringWithUTF8String:cmdName];
    NSMutableArray<NSString*>* args = [NSMutableArray array];

    // Split argList on whitespace (simple tokenisation, no quoting).
    // For PoB's self-restart use case this is sufficient.
    if (argList && argList[0]) {
        NSString* argStr = [NSString stringWithUTF8String:argList];
        NSArray<NSString*>* tokens =
            [argStr componentsSeparatedByCharactersInSet:
                [NSCharacterSet whitespaceCharacterSet]];
        for (NSString* t in tokens) {
            if (t.length > 0)
                [args addObject:t];
        }
    }

    NSTask* task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:cmd];
    task.arguments = args;

    NSError* err = nil;
    if (![task launchAndReturnError:&err]) {
        NSLog(@"SysMac_SpawnProcess: failed to launch %@: %@",
              cmd, err ? err.localizedDescription : @"unknown error");
    }
}

// ── Retina / EGL layer scale fix ─────────────────────────────────────────────

// GLFW 3.4's EGL code path does not set the CALayer's contentsScale the
// way the native NSGL and Metal/Vulkan paths do.  Without this, ANGLE's
// EGL surface is created at 1× logical pixels on a Retina display, while
// glfwGetFramebufferSize reports the 2× physical size.  The result is a
// blurry, zoomed-in quarter of the UI.
//
// This function sets contentsScale on the view's layer tree so that
// ANGLE's drawable matches the true physical pixel count.  We walk
// sublayers because ANGLE may create its own CAMetalLayer beneath the
// root layer that GLFW handed it.
//
// Called from sys_video.cpp right after glfwMakeContextCurrent.

static void setScaleRecursive(CALayer* layer, CGFloat scale)
{
    [layer setContentsScale:scale];
    for (CALayer* sub in [layer sublayers]) {
        setScaleRecursive(sub, scale);
    }
}

extern "C" void SysMac_FixEGLLayerScale(void* nsWindowPtr)
{
    if (!nsWindowPtr)
        return;

    NSWindow* window = (__bridge NSWindow*)nsWindowPtr;
    NSView* view = [window contentView];
    CALayer* layer = [view layer];
    if (layer) {
        CGFloat scale = [window backingScaleFactor];
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        setScaleRecursive(layer, scale);
        [CATransaction commit];
        [CATransaction flush];
    }
}
