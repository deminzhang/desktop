/*
 * xuandesk_native.c -- the in-process native half of XuanDesk.
 *
 * This is a pure-C GDExtension: it links against the interface header the
 * editor itself dumps (`godot --dump-gdextension-interface`), so it needs
 * neither godot-cpp nor scons. Build:
 *
 *   gcc -O2 -shared -Wall -Wextra -o <root>/xuandesk_native.dll xuandesk_native.c \
 *       -I <dir holding gdextension_interface.h> -luser32 -lshell32 -ladvapi32
 *
 * It is the planned replacement for the separate process bin/host.exe
 * (native/host.c): the same Win32 work, but running inside the Godot process
 * so there is no loopback TCP IPC, no command-line plumbing, no single-instance
 * mutex and no respawn logic.
 *
 * STAGE: gate 1 -- prove the DLL loads, the class registers, and GDScript can
 * call a static method and get a String / an int back. The Win32 port comes
 * next, function by function, against the inventory of native/host.c.
 */

/*
 * Windows headers come first, and the target version before those, on purpose:
 * <_mingw.h> is reached through <stdarg.h> and picks _WIN32_WINNT itself, and
 * <netioapi.h> only declares the interface-table API (MIB_IF_TABLE2 / GetIfTable2)
 * for the right target and with the winsock2 headers already in place. This is
 * host.c's exact include order, which is known good on this toolchain -- dropping
 * either half of it silently loses GetIfTable2 and with it the network metrics.
 */
#define WIN32_LEAN_AND_MEAN
#define _WIN32_WINNT 0x0601
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <shellapi.h>
#include <iphlpapi.h>
#include <netioapi.h>
#include <ipifcons.h>

#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "gdextension_interface.h"

/* ------------------------------------------------------------- the interface */

static GDExtensionClassLibraryPtr g_library = NULL;

static GDExtensionInterfaceGetProcAddress p_get_proc_address = NULL;

static GDExtensionInterfaceStringNameNewWithUtf8Chars p_string_name_new = NULL;
static GDExtensionInterfaceStringNewWithUtf8Chars p_string_new = NULL;
static GDExtensionInterfaceStringToUtf8Chars p_string_to_utf8 = NULL;
static GDExtensionInterfaceClassdbRegisterExtensionClass6 p_classdb_register_class = NULL;
static GDExtensionInterfaceClassdbUnregisterExtensionClass p_classdb_unregister_class = NULL;
static GDExtensionInterfaceClassdbRegisterExtensionClassMethod p_classdb_register_method = NULL;
static GDExtensionInterfacePrintError p_print_error = NULL;

/* Variant <-> raw converters. Cached once because every method call needs them
   when the caller comes through the Variant path (call_func) rather than the
   fast pointer path (ptrcall_func). */
static GDExtensionVariantFromTypeConstructorFunc ctor_string = NULL;
static GDExtensionVariantFromTypeConstructorFunc ctor_int = NULL;
static GDExtensionTypeFromVariantConstructorFunc to_string = NULL;
static GDExtensionTypeFromVariantConstructorFunc to_int = NULL;

/*
 * Opaque storage for the engine's String / StringName objects.
 *
 * extension_api.json reports these as 4 bytes in this build, which is smaller
 * than a pointer -- that is suspicious enough that I do not want to trust it.
 * Over-allocating is harmless (the engine writes its own size); under-allocating
 * corrupts the stack, so every one of these is one 8-byte slot, which is at
 * least as large as anything the engine can put there.
 */
typedef union {
	uint64_t u64;
	void *ptr;
	double dbl;
} name_store;

static name_store g_sn_class;      /* "XuanDeskNative" */
static name_store g_sn_parent;     /* "Object"         */
static name_store g_sn_ping;       /* "ping"           */
static name_store g_sn_add;        /* "add"            */
static name_store g_sn_info;       /* "info"           */
static name_store g_sn_ret;        /* "r"              */
static name_store g_sn_arg_a;      /* "a"              */
static name_store g_sn_arg_b;      /* "b"              */
static name_store g_sn_empty;      /* ""               */
static name_store g_sn_start;      /* "start"          */
static name_store g_sn_command;    /* "command"        */
static name_store g_sn_poll;       /* "poll"           */
static name_store g_sn_status;     /* "status"         */
/* "test" is declared inside the debug-only registration block below, so a release
 * build does not carry an unused StringName slot. */
static name_store g_sn_line;       /* "line"           */
static name_store g_sn_a1;         /* "hwnd_main"      */
static name_store g_sn_a2;         /* "hwnd_hud"       */
static name_store g_sn_a3;         /* "wallpaper"      */
static name_store g_sn_a4;         /* "interval_ms"    */
static name_store g_sn_a5;         /* "no_activate"    */
/*
 * hint_string is a `GDExtensionStringPtr` -- a real String, NOT a StringName.
 * The engine dereferences it, so it must never be NULL.
 */
static name_store g_hint_empty;

/*
 * Breadcrumb log. The extension runs inside the Godot process, which is
 * GUI-subsystem (so PowerShell cannot capture its stderr) and, under the DSH
 * sandbox, cannot have its stdout piped either. Writing our own file in the
 * project root is the only reliable channel while bringing this up.
 */
#ifdef XD_DEBUG_LOG
static void dbg(const char *fmt, ...) {
	FILE *f = fopen("E:/xuandesk/_gdext_init.log", "a");
	if (!f) {
		return;
	}
	va_list ap;
	va_start(ap, fmt);
	vfprintf(f, fmt, ap);
	va_end(ap);
	fputc('\n', f);
	fclose(f);
}
/* host.c's logging calls, kept verbatim so the ported code stays line-for-line
 * comparable with the original. Build with -DXD_DEBUG_LOG to arm this. */
#define logf_(...) dbg(__VA_ARGS__)
#else
#define dbg(...) ((void)0)
#define logf_(...) ((void)0)
#endif

/* Registration success is breadcrumb material, not an engine error: reporting it
 * through print_error puts a red "ERROR:" line in Godot's log for something that
 * went right. */

#define SN(slot, text) p_string_name_new((GDExtensionUninitializedStringNamePtr)&(slot), (text))

/* ------------------------------------------------------- value marshalling */

/*
 * The two paths Godot can take into an extension method:
 *
 *   call_func    -- arguments and the return value are Variants (this is what a
 *                   dynamic GDScript call uses);
 *   ptrcall_func -- arguments and the return value are raw native values.
 *
 * Both are provided so that whichever path the engine picks works. `id` is the
 * small integer we pass as method_userdata to tell the methods apart.
 */

enum {
	MID_PING = 1,
	MID_ADD = 2,
	MID_INFO = 3,
	MID_START = 4,
	MID_COMMAND = 5,
	MID_POLL = 6,
	MID_STATUS = 7,
	MID_TEST = 8,
};

/* The whole Win32 native side lives further down this file; these are the entry points
 * the dispatchers above need to see. */
static void handle_command(const char *line);
static int xd_start(HWND main_hwnd, HWND hud_hwnd, int wallpaper, int interval_ms,
		int no_activate);
static const char *xd_poll(void);
static const char *xd_status(void);
static const char *xd_test(int which, int arg);
static int g_cmd_quit;

/* Build a String into raw storage, then hand it to the Variant return slot. */
static void call_return_string(GDExtensionVariantPtr r_return, const char *utf8) {
	name_store tmp;
	memset(&tmp, 0, sizeof tmp);
	p_string_new((GDExtensionUninitializedStringPtr)&tmp, utf8);
	ctor_string(r_return, (GDExtensionTypePtr)&tmp);
}

static void call_return_int(GDExtensionVariantPtr r_return, int64_t value) {
	ctor_int(r_return, (GDExtensionTypePtr)&value);
}

static int64_t call_arg_int(const GDExtensionConstVariantPtr *p_args, GDExtensionInt i) {
	int64_t out = 0;
	to_int((GDExtensionTypePtr)&out, (GDExtensionVariantPtr)p_args[i]);
	return out;
}

/* String -> UTF-8 in a fixed buffer.
 *
 * The engine's own accessor is easy to get wrong in two ways at once, and this code
 * had both. gdextension_interface.h says of string_to_utf8_chars "It doesn't write a
 * null terminator", and p_max_write_length counts *characters* while the buffer is
 * bytes (one character can be four of them).
 *
 * Trusting a terminator that is never written means the caller reads whatever was on
 * the stack next: measured 2026-10-16, a tray row whose text is 17 bytes long came back
 * 22 bytes long, and MultiByteToWideChar turned those four stray bytes into U+FFFD -
 * the 乱码 the user saw after a Chinese label in the 换桌面 submenu. The
 * character-counted limit could also write four times the buffer for a CJK line.
 *
 * So clear the buffer first, then let the engine write at most (cap-1)/4 characters
 * (at most cap-1 bytes), and let the clear be the terminator. A cut is still possible
 * but lands on a character boundary; callers that copy further trim it. */
static void string_to_utf8_bounded(GDExtensionConstStringPtr p_self, char *dst, size_t cap) {
	if (cap == 0) return;
	memset(dst, 0, cap);
	if (!p_string_to_utf8) return;
	GDExtensionInt max_chars = (GDExtensionInt)((cap - 1) / 4);
	if (max_chars <= 0) return;
	p_string_to_utf8(p_self, dst, max_chars);
}

static void call_arg_string(const GDExtensionConstVariantPtr *p_args, GDExtensionInt i, char *dst, size_t cap) {
	name_store tmp;
	memset(&tmp, 0, sizeof tmp);
	to_string((GDExtensionTypePtr)&tmp, (GDExtensionVariantPtr)p_args[i]);
	/* String -> utf8 through the engine's own accessor */
	string_to_utf8_bounded((GDExtensionConstStringPtr)&tmp, dst, cap);
}

static void method_call(void *method_userdata, GDExtensionClassInstancePtr p_instance,
		const GDExtensionConstVariantPtr *p_args, GDExtensionInt p_argument_count,
		GDExtensionVariantPtr r_return, GDExtensionCallError *r_error) {
	(void)p_instance;
	dbg("  >> method_call  id=%d argc=%d", (int)(intptr_t)method_userdata, (int)p_argument_count);
	r_error->error = GDEXTENSION_CALL_OK;
	r_error->argument = 0;
	r_error->expected = 0;

	switch ((int)(intptr_t)method_userdata) {
		case MID_PING:
			call_return_string(r_return, "xuandesk-native: gate 1 alive");
			break;
		case MID_ADD: {
			if (p_argument_count < 2) {
				r_error->error = GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS;
				r_error->expected = 2;
				return;
			}
			call_return_int(r_return, call_arg_int(p_args, 0) + call_arg_int(p_args, 1));
		} break;
		case MID_INFO: {
			char who[64];
			if (p_argument_count < 1) {
				r_error->error = GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS;
				r_error->expected = 1;
				return;
			}
			call_arg_string(p_args, 0, who, sizeof who);
			char out[160];
			snprintf(out, sizeof out, "hello %s from inside the Godot process", who);
			call_return_string(r_return, out);
		} break;
		case MID_START: {
			if (p_argument_count < 5) {
				r_error->error = GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS;
				r_error->expected = 5;
				return;
			}
			xd_start((HWND)(intptr_t)call_arg_int(p_args, 0),
					(HWND)(intptr_t)call_arg_int(p_args, 1),
					(int)call_arg_int(p_args, 2), (int)call_arg_int(p_args, 3),
					(int)call_arg_int(p_args, 4));
			call_return_string(r_return, xd_status());
		} break;
		case MID_COMMAND: {
			char line[512];
			if (p_argument_count < 1) {
				r_error->error = GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS;
				r_error->expected = 1;
				return;
			}
			call_arg_string(p_args, 0, line, sizeof line);
			handle_command(line);
			call_return_string(r_return, g_cmd_quit ? "quit" : "");
		} break;
		case MID_POLL:
			call_return_string(r_return, xd_poll());
			break;
		case MID_STATUS:
			call_return_string(r_return, xd_status());
			break;
		case MID_TEST: {
			if (p_argument_count < 2) {
				r_error->error = GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS;
				r_error->expected = 2;
				return;
			}
			call_return_string(r_return,
					xd_test((int)call_arg_int(p_args, 0), (int)call_arg_int(p_args, 1)));
		} break;
		default:
			r_error->error = GDEXTENSION_CALL_ERROR_INVALID_METHOD;
			break;
	}
}

static void method_ptrcall(void *method_userdata, GDExtensionClassInstancePtr p_instance,
		const GDExtensionConstTypePtr *p_args, GDExtensionTypePtr r_ret) {
	(void)p_instance;
	dbg("  >> method_ptrcall id=%d", (int)(intptr_t)method_userdata);
	switch ((int)(intptr_t)method_userdata) {
		case MID_PING:
			p_string_new((GDExtensionUninitializedStringPtr)r_ret, "xuandesk-native: gate 1 alive");
			break;
		case MID_ADD: {
			int64_t a = *(const int64_t *)p_args[0];
			int64_t b = *(const int64_t *)p_args[1];
			*(int64_t *)r_ret = a + b;
		} break;
		case MID_INFO: {
			char who[64];
			string_to_utf8_bounded((GDExtensionConstStringPtr)p_args[0], who, sizeof who);
			char out[160];
			snprintf(out, sizeof out, "hello %s from inside the Godot process", who);
			p_string_new((GDExtensionUninitializedStringPtr)r_ret, out);
		} break;
		case MID_START:
			xd_start((HWND)(intptr_t) * (const int64_t *)p_args[0],
					(HWND)(intptr_t) * (const int64_t *)p_args[1],
					(int)*(const int64_t *)p_args[2], (int)*(const int64_t *)p_args[3],
					(int)*(const int64_t *)p_args[4]);
			p_string_new((GDExtensionUninitializedStringPtr)r_ret, xd_status());
			break;
		case MID_COMMAND: {
			char line[512];
			string_to_utf8_bounded((GDExtensionConstStringPtr)p_args[0], line, sizeof line);
			handle_command(line);
			p_string_new((GDExtensionUninitializedStringPtr)r_ret, g_cmd_quit ? "quit" : "");
		} break;
		case MID_POLL:
			p_string_new((GDExtensionUninitializedStringPtr)r_ret, xd_poll());
			break;
		case MID_STATUS:
			p_string_new((GDExtensionUninitializedStringPtr)r_ret, xd_status());
			break;
		case MID_TEST:
			p_string_new((GDExtensionUninitializedStringPtr)r_ret,
					xd_test((int)*(const int64_t *)p_args[0],
							(int)*(const int64_t *)p_args[1]));
			break;
		default:
			break;
	}
}

/* ============================================================================
 * The Win32 native side, ported from native/host.c.
 *
 * Everything below is host.c's work moved inside the Godot process. What changed,
 * and only what had to:
 *
 *   - window discovery by PID + title prefix is gone (README G7): GDScript hands
 *     us the two HWNDs, so g_main_hwnd/g_overlay_hwnd are parameters;
 *   - the loopback socket is gone: incoming lines arrive through command(), and
 *     the frame that used to be socket-sent is returned by poll();
 *   - the hotkey/sample/housekeeping schedule is driven by poll() instead of a
 *     private loop, so GDScript's frame rate paces us now;
 *   - logf_() writes to the breadcrumb log instead of host.log.
 *
 * What deliberately did NOT change: the WS_CHILD-before-SetParent dance, the
 * never-SWP_FRAMECHANGED rule, the tray's window class and popup, the command
 * grammar (the client still speaks "menu bg ..." lines) and the JSON frame's field
 * names, so metrics.gd's parser survives the merge untouched.
 *
 * WorkerW belongs to Explorer, so SetParent stays CROSS-PROCESS even now: having the
 * native side inside Godot removes the Godot<->native side boundary only, never the
 * Godot<->Explorer one. W5 therefore still applies in full.
 * ========================================================================== */

#define IDI_TRAY 1
#define TRAY_CALLBACK (WM_APP + 1)
#define TRAY_MAX_ITEMS 12
#define TRAY_LABEL 64              /* UTF-8 bytes; the widest label here is 11 */

#define CMD_QUIT 1
#define CMD_PASSTHROUGH 2
#define CMD_DESKTOP 3
#define CMD_PANEL 4
#define CMD_BG_BASE 100            /* + index: a 换桌面 row */
#define CMD_SCREEN_BASE 200        /* + index: a 显示器 row */

#define MAX_EVENTS 8

typedef struct {
	char id[32];
	char label[TRAY_LABEL];
	int current;
} tray_item;

/* ---------------------------------------------------------- native side state */

static HWND g_main_hwnd = NULL;      /* the wallpaper window, from GDScript */
static HWND g_overlay_hwnd = NULL;   /* the HUD window, from GDScript */
static HWND g_worker = NULL;         /* the shell's wallpaper layer */
static int g_overlay_shown = 0;
/* Only used when GDScript did not hand us the handles. host.c matched by title
 * prefix because it was a different process; here the window titles are still the
 * cheapest fallback when DisplayServer hands back 0. */
static const char *g_title = "XuanDesk.Aquarium";
static const char *g_overlay_title = "XuanDesk.HUD";
static const char *g_wall_state = "off";
static int g_wall_shown = 1;
static int g_hud_shown = 1;
static int g_hud_locked = 0;
static int g_wallpaper = 1;
static int g_interval_ms = 1000;
static int g_no_activate = 1;
static int g_started = 0;
static ULONGLONG g_start_tick = 0;

static HWND g_tray_hwnd = NULL;
static HINSTANCE g_hinst = NULL;
static UINT g_taskbar_created = 0;
static int g_tray_added = 0;
/* Why NIM_ADD failed, kept for the status line: a Low-integrity process cannot send
 * the shell's tray messages at all (UIPI), which looks exactly like a code bug. */
static DWORD g_tray_err = 0;
static int g_icon_ok = 0;
static tray_item g_tray_bg[TRAY_MAX_ITEMS];
static int g_tray_bg_count = 0;
static tray_item g_tray_screens[TRAY_MAX_ITEMS];
static int g_tray_screen_count = 0;
static int g_tray_desk_row = 0;
static int g_tray_panel_row = 0;
static int g_tray_locked = 0;

/* Metric readouts. CPU / GPU / VRAM / temperature / network arrive with their own
 * increment; until then they report the same "no reading" sentinels host.c used
 * when NVML was missing (-1 / 0), so the frame shape is already final. */
static double g_cpu_last = -1.0;
static double g_rx_last = 0.0, g_tx_last = 0.0;
static unsigned long long g_seq = 0;
static int g_gpu_util = -1;
static int g_gpu_temp = -1;
static unsigned long long g_vram_used = 0, g_vram_total = 0;

static int g_frame_dirty = 0;
static char g_frame[2048];
static int g_cmd_quit = 0;

static ULONGLONG g_next_sample = 0, g_next_hotkey = 0, g_next_house = 0;

#define MAX_SCREENS 8
typedef struct {
	RECT rect;      /* virtual-screen coordinates */
	int primary;
} screen_t;

static screen_t g_screens[MAX_SCREENS];
static int g_screen_count = 0;
static int g_screen_index = 0;

static BOOL CALLBACK enum_screen_proc(HMONITOR monitor, HDC dc, LPRECT clip, LPARAM lp) {
	(void)dc;
	(void)clip;
	(void)lp;
	MONITORINFO info;
	info.cbSize = sizeof info;
	if (!GetMonitorInfoA(monitor, &info)) return TRUE;
	if (g_screen_count >= MAX_SCREENS) return FALSE;
	g_screens[g_screen_count].rect = info.rcMonitor;
	g_screens[g_screen_count].primary =
			(info.dwFlags & MONITORINFOF_PRIMARY) ? 1 : 0;
	g_screen_count++;
	return TRUE;
}

/* Primary first, then left to right: the client's list has one order and it does
 * not move when a monitor is unplugged and plugged back in. Runs at startup and
 * with the housekeeping pass, so a monitor appearing or going away is followed
 * without a restart - and it only says so in the log when it changed. */
static void enumerate_screens(void) {
	screen_t previous[MAX_SCREENS];
	int previous_count = g_screen_count;
	for (int i = 0; i < previous_count; i++) previous[i] = g_screens[i];

	g_screen_count = 0;
	EnumDisplayMonitors(NULL, NULL, enum_screen_proc, 0);
	for (int i = 0; i < g_screen_count; i++) {
		for (int j = i + 1; j < g_screen_count; j++) {
			int swap = g_screens[j].primary > g_screens[i].primary;
			if (!swap && g_screens[j].primary == g_screens[i].primary)
				swap = g_screens[j].rect.left < g_screens[i].rect.left;
			if (!swap) continue;
			screen_t tmp = g_screens[i];
			g_screens[i] = g_screens[j];
			g_screens[j] = tmp;
		}
	}
	if (g_screen_count == 0) {
		/* never leave the list empty: one screen with the primary's size */
		g_screens[0].rect.left = 0;
		g_screens[0].rect.top = 0;
		g_screens[0].rect.right = GetSystemMetrics(SM_CXSCREEN);
		g_screens[0].rect.bottom = GetSystemMetrics(SM_CYSCREEN);
		g_screens[0].primary = 1;
		g_screen_count = 1;
	}
	/* The list can change under us. Keep the client on the monitor it picked by
	 * its geometry when that geometry is still there, and clamp otherwise - a
	 * wallpaper that vanishes because its monitor went away is worse than one that
	 * falls back to the primary. */
	if (previous_count > 0) {
		RECT want = previous[g_screen_index < previous_count ? g_screen_index : 0].rect;
		int found = -1;
		for (int i = 0; i < g_screen_count; i++) {
			if (g_screens[i].rect.left == want.left && g_screens[i].rect.top == want.top)
				found = i;
		}
		if (found >= 0) g_screen_index = found;
		else if (g_screen_index >= g_screen_count) g_screen_index = 0;
	}
	if (g_screen_index >= g_screen_count) g_screen_index = 0;

	int changed = g_screen_count != previous_count;
	for (int i = 0; !changed && i < g_screen_count; i++) {
		if (g_screens[i].rect.left != previous[i].rect.left
				|| g_screens[i].rect.top != previous[i].rect.top
				|| g_screens[i].rect.right != previous[i].rect.right
				|| g_screens[i].rect.bottom != previous[i].rect.bottom)
			changed = 1;
	}
	if (!changed) return;
	for (int i = 0; i < g_screen_count; i++) {
		logf_("screen %d: %d,%d %dx%d%s%s", i, g_screens[i].rect.left,
				g_screens[i].rect.top, g_screens[i].rect.right - g_screens[i].rect.left,
				g_screens[i].rect.bottom - g_screens[i].rect.top,
				g_screens[i].primary ? " (primary)" : "",
				i == g_screen_index ? " <- desktop" : "");
	}
}

static int overlap_area(const RECT *a, const RECT *b) {
	int w = (a->right < b->right ? a->right : b->right)
			- (a->left > b->left ? a->left : b->left);
	int h = (a->bottom < b->bottom ? a->bottom : b->bottom)
			- (a->top > b->top ? a->top : b->top);
	if (w <= 0 || h <= 0) return 0;
	return w * h;
}

/* Forward declarations: the command grammar below drives these. */
static void apply_wallpaper(void);
static void apply_overlay(void);

/* --------------------------------------------------------------- 事件队列 */

static const char *g_events[MAX_EVENTS];
/* Room for the events that carry a payload - the tray's rows: "menu background
 * sky", "menu screen 1". Literal events keep pointing at their own string;
 * g_events[i] is either. */
static char g_event_text[MAX_EVENTS][64];
static int g_event_count = 0;

static void push_event(const char *name) {
	if (g_event_count < MAX_EVENTS) g_events[g_event_count++] = name;
}

static void push_eventf(const char *fmt, ...) {
	if (g_event_count >= MAX_EVENTS) return;
	char *slot = g_event_text[g_event_count];
	va_list ap;
	va_start(ap, fmt);
	vsnprintf(slot, sizeof g_event_text[0], fmt, ap);
	va_end(ap);
	g_events[g_event_count++] = slot;
}

/* What a tray row produced has to go out on the next poll(), not with the next
 * sample tick: the answer to a click should not wait up to a second. */
static void flush_events(void) {
	if (g_event_count > 0) g_frame_dirty = 1;
}

/* ------------------------------------------------------------------ hotkeys */

static void poll_hotkeys(void) {
	static int h_down = 0, t_down = 0, q_down = 0;
	int ctrl = (GetAsyncKeyState(VK_CONTROL) & 0x8000) != 0;
	int alt = (GetAsyncKeyState(VK_MENU) & 0x8000) != 0;
	int combo = ctrl && alt;
	int h = combo && (GetAsyncKeyState('H') & 0x8000) != 0;
	int t = combo && (GetAsyncKeyState('T') & 0x8000) != 0;
	int q = combo && (GetAsyncKeyState('Q') & 0x8000) != 0;
	if (h && !h_down) push_event("toggle_desktop");
	if (t && !t_down) push_event("toggle_clickthrough");
	if (q && !q_down) push_event("quit");
	h_down = h;
	t_down = t;
	q_down = q;
}

/* ---------------------------------------------------------------------- tray */

static void to_wide(const char *src, WCHAR *dst, int cch) {
	int n = MultiByteToWideChar(CP_UTF8, 0, src, -1, dst, cch);
	if (n <= 0) {
		dst[0] = 0;
		return;
	}
	dst[cch - 1] = 0;
}

/* Whitespace-delimited token, copied out; returns the rest of the line. */
static const char *next_token(const char *p, char *out, int out_size) {
	while (*p == ' ' || *p == '\t') p++;
	const char *start = p;
	while (*p && *p != ' ' && *p != '\t') p++;
	int n = (int)(p - start);
	if (n > out_size - 1) n = out_size - 1;
	memcpy(out, start, (size_t)n);
	out[n] = 0;
	return p;
}

/* copy_str cuts by bytes, and a cut in the middle of a UTF-8 character is a
 * mojibake in the menu, so an *incomplete* trailing character is dropped - only an
 * incomplete one. Every character above ASCII ends in a continuation byte, so
 * "drop the trailing continuation bytes" ate the last character of every Chinese
 * label and left its dangling lead byte behind (用户 "换桌面的菜单项尾部有乱码" -
 * 水族箱 came out as 水族 + one stray byte). So measure the character the tail
 * belongs to and drop it whole only when the string ends before its last byte. */
static void trim_utf8(char *s) {
	int n = (int)strlen(s);
	int i = n;
	while (i > 0 && ((unsigned char)s[i - 1] & 0xC0) == 0x80) i--;  /* back to its lead byte */
	if (i == 0) {   /* nothing but continuation bytes: no character to keep */
		s[0] = 0;
		return;
	}
	unsigned char lead = (unsigned char)s[i - 1];
	int want = 1;                         /* ASCII (and anything invalid) is one byte */
	if ((lead & 0xE0) == 0xC0) want = 2;
	else if ((lead & 0xF0) == 0xE0) want = 3;
	else if ((lead & 0xF8) == 0xF0) want = 4;
	if (i - 1 + want > n) s[i - 1] = 0;   /* the cut split it: the whole character goes */
}

/* Bounded copy: whatever does not fit is cut, and the caller trims the cut. */
static void copy_str(char *dst, int cch, const char *src) {
	int n = (int)strlen(src);
	if (n > cch - 1) n = cch - 1;
	memcpy(dst, src, (size_t)n);
	dst[n] = 0;
}

/* ------------------------------------------------------- the client's model */

static void tray_reset_model(void) {
	g_tray_bg_count = 0;
	g_tray_screen_count = 0;
	memset(g_tray_bg, 0, sizeof g_tray_bg);
	memset(g_tray_screens, 0, sizeof g_tray_screens);
}

/* One row: "<index> <current> [<id> ]<label>" - everything left after the id (or
 * after <current>, for a row that has none) is the label, spaces and all. */
static void tray_set_item(const char *rest, int has_id, tray_item *list, int *count) {
	char tok[64];
	rest = next_token(rest, tok, sizeof tok);
	int index = atoi(tok);
	rest = next_token(rest, tok, sizeof tok);
	int current = atoi(tok);
	if (index < 0 || index >= TRAY_MAX_ITEMS) return;
	tray_item *item = &list[index];
	memset(item, 0, sizeof *item);
	if (has_id) {
		rest = next_token(rest, tok, sizeof tok);
		copy_str(item->id, (int)sizeof item->id, tok);
	}
	while (*rest == ' ' || *rest == '\t') rest++;
	copy_str(item->label, (int)sizeof item->label, rest);
	trim_utf8(item->label);
	/* The label with its byte length: a menu that comes out wrong is nearly always a
	   label that arrived wrong, and this is where that is visible. */
	logf_("menu item[%d] label %d B: %s", index, (int)strlen(item->label), item->label);
	item->current = current;
	if (index + 1 > *count) *count = index + 1;
}

/* --------------------------------------------------------------- the popup */

/* A row the user picked: the client answers it, over the same event channel a
 * hotkey uses - the tray is a second keyboard, not a second brain. */
static void tray_command(int cmd) {
	if (cmd == CMD_QUIT) {
		logf_("tray: quit");
		push_event("quit");
	} else if (cmd == CMD_PASSTHROUGH) {
		logf_("tray: passthrough");
		push_event("toggle_clickthrough");
	} else if (cmd == CMD_DESKTOP) {
		logf_("tray: desktop");
		push_event("toggle_desktop");
	} else if (cmd == CMD_PANEL) {
		logf_("tray: panel");
		push_event("toggle_panel");
	} else if (cmd >= CMD_SCREEN_BASE) {
		int i = cmd - CMD_SCREEN_BASE;
		if (i >= g_tray_screen_count) return;
		logf_("tray: screen %d", i);
		push_eventf("menu screen %d", i);
	} else if (cmd >= CMD_BG_BASE) {
		int i = cmd - CMD_BG_BASE;
		if (i >= g_tray_bg_count) return;
		logf_("tray: background %s", g_tray_bg[i].id);
		push_eventf("menu background %s", g_tray_bg[i].id);
	} else {
		return;                    /* dismissed, or nothing picked */
	}
	flush_events();
}

static void tray_append_items(HMENU menu, tray_item *list, int count, int base) {
	for (int i = 0; i < count; i++) {
		WCHAR label[256];
		to_wide(list[i].label, label, 256);
		AppendMenuW(menu, MF_STRING | (list[i].current ? MF_CHECKED : 0), base + i, label);
	}
}

static void tray_show_menu(void) {
	HMENU menu = CreatePopupMenu();
	if (!menu) return;

	if (g_tray_bg_count > 0) {
		HMENU backgrounds = CreatePopupMenu();
		tray_append_items(backgrounds, g_tray_bg, g_tray_bg_count, CMD_BG_BASE);
		AppendMenuW(menu, MF_POPUP, (UINT_PTR)backgrounds, L"换桌面");
	}
	/* One monitor is not a choice: the whole row goes, and so does this submenu. */
	if (g_tray_screen_count > 1) {
		HMENU screens = CreatePopupMenu();
		tray_append_items(screens, g_tray_screens, g_tray_screen_count, CMD_SCREEN_BASE);
		AppendMenuW(menu, MF_POPUP, (UINT_PTR)screens, L"显示器");
	}
	AppendMenuW(menu, MF_SEPARATOR, 0, NULL);
	AppendMenuW(menu, MF_STRING | (g_tray_locked ? MF_CHECKED : 0), CMD_PASSTHROUGH,
			L"穿透");
	if (g_tray_desk_row) {
		AppendMenuW(menu, MF_STRING | (g_wall_shown ? MF_CHECKED : 0), CMD_DESKTOP,
				L"桌面");
	}
	if (g_tray_panel_row) {
		AppendMenuW(menu, MF_STRING | (g_hud_shown ? MF_CHECKED : 0), CMD_PANEL,
				L"面板");
	}
	AppendMenuW(menu, MF_SEPARATOR, 0, NULL);
	AppendMenuW(menu, MF_STRING, CMD_QUIT, L"退出");

	POINT pt;
	GetCursorPos(&pt);
	/* The foreground dance TrackPopupMenu needs: without the foreground window the
	   menu stays up when the user clicks elsewhere, and without the trailing WM_NULL
	   the next open can be swallowed. The window is hidden, so this shows nothing
	   and takes nothing from the user. */
	SetForegroundWindow(g_tray_hwnd);
	int cmd = (int)TrackPopupMenuEx(menu, TPM_RIGHTBUTTON | TPM_RETURNCMD | TPM_NONOTIFY,
			pt.x, pt.y, g_tray_hwnd, NULL);
	PostMessageW(g_tray_hwnd, WM_NULL, 0, 0);
	DestroyMenu(menu);
	tray_command(cmd);
}

/* ------------------------------------------------------------------- the icon */

static void tray_fill_nid(NOTIFYICONDATAW *nid) {
	memset(nid, 0, sizeof *nid);
	nid->cbSize = sizeof *nid;
	nid->hWnd = g_tray_hwnd;
	nid->uID = IDI_TRAY;
	nid->uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
	nid->uCallbackMessage = TRAY_CALLBACK;
	nid->hIcon = LoadIconW(g_hinst, MAKEINTRESOURCEW(IDI_TRAY));
	/* MAKEINTRESOURCE is typed for the ANSI call in this TU: cast it back */
	if (!nid->hIcon) nid->hIcon = LoadIconW(NULL, (LPCWSTR)IDI_APPLICATION);
	g_icon_ok = nid->hIcon != NULL;
	to_wide("玄桌面 XuanDesk", nid->szTip,
			(int)(sizeof nid->szTip / sizeof nid->szTip[0]));
}

static void tray_add(void) {
	if (g_tray_added || !g_tray_hwnd) return;
	NOTIFYICONDATAW nid;
	tray_fill_nid(&nid);
	if (Shell_NotifyIconW(NIM_ADD, &nid)) {
		g_tray_added = 1;
		logf_("tray icon added");
	} else {
		g_tray_err = GetLastError();
		logf_("tray icon NOT added (Shell_NotifyIcon error %lu)", g_tray_err);
	}
}

static LRESULT CALLBACK tray_wnd_proc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
	(void)wp;
	if (msg == TRAY_CALLBACK) {
		/* The default notification version: lParam *is* the mouse message (version 4
		   packs the cursor position into it instead). Either button opens the menu -
		   there is nothing else a click on this icon can mean. */
		if (lp == WM_RBUTTONUP || lp == WM_LBUTTONUP || lp == WM_CONTEXTMENU)
			tray_show_menu();
		return 0;
	}
	if (g_taskbar_created && msg == g_taskbar_created) {
		/* Explorer restarted and took every icon with it: put ours back. */
		logf_("taskbar recreated, re-adding the tray icon");
		g_tray_added = 0;
		tray_add();
		return 0;
	}
	return DefWindowProcW(hwnd, msg, wp, lp);
}

static void tray_create(void) {
	WNDCLASSEXW wc;
	memset(&wc, 0, sizeof wc);
	wc.cbSize = sizeof wc;
	wc.lpfnWndProc = tray_wnd_proc;
	wc.hInstance = g_hinst;
	wc.lpszClassName = L"XuanDeskTray";
	if (!RegisterClassExW(&wc)) {
		logf_("tray: RegisterClassExW failed (%lu)", GetLastError());
		return;
	}
	/* Never shown, and deliberately without WS_EX_NOACTIVATE: it has to be able to
	   become the foreground window for the menu to dismiss on a click away. */
	g_tray_hwnd = CreateWindowExW(0, L"XuanDeskTray", L"XuanDesk tray", 0, 0, 0, 0, 0,
			NULL, NULL, g_hinst, NULL);
	if (!g_tray_hwnd) {
		logf_("tray: CreateWindowExW failed (%lu)", GetLastError());
		return;
	}
	g_taskbar_created = RegisterWindowMessageW(L"TaskbarCreated");
	logf_("tray window %p", (void *)g_tray_hwnd);
	tray_add();
}

/* One turn of our own message queue. Filtered to the tray window on purpose: it
 * never touches a message belonging to Godot, so it is safe to run inside Godot's
 * main thread even though Godot has a pump of its own. This is also what makes us
 * independent of that pump -- headless, or inside a nested modal loop, the icon's
 * callbacks still get dispatched. */
static void tray_pump(void) {
	if (!g_tray_hwnd) return;
	MSG msg;
	while (PeekMessageW(&msg, g_tray_hwnd, 0, 0, PM_REMOVE)) {
		TranslateMessage(&msg);
		DispatchMessageW(&msg);
	}
}

/* ---------------------------------------------------------------- commands */

/* The client's own lines, one per call - the grammar is host.c's, unchanged:
 *   quit                            stop the app (the client acts on it)
 *   wall 0|1                        show/hide the 3D desktop
 *   screen <n>                      put the 3D desktop on monitor n
 *   lock 0|1                        whether the HUD passes the mouse through (穿透)
 *   hud 0|1                         show/hide the HUD window (the 面板 switch)
 *   menu reset                      forget the tray model; the rows below refill it
 *   menu bg <i> <cur> <id> <label>  a 换桌面 row
 *   menu screen <i> <cur> <label>   a 显示器 row (only drawn when there are 2+)
 *   menu desk 0|1                   whether the 桌面 row exists at all
 *   menu panel 0|1                  whether the 面板 row exists at all
 *   menu locked 0|1                 whether 穿透 is locked (the row's tick)
 */
static void handle_command(const char *line) {
	if (!strncmp(line, "quit", 4)) {
		logf_("quit requested by client");
		g_cmd_quit = 1;
	} else if (!strncmp(line, "wall ", 5)) {
		/* The client's 桌面 switch: only meaningful while this process is wearing
		   the desktop layer, so wallpaper=0 makes it a no-op. */
		if (g_wallpaper) {
			g_wall_shown = line[5] != '0';
			logf_("desktop %s by client request", g_wall_shown ? "shown" : "hidden");
			apply_wallpaper();
		}
	} else if (!strncmp(line, "lock ", 5)) {
		/* The client's 穿透 switch: the HUD window goes transparent to the mouse. */
		int locked = line[5] != '0';
		if (locked != g_hud_locked) {
			g_hud_locked = locked;
			logf_("hud mouse passthrough %s by client request", locked ? "on" : "off");
		}
		apply_overlay();
	} else if (!strncmp(line, "hud ", 4)) {
		/* The client's 面板 switch: the HUD window leaves the screen and comes back.
		   The window is this side's to show and hide like the wallpaper is, and the
		   tray's 面板 row reads the flag back. */
		int shown = line[4] != '0';
		if (shown != g_hud_shown) {
			g_hud_shown = shown;
			logf_("panel %s by client request", shown ? "shown" : "hidden");
		}
		apply_overlay();
	} else if (!strncmp(line, "screen ", 7)) {
		/* Which monitor the 3D desktop is on. The list is the one enumerated at
		   startup and refreshed by housekeeping, so an index the client sent against
		   a stale list is clamped rather than trusted. */
		int want = atoi(line + 7);
		if (want < 0 || want >= g_screen_count) want = 0;
		if (want != g_screen_index) {
			logf_("desktop screen %d -> %d by client request", g_screen_index, want);
			g_screen_index = want;
			if (g_wallpaper) apply_wallpaper();
		}
	} else if (!strncmp(line, "menu ", 5)) {
		const char *rest = line + 5;
		if (!strncmp(rest, "reset", 5)) {
			tray_reset_model();
		} else if (!strncmp(rest, "bg ", 3)) {
			tray_set_item(rest + 3, 1, g_tray_bg, &g_tray_bg_count);
		} else if (!strncmp(rest, "screen ", 7)) {
			tray_set_item(rest + 7, 0, g_tray_screens, &g_tray_screen_count);
		} else if (!strncmp(rest, "desk ", 5)) {
			g_tray_desk_row = atoi(rest + 5) != 0;
		} else if (!strncmp(rest, "panel ", 6)) {
			g_tray_panel_row = atoi(rest + 6) != 0;
		} else if (!strncmp(rest, "locked ", 7)) {
			g_tray_locked = atoi(rest + 7) != 0;
		}
	}
}

/* --------------------------------------------------------------- json frame */

/* Bounded append: snprintf reports the length it *would* have written, so a
 * truncated frame would otherwise walk the offset past the buffer. */
static int sb_add(char *buf, int cap, int n, const char *fmt, ...) {
	if (n < 0) n = 0;
	if (n >= cap - 1) return n;
	va_list ap;
	va_start(ap, fmt);
	int w = vsnprintf(buf + n, (size_t)(cap - n), fmt, ap);
	va_end(ap);
	if (w < 0) return n;
	return (n + w >= cap) ? cap - 1 : n + w;
}

/* host.c's send_frame, writing into a buffer instead of a socket. The field names
 * are the wire format metrics.gd already parses; do not rename one without the
 * other. */
static const char *build_frame(void) {
	MEMORYSTATUSEX ms;
	ms.dwLength = sizeof ms;
	GlobalMemoryStatusEx(&ms);

	char *buf = g_frame;
	const int cap = (int)sizeof g_frame;
	int n = 0;
	n = sb_add(buf, cap, n,
			"{\"seq\":%llu,\"cpu\":%.1f,\"mem_used\":%llu,\"mem_total\":%llu,"
			"\"gpu\":%d,\"vram_used\":%llu,\"vram_total\":%llu,\"gpu_temp\":%d,"
			"\"net_rx\":%.0f,\"net_tx\":%.0f,\"up\":%llu,\"wall\":\"%s\",\"screen\":%d,\"screens\":[",
			(unsigned long long)++g_seq, g_cpu_last,
			(unsigned long long)(ms.ullTotalPhys - ms.ullAvailPhys),
			(unsigned long long)ms.ullTotalPhys,
			g_gpu_util,
			g_vram_used / (1024ull * 1024ull), g_vram_total / (1024ull * 1024ull),
			g_gpu_temp,
			g_rx_last, g_tx_last,
			(unsigned long long)((GetTickCount64() - g_start_tick) / 1000ull),
			g_wall_state, g_screen_index);
	for (int i = 0; i < g_screen_count; i++) {
		n = sb_add(buf, cap, n,
				"%s{\"w\":%d,\"h\":%d,\"x\":%d,\"y\":%d,\"primary\":%d}", i ? "," : "",
				(int)(g_screens[i].rect.right - g_screens[i].rect.left),
				(int)(g_screens[i].rect.bottom - g_screens[i].rect.top),
				(int)g_screens[i].rect.left, (int)g_screens[i].rect.top,
				g_screens[i].primary);
	}
	n = sb_add(buf, cap, n, "],\"ev\":[");
	for (int i = 0; i < g_event_count; i++) {
		n = sb_add(buf, cap, n, "%s\"%s\"", i ? "," : "", g_events[i]);
	}
	n = sb_add(buf, cap, n, "]}");
	g_event_count = 0;
	return g_frame;
}

/* -------------------------------------------------------- wallpaper / overlay */

/* ------------------------------------------------------------------ metrics */

typedef struct {
	ULONGLONG idle, kernel, user;
} cpu_sample;

static cpu_sample g_cpu_prev;
static int g_cpu_primed = 0;
static ULONGLONG g_net_rx_prev = 0, g_net_tx_prev = 0;
static int g_net_primed = 0;

static double sample_cpu(void) {
	FILETIME i, k, u;
	if (!GetSystemTimes(&i, &k, &u)) return -1.0;
	cpu_sample cur;
	cur.idle = ((ULONGLONG)i.dwHighDateTime << 32) | i.dwLowDateTime;
	cur.kernel = ((ULONGLONG)k.dwHighDateTime << 32) | k.dwLowDateTime;
	cur.user = ((ULONGLONG)u.dwHighDateTime << 32) | u.dwLowDateTime;
	if (!g_cpu_primed) {
		g_cpu_prev = cur;
		g_cpu_primed = 1;
		return 0.0;
	}
	ULONGLONG d_idle = cur.idle - g_cpu_prev.idle;
	ULONGLONG d_kernel = cur.kernel - g_cpu_prev.kernel;
	ULONGLONG d_user = cur.user - g_cpu_prev.user;
	g_cpu_prev = cur;
	ULONGLONG total = d_kernel + d_user; /* kernel time already contains idle */
	if (total == 0) return 0.0;
	double busy = (double)(total - d_idle) * 100.0 / (double)total;
	if (busy < 0.0) busy = 0.0;
	if (busy > 100.0) busy = 100.0;
	return busy;
}

static void sample_net(double dt, double *rx, double *tx) {
	*rx = 0.0;
	*tx = 0.0;
	PMIB_IF_TABLE2 table = NULL;
	if (GetIfTable2(&table) != NO_ERROR || !table) return;
	ULONGLONG rx_total = 0, tx_total = 0;
	for (ULONG i = 0; i < table->NumEntries; i++) {
		MIB_IF_ROW2 *row = &table->Table[i];
		if (row->Type == IF_TYPE_SOFTWARE_LOOPBACK) continue;
		if (row->OperStatus != IfOperStatusUp) continue;
		if (row->MediaConnectState == MediaConnectStateDisconnected) continue;
		rx_total += row->InOctets;
		tx_total += row->OutOctets;
	}
	FreeMibTable(table);
	if (g_net_primed && dt > 0.0) {
		*rx = (double)(rx_total - g_net_rx_prev) / dt;
		*tx = (double)(tx_total - g_net_tx_prev) / dt;
		if (*rx < 0.0) *rx = 0.0;
		if (*tx < 0.0) *tx = 0.0;
	}
	g_net_rx_prev = rx_total;
	g_net_tx_prev = tx_total;
	g_net_primed = 1;
}

/* NVML is loaded dynamically so the binary has no hard driver dependency. */
typedef struct {
	unsigned int gpu;
	unsigned int memory;
} nvml_util_t;
typedef struct {
	unsigned long long total;
	unsigned long long free;
	unsigned long long used;
} nvml_mem_t;

typedef int (*nvml_init_fn)(void);
typedef int (*nvml_handle_fn)(unsigned int, void **);
typedef int (*nvml_util_fn)(void *, nvml_util_t *);
typedef int (*nvml_mem_fn)(void *, nvml_mem_t *);
typedef int (*nvml_temp_fn)(void *, int, unsigned int *);

static HMODULE g_nvml_dll = NULL;
static void *g_nvml_dev = NULL;
static nvml_util_fn p_nvml_util = NULL;
static nvml_mem_fn p_nvml_mem = NULL;
static nvml_temp_fn p_nvml_temp = NULL;
static int g_gpu_ok = 0;
static int g_nvml_ready = 0;
static char g_gpu_name[96] = "";

static int nvml_open(void) {
	g_nvml_dll = LoadLibraryA("nvml.dll");
	if (!g_nvml_dll) {
		logf_("nvml.dll not available - GPU metrics disabled");
		return 0;
	}
	nvml_init_fn init = (nvml_init_fn)(void *)GetProcAddress(g_nvml_dll, "nvmlInit_v2");
	if (!init) init = (nvml_init_fn)(void *)GetProcAddress(g_nvml_dll, "nvmlInit");
	nvml_handle_fn handle = (nvml_handle_fn)(void *)GetProcAddress(g_nvml_dll, "nvmlDeviceGetHandleByIndex_v2");
	if (!handle) handle = (nvml_handle_fn)(void *)GetProcAddress(g_nvml_dll, "nvmlDeviceGetHandleByIndex");
	p_nvml_util = (nvml_util_fn)(void *)GetProcAddress(g_nvml_dll, "nvmlDeviceGetUtilizationRates");
	p_nvml_mem = (nvml_mem_fn)(void *)GetProcAddress(g_nvml_dll, "nvmlDeviceGetMemoryInfo");
	p_nvml_temp = (nvml_temp_fn)(void *)GetProcAddress(g_nvml_dll, "nvmlDeviceGetTemperature");
	if (!init || !handle || !p_nvml_util || !p_nvml_mem) return 0;
	if (init() != 0) return 0;
	if (handle(0, &g_nvml_dev) != 0) return 0;
	char name[96] = "gpu";
	typedef int (*name_fn)(void *, char *, unsigned int);
	name_fn getname = (name_fn)(void *)GetProcAddress(g_nvml_dll, "nvmlDeviceGetName");
	if (getname) getname(g_nvml_dev, name, sizeof name);
	snprintf(g_gpu_name, sizeof g_gpu_name, "%s", name);
	g_nvml_ready = 1;
	logf_("nvml ready: %s", name);
	return 1;
}

static void sample_gpu(void) {
	if (!g_gpu_ok) return;
	nvml_util_t u;
	if (p_nvml_util(g_nvml_dev, &u) == 0) g_gpu_util = (int)u.gpu;
	nvml_mem_t m;
	if (p_nvml_mem(g_nvml_dev, &m) == 0) {
		g_vram_used = m.used;
		g_vram_total = m.total;
	}
	if (p_nvml_temp) {
		unsigned int t = 0;
		if (p_nvml_temp(g_nvml_dev, 0 /* NVML_TEMPERATURE_GPU */, &t) == 0) g_gpu_temp = (int)t;
	}
}

/* Increments 4 and 3. Kept as stubs so the command grammar, the tray model and the
 * frame plumbing can be verified on their own first. */

/* Windows are matched by owning process first and title prefix second. In-process
 * that process is always ours, which is stricter than host.c's --pid handshake:
 * there is no way to mistake another application's window for one of ours. */
typedef struct {
	const char *title;
	HWND found;
	int require_visible;
} find_ctx;

static BOOL CALLBACK find_window_proc(HWND hwnd, LPARAM lp) {
	find_ctx *ctx = (find_ctx *)lp;
	if (ctx->require_visible && !IsWindowVisible(hwnd)) return TRUE;
	DWORD pid = 0;
	GetWindowThreadProcessId(hwnd, &pid);
	if (pid != GetCurrentProcessId()) return TRUE;
	char buf[256];
	int n = GetWindowTextA(hwnd, buf, sizeof buf - 1);
	if (n <= 0) return TRUE;
	buf[n] = 0;
	size_t want = strlen(ctx->title);
	if (want == 0) return TRUE;
	if (_strnicmp(buf, ctx->title, want) != 0) return TRUE;
	ctx->found = hwnd;
	return FALSE;
}

static HWND find_window_by_title(const char *title, int require_visible) {
	find_ctx ctx = {title, NULL, require_visible};
	EnumWindows(find_window_proc, (LPARAM)&ctx);
	return ctx.found;
}

/* Windows 11 keeps a pile of hidden WorkerW windows for shell features and nests
 * the real wallpaper layer *inside* Progman: a visible WorkerW that is a sibling
 * of SHELLDLL_DefView. The classic top-level sibling lookup misses it, and
 * parenting into one of the hidden top-level WorkerWs looks like a success but
 * renders nothing. */
typedef struct {
	const char *cls;
	HWND found;
} class_ctx;

static BOOL CALLBACK enum_class_proc(HWND hwnd, LPARAM lp) {
	class_ctx *ctx = (class_ctx *)lp;
	char cls[64];
	if (GetClassNameA(hwnd, cls, sizeof cls) == 0) return TRUE;
	if (strcmp(cls, ctx->cls) != 0) return TRUE;
	ctx->found = hwnd;   /* last match wins (lowest in z-order) */
	return TRUE;
}

static BOOL CALLBACK enum_worker_proc(HWND hwnd, LPARAM lp) {
	char cls[64];
	if (GetClassNameA(hwnd, cls, sizeof cls) == 0) return TRUE;
	if (strcmp(cls, "WorkerW") != 0) return TRUE;
	if (FindWindowExA(hwnd, NULL, "SHELLDLL_DefView", NULL) != NULL) return TRUE;
	if (!IsWindowVisible(hwnd)) return TRUE;
	*(HWND *)lp = hwnd;
	return TRUE;
}

/* class lookup through EnumWindows: FindWindowA("Progman") is unreliable here */
static HWND find_window_by_class(const char *cls) {
	class_ctx ctx = {cls, NULL};
	EnumWindows(enum_class_proc, (LPARAM)&ctx);
	return ctx.found;
}

/* The wallpaper-layer candidates, so the one that belongs to the monitor the
 * client asked for can be chosen (2026-10-10). `best` is the candidate covering
 * the most of that monitor, `first` the first one seen - which is what is used
 * when none of them overlaps it, because a wallpaper that is merely in the wrong
 * place beats a wallpaper that is not there. */
typedef struct {
	HWND best;
	HWND first;
	int best_area;
} worker_ctx;

static void consider_worker(HWND w, worker_ctx *ctx) {
	if (!w || !IsWindow(w)) return;
	char cls[64];
	if (GetClassNameA(w, cls, sizeof cls) == 0) return;
	if (strcmp(cls, "WorkerW") != 0) return;
	if (!IsWindowVisible(w)) return;
	/* the icon host is not the wallpaper layer */
	if (FindWindowExA(w, NULL, "SHELLDLL_DefView", NULL) != NULL) return;
	if (!ctx->first) ctx->first = w;
	RECT r;
	if (!GetWindowRect(w, &r)) return;
	int area = overlap_area(&r, &g_screens[g_screen_index].rect);
	if (area > ctx->best_area) {
		ctx->best_area = area;
		ctx->best = w;
	}
}

static BOOL CALLBACK enum_worker_all_proc(HWND hwnd, LPARAM lp) {
	consider_worker(hwnd, (worker_ctx *)lp);
	return TRUE;
}

static HWND find_wallpaper_worker(void) {
	HWND progman = find_window_by_class("Progman");

	static int triggered = 0;
	if (!triggered) {
		triggered = 1;
		DWORD_PTR res = 0;
		SendMessageTimeoutA(progman, 0x052C, 0, 0, SMTO_NORMAL, 1000, &res);
		SendMessageTimeoutA(progman, 0x052C, 0xD, 1, SMTO_NORMAL, 1000, &res);
	}

	/* Every candidate, so the one covering the chosen monitor can be picked
	 * (2026-10-10): with one monitor there is only ever one and this is the old
	 * behaviour, but a second monitor usually brings its own WorkerW with it, and
	 * parenting into the primary's would position the scene off that monitor's
	 * client area - where it is clipped and never seen. */
	worker_ctx ctx = {NULL, NULL, 0};

	if (progman) {
		HWND w = NULL;
		while ((w = FindWindowExA(progman, w, "WorkerW", NULL)) != NULL)
			consider_worker(w, &ctx);
	}
	EnumWindows(enum_worker_all_proc, (LPARAM)&ctx);
	if (ctx.best) {
		RECT r;
		GetWindowRect(ctx.best, &r);
		logf_("wallpaper WorkerW %p for screen %d (rect %d,%d %dx%d, overlap %d)",
				(void *)ctx.best, g_screen_index, r.left, r.top, r.right - r.left,
				r.bottom - r.top, ctx.best_area);
		return ctx.best;
	}
	if (ctx.first) {
		RECT r;
		GetWindowRect(ctx.first, &r);
		logf_("wallpaper WorkerW %p (first found, rect %d,%d %dx%d - no overlap with "
				"screen %d)", (void *)ctx.first, r.left, r.top, r.right - r.left,
				r.bottom - r.top, g_screen_index);
		return ctx.first;
	}

	/* classic layout: a visible top-level WorkerW that is not the icon host */
	for (int i = 0; i < 25; i++) {
		HWND w = NULL;
		EnumWindows(enum_worker_proc, (LPARAM)&w);
		if (w) {
			logf_("wallpaper WorkerW %p (top-level, attempt %d)", (void *)w, i);
			return w;
		}
		Sleep(80);
	}
	return NULL;
}

static void fit_into_worker(HWND hwnd, HWND worker) {
	POINT origin = {0, 0};
	ClientToScreen(worker, &origin);
	/* the chosen monitor's rect, in virtual-screen coordinates, converted to the
	   wallpaper layer's own space. Index 0 is the primary, which is what the old
	   single-screen fit always used - GetSystemMetrics(SM_CXSCREEN/SM_CYSCREEN)
	   with the origin at the layer's top-left corner. */
	RECT target = g_screens[g_screen_index].rect;
	if (target.right <= target.left || target.bottom <= target.top) {
		target.left = 0;
		target.top = 0;
		target.right = GetSystemMetrics(SM_CXSCREEN);
		target.bottom = GetSystemMetrics(SM_CYSCREEN);
	}
	int w = target.right - target.left;
	int h = target.bottom - target.top;
	/* HWND_BOTTOM keeps the scene underneath the desktop icons, and the show/hide
	   follows the client's own switch. No SWP_FRAMECHANGED: that would invalidate
	   the renderer's swap chain (a resize is a WM_SIZE the renderer handles, which
	   is how the scene comes to fill the monitor the client picked). */
	SetWindowPos(hwnd, HWND_BOTTOM, target.left - origin.x, target.top - origin.y,
			w, h, SWP_NOACTIVATE | (g_wall_shown ? SWP_SHOWWINDOW : SWP_HIDEWINDOW));
}

static void apply_wallpaper(void) {
	if (!g_wallpaper) {
		g_wall_state = "off";
		return;
	}
	if (!g_main_hwnd || !IsWindow(g_main_hwnd)) {
		g_main_hwnd = find_window_by_title(g_title, 1);
		if (!g_main_hwnd) {
			g_wall_state = "waiting";
			return;
		}
		logf_("found wallpaper window %p", (void *)g_main_hwnd);
	}
	if (!g_worker || !IsWindow(g_worker)) {
		g_worker = find_wallpaper_worker();
		if (!g_worker) {
			/* No wallpaper layer yet. Stay a plain top-level window (visible,
			   just above the icons) and try again on the next housekeeping tick
			   rather than forcing a parent that the shell will paint over. */
			g_wall_state = "no-worker";
			return;
		}
		logf_("wallpaper host %p", (void *)g_worker);
	}
	if (GetParent(g_main_hwnd) != g_worker) {
		/* Cross-process SetParent only takes effect on a WS_CHILD window, but
		   rewriting the style is what invalidates the renderer's swap chain, so
		   do the minimum: flip WS_POPUP to WS_CHILD and never pass
		   SWP_FRAMECHANGED (which forces a frame recalculation). */
		LONG_PTR style = GetWindowLongPtrA(g_main_hwnd, GWL_STYLE);
		style &= ~WS_POPUP;
		style |= WS_CHILD | WS_VISIBLE;
		SetWindowLongPtrA(g_main_hwnd, GWL_STYLE, style);
		LONG_PTR ex = GetWindowLongPtrA(g_main_hwnd, GWL_EXSTYLE);
		ex &= ~WS_EX_APPWINDOW;
		ex |= WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE;
		SetWindowLongPtrA(g_main_hwnd, GWL_EXSTYLE, ex);
		/* GetParent() alone cannot tell "mounted" from "refused and left dangling":
		 * when SetParent is refused on a window that already carries WS_CHILD, the
		 * shell quietly becomes its parent instead, which looks exactly like a
		 * successful mount. Checking the call's own result is what separates the two,
		 * and it is how the sandbox's Low-integrity token was caught refusing the
		 * cross-process reparent into Explorer's WorkerW. The call itself stays
		 * outside the log statement so a release build cannot skip it. */
		SetLastError(0);
		SetParent(g_main_hwnd, g_worker);
#ifdef XD_DEBUG_LOG
		logf_("SetParent onto worker %p -> err=%lu, parent now %p",
				(void *)g_worker, (unsigned long)GetLastError(),
				(void *)GetParent(g_main_hwnd));
#endif
	}
	fit_into_worker(g_main_hwnd, g_worker);

	char cls[64] = "";
	if (GetParent(g_main_hwnd)) GetClassNameA(GetParent(g_main_hwnd), cls, sizeof cls);
	int vis = IsWindowVisible(g_main_hwnd) ? 1 : 0;
	if (!g_wall_shown) {
		/* hidden because the client asked for it - not a failure */
		g_wall_state = "hidden";
	} else if (!vis) {
		g_wall_state = "hidden";
		logf_("wallpaper window not visible after reparent (parent class %s)", cls);
	} else if (!strcmp(cls, "WorkerW") || !strcmp(cls, "Progman")) {
		g_wall_state = "ok";
	} else {
		g_wall_state = "failed";
	}
}

/* One always-on-top, tool-windowed, non-activating overlay: the HUD. (The 菜单
 * used to be a second one of these, glued to the HUD's corner by the client -
 * 2026-10-13 it moved to the notification area, see the tray block below.) */
static void apply_one_overlay(const char *title, HWND *slot, int *shown) {
	if (!title[0]) return;
	if (!*slot || !IsWindow(*slot)) {
		*slot = find_window_by_title(title, 0);
		if (!*slot) return;
		logf_("found overlay window %p (\"%s\") visible=%d", (void *)*slot, title,
				IsWindowVisible(*slot));
	}
	if (!*shown) {
		/* Godot can create the subwindow without ever raising WS_VISIBLE - and the
		   client may already have asked for the panel to be hidden, since "hud 0"
		   can arrive before this process has found the window. So the first pass
		   adopts the window and every pass after it leaves the showing to the
		   SetWindowPos below, which carries g_hud_shown the way fit_into_worker
		   carries g_wall_shown. */
		*shown = 1;
		logf_("overlay window %p adopted (%s)", (void *)*slot,
				g_hud_shown ? "shown" : "hidden");
	}
	LONG_PTR ex = GetWindowLongPtrA(*slot, GWL_EXSTYLE);
	LONG_PTR want = ex | WS_EX_TOPMOST | WS_EX_TOOLWINDOW;
	if (g_no_activate) want |= WS_EX_NOACTIVATE;
	/* 穿透. Godot's own Window.mouse_passthrough cannot do this on Windows: the
	   platform layer only makes the window answer WM_NCHITTEST with
	   HTTRANSPARENT (display_server_windows.cpp), and the system hands that to
	   underlying windows *in the same thread* - measured, the click is swallowed
	   and the app under the HUD gets nothing. What Windows honours across
	   processes is the layered pair, and the HUD keeps drawing with it (it is
	   DWM-composited either way; measured: same ink before and after).
	   Windows never sets these two itself, so clearing them here is safe. */
	if (g_hud_locked) {
		want |= WS_EX_LAYERED | WS_EX_TRANSPARENT;
	} else {
		want &= ~((LONG_PTR)(WS_EX_LAYERED | WS_EX_TRANSPARENT));
	}
	if (want != ex) {
		SetWindowLongPtrA(*slot, GWL_EXSTYLE, want);
		logf_("overlay exstyle %llx -> %llx", (unsigned long long)ex, (unsigned long long)want);
	}
	SetWindowPos(*slot, HWND_TOPMOST, 0, 0, 0, 0,
			SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE
					| (g_hud_shown ? SWP_SHOWWINDOW : SWP_HIDEWINDOW));
}

static void apply_overlay(void) {
	apply_one_overlay(g_overlay_title, &g_overlay_hwnd, &g_overlay_shown);
}

static void sample_all(void) {
	/* host.c measured dt with QPC in its own loop; poll() is called at whatever rate
	 * GDScript's frames come at, so measure it here or the network rate is wrong. */
	static LARGE_INTEGER freq, last;
	static int primed = 0;
	if (!primed) {
		QueryPerformanceFrequency(&freq);
		QueryPerformanceCounter(&last);
		primed = 1;
	}
	LARGE_INTEGER cur;
	QueryPerformanceCounter(&cur);
	double dt = (double)(cur.QuadPart - last.QuadPart) / (double)freq.QuadPart;
	last = cur;
	if (dt <= 0.0) dt = g_interval_ms / 1000.0;

	g_cpu_last = sample_cpu();
	sample_net(dt, &g_rx_last, &g_tx_last);
	sample_gpu();
}

/* --------------------------------------------------------------------- start */

static int xd_start(HWND main_hwnd, HWND hud_hwnd, int wallpaper, int interval_ms,
		int no_activate) {
	if (g_started) return 1;
	g_main_hwnd = main_hwnd;
	g_overlay_hwnd = hud_hwnd;
	g_wallpaper = wallpaper;
	g_interval_ms = interval_ms < 200 ? 200 : interval_ms;
	g_no_activate = no_activate;

	/* The DLL's own module, so LoadIconW finds resource id 1 in the DLL rather than
	 * in the Godot executable. */
	GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
			GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
			(LPCWSTR)(const void *)&xd_start, &g_hinst);

	g_start_tick = GetTickCount64();
	g_gpu_ok = nvml_open();
	enumerate_screens();
	logf_("start: main_hwnd=%p hud_hwnd=%p wallpaper=%d interval=%d no_activate=%d hinst=%p",
			(void *)g_main_hwnd, (void *)g_overlay_hwnd, g_wallpaper, g_interval_ms,
			g_no_activate, (void *)g_hinst);
	tray_create();

	ULONGLONG now = GetTickCount64();
	g_next_sample = now;                 /* first frame right away */
	g_next_hotkey = now;
	g_next_house = now + 2000;
	g_started = 1;
	return 0;
}

/* One turn: our messages, then whatever the schedule owes. Returns the empty string
 * when there is nothing new to report, so GDScript can skip it. */
static const char *xd_poll(void) {
	if (!g_started) return "";
	tray_pump();

	ULONGLONG now = GetTickCount64();
	if ((LONGLONG)(now - g_next_hotkey) >= 0) {
		g_next_hotkey = now + 50;
		poll_hotkeys();
		if (g_event_count > 0) g_frame_dirty = 1;
	}
	if ((LONGLONG)(now - g_next_sample) >= 0) {
		g_next_sample = now + (ULONGLONG)g_interval_ms;
		sample_all();
		g_frame_dirty = 1;
	}
	if ((LONGLONG)(now - g_next_house) >= 0) {
		g_next_house = now + 5000;
		enumerate_screens();
		if (g_wallpaper) apply_wallpaper();
		apply_overlay();
	}

	if (!g_frame_dirty) return "";
	g_frame_dirty = 0;
	return build_frame();
}

/* A short status line for the gate probes: what we think we own and whether the
 * icon actually landed in the notification area. */
static const char *xd_status(void) {
	static char buf[512];
	snprintf(buf, sizeof buf,
			"{\"started\":%d,\"tray_hwnd\":%llu,\"tray_added\":%d,\"hinst\":%llu,"
			"\"tray_err\":%lu,\"icon_ok\":%d,"
			"\"gpu_ok\":%d,\"nvml\":%d,\"gpu_name\":\"%s\","
			"\"main_hwnd\":%llu,\"hud_hwnd\":%llu,\"wallpaper\":%d,\"interval_ms\":%d,"
			"\"wall\":\"%s\",\"wall_shown\":%d,\"hud_shown\":%d,\"locked\":%d,"
			"\"screens\":%d,\"bg_rows\":%d,\"screen_rows\":%d,\"desk_row\":%d,"
			"\"panel_row\":%d,\"tray_locked\":%d}",
			g_started, (unsigned long long)(uintptr_t)g_tray_hwnd, g_tray_added,
			(unsigned long long)(uintptr_t)g_hinst,
			(unsigned long)g_tray_err, g_icon_ok,
			g_gpu_ok, g_nvml_ready, g_gpu_name,
			(unsigned long long)(uintptr_t)g_main_hwnd,
			(unsigned long long)(uintptr_t)g_overlay_hwnd,
			g_wallpaper, g_interval_ms, g_wall_state, g_wall_shown, g_hud_shown,
			g_hud_locked, g_screen_count, g_tray_bg_count, g_tray_screen_count,
			g_tray_desk_row, g_tray_panel_row, g_tray_locked);
	return buf;
}

/* Debug-only hooks, so a gate probe can drive the parts that normally need a human
 * at the mouse. Compiled out entirely unless XD_DEBUG_LOG is defined -- and the
 * method is not even registered then, so a release build has no such surface.
 *
 *   1 <cmd>  run a tray command exactly as picking a row would (tray_command)
 *   2        post the shell's TaskbarCreated broadcast at ourselves (re-add path)
 *   3        force the next poll() to emit a frame                                    */
static const char *xd_test(int which, int arg) {
#ifdef XD_DEBUG_LOG
	static char buf[256];
	switch (which) {
		case 1:
			tray_command(arg);
			snprintf(buf, sizeof buf, "tray_command(%d) done, tray_added=%d",
					arg, g_tray_added);
			return buf;
		case 2: {
			/* A real TaskbarCreated only ever arrives after Explorer has died and
			   forgotten every icon, so adding twice would fail as a duplicate. To
			   exercise the re-add path honestly, take the icon away first. */
			NOTIFYICONDATAW nid;
			tray_fill_nid(&nid);
			BOOL gone = Shell_NotifyIconW(NIM_DELETE, &nid);
			g_tray_added = 0;
			if (g_tray_hwnd && g_taskbar_created) {
				PostMessageW(g_tray_hwnd, g_taskbar_created, 0, 0);
				tray_pump();
			}
			snprintf(buf, sizeof buf,
					"TaskbarCreated emulated (NIM_DELETE ok=%d), tray_added=%d",
					gone ? 1 : 0, g_tray_added);
			return buf;
		}
		case 3:
			g_frame_dirty = 1;
			return "frame forced";
		default:
			return "unknown test id";
	}
#else
	(void)which;
	(void)arg;
	return "";
#endif
}

/* ------------------------------------------------------------ registration */

static void add_method(const name_store *name, void *id, GDExtensionClassMethodArgumentMetadata ret_meta,
		GDExtensionPropertyInfo *ret_info, uint32_t argc, GDExtensionPropertyInfo *args,
		GDExtensionClassMethodArgumentMetadata *arg_meta) {
	GDExtensionClassMethodInfo mi;
	memset(&mi, 0, sizeof mi);
	mi.name = (GDExtensionStringNamePtr)name;
	mi.method_userdata = id;
	mi.call_func = method_call;
	mi.ptrcall_func = method_ptrcall;
	mi.method_flags = GDEXTENSION_METHOD_FLAG_STATIC | GDEXTENSION_METHOD_FLAG_NORMAL;
	mi.has_return_value = ret_info != NULL;
	mi.return_value_info = ret_info;
	mi.return_value_metadata = ret_meta;
	mi.argument_count = argc;
	mi.arguments_info = args;
	mi.arguments_metadata = arg_meta;
	mi.default_argument_count = 0;
	mi.default_arguments = NULL;
	dbg("add_method: id=%d argc=%u class=%p", (int)(intptr_t)id, (unsigned)argc, (void *)g_library);
	p_classdb_register_method(g_library, (GDExtensionConstStringNamePtr)&g_sn_class, &mi);
	dbg("add_method: id=%d done", (int)(intptr_t)id);
}

static void register_class(void) {
	dbg("register_class: creating StringNames");
	SN(g_sn_class, "XuanDeskNative");
	SN(g_sn_parent, "Object");
	SN(g_sn_ping, "ping");
	SN(g_sn_add, "add");
	SN(g_sn_info, "info");
	SN(g_sn_ret, "r");
	SN(g_sn_arg_a, "a");
	SN(g_sn_arg_b, "b");
	SN(g_sn_empty, "");
	memset(&g_hint_empty, 0, sizeof g_hint_empty);
	p_string_new((GDExtensionUninitializedStringPtr)&g_hint_empty, "");
	dbg("register_class: StringNames created");

	/* Class: no constructor, because every method is static. */
	GDExtensionClassCreationInfo6 ci;
	memset(&ci, 0, sizeof ci);
	ci.is_virtual = 0;
	ci.is_abstract = 1;
	ci.is_exposed = 1;
	ci.is_runtime = 0;
	ci.icon_path = NULL;
	ci.create_instance_func = NULL;
	ci.free_instance_func = NULL;
	ci.class_userdata = NULL;
	dbg("register_class: calling classdb_register_extension_class6 (sizeof ci=%d)", (int)sizeof ci);
	p_classdb_register_class(g_library, (GDExtensionConstStringNamePtr)&g_sn_class,
			(GDExtensionConstStringNamePtr)&g_sn_parent, &ci);
	dbg("register_class: class registered");

	/* ping() -> String */
	/* Every PropertyInfo below has static storage duration on purpose: the engine
	   copies the GDExtensionClassMethodInfo *struct* but keeps the pointers to the
	   argument arrays, so a stack array would dangle the moment we return. */
	static GDExtensionPropertyInfo ret_string;
	memset(&ret_string, 0, sizeof ret_string);
	ret_string.type = GDEXTENSION_VARIANT_TYPE_STRING;
	ret_string.name = (GDExtensionStringNamePtr)&g_sn_ret;
	ret_string.class_name = (GDExtensionStringNamePtr)&g_sn_empty;
	ret_string.hint = 0;
	ret_string.hint_string = (GDExtensionStringPtr)&g_hint_empty;
	ret_string.usage = 0;
	add_method(&g_sn_ping, (void *)(intptr_t)MID_PING, GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE,
			&ret_string, 0, NULL, NULL);

	/* add(a: int, b: int) -> int */
	static GDExtensionPropertyInfo ret_int;
	memset(&ret_int, 0, sizeof ret_int);
	ret_int.type = GDEXTENSION_VARIANT_TYPE_INT;
	ret_int.name = (GDExtensionStringNamePtr)&g_sn_ret;
	ret_int.class_name = (GDExtensionStringNamePtr)&g_sn_empty;
	ret_int.hint = 0;
	ret_int.hint_string = (GDExtensionStringPtr)&g_hint_empty;
	ret_int.usage = 0;

	static GDExtensionPropertyInfo args_add[2];
	memset(args_add, 0, sizeof args_add);
	args_add[0].type = GDEXTENSION_VARIANT_TYPE_INT;
	args_add[0].name = (GDExtensionStringNamePtr)&g_sn_arg_a;
	args_add[0].class_name = (GDExtensionStringNamePtr)&g_sn_empty;
	args_add[0].hint_string = (GDExtensionStringPtr)&g_hint_empty;
	args_add[1].type = GDEXTENSION_VARIANT_TYPE_INT;
	args_add[1].name = (GDExtensionStringNamePtr)&g_sn_arg_b;
	args_add[1].class_name = (GDExtensionStringNamePtr)&g_sn_empty;
	args_add[1].hint_string = (GDExtensionStringPtr)&g_hint_empty;
	static GDExtensionClassMethodArgumentMetadata add_meta[2] = {
		GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_INT64,
		GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_INT64,
	};
	add_method(&g_sn_add, (void *)(intptr_t)MID_ADD, GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_INT64,
			&ret_int, 2, args_add, add_meta);

	/* info(who: String) -> String */
	static GDExtensionPropertyInfo args_info[1];
	memset(args_info, 0, sizeof args_info);
	args_info[0].type = GDEXTENSION_VARIANT_TYPE_STRING;
	args_info[0].name = (GDExtensionStringNamePtr)&g_sn_arg_a;
	args_info[0].class_name = (GDExtensionStringNamePtr)&g_sn_empty;
	args_info[0].hint_string = (GDExtensionStringPtr)&g_hint_empty;
	GDExtensionClassMethodArgumentMetadata info_meta[1] = { GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE };
	add_method(&g_sn_info, (void *)(intptr_t)MID_INFO, GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE,
			&ret_string, 1, args_info, info_meta);

	/* ---------------------------------------------------------- the real API */

	SN(g_sn_start, "start");
	SN(g_sn_command, "command");
	SN(g_sn_poll, "poll");
	SN(g_sn_line, "line");
	SN(g_sn_a1, "hwnd_main");
	SN(g_sn_a2, "hwnd_hud");
	SN(g_sn_a3, "wallpaper");
	SN(g_sn_a4, "interval_ms");
	SN(g_sn_a5, "no_activate");

	/* start(hwnd_main: int, hwnd_hud: int, wallpaper: int, interval_ms: int,
	 *       no_activate: int) -> String */
	{
		static GDExtensionPropertyInfo args_start[5];
		static GDExtensionClassMethodArgumentMetadata start_meta[5];
		GDExtensionStringNamePtr names[5];
		names[0] = (GDExtensionStringNamePtr)&g_sn_a1;
		names[1] = (GDExtensionStringNamePtr)&g_sn_a2;
		names[2] = (GDExtensionStringNamePtr)&g_sn_a3;
		names[3] = (GDExtensionStringNamePtr)&g_sn_a4;
		names[4] = (GDExtensionStringNamePtr)&g_sn_a5;
		for (int i = 0; i < 5; i++) {
			memset(&args_start[i], 0, sizeof args_start[i]);
			args_start[i].type = GDEXTENSION_VARIANT_TYPE_INT;
			args_start[i].name = names[i];
			args_start[i].class_name = (GDExtensionStringNamePtr)&g_sn_empty;
			args_start[i].hint_string = (GDExtensionStringPtr)&g_hint_empty;
			start_meta[i] = GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_INT64;
		}
		add_method(&g_sn_start, (void *)(intptr_t)MID_START,
				GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE, &ret_string, 5, args_start,
				start_meta);
	}

	/* command(line: String) -> String */
	{
		static GDExtensionPropertyInfo args_cmd[1];
		static GDExtensionClassMethodArgumentMetadata cmd_meta[1] = {
			GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE
		};
		memset(&args_cmd[0], 0, sizeof args_cmd[0]);
		args_cmd[0].type = GDEXTENSION_VARIANT_TYPE_STRING;
		args_cmd[0].name = (GDExtensionStringNamePtr)&g_sn_line;
		args_cmd[0].class_name = (GDExtensionStringNamePtr)&g_sn_empty;
		args_cmd[0].hint_string = (GDExtensionStringPtr)&g_hint_empty;
		add_method(&g_sn_command, (void *)(intptr_t)MID_COMMAND,
				GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE, &ret_string, 1, args_cmd,
				cmd_meta);
	}

	/* poll() -> String */
	add_method(&g_sn_poll, (void *)(intptr_t)MID_POLL,
			GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE, &ret_string, 0, NULL, NULL);

	/* status() -> String */
	SN(g_sn_status, "status");
	add_method(&g_sn_status, (void *)(intptr_t)MID_STATUS,
			GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE, &ret_string, 0, NULL, NULL);

#ifdef XD_DEBUG_LOG
	/* test(which: int, arg: int) -> String -- debug builds only */
	{
		static name_store g_sn_test;
		static GDExtensionPropertyInfo args_test[2];
		static GDExtensionClassMethodArgumentMetadata test_meta[2] = {
			GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_INT64,
			GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_INT64,
		};
		GDExtensionStringNamePtr names[2];
		names[0] = (GDExtensionStringNamePtr)&g_sn_a1;
		names[1] = (GDExtensionStringNamePtr)&g_sn_a2;
		for (int i = 0; i < 2; i++) {
			memset(&args_test[i], 0, sizeof args_test[i]);
			args_test[i].type = GDEXTENSION_VARIANT_TYPE_INT;
			args_test[i].name = names[i];
			args_test[i].class_name = (GDExtensionStringNamePtr)&g_sn_empty;
			args_test[i].hint_string = (GDExtensionStringPtr)&g_hint_empty;
		}
		SN(g_sn_test, "test");
		add_method(&g_sn_test, (void *)(intptr_t)MID_TEST,
				GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE, &ret_string, 2, args_test,
				test_meta);
	}
#endif

	dbg("XuanDeskNative registered");
}

/* ------------------------------------------------------------- the plumbing */

static void on_initialize(void *userdata, GDExtensionInitializationLevel level) {
	(void)userdata;
	dbg("on_initialize level=%d", (int)level);
	if (level != GDEXTENSION_INITIALIZATION_SCENE) {
		return;
	}
	register_class();
}

static void on_deinitialize(void *userdata, GDExtensionInitializationLevel level) {
	(void)userdata;
	if (level != GDEXTENSION_INITIALIZATION_SCENE) {
		return;
	}
	if (p_classdb_unregister_class && g_library) {
		p_classdb_unregister_class(g_library, (GDExtensionConstStringNamePtr)&g_sn_class);
	}
}

#define LOAD(var, name)                                                          \
	do {                                                                         \
		(var) = (void *)p_get_proc_address(name);                                 \
		dbg("  load %-44s %s", name, (var) ? "ok" : "MISSING");                   \
		if (!(var)) {                                                             \
			dbg("=> refusing to load: %s is missing", name);                      \
			return 0; /* missing entry point: refuse to load */                   \
		}                                                                         \
	} while (0)

GDExtensionBool xuandesk_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address_fn,
		GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
	p_get_proc_address = p_get_proc_address_fn;
	g_library = p_library;
	dbg("=== xuandesk_library_init: get_proc_address=%p library=%p r_init=%p",
		(void *)p_get_proc_address, (void *)g_library, (void *)r_initialization);

	LOAD(p_string_name_new, "string_name_new_with_utf8_chars");
	LOAD(p_string_new, "string_new_with_utf8_chars");
	LOAD(p_classdb_register_class, "classdb_register_extension_class6");
	LOAD(p_classdb_register_method, "classdb_register_extension_class_method");

	/* Optional: absent is not fatal. */
	p_classdb_unregister_class = (void *)p_get_proc_address("classdb_unregister_extension_class");
	p_print_error = (void *)p_get_proc_address("print_error");
	p_string_to_utf8 = (void *)p_get_proc_address("string_to_utf8_chars");
	dbg("  optional unregister=%p print_error=%p string_to_utf8=%p",
		(void *)p_classdb_unregister_class, (void *)p_print_error, (void *)p_string_to_utf8);

	{
		GDExtensionInterfaceGetVariantFromTypeConstructor get_from =
			(void *)p_get_proc_address("get_variant_from_type_constructor");
		GDExtensionInterfaceGetVariantToTypeConstructor get_to =
			(void *)p_get_proc_address("get_variant_to_type_constructor");
		dbg("  get_from=%p get_to=%p", (void *)get_from, (void *)get_to);
		if (!get_from || !get_to) {
			return 0;
		}
		ctor_string = get_from(GDEXTENSION_VARIANT_TYPE_STRING);
		ctor_int = get_from(GDEXTENSION_VARIANT_TYPE_INT);
		to_string = get_to(GDEXTENSION_VARIANT_TYPE_STRING);
		to_int = get_to(GDEXTENSION_VARIANT_TYPE_INT);
		dbg("  ctor_string=%p ctor_int=%p to_string=%p to_int=%p",
			(void *)ctor_string, (void *)ctor_int, (void *)to_string, (void *)to_int);
		if (!ctor_string || !ctor_int || !to_string || !to_int) {
			return 0;
		}
	}

	dbg("=== xuandesk_library_init: handing r_initialization back");
	r_initialization->minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE;
	r_initialization->userdata = NULL;
	r_initialization->initialize = on_initialize;
	r_initialization->deinitialize = on_deinitialize;
	dbg("=== xuandesk_library_init: returning 1");
	return 1;
}
