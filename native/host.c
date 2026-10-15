/* XuanDesk native host — sidecar process for the Godot desktop client.
 *
 * Responsibilities
 *   1. Parent the wallpaper window into the desktop WorkerW layer so the 3D
 *      scene becomes the real wallpaper (rendered behind the desktop icons).
 *   2. Keep the HUD window topmost, tool-windowed and non-activating - and on the
 *      screen or off it, which is the client's 面板 switch ("hud 0|1"), the same
 *      way the wallpaper's own visibility is the client's 桌面 switch.
 *   3. Sample CPU / RAM / GPU / network and stream newline-delimited JSON over a
 *      loopback socket the Godot client listens on.
 *   4. Watch global hotkeys (Ctrl+Alt+H / T / Q) and forward them as events.
 *   5. Show or hide the wallpaper window on the client's command ("wall 0|1").
 *      Ctrl+Alt+H is forwarded as "toggle_desktop" and comes back as that
 *      command, so what the key toggles - the 3D desktop itself - is decided on
 *      the client side, where the flag is kept.
 *   6. Own the 菜单 (2026-10-13): a notification-area icon and the Win32 popup it
 *      opens. The tray holds an icon and a click callback, never somebody else's
 *      window, so the menu is drawn here out of a model the client pushes over
 *      the same socket ("menu ...", see handle_command) - and what a row asks for
 *      goes back as an event, exactly like a hotkey. This is also what keeps 穿透
 *      escapable: a window that has passed the mouse through cannot keep a corner
 *      of itself live, and the tray is not a window of ours at all.
 *
 * The process exits as soon as the socket peer disappears, so it can never
 * outlive its client.
 *
 * Build: native/build.sh  (mingw-w64 gcc, -mwindows, no console window) - and the
 * tray icon is compiled in from native/tray.rc + native/xuandesk.ico, so the
 * process carries its own icon and never looks for a file beside itself.
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
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ------------------------------------------------------------------ logging */

static FILE *g_log;

static void log_open(void) {
	char dir[MAX_PATH];
	const char *base = getenv("LOCALAPPDATA");
	if (!base || !*base) base = getenv("TEMP");
	if (!base || !*base) base = ".";
	char path[MAX_PATH];
	snprintf(dir, sizeof dir, "%s\\XuanDesk", base);
	CreateDirectoryA(dir, NULL);
	snprintf(path, sizeof path, "%s\\XuanDesk\\host.log", base);
	g_log = fopen(path, "wb");
}

static void logf_(const char *fmt, ...) {
	if (!g_log) return;
	SYSTEMTIME st;
	GetLocalTime(&st);
	fprintf(g_log, "[%02d:%02d:%02d.%03d] ", st.wHour, st.wMinute, st.wSecond, st.wMilliseconds);
	va_list ap;
	va_start(ap, fmt);
	vfprintf(g_log, fmt, ap);
	va_end(ap);
	fputc('\n', g_log);
	fflush(g_log);
}

/* ------------------------------------------------------------------- config */

static char g_host[64] = "127.0.0.1";
static int g_port = 0;
static char g_title[192] = "XuanDesk";
static char g_overlay_title[192] = "";
static int g_wallpaper = 1;
static int g_interval_ms = 1000;
static int g_no_activate = 1;
static int g_quiet = 0;
static DWORD g_pid = 0;

static void parse_args(int argc, char **argv) {
	for (int i = 1; i < argc; i++) {
		const char *a = argv[i];
		const char *v = (i + 1 < argc) ? argv[i + 1] : "";
		if (!strcmp(a, "--connect") && *v) {
			const char *colon = strrchr(v, ':');
			if (colon) {
				size_t n = (size_t)(colon - v);
				if (n >= sizeof g_host) n = sizeof g_host - 1;
				memcpy(g_host, v, n);
				g_host[n] = 0;
				g_port = atoi(colon + 1);
			}
			i++;
		} else if (!strcmp(a, "--title") && *v) {
			snprintf(g_title, sizeof g_title, "%s", v);
			i++;
		} else if (!strcmp(a, "--overlay-title") && *v) {
			snprintf(g_overlay_title, sizeof g_overlay_title, "%s", v);
			i++;
		} else if (!strcmp(a, "--wallpaper")) {
			g_wallpaper = atoi(v);
			i++;
		} else if (!strcmp(a, "--interval")) {
			g_interval_ms = atoi(v);
			if (g_interval_ms < 200) g_interval_ms = 200;
			i++;
		} else if (!strcmp(a, "--no-activate")) {
			g_no_activate = atoi(v);
			i++;
		} else if (!strcmp(a, "--pid")) {
			g_pid = (DWORD)strtoul(v, NULL, 10);
			i++;
		} else if (!strcmp(a, "--quiet")) {
			g_quiet = 1;
		}
	}
}

/* ---------------------------------------------------------------- wallpaper */

static HWND g_worker = NULL;
static HWND g_main_hwnd = NULL;
static HWND g_overlay_hwnd = NULL;
static const char *g_wall_state = "off";
static int g_match_pid = 1;
/* The client's 桌面 switch. While it is off the wallpaper stays mounted but
 * hidden, and every later housekeeping pass has to leave it that way - which is
 * why the fit below shows or hides rather than always showing. */
static int g_wall_shown = 1;

/* The client's 穿透 switch (2026-10-13). The state is kept here rather than just
 * stamped once, because the HUD window is looked up by title on every
 * housekeeping pass - the client can ask before this process has found it - and
 * because a respawned host has to be told again (the client re-sends it with the
 * wall/screen pair, main.gd _on_host_online). */
static int g_hud_locked = 0;

/* The client's 面板 switch (2026-10-15): whether the HUD window is on the screen at
 * all - the 罗盘 and the status readings in the corner, which is what the tray's
 * 面板 row turns over. Kept here for the same two reasons as 穿透: the window is
 * found by title on every pass, and a respawned host starts out showing it. */
static int g_hud_shown = 1;

/* The monitors the client can put the wallpaper on (2026-10-10). Index 0 is the
 * primary whatever order the system enumerates in; the client shows this list in
 * the HUD menu and answers with "screen <index>". */
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

/* Godot rewrites the OS window title (it appends " (DEBUG)" for debug builds),
 * so windows are matched by owning process first and title prefix second. */
typedef struct {
	const char *title;
	HWND found;
	int require_visible;
	DWORD skip_pid;
} find_ctx;

static BOOL CALLBACK find_window_proc(HWND hwnd, LPARAM lp) {
	find_ctx *ctx = (find_ctx *)lp;
	if (ctx->require_visible && !IsWindowVisible(hwnd)) return TRUE;
	DWORD pid = 0;
	GetWindowThreadProcessId(hwnd, &pid);
	if (ctx->skip_pid && pid == ctx->skip_pid) return TRUE;
	if (g_match_pid && g_pid && pid != g_pid) return TRUE;
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

static HWND find_window_ex(const char *title, int require_visible, DWORD skip_pid) {
	find_ctx ctx = {title, NULL, require_visible, skip_pid};
	EnumWindows(find_window_proc, (LPARAM)&ctx);
	return ctx.found;
}

static HWND find_window_by_title(const char *title, int require_visible) {
	return find_window_ex(title, require_visible, 0);
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
		SetParent(g_main_hwnd, g_worker);
		logf_("reparented -> parent=%p", (void *)GetParent(g_main_hwnd));
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

static int g_overlay_shown = 0;

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

/* ------------------------------------------------------------------ metrics */

typedef struct {
	ULONGLONG idle, kernel, user;
} cpu_sample;

static cpu_sample g_cpu_prev;
static int g_cpu_primed = 0;
static ULONGLONG g_net_rx_prev = 0, g_net_tx_prev = 0;
static int g_net_primed = 0;
static ULONGLONG g_start_tick = 0;

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

static HMODULE g_nvml_dll;
static void *g_nvml_dev;
static nvml_util_fn p_nvml_util;
static nvml_mem_fn p_nvml_mem;
static nvml_temp_fn p_nvml_temp;

static int nvml_open(void) {
	g_nvml_dll = LoadLibraryA("nvml.dll");
	if (!g_nvml_dll) {
		logf_("nvml.dll not available — GPU metrics disabled");
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
	logf_("nvml ready: %s", name);
	return 1;
}

static int g_gpu_ok = 0;
static int g_gpu_util = -1;
static int g_gpu_temp = -1;
static unsigned long long g_vram_used = 0, g_vram_total = 0;

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

/* ------------------------------------------------------------------ hotkeys */

#define MAX_EVENTS 8
static const char *g_events[MAX_EVENTS];
/* Room for the events that carry a payload - the tray's rows (2026-10-13):
 * "menu background sky", "menu screen 1". Literal events keep pointing at their
 * own string; g_events[i] is either. */
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

static void flush_events(void);   /* send_frame, defined with the json below */

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

/* The 菜单, in the notification area (2026-10-13).
 *
 * Windows' tray holds an icon and a click callback, never somebody else's window,
 * so the menu is a Win32 popup drawn here: out of a model the client pushes over
 * the socket ("menu ..." lines, handle_command) and with what a row asks for going
 * back as an event - the same channel the hotkeys use. The client owns the state
 * (which background is live, which monitor the desktop is on, whether 穿透 is
 * locked), so it owns the labels and the check marks; this side owns the icon,
 * the popup and the geometry.
 *
 * The window the icon rides on is a hidden *top-level* window, not a message-only
 * one: TrackPopupMenu needs a window that can take the foreground, or the menu
 * will not dismiss when the user clicks somewhere else.
 *
 * It is also what keeps 穿透 escapable - the reason the menu used to be a window
 * of its own. A window that has passed the mouse through has passed it through
 * everywhere, so nothing painted inside the HUD stays clickable; the tray is not
 * one of our windows at all.
 */

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

typedef struct {
	char id[32];
	char label[TRAY_LABEL];
	int current;
} tray_item;

static HWND g_tray_hwnd = NULL;
static HINSTANCE g_hinst = NULL;
static UINT g_taskbar_created = 0;
static int g_tray_added = 0;
static tray_item g_tray_bg[TRAY_MAX_ITEMS];
static int g_tray_bg_count = 0;
static tray_item g_tray_screens[TRAY_MAX_ITEMS];
static int g_tray_screen_count = 0;
/* The three rows only the client can decide: whether the 桌面 row exists at all (a
 * run that is not wearing the desktop layer has nothing to show or hide), whether the
 * 面板 row exists at all (a run without a HUD window has no panel to show or hide),
 * and whether 穿透 is locked. The 桌面 row is that switch's only seat since
 * 2026-10-15 (the card's own chip was removed at the user's request). Its tick is
 * g_wall_shown and the 面板 row's is g_hud_shown, both of which this process already
 * keeps. */
static int g_tray_desk_row = 0;
static int g_tray_panel_row = 0;
static int g_tray_locked = 0;


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
 * label and left its dangling lead byte behind: 2026-10-14 用户 "换桌面的菜单项尾部
 * 有乱码" - 水族箱 came out as 水族 + one stray byte (drawn as the replacement glyph),
 * 星空 as 星 + one. So measure the character the tail belongs to and drop it whole
 * only when the string ends before its last byte. */
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


/* Bounded copy: whatever does not fit is cut, and the caller trims the cut
 * (trim_utf8). */
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
	flush_events();                /* a row's answer goes out now, not with the
	                                  next sample tick */
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
	/* One monitor is not a choice: the whole row goes, exactly as it did in the
	   client's own menu - and so does this submenu. */
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


/* ------------------------------------------------------------- the icon */

static void tray_add(void) {
	if (g_tray_added || !g_tray_hwnd) return;
	NOTIFYICONDATAW nid;
	memset(&nid, 0, sizeof nid);
	nid.cbSize = sizeof nid;
	nid.hWnd = g_tray_hwnd;
	nid.uID = IDI_TRAY;
	nid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
	nid.uCallbackMessage = TRAY_CALLBACK;
	nid.hIcon = LoadIconW(g_hinst, MAKEINTRESOURCEW(IDI_TRAY));
	/* MAKEINTRESOURCE is typed for the ANSI call in this TU: cast it back */
	if (!nid.hIcon) nid.hIcon = LoadIconW(NULL, (LPCWSTR)IDI_APPLICATION);
	to_wide("玄桌面 XuanDesk", nid.szTip, (int)(sizeof nid.szTip / sizeof nid.szTip[0]));
	if (Shell_NotifyIconW(NIM_ADD, &nid)) {
		g_tray_added = 1;
		logf_("tray icon added");
	} else {
		logf_("tray icon NOT added (Shell_NotifyIcon error %lu)", GetLastError());
	}
}


static LRESULT CALLBACK tray_wnd_proc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
	(void)wp;
	if (msg == TRAY_CALLBACK) {
		/* The default notification version: lParam *is* the mouse message
		   (version 4 packs the cursor position into it instead). Either button
		   opens the menu - there is nothing else a click on this icon can mean. */
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


/* One turn of this process' message queue: the icon's callbacks arrive here, and
 * TrackPopupMenu runs its own loop inside one of them. */
static void tray_pump(void) {
	MSG msg;
	while (PeekMessageW(&msg, NULL, 0, 0, PM_REMOVE)) {
		TranslateMessage(&msg);
		DispatchMessageW(&msg);
	}
}

/* ------------------------------------------------------------------- socket */

static SOCKET g_sock = INVALID_SOCKET;

static int sock_connect(void) {
	struct addrinfo hints, *res = NULL;
	char port[16];
	snprintf(port, sizeof port, "%d", g_port);
	memset(&hints, 0, sizeof hints);
	hints.ai_family = AF_INET;
	hints.ai_socktype = SOCK_STREAM;
	hints.ai_protocol = IPPROTO_TCP;
	if (getaddrinfo(g_host, port, &hints, &res) != 0 || !res) return 0;
	SOCKET s = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
	if (s == INVALID_SOCKET) {
		freeaddrinfo(res);
		return 0;
	}
	int ok = connect(s, res->ai_addr, (int)res->ai_addrlen) == 0;
	freeaddrinfo(res);
	if (!ok) {
		closesocket(s);
		return 0;
	}
	BOOL nodelay = TRUE;
	setsockopt(s, IPPROTO_TCP, TCP_NODELAY, (const char *)&nodelay, sizeof nodelay);
	g_sock = s;
	return 1;
}

static int sock_send(const char *buf, int len) {
	int sent = 0;
	while (sent < len) {
		int n = send(g_sock, buf + sent, len - sent, 0);
		if (n <= 0) return 0;
		sent += n;
	}
	return 1;
}

/* ------------------------------------------------------------------ commands */

/* The client's own lines, one per '\n', on the same socket the frames go out on:
 *   quit                            exit (the client stops the host through this)
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
static char g_cmd_buf[4096];
static int g_cmd_len = 0;
static int g_cmd_quit = 0;

static void handle_command(const char *line) {
	if (!strncmp(line, "quit", 4)) {
		logf_("quit requested by client");
		g_cmd_quit = 1;
	} else if (!strncmp(line, "wall ", 5)) {
		/* The client's 桌面 switch: only meaningful while this process is wearing
		   the desktop layer, so --wallpaper=0 makes it a no-op. */
		if (g_wallpaper) {
			g_wall_shown = line[5] != '0';
			logf_("desktop %s by client request", g_wall_shown ? "shown" : "hidden");
			apply_wallpaper();
		}
	} else if (!strncmp(line, "lock ", 5)) {
		/* The client's 穿透 switch: the HUD window goes transparent to the mouse
		   (see apply_one_overlay for why this is done here and not in Godot). */
		int locked = line[5] != '0';
		if (locked != g_hud_locked) {
			g_hud_locked = locked;
			logf_("hud mouse passthrough %s by client request", locked ? "on" : "off");
		}
		apply_overlay();
	} else if (!strncmp(line, "hud ", 4)) {
		/* The client's 面板 switch: the HUD window leaves the screen and comes back
		   (the 罗盘 and the status readings with it). The window is this process's to
		   show and hide like the wallpaper is - it is the one that owns the HUD's
		   window styles - and the tray's 面板 row reads the flag back. */
		int shown = line[4] != '0';
		if (shown != g_hud_shown) {
			g_hud_shown = shown;
			logf_("panel %s by client request", shown ? "shown" : "hidden");
		}
		apply_overlay();
	} else if (!strncmp(line, "screen ", 7)) {
		/* Which monitor the 3D desktop is on (2026-10-10). The list is the one
		   enumerated at startup and refreshed by housekeeping, so an index the
		   client sent against a stale list is clamped rather than trusted. */
		int want = atoi(line + 7);
		if (want < 0 || want >= g_screen_count) want = 0;
		if (want != g_screen_index) {
			logf_("desktop screen %d -> %d by client request", g_screen_index, want);
			g_screen_index = want;
			/* the layer for the new monitor is not the one cached: find it again,
			   and reposition the window even when the layer is the same one */
			g_worker = NULL;
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

/* Whatever arrived, split into lines. The first version matched the head of the
 * recv buffer, so two commands that arrived in one read (the client sends "wall 1"
 * and "screen 0" back to back when the link comes up) silently dropped all but the
 * first - and a tray model is longer than one read anyway. */
static void read_commands(void) {
	char scratch[512];
	int n = recv(g_sock, scratch, sizeof scratch, 0);
	if (n <= 0) {
		logf_("peer closed the connection, exiting");
		g_cmd_quit = 1;
		return;
	}
	if (g_cmd_len + n > (int)sizeof g_cmd_buf - 1) {
		/* longer than the buffer: drop the partial line. The client re-sends the
		   whole model whenever anything changes, so nothing is lost for good. */
		logf_("command line longer than %d bytes, dropped", (int)sizeof g_cmd_buf);
		g_cmd_len = 0;
	}
	memcpy(g_cmd_buf + g_cmd_len, scratch, (size_t)n);
	g_cmd_len += n;
	char *nl;
	while ((nl = (char *)memchr(g_cmd_buf, '\n', (size_t)g_cmd_len)) != NULL) {
		int line_len = (int)(nl - g_cmd_buf);
		*nl = 0;
		if (line_len > 0) handle_command(g_cmd_buf);
		int rest = g_cmd_len - line_len - 1;
		memmove(g_cmd_buf, nl + 1, (size_t)rest);
		g_cmd_len = rest;
	}
}

/* --------------------------------------------------------------- json frame */

static double g_cpu_last = -1.0;
static double g_rx_last = 0.0, g_tx_last = 0.0;
static unsigned long long g_seq = 0;

static void send_frame(void) {
	MEMORYSTATUSEX ms;
	ms.dwLength = sizeof ms;
	GlobalMemoryStatusEx(&ms);

	char buf[2048];
	int n = snprintf(buf, sizeof buf,
			"{\"seq\":%llu,\"cpu\":%.1f,\"mem_used\":%llu,\"mem_total\":%llu,"
			"\"gpu\":%d,\"vram_used\":%llu,\"vram_total\":%llu,\"gpu_temp\":%d,"
			"\"net_rx\":%.0f,\"net_tx\":%.0f,\"up\":%llu,\"wall\":\"%s\",\"screen\":%d,\"screens\":[",
			(unsigned long long)++g_seq, g_cpu_last,
			(unsigned long long)(ms.ullTotalPhys - ms.ullAvailPhys),
			(unsigned long long)ms.ullTotalPhys,
			g_gpu_util,
			g_vram_used / (1024ull * 1024ull), g_vram_total / (1024ull * 1024ull), g_gpu_temp,
			g_rx_last, g_tx_last,
			(unsigned long long)((GetTickCount64() - g_start_tick) / 1000ull),
			g_wall_state, g_screen_index);
	for (int i = 0; i < g_screen_count; i++) {
		n += snprintf(buf + n, sizeof buf - n,
				"%s{\"w\":%d,\"h\":%d,\"x\":%d,\"y\":%d,\"primary\":%d}", i ? "," : "",
				(int)(g_screens[i].rect.right - g_screens[i].rect.left),
				(int)(g_screens[i].rect.bottom - g_screens[i].rect.top),
				(int)g_screens[i].rect.left, (int)g_screens[i].rect.top,
				g_screens[i].primary);
	}
	n += snprintf(buf + n, sizeof buf - n, "],\"ev\":[");
	for (int i = 0; i < g_event_count; i++) {
		n += snprintf(buf + n, sizeof buf - n, "%s\"%s\"", i ? "," : "", g_events[i]);
	}
	n += snprintf(buf + n, sizeof buf - n, "]}\n");
	g_event_count = 0;
	if (!sock_send(buf, n)) {
		logf_("send failed — client gone, exiting");
		exit(0);
	}
}

/* What a tray row produced goes out now, not with the next sample tick: the answer
 * to a click should not wait up to a second. */
static void flush_events(void) {
	if (g_event_count > 0) send_frame();
}

static void sample_all(double dt) {
	g_cpu_last = sample_cpu();
	sample_net(dt, &g_rx_last, &g_tx_last);
	sample_gpu();
	send_frame();
}

/* -------------------------------------------------------------- window mgmt */

static void close_previous_instance(void) {
	/* A second host may only take over from an *older* client. Closing a window
	   owned by our own client would kill the app we were spawned to serve. */
	g_match_pid = 0;
	HWND target = find_window_ex(g_title, 0, g_pid);
	g_match_pid = 1;
	if (!target) return;
	logf_("replacing previous instance (window %p)", (void *)target);
	PostMessageA(target, WM_CLOSE, 0, 0);
}

/* -------------------------------------------------------------------- entry */

int WINAPI WinMain(HINSTANCE hinst, HINSTANCE hprev, LPSTR cmdline, int show) {
	(void)hprev;
	(void)cmdline;
	(void)show;

	g_hinst = hinst;
	log_open();
	parse_args(__argc, __argv);
	g_start_tick = GetTickCount64();

	logf_("host start: argc=%d connect=%s:%d pid=%lu title=\"%s\" overlay=\"%s\" wallpaper=%d interval=%d",
			__argc, g_host, g_port, (unsigned long)g_pid, g_title, g_overlay_title,
			g_wallpaper, g_interval_ms);

	if (g_port <= 0) {
		logf_("no --connect port, nothing to do");
		return 1;
	}

	HANDLE mutex = NULL;
	for (int attempt = 0; attempt < 40; attempt++) {
		mutex = CreateMutexA(NULL, TRUE, "Local\\XuanDesk.Host");
		if (mutex && GetLastError() != ERROR_ALREADY_EXISTS) break;
		if (mutex) {
			CloseHandle(mutex);
			mutex = NULL;
		}
		if (attempt == 0) close_previous_instance();
		Sleep(100);
	}
	if (!mutex) {
		logf_("another instance is still running, aborting");
		return 2;
	}

	WSADATA wsa;
	if (WSAStartup(MAKEWORD(2, 2), &wsa) != 0) {
		logf_("WSAStartup failed");
		return 3;
	}
	g_gpu_ok = nvml_open();

	/* connect, retrying while the client brings its listener up */
	for (int i = 0; i < 150 && g_sock == INVALID_SOCKET; i++) {
		if (!sock_connect()) Sleep(100);
	}
	if (g_sock == INVALID_SOCKET) {
		logf_("could not connect to %s:%d", g_host, g_port);
		return 4;
	}
	logf_("connected to %s:%d", g_host, g_port);

	enumerate_screens();
	if (g_wallpaper) apply_wallpaper();
	apply_overlay();
	tray_create();
	LARGE_INTEGER freq, last;
	QueryPerformanceFrequency(&freq);
	QueryPerformanceCounter(&last);
	ULONGLONG next_sample = GetTickCount64();
	ULONGLONG next_house = GetTickCount64() + 2000;
	ULONGLONG next_hotkey = GetTickCount64();

	for (;;) {
		tray_pump();

		fd_set rfds;
		FD_ZERO(&rfds);
		FD_SET(g_sock, &rfds);
		struct timeval tv = {0, 20000}; /* 20 ms */
		int r = select(0, &rfds, NULL, NULL, &tv);
		if (r > 0 && FD_ISSET(g_sock, &rfds)) {
			read_commands();
			if (g_cmd_quit) break;
		} else if (r == SOCKET_ERROR) {
			logf_("select error %d, exiting", WSAGetLastError());
			break;
		}

		ULONGLONG now = GetTickCount64();
		if (now >= next_sample) {
			LARGE_INTEGER cur;
			QueryPerformanceCounter(&cur);
			double dt = (double)(cur.QuadPart - last.QuadPart) / (double)freq.QuadPart;
			last = cur;
			next_sample = now + (ULONGLONG)g_interval_ms;
			if (dt <= 0.0) dt = (double)g_interval_ms / 1000.0;
			sample_all(dt);
		}
		if (now >= next_hotkey) {
			next_hotkey = now + 50;
			poll_hotkeys();
			if (g_event_count > 0) send_frame();
		}
		if (now >= next_house) {
			next_house = now + 5000;
			enumerate_screens();
			if (g_wallpaper) apply_wallpaper();
			apply_overlay();
		}
	}

	if (g_sock != INVALID_SOCKET) closesocket(g_sock);
	WSACleanup();
	if (g_nvml_dll) FreeLibrary(g_nvml_dll);
	logf_("host stop");
	if (mutex) CloseHandle(mutex);
	return 0;
}
