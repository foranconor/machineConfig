#!/usr/bin/env bash
# Run on the NUC after a failed LinuxCNC start. Writes diag.txt to this directory.

set -euo pipefail
OUT="$(dirname "$0")/diag.txt"
CONFIG="$HOME/linuxcnc/configs/myCoolMachine"

{
  echo "=== DEPLOYED FILES ==="
  echo "--- python/remap.py ---"
  cat "$CONFIG/python/remap.py" 2>/dev/null || echo "NOT FOUND"
  echo
  echo "--- python/toplevel.py ---"
  cat "$CONFIG/python/toplevel.py" 2>/dev/null || echo "NOT FOUND"
  echo
  echo "--- myCoolMachine.ini [PYTHON] and [RS274NGC] ---"
  grep -A5 '^\[PYTHON\]' "$CONFIG/myCoolMachine.ini" 2>/dev/null
  echo
  grep -A10 '^\[RS274NGC\]' "$CONFIG/myCoolMachine.ini" 2>/dev/null
  echo

  echo "=== PYTHON IMPORT TEST ==="
  python3 - <<'PYEOF'
import sys
print("sys.path:", sys.path)

# Check if LinuxCNC Python modules are findable
for mod in ("emccanon", "interpreter", "linuxcnc"):
    try:
        __import__(mod)
        print(f"import {mod}: OK")
    except ImportError as e:
        print(f"import {mod}: FAILED — {e}")

# Try loading remap.py directly
import importlib.util, os
remap_path = os.path.expanduser("~/linuxcnc/configs/myCoolMachine/python/remap.py")
try:
    spec = importlib.util.spec_from_file_location("remap", remap_path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    print("remap.py loaded OK")
    print("  functions:", [x for x in dir(mod) if not x.startswith("_")])
except Exception as e:
    print(f"remap.py load FAILED: {e}")
PYEOF

  echo
  echo "=== LINUXCNC PRINT LOG (last 80 lines) ==="
  tail -80 "$HOME/linuxcnc_print.txt" 2>/dev/null || echo "NOT FOUND"

  echo
  echo "=== LINUXCNC DEBUG LOG (last 80 lines) ==="
  tail -80 "$HOME/linuxcnc_debug.txt" 2>/dev/null || echo "NOT FOUND"

} > "$OUT" 2>&1

echo "Written to $OUT"
