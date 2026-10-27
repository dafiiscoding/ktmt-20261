#!/usr/bin/env bash
# Cài môi trường mô phỏng Verilog BẢN PORTABLE vào .toolchain/ của project
# (không cài vào Program Files, không sửa PATH hệ thống, không ghi registry).
#   Icarus Verilog + GTKWave + Verilator + Yosys  (gói OSS CAD Suite của YosysHQ)
#   MARS 4.5 (assembler/simulator MIPS, cần Java — máy đã có JDK 17)
# Chạy:  bash tools/setup_env.sh      Dùng:  source tools/env.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/.toolchain"
mkdir -p "$DEST"

# Tải có tải-tiếp (-C -) + tự thử lại tối đa 20 lần khi mạng rớt
dl() {
  local n
  for n in $(seq 1 20); do
    curl -L --fail -C - --retry 5 --retry-delay 5 -o "$2" "$1" && return 0
    # 416 = file đã đủ (server không còn gì để gửi)
    [ "$(curl -sIL -o /dev/null -w '%{http_code}' -r "$(stat -c %s "$2")-" "$1")" = "416" ] && return 0
    echo ">> Mang rot, thu lai lan $n sau 5 giay..."; sleep 5
  done
  echo "!! Tai that bai sau 20 lan"; return 1
}

if [ ! -x "$DEST/oss-cad-suite/bin/iverilog.exe" ]; then
  # Dò 8 bản phát hành gần nhất, lấy file Windows x64 đầu tiên (hiện là .tgz; .exe/.zip để dự phòng)
  # Đang tải dở thì dùng lại đúng URL cũ (để tải tiếp, không lẫn bản ngày khác)
  if [ -f "$DEST/url.txt" ]; then URL=$(cat "$DEST/url.txt"); else
  URL=$(curl -s "https://api.github.com/repos/YosysHQ/oss-cad-suite-build/releases?per_page=8" | python -c "
import sys, json
d = json.load(sys.stdin)
if isinstance(d, dict):
    sys.exit('GitHub API loi: ' + str(d.get('message')))
names = []
for rel in d:
    for a in rel.get('assets', []):
        names.append(a['name'])
        n = a['name'].lower()
        if 'windows' in n and 'x64' in n and n.endswith(('.tgz', '.exe', '.zip')):
            print(a['browser_download_url']); sys.exit(0)
sys.exit('Khong thay ban Windows. Ten file co: ' + ', '.join(names[:40]))")
  echo "$URL" > "$DEST/url.txt"; fi
  echo ">> Tai $URL (vai tram MB)"
  case "$URL" in
    *.tgz)
      dl "$URL" "$DEST/oss-cad-suite.tgz"
      echo ">> Giai nen vao $DEST (vai phut)"
      tar -xzf "$DEST/oss-cad-suite.tgz" -C "$DEST" --force-local
      rm -f "$DEST/oss-cad-suite.tgz" "$DEST/url.txt" ;;
    *.exe)
      curl -L --fail -o "$DEST/oss-cad-suite.exe" "$URL"
      echo ">> Giai nen vao $DEST/oss-cad-suite"
      "$DEST/oss-cad-suite.exe" -o"$(cygpath -w "$DEST")" -y
      rm -f "$DEST/oss-cad-suite.exe" ;;
    *.zip)
      curl -L --fail -o "$DEST/oss-cad-suite.zip" "$URL"
      echo ">> Giai nen vao $DEST"
      unzip -q -o "$DEST/oss-cad-suite.zip" -d "$DEST"
      rm -f "$DEST/oss-cad-suite.zip" ;;
  esac
  [ -x "$DEST/oss-cad-suite/bin/iverilog.exe" ] || { echo "!! Giai nen xong nhung khong thay $DEST/oss-cad-suite/bin/iverilog.exe:"; ls "$DEST"; exit 1; }
fi

MARS_LOCAL="$ROOT/../study-2026-1/mon-hoc/mars-mips/Mars4_5.jar"   # máy Long đã có sẵn
if [ ! -f "$DEST/Mars4_5.jar" ] && [ -f "$MARS_LOCAL" ]; then cp "$MARS_LOCAL" "$DEST/Mars4_5.jar"; fi
if [ ! -f "$DEST/Mars4_5.jar" ]; then
  curl -L --fail -o "$DEST/Mars4_5.jar" \
    https://courses.missouristate.edu/KenVollmar/mars/MARS_4_5_Aug2014/Mars4_5.jar \
    || echo "!! Khong tai duoc MARS: tai tay Mars4_5.jar vao $DEST/"
fi

# Kiểm: biên dịch + chạy 1 testbench nhỏ (nằm trong .toolchain, không phải code đồ án)
source "$ROOT/tools/env.sh"
mkdir -p "$DEST/smoke"
cat > "$DEST/smoke/smoke_tb.v" <<'V'
module smoke_tb;
  integer i, n = 0;
  initial begin
    for (i = 0; i < 10; i = i + 1) n = n + 1;
    if (n == 10) $display("PASS smoke_tb 10"); else $display("FAIL smoke_tb n=%0d", n);
    $finish;
  end
endmodule
V
( cd "$DEST/smoke" && iverilog -g2012 -o smoke.vvp smoke_tb.v && vvp -n smoke.vvp )
iverilog -V 2>&1 | head -1
verilator_bin --version || true
( cd "$DEST/smoke" && verilator_bin --lint-only -Wall --timing smoke_tb.v && echo "LINT OK (verilator)" )
python "$ROOT/tb/vectors/gen_vectors.py" | tail -1
[ -f "$DEST/Mars4_5.jar" ] && echo "MARS: $DEST/Mars4_5.jar (chay: java -jar .toolchain/Mars4_5.jar)"
echo ">> XONG. Moi terminal moi: source tools/env.sh"
