#!/usr/bin/env bash
# Build the XuanDesk native host with mingw-w64 gcc.
#   -mwindows : GUI subsystem, so Windows never allocates a console window.
#   -s        : strip.
#
# Works from WSL bash (/mnt/c/...), msys/git-bash (/c/...) or plain Windows PATH.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p ../bin

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
"$WINDRES_BIN" tray.rc -O coff -o tray_res.o \
    --preprocessor="gcc -E -xc-header -DRC_INVOKED"

# __USE_MINGW_ANSI_STDIO: recent mingw-w64 gcc defaults to its own printf, but an
# older one (7.x, as shipped in "C:\Program Files\mingw") hands %llu straight to
# msvcrt, which does not know "ll" - the metric frame's seq/mem/up fields print
# garbage. Asking for it explicitly is a no-op on the new toolchains.
"$GCC_BIN" -O2 -s -Wall -Wextra -mwindows -D__USE_MINGW_ANSI_STDIO=1 \
    -o ../bin/host.exe host.c tray_res.o \
    -lws2_32 -liphlpapi -luser32 -ladvapi32 -lshell32
rm -f tray_res.o
echo "built bin/host.exe with $GCC_BIN"
