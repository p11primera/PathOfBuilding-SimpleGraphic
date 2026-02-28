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
#import <QuartzCore/CAMetalLayer.h>

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

// GLFW 3.4's EGL code path does not configure ANGLE's CAMetalLayer for
// Retina displays.  ANGLE sets CAMetalLayer.drawableSize from the view's
// bounds in *points* (logical pixels), so on a 2× Retina display the EGL
// surface ends up at half the physical resolution in each dimension, giving
// ANGLE a 1× drawable while glfwGetFramebufferSize reports the full 2×
// framebuffer.  The renderer then sizes its RTT and viewport to the 2×
// fbSize, but the actual EGL surface is only 1×, so only the top-left
// quarter of the rendered image is visible — appearing enlarged and blurry.
// Resizing the window works around this because Cocoa sends a
// frameDidChange notification that causes ANGLE to recalculate drawableSize.
//
// The fix: walk the CALayer tree and for every CAMetalLayer found (ANGLE
// creates one beneath the view's root layer), explicitly set both
// contentsScale and drawableSize to the physical pixel dimensions.  Both
// fields must be updated: contentsScale alone does not update drawableSize.
//
// Called from sys_video.cpp after glfwShowWindow + glfwPollEvents so that
// ANGLE has already created and attached its CAMetalLayer.

static void fixLayerRecursive(CALayer* layer, CGFloat scale, CGSize viewBoundsSize)
{
    layer.contentsScale = scale;
    if ([layer isKindOfClass:[CAMetalLayer class]]) {
        CAMetalLayer* metalLayer = (CAMetalLayer*)layer;
        metalLayer.drawableSize = CGSizeMake(
            viewBoundsSize.width  * scale,
            viewBoundsSize.height * scale);
    }
    for (CALayer* sub in [layer sublayers]) {
        fixLayerRecursive(sub, scale, viewBoundsSize);
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
        CGSize viewSize = view.bounds.size;
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        fixLayerRecursive(layer, scale, viewSize);
        [CATransaction commit];
        // flush pushes layer tree changes to the Core Animation render server
        // immediately, before the next display pass.  Without it, changes are
        // deferred and ANGLE reads stale geometry when allocating its EGL
        // surface, reproducing the 1x quarter-render on initial load.
        [CATransaction flush];
    }
}

// ── Dock launch progress indicator ───────────────────────────────────────────
//
// GLFW calls [NSApp finishLaunching] inside glfwInit(), which ends the
// automatic Dock bounce before the Lua VM has loaded any content.
// [NSApp requestUserAttention:] is a no-op when the app is already the
// active/frontmost application (always the case on double-click launch).
// NSDockTile.contentView + NSProgressIndicator requires the main run loop to
// be spinning to animate — which it isn't during synchronous Lua loading.
//
// Reliable solution: dockTile.badgeLabel.  This is pure IPC to the Dock
// process and works from any thread and any run-loop state.  An ellipsis
// badge on the icon gives clear "loading" feedback at zero complexity.

extern "C" void SysMac_BeginLaunch(void)
{
    [NSApp dockTile].badgeLabel = @"…";
}

extern "C" void SysMac_EndLaunch(void)
{
    [NSApp dockTile].badgeLabel = nil;
}
