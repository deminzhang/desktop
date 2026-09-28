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

"$GCC_BIN" -O2 -s -Wall -Wextra -mwindows -o ../bin/host.exe host.c \
    -lws2_32 -liphlpapi -luser32 -ladvapi32 -lshell32
echo "built bin/host.exe with $GCC_BIN"
