#!/usr/bin/env bash
# Run on the NUC after a failed M6. Writes diag.txt to this directory.
# For best results: launch LinuxCNC from a terminal, attempt M6 in MDI, close it,
# then run this script. The terminal output is the most useful thing — paste it in too.

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
  echo "--- INI [PYTHON] + [RS274NGC] ---"
  python3 - "$CONFIG/myCoolMachine.ini" <<'PYEOF'
import sys, configparser
p = configparser.RawConfigParser()
p.read(sys.argv[1])
for s in ("PYTHON", "RS274NGC"):
    if p.has_section(s):
        print(f"[{s}]")
        for k, v in p.items(s): print(f"  {k} = {v}")
PYEOF
  echo

  echo "=== LINUXCNC PRINT LOG (full) ==="
  cat "$HOME/linuxcnc_print.txt" 2>/dev/null || echo "NOT FOUND"

  echo
  echo "=== LINUXCNC DEBUG LOG (full) ==="
  cat "$HOME/linuxcnc_debug.txt" 2>/dev/null || echo "NOT FOUND"

  echo
  echo "=== OTHER LOG FILES ==="
  for f in "$HOME/.linuxcnc/"*.log "$HOME/linuxcnc/"*.log /tmp/linuxcnc*.log; do
    [[ -f "$f" ]] || continue
    echo "--- $f ---"
    cat "$f"
  done

} > "$OUT" 2>&1

echo "Written to $OUT"
echo
echo "IMPORTANT: also paste the terminal output from the LinuxCNC session where M6 was attempted."
echo "That terminal shows Python tracebacks that don't land in the log files."
