/* XuanDesk native host — sidecar process for the Godot desktop client.
 *
 * Responsibilities
 *   1. Parent the wallpaper window into the desktop WorkerW layer so the 3D
 *      scene becomes the real wallpaper (rendered behind the desktop icons).
 *   2. Keep the HUD window topmost, tool-windowed and non-activating.
 *   3. Sample CPU / RAM / GPU / network and stream newline-delimited JSON over a
 *      loopback socket the Godot client listens on.
 *   4. Watch global hotkeys (Ctrl+Alt+H / T / Q) and forward them as events.
 *
 * The process exits as soon as the socket peer disappears, so it can never
 * outlive its client.
 *
 * Build: native/build.sh  (mingw-w64 gcc, -mwindows, no console window)
 */

#define WIN32_LEAN_AND_MEAN
#define _WIN32_WINNT 0x0601

#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
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

static HWND find_wallpaper_worker(void) {
	HWND progman = find_window_by_class("Progman");

	static int triggered = 0;
	if (!triggered) {
		triggered = 1;
		DWORD_PTR res = 0;
		SendMessageTimeoutA(progman, 0x052C, 0, 0, SMTO_NORMAL, 1000, &res);
		SendMessageTimeoutA(progman, 0x052C, 0xD, 1, SMTO_NORMAL, 1000, &res);
	}

	if (progman) {
		HWND w = NULL;
		while ((w = FindWindowExA(progman, w, "WorkerW", NULL)) != NULL) {
			if (!IsWindowVisible(w)) continue;
			if (FindWindowExA(w, NULL, "SHELLDLL_DefView", NULL) != NULL) continue;
			logf_("wallpaper WorkerW %p (nested in Progman, visible)", (void *)w);
			return w;
		}
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
	int w = GetSystemMetrics(SM_CXSCREEN);
	int h = GetSystemMetrics(SM_CYSCREEN);
	/* primary monitor occupies screen rect (0,0)-(w,h); convert to parent space.
	   HWND_BOTTOM keeps the scene underneath the desktop icons. No
	   SWP_FRAMECHANGED: that would invalidate the renderer's swap chain. */
	SetWindowPos(hwnd, HWND_BOTTOM, -origin.x, -origin.y, w, h,
			SWP_NOACTIVATE | SWP_SHOWWINDOW);
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
	if (!vis) {
		g_wall_state = "hidden";
		logf_("wallpaper window not visible after reparent (parent class %s)", cls);
	} else if (!strcmp(cls, "WorkerW") || !strcmp(cls, "Progman")) {
		g_wall_state = "ok";
	} else {
		g_wall_state = "failed";
	}
}

static int g_overlay_shown = 0;

static void apply_overlay(void) {
	if (!g_overlay_title[0]) return;
	if (!g_overlay_hwnd || !IsWindow(g_overlay_hwnd)) {
		g_overlay_hwnd = find_window_by_title(g_overlay_title, 0);
		if (!g_overlay_hwnd) return;
		logf_("found overlay window %p (\"%s\") visible=%d", (void *)g_overlay_hwnd,
				g_overlay_title, IsWindowVisible(g_overlay_hwnd));
	}
	if (!g_overlay_shown) {
		/* Godot can create the subwindow without ever raising WS_VISIBLE */
		ShowWindow(g_overlay_hwnd, SW_SHOWNOACTIVATE);
		g_overlay_shown = 1;
		logf_("overlay shown, visible=%d", IsWindowVisible(g_overlay_hwnd));
	}
	LONG_PTR ex = GetWindowLongPtrA(g_overlay_hwnd, GWL_EXSTYLE);
	LONG_PTR want = ex | WS_EX_TOPMOST | WS_EX_TOOLWINDOW;
	if (g_no_activate) want |= WS_EX_NOACTIVATE;
	if (want != ex) {
		SetWindowLongPtrA(g_overlay_hwnd, GWL_EXSTYLE, want);
		logf_("overlay exstyle %llx -> %llx", (unsigned long long)ex, (unsigned long long)want);
	}
	SetWindowPos(g_overlay_hwnd, HWND_TOPMOST, 0, 0, 0, 0,
			SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
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
static int g_event_count = 0;

static void push_event(const char *name) {
	if (g_event_count < MAX_EVENTS) g_events[g_event_count++] = name;
}

static void poll_hotkeys(void) {
	static int h_down = 0, t_down = 0, q_down = 0;
	int ctrl = (GetAsyncKeyState(VK_CONTROL) & 0x8000) != 0;
	int alt = (GetAsyncKeyState(VK_MENU) & 0x8000) != 0;
	int combo = ctrl && alt;
	int h = combo && (GetAsyncKeyState('H') & 0x8000) != 0;
	int t = combo && (GetAsyncKeyState('T') & 0x8000) != 0;
	int q = combo && (GetAsyncKeyState('Q') & 0x8000) != 0;
	if (h && !h_down) push_event("toggle_hud");
	if (t && !t_down) push_event("toggle_clickthrough");
	if (q && !q_down) push_event("quit");
	h_down = h;
	t_down = t;
	q_down = q;
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

/* --------------------------------------------------------------- json frame */

static double g_cpu_last = -1.0;
static double g_rx_last = 0.0, g_tx_last = 0.0;
static unsigned long long g_seq = 0;

static void send_frame(void) {
	MEMORYSTATUSEX ms;
	ms.dwLength = sizeof ms;
	GlobalMemoryStatusEx(&ms);

	char buf[768];
	int n = snprintf(buf, sizeof buf,
			"{\"seq\":%llu,\"cpu\":%.1f,\"mem_used\":%llu,\"mem_total\":%llu,"
			"\"gpu\":%d,\"vram_used\":%llu,\"vram_total\":%llu,\"gpu_temp\":%d,"
			"\"net_rx\":%.0f,\"net_tx\":%.0f,\"up\":%llu,\"wall\":\"%s\",\"ev\":[",
			(unsigned long long)++g_seq, g_cpu_last,
			(unsigned long long)(ms.ullTotalPhys - ms.ullAvailPhys),
			(unsigned long long)ms.ullTotalPhys,
			g_gpu_util,
			g_vram_used / (1024ull * 1024ull), g_vram_total / (1024ull * 1024ull), g_gpu_temp,
			g_rx_last, g_tx_last,
			(unsigned long long)((GetTickCount64() - g_start_tick) / 1000ull),
			g_wall_state);
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
	(void)hinst;
	(void)hprev;
	(void)cmdline;
	(void)show;

	log_open();
	parse_args(__argc, __argv);
	g_start_tick = GetTickCount64();

	logf_("host start: argc=%d connect=%s:%d pid=%lu title=\"%s\" overlay=\"%s\" wallpaper=%d interval=%d",
			__argc, g_host, g_port, (unsigned long)g_pid, g_title, g_overlay_title, g_wallpaper,
			g_interval_ms);

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

	if (g_wallpaper) apply_wallpaper();
	apply_overlay();

	LARGE_INTEGER freq, last;
	QueryPerformanceFrequency(&freq);
	QueryPerformanceCounter(&last);
	ULONGLONG next_sample = GetTickCount64();
	ULONGLONG next_house = GetTickCount64() + 2000;
	ULONGLONG next_hotkey = GetTickCount64();

	for (;;) {
		fd_set rfds;
		FD_ZERO(&rfds);
		FD_SET(g_sock, &rfds);
		struct timeval tv = {0, 20000}; /* 20 ms */
		int r = select(0, &rfds, NULL, NULL, &tv);
		if (r > 0 && FD_ISSET(g_sock, &rfds)) {
			char scratch[256];
			int n = recv(g_sock, scratch, sizeof scratch, 0);
			if (n <= 0) {
				logf_("peer closed the connection, exiting");
				break;
			}
			if (n >= 4 && !strncmp(scratch, "quit", 4)) {
				logf_("quit requested by client");
				break;
			}
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
