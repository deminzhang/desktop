#!/usr/bin/env bash
# Build the XuanDesk GDExtension (../xuandesk_native.dll), which the engine loads
# in-process: it owns the WorkerW wallpaper mount, the tray icon, the HUD window
# styling and the metrics sampler, so the project runs as ONE process - no helper
# exe and no loopback socket. host.c is the original separate-process
# implementation, kept as the reference the port was written against.
#
#   build.sh          release DLL - no debug surface (no breadcrumb log, no test())
#   build.sh debug    adds -DXD_DEBUG_LOG: arms _gdext_init.log and the test()
#                     hook that the gate probes drive
#   build.sh host     legacy bin/host.exe
#
# -shared : a GDExtension is a DLL the engine dlopens, not an exe.
#
# Works from WSL bash (/mnt/c/...), msys/git-bash (/c/...) or plain Windows PATH.
set -euo pipefail
cd "$(dirname "$0")"
trap 'rm -f ../tray_res.o' EXIT

find_gcc() {
  if [ -n "${GCC:-}" ]; then echo "$GCC"; return; fi
  for c in \
      /mnt/c/mingw64/bin/gcc.exe \
      /c/mingw64/bin/gcc.exe \
      C:/mingw64/bin/gcc.exe \
      /mnt/c/msys64/mingw64/bin/gcc.exe \
      gcc; do
    if [ -x "$c" ] || command -v "$c" >/dev/null 2>&1; then echo "$c"; return; fi
  done
}

GCC_BIN="$(find_gcc)"
if [ -z "$GCC_BIN" ]; then
  echo "no gcc found; install mingw-w64 or set GCC=/path/to/gcc" >&2
  exit 1
fi

# windres, for the tray icon resource (native/tray.rc + xuandesk.ico): it ships
# beside gcc, so look there first and fall back to PATH. It cds with the script,
# which is also what makes the .rc's relative icon path resolve.
GCC_DIR="$(dirname "$GCC_BIN")"
WINDRES_BIN=""
for c in "$GCC_DIR/windres" "$GCC_DIR/windres.exe" windres; do
  if [ -x "$c" ] || command -v "$c" >/dev/null 2>&1; then WINDRES_BIN="$c"; break; fi
done
if [ -z "$WINDRES_BIN" ]; then
  echo "no windres found; it ships with mingw-w64 (set PATH or install it)" >&2
  exit 1
fi

# windres preprocesses the .rc by running the gcc *beside it*, spelled out with
# that full path - a mingw under "C:\Program Files\..." comes back unquoted and
# the command line splits at the space ("preprocessing failed"). Naming gcc bare
# lets PATH resolve it (with gcc's own directory put first, when it has one); the
# flags have to be spelled out because --preprocessor replaces the whole command,
# not just the program.
if [ "$GCC_DIR" != "." ]; then PATH="$GCC_DIR:$PATH"; fi
"$WINDRES_BIN" tray.rc -O coff -o ../tray_res.o \
    --preprocessor="gcc -E -xc-header -DRC_INVOKED"

if [ "${1:-}" = "host" ]; then
  # Legacy: the separate-process host the merged build no longer needs.
  mkdir -p ../bin
  # -D__USE_MINGW_ANSI_STDIO: %llu on an old mingw's msvcrt prints garbage (T23; see
  # the DLL link's note).
  "$GCC_BIN" -O2 -s -Wall -Wextra -mwindows -D__USE_MINGW_ANSI_STDIO=1 \
      -o ../bin/host.exe host.c ../tray_res.o \
      -lws2_32 -liphlpapi -luser32 -ladvapi32 -lshell32
  echo "built bin/host.exe with $GCC_BIN"
  exit 0
fi

DBG=""
if [ "${1:-}" = "debug" ]; then DBG="-DXD_DEBUG_LOG"; fi
# __USE_MINGW_ANSI_STDIO: an old mingw (7.x, as shipped in "C:\Program Files\mingw")
# hands %llu straight to the pre-VS2015 msvcrt, which does not know "ll" - the metric
# frame's seq/mem/up fields print garbage (T23). Asking for it costs ~29 KB (measured
# on gcc 15.1.0: 85,016 -> 114,023 B before the tray resource) and is what makes the
# frame correct on any toolchain, so both links here pass it.
"$GCC_BIN" -O2 -shared -Wall -Wextra -Wl,--export-all-symbols $DBG \
    -D__USE_MINGW_ANSI_STDIO=1 -o ../xuandesk_native.dll gdext/xuandesk_native.c -I. \
    -luser32 -lshell32 -ladvapi32 -liphlpapi ../tray_res.o
echo "built xuandesk_native.dll with $GCC_BIN"
