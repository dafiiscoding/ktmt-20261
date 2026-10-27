#!/usr/bin/env bash
# Chạy testbench đơn vị bằng Icarus. Chạy từ thư mục gốc project:
#   bash tools/run_unit.sh                 # mọi tb/*_tb.v
#   bash tools/run_unit.sh alu muldiv      # chỉ vài tb
#   PLUSARGS=+slow bash tools/run_unit.sh timebase
# tb có dòng đầu chứa "(cosim)" (vd. cpu_g1_tb) cần chương trình → chạy qua tools/cosim_mars.py;
# chạy không tham số thì cuối cùng gọi luôn cosim_mars.py (golden MARS), test Python của asm/ISS/cmp_trace
# (pytest tools/) và cosim_iss.py (RTL ↔ ISS từng lệnh, gồm firmware SoC).
# tb có dòng đầu chứa "(fw: <file.s>)" (vd. soc_clock_tb) → dịch firmware đó ra work/<tb>.hex, chạy với +imem=.
# Mỗi tb dòng cuối in "PASS <tb> <n>" hoặc "FAIL ...". Mã thoát ≠ 0 nếu có tb FAIL.
cd "$(dirname "$0")/.." || exit 2
source tools/env.sh
mkdir -p work
all=0
if [ $# -eq 0 ]; then
    all=1
    set -- $(for f in tb/*_tb.v; do head -n 1 "$f" | grep -q "(cosim)" || echo "$f"; done | sed 's#tb/##; s#_tb\.v##')
fi
fail=0
for t in "$@"; do
    # tb/*.v không phải *_tb.v là module phụ trợ (vd. screen_dump.v)
    if ! iverilog -g2005 -Wall -Wno-timescale -o "work/${t}_tb.vvp" "tb/${t}_tb.v" src/*.v $(ls tb/*.v | grep -v '_tb\.v$'); then
        echo "FAIL ${t}_tb (bien dich)"; fail=1; continue
    fi
    fw=$(head -n 1 "tb/${t}_tb.v" | sed -n 's/.*(fw: *\([^)]*\)).*/\1/p')
    fwarg=""
    if [ -n "$fw" ]; then
        if ! python tools/fw_build.py "$fw" "work/${t}.hex" > /dev/null; then
            echo "FAIL ${t}_tb (dich firmware $fw)"; fail=1; continue
        fi
        fwarg="+imem=work/${t}.hex"
    fi
    out=$(vvp -n "work/${t}_tb.vvp" $fwarg $PLUSARGS)
    echo "$out"
    echo "$out" | grep -E "^(PASS|FAIL) " | tail -n 1 | grep -q "^PASS ${t}_tb " || fail=1
done
if [ $all -eq 1 ]; then
    # system_tb lần 2 với firmware polling (USE_IRQ = 0, chép từ fw/main.s): +poll nới cửa sổ giờ $R
    sed 's/^\( *\.eqv  *USE_IRQ  *\)1/\10/' fw/main.s > work/main_poll.s
    if grep -q '^ *\.eqv  *USE_IRQ  *0' work/main_poll.s && python tools/fw_build.py work/main_poll.s work/system_poll.hex > /dev/null; then
        out=$(vvp -n work/system_tb.vvp +imem=work/system_poll.hex +poll | grep -E "^(PASS|FAIL) system_tb" | tail -n 1)
        echo "${out/system_tb/system_tb (USE_IRQ = 0)}"
        echo "$out" | grep -q "^PASS system_tb " || fail=1
    else
        echo "FAIL system_tb (USE_IRQ = 0): khong tao duoc firmware polling"; fail=1
    fi
    python tools/cosim_mars.py || fail=1
    if out=$(python -m pytest -q --color=no -p no:cacheprovider tools/ 2>&1); then
        echo "PASS pytest_tools $(echo "$out" | tail -n 1)"
    else
        echo "$out" | tail -n 30; echo "FAIL pytest_tools"; fail=1
    fi
    python tools/cosim_iss.py || fail=1
fi
exit $fail
