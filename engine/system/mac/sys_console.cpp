// SimpleGraphic Engine
//
// Module: System Console
// Platform: macOS
//
// Writes engine output to stderr (visible in Terminal.app and Console.app).
// No GUI console window is created; the macOS app presents the main window only.
//

#include "../win/sys_local.h"

#include <chrono>
#include <iostream>
#include <thread>

// ======================
// sys_IConsole Interface
// ======================

class sys_console_c: public sys_IConsole, public conPrintHook_c, public thread_c {
public:
	// Interface
	void	SetVisible(bool show);
	bool	IsVisible();
	void	SetForeground();
	void	SetTitle(const char* title);

	// Encapsulated
	sys_console_c(sys_IMain* sysHnd);
	~sys_console_c();

	sys_main_c* sys = nullptr;

	volatile bool doRun;
	volatile bool isRunning;

	void	RunMessages(void* = nullptr);
	void	ThreadProc();

	void	Print(const char* text);

	void	ConPrintHook(const char* text);
	void	ConPrintClear();
};

sys_IConsole* sys_IConsole::GetHandle(sys_IMain* sysHnd)
{
	return new sys_console_c(sysHnd);
}

void sys_IConsole::FreeHandle(sys_IConsole* hnd)
{
	delete (sys_console_c*)hnd;
}

sys_console_c::sys_console_c(sys_IMain* sysHnd)
	: conPrintHook_c(sysHnd->con), sys((sys_main_c*)sysHnd), thread_c(sysHnd)
{
	isRunning = false;
	doRun = true;

	ThreadStart(true);
	while (!isRunning);
}

void sys_console_c::RunMessages(void*)
{}

void sys_console_c::ThreadProc()
{
	// Flush any messages created
	RunMessages();

	InstallPrintHook();

	isRunning = true;
	while (doRun) {
		RunMessages();
		sys->Sleep(1);
	}

	RemovePrintHook();

	isRunning = false;
}

sys_console_c::~sys_console_c()
{
	doRun = false;
	while (isRunning);
}

// ==============
// System Console
// ==============

void sys_console_c::SetVisible(bool show)
{}

void sys_console_c::SetForeground()
{}

bool sys_console_c::IsVisible()
{
	// macOS has no console window — return false so the idle detection in
	// ui_main_c::Frame() doesn't think a console is being displayed.
	return false;
}

void sys_console_c::SetTitle(const char* title)
{}

void sys_console_c::Print(const char* text)
{
	int escLen;

	// Compute the required buffer length (strip colour escapes)
	int len = 0;
	for (int b = 0; text[b]; b++) {
		if (text[b] == '\n') {
			len += 1;
		} else if ((escLen = IsColorEscape(&text[b]))) {
			b += escLen - 1;
		} else {
			len++;
		}
	}

	// Parse into the buffer
	char* stripped = AllocStringLen(len);
	char* p = stripped;
	for (int b = 0; text[b]; b++) {
		if (text[b] == '\n') {
			*(p++) = '\n';
		} else if ((escLen = IsColorEscape(&text[b]))) {
			b += escLen - 1;
		} else {
			*(p++) = text[b];
		}
	}

	// Write to stderr — visible in Terminal.app and Console.app
	std::cerr << stripped << std::flush;
	delete stripped;
}

void sys_console_c::ConPrintHook(const char* text)
{
	Print(text);
}

void sys_console_c::ConPrintClear()
{}
