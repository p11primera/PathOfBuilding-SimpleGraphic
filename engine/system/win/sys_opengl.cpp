// SimpleGraphic Engine
// (c) David Gowor, 2014
//
// Module: System OpenGL
// Platform: Windows / macOS / Linux
//
// macOS notes:
//   • ANGLE is linked directly (libEGL.dylib / libGLESv2.dylib) — no dlopen.
//   • The Metal backend is selected before glfwInit() via
//     GLFW_ANGLE_PLATFORM_TYPE_METAL in sys_video.cpp; no changes are needed here.
//   • glfwGetProcAddress resolves ANGLE entry points on all platforms.
//

#include "sys_local.h"

#include <GLFW/glfw3.h>

#ifdef __APPLE__
extern "C" void SysMac_EndLaunch(void);
#endif

// =====================
// sys_IOpenGL Interface
// =====================

class sys_openGL_c: public sys_IOpenGL {
public:
	// Interface
	bool	Init(sys_glSet_s* set);
	bool	Shutdown();
	void	Swap();

	void*	GetProc(const char* name);

	// Encapsulated
	sys_openGL_c(sys_IMain* sysHnd);

	sys_main_c* sys;
#ifdef __APPLE__
	bool firstFrameDone = false;
#endif
};

sys_IOpenGL* sys_IOpenGL::GetHandle(sys_IMain* sysHnd)
{
	return new sys_openGL_c(sysHnd);
}

void sys_IOpenGL::FreeHandle(sys_IOpenGL* hnd)
{
	delete (sys_openGL_c*)hnd;
}

sys_openGL_c::sys_openGL_c(sys_IMain* sysHnd)
	: sys((sys_main_c*)sysHnd)
{
}

// ===================
// System OpenGL Class
// ===================

bool sys_openGL_c::Init(sys_glSet_s* set)
{
	// Set swap interval
	glfwSwapInterval(set->vsync ? 1 : 0);

	return false;
}

bool sys_openGL_c::Shutdown()
{
	return false;
}

void sys_openGL_c::Swap()
{
	glfwSwapBuffers((GLFWwindow*)sys->video->GetWindowHandle());
#ifdef __APPLE__
	// Cancel the Dock bounce on the first real rendered frame.
	// SysMac_BeginLaunch() was called during window creation so the icon
	// bounces throughout the Lua VM / asset loading phase.
	if (!firstFrameDone) {
		firstFrameDone = true;
		SysMac_EndLaunch();
	}
#endif
}

void* sys_openGL_c::GetProc(const char* name)
{
	return (void*)glfwGetProcAddress(name);
}
