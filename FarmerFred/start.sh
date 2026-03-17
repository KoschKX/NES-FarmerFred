#!/bin/sh

# Build the FarmerFred project using the nesasm SDK bundled in `nesasm`.
set -e

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Default SDK location (can be overridden by first arg or NES_SDK env)
SDK_DIR="${1:-${NES_SDK:-}}"
if [ -z "$SDK_DIR" ]; then
  cur="$ROOT_DIR"
  while [ "$cur" != "/" ] && [ -z "$SDK_DIR" ]; do
    if [ -d "$cur/nesasm" ]; then
      SDK_DIR="$cur/nesasm"
      break
    fi
    for s in "$cur"/*SDK*/nesasm "$cur"/*-SDK-*/nesasm; do
      if [ -d "$s" ]; then
        SDK_DIR="$s"
        break 2
      fi
    done
    cur="$(dirname "$cur")"
  done
fi

PROJECT_DIR="$ROOT_DIR"


# Clear console_output.txt before build
> "$PROJECT_DIR/console_output.txt"

echo "Root: $ROOT_DIR"

PROJECT_NAME="Farmer Fred"

if [ ! -d "$PROJECT_DIR" ]; then
  echo "Error: project directory not found: "$PROJECT_DIR""
  exit 3
fi

# Ensure SDK make helper exists
if [ -z "$SDK_DIR" ] || [ ! -d "$SDK_DIR" ]; then
  echo "Error: SDK directory not found. Provide path as first arg or set NES_SDK env."
  exit 5
fi

if [ ! -x "$SDK_DIR/make.sh" ]; then
  echo "Warning: SDK make helper not found or not executable: "$SDK_DIR/make.sh" (continuing — direct assembler will be used)"
fi

# Prefer asm6 from the SDK, fall back to asm6f or compile from source
EXE=""
if [ -x "$SDK_DIR/asm6" ]; then
  EXE="$SDK_DIR/asm6"
elif [ -x "$SDK_DIR/asm6f" ]; then
  EXE="$SDK_DIR/asm6f"
elif [ -x "$SDK_DIR/build/nesasm" ]; then
  EXE="$SDK_DIR/build/nesasm"
fi

# Try to compile asm6f from source if nothing found
if [ -z "$EXE" ]; then
  echo "No assembler binary found; attempting to compile asm6f from source"
  if [ -f "$SDK_DIR/asm6f.mac.c" ]; then
    (cd "$SDK_DIR" && cc -O2 -o "asm6f" "asm6f.mac.c") && EXE="$SDK_DIR/asm6f" || true
  fi
  if [ -z "$EXE" ] && [ -f "$SDK_DIR/asm6.c" ]; then
    mkdir -p "$SDK_DIR/build"
    (cd "$SDK_DIR" && cc -O2 -o "build/nesasm" "asm6.c") && EXE="$SDK_DIR/build/nesasm" || true
  fi
fi

if [ -z "$EXE" ]; then
  echo "Error: no assembler found in \"$SDK_DIR\""
  exit 6
fi

echo "Using assembler: \"$EXE\""

cd "$PROJECT_DIR"

if [ ! -f "main.asm" ]; then
  echo "Error: main.asm not found in \"$PROJECT_DIR\""
  exit 4
fi
build_once() {

  NES_PATH="$ROOT_DIR/$PROJECT_NAME.nes"
  # compute prior ROM hash (if present)
  OLD_NES_HASH=""
  if [ -f "$NES_PATH" ]; then
    OLD_NES_HASH="$(compute_file_hash "$NES_PATH")"
  fi

  # If a .pal file exists, convert it to pal/palettes.asm before assembling
  if [ -f "$PROJECT_DIR/pal/palettes.pal" ]; then
    echo "Converting pal/palettes.pal -> pal/palettes.asm"
    python3 - <<'PY'
import pathlib
src = pathlib.Path('pal/palettes.pal')
out = pathlib.Path('pal/palettes.asm')
data = src.read_bytes()
vals = list(data[:32])
if len(vals) < 32:
    vals += [0x0C] * (32 - len(vals))
lines = []
lines.append('palettes:')
for i in range(0, 32, 4):
    grp = vals[i:i+4]
    lines.append('  .db ' + ','.join('$%02X' % v for v in grp))
lines.append('')
lines.append('; Upload full 32-byte palette to PPU ($3F00-$3F1F)')
lines.append('; Call from NMI or before enabling rendering')
lines.append('UploadPalettes:')
lines.append("  lda #$3F")
lines.append("  sta $2006")
lines.append("  lda #$00")
lines.append("  sta $2006")
lines.append("  ldx #$00")
lines.append("UploadPalLoop:")
lines.append("  lda palettes,x")
lines.append("  sta $2007")
lines.append("  inx")
lines.append("  cpx #$20")
lines.append("  bne UploadPalLoop")
lines.append("  rts")
out.write_text('\n'.join(lines))
print('Wrote', out)
PY
  fi

  # If a binary .map exists for level_001, convert it to an ASM include
  if [ -f "$PROJECT_DIR/map/level_001.map" ]; then
    echo "Converting map/level_001.map -> map/level_001.asm"
    python3 - <<'PY'
import pathlib
src = pathlib.Path('map/level_001.map')
out = pathlib.Path('map/level_001.asm')
data = src.read_bytes()
lines = []
lines.append('level_001:')
for i in range(0, len(data), 16):
    chunk = data[i:i+16]
    vals = ','.join('$%02X' % b for b in chunk)
    lines.append('\t.byte ' + vals)
out.write_text('\n'.join(lines) + '\n')
print('Wrote', out)
PY
  fi

  echo "Generating random rows includes..."
  if [ -x "$(command -v python3)" ]; then
    # Generate row asm files into /tmp/map (converter will not create project include files)
    python3 tools/convert_random_rows.py --pad || echo "Warning: random rows generator failed (continuing)"
  else
    echo "Warning: python3 not found; skipping random rows generation"
  fi

  echo "Assembling..."
  "$EXE" "main.asm" "main.nes" > "build_output.txt" 2>&1
  tail -n 40 "build_output.txt" | tee "console_output.txt"

  # Move outputs to root project folder if produced
  if [ -f "main.nes" ]; then
    mv -f "main.nes" "$ROOT_DIR/$PROJECT_NAME.nes"
  fi
  if [ -f "main.fns" ]; then
    mv -f "main.fns" "$ROOT_DIR/$PROJECT_NAME.fns"
  fi

  echo "Build complete. Outputs (if produced): "$ROOT_DIR/$PROJECT_NAME.nes" "$ROOT_DIR/$PROJECT_NAME.fns""

  # Only launch emulator if no errors found in build_output.txt
  if grep -q 'error' build_output.txt; then
    echo "Errors detected in build. Skipping emulator launch."
    return
  fi

  # Open the produced .nes with the default application only if it changed
  NEW_NES_HASH=""
  if [ -f "$NES_PATH" ]; then
    NEW_NES_HASH="$(compute_file_hash "$NES_PATH")"
  fi

  if [ -z "$NEW_NES_HASH" ]; then
    echo "No ROM produced; skipping emulator launch."
  elif [ "$NEW_NES_HASH" = "$OLD_NES_HASH" ] && [ "${FIRST_BUILD_FLAG:-0}" != "1" ]; then
    echo "ROM unchanged; skipping emulator launch."
  else
    echo "Opening "$NES_PATH" with default application..."
    case "$(uname)" in
      Darwin)
        EMULATORS="OpenEmu FCEUX Nestopia Mesen RetroArch"
        CLOSE_MODE="${NES_EMULATOR_CLOSE:-force}"
        for app in $EMULATORS; do
          pkill -9 -x "$app" 2>/dev/null || true
        done
        open "$NES_PATH" || true
        ;;
      Linux)
        for app in fceux nestopia mesen retroarch; do
          pkill -9 -x "$app" 2>/dev/null || true
        done
        xdg-open "$NES_PATH" >/dev/null 2>&1 || true
        ;;
      CYGWIN*|MINGW*|MSYS*)
        cmd.exe /C start "$(cygpath -w "$NES_PATH")" || true
        ;;
      *)
        echo "No automatic opener for this platform.";
        ;;
    esac
  fi
  # Clear the first-build flag after attempting the launch so subsequent
  # builds behave normally.
  FIRST_BUILD_FLAG=0

  # Restore original level file if we overwrote it earlier
  if [ "$RESTORE_LEVEL" = "1" ]; then
    echo "Restoring original level file..."
    if [ -f "$BACKUP" ]; then
      mv -f "$BACKUP" "$LEVEL_SRC"
      rm -f "$COMBINED" || true
    fi
    RESTORE_LEVEL=0
  fi
  # If we created a temporary ASM from .nrle, restore the original .asm if needed
  if [ "$TEMP_BACKUP_NEEDED" = "1" ]; then
    echo "Restoring level_001.orig to level_001.asm"
    if [ -f "$LEVEL_SRC.orig" ]; then
      mv -f "$LEVEL_SRC.orig" "$LEVEL_SRC"
    fi
    rm -f "$TEMP_FROM_NRLE" || true
    TEMP_BACKUP_NEEDED=0
  fi
}

# Compute a combined hash of all .asm and .chr files under the project.
compute_watch_hash() {
  # Portable combined hash of matching files. Produces a single checksum string
  # Works on macOS and Linux without GNU-only options.
  if command -v shasum >/dev/null 2>&1; then
    file_hashes=$(find "$PROJECT_DIR" -type f \( -name '*.asm' -o -name '*.chr' -o -name '*.pal' \) -print0 2>/dev/null \
      | xargs -0 -n1 shasum 2>/dev/null | LC_ALL=C sort)
    if [ -z "$file_hashes" ]; then
      echo
    else
      echo "$file_hashes" | shasum 2>/dev/null | awk '{print $1}'
    fi
  elif command -v md5sum >/dev/null 2>&1; then
    file_hashes=$(find "$PROJECT_DIR" -type f \( -name '*.asm' -o -name '*.chr' -o -name '*.pal' \) -print0 2>/dev/null \
      | xargs -0 -n1 md5sum 2>/dev/null | LC_ALL=C sort)
    if [ -z "$file_hashes" ]; then
      echo
    else
      echo "$file_hashes" | md5sum 2>/dev/null | awk '{print $1}'
    fi
  elif command -v md5 >/dev/null 2>&1; then
    file_hashes=$(find "$PROJECT_DIR" -type f \( -name '*.asm' -o -name '*.chr' -o -name '*.pal' \) -print0 2>/dev/null \
      | xargs -0 -n1 md5 2>/dev/null | LC_ALL=C sort)
    if [ -z "$file_hashes" ]; then
      echo
    else
      echo "$file_hashes" | md5 2>/dev/null | awk '{print $NF}'
    fi
  else
    echo
  fi
}

# Compute hash for a single file (portable across macOS/Linux)
compute_file_hash() {
  file="$1"
  if [ -z "$file" ] || [ ! -f "$file" ]; then
    echo
    return
  fi
  if command -v shasum >/dev/null 2>&1; then
    shasum "$file" 2>/dev/null | awk '{print $1}'
  elif command -v md5sum >/dev/null 2>&1; then
    md5sum "$file" 2>/dev/null | awk '{print $1}'
  elif command -v md5 >/dev/null 2>&1; then
    md5 -q "$file" 2>/dev/null || md5 "$file" 2>/dev/null | awk '{print $NF}'
  else
    echo
  fi
}

# Default to watching the script folder unless disabled.
# Disable by setting WATCH=0 or passing second arg 'once' or 'nowatch'.
WATCH_MODE=1
if [ "${WATCH:-1}" = "0" ] || [ "${2:-}" = "once" ] || [ "${2:-}" = "nowatch" ] || [ "${2:-}" = "no-watch" ]; then
  WATCH_MODE=0
fi

# If not watching, just build once and exit
if [ "$WATCH_MODE" -ne 1 ]; then
  build_once
  exit 0
fi

echo "Watch mode: monitoring .asm and .chr files under $PROJECT_DIR"

# Perform an initial build on start so the ROM exists immediately.
# Mark this as the first build so the ROM will be opened even if unchanged.
FIRST_BUILD_FLAG=1
build_once

# Initial hash
LAST_HASH="$(compute_watch_hash)"

while true; do
  sleep 1
  NEW_HASH="$(compute_watch_hash)"
  if [ "$NEW_HASH" != "$LAST_HASH" ]; then
    echo "Change detected — rebuilding..."
    LAST_HASH="$NEW_HASH"
    build_once
    tail -n 40 build_output.txt > console_output.txt
  fi
done
