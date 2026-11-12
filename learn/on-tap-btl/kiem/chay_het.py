"""Chạy mọi kiem/*.py (trừ file này), in PASS/FAIL từng file; exit != 0 nếu có FAIL."""
import os
import subprocess
import sys
from pathlib import Path

AQUI = Path(__file__).resolve().parent
env = {**os.environ, "PYTHONUTF8": "1"}
fail = 0
for f in sorted(AQUI.glob("*.py")):
    if f.name == Path(__file__).name:
        continue
    p = subprocess.run([sys.executable, str(f)], capture_output=True, text=True, encoding="utf-8", env=env)
    ok = p.returncode == 0
    fail += not ok
    print(("PASS " if ok else "FAIL ") + f.name)
    if not ok:
        print(p.stdout + p.stderr)
print(f"{'FAIL' if fail else 'PASS'}: {fail} file lỗi")
sys.exit(1 if fail else 0)
