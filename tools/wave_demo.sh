#!/usr/bin/env bash
# Mô phỏng thật để DEMO: dịch fw/main.s, chạy soc_top G1 bằng Icarus, ghi work/wave_demo.vcd, in dòng thời gian sự kiện.
#   bash tools/wave_demo.sh          # chạy + in sự kiện
#   bash tools/wave_demo.sh view     # chạy rồi mở GTKWave (cần màn hình)
cd "$(dirname "$0")/.." || exit 2
source tools/env.sh
mkdir -p work
python tools/fw_build.py fw/main.s work/wave_demo.hex > /dev/null || { echo "FAIL dich firmware"; exit 1; }
iverilog -g2005 -Wall -Wno-timescale -o work/wave_demo.vvp tb/wave/wave_demo.v src/*.v || { echo "FAIL bien dich"; exit 1; }
vvp -n work/wave_demo.vvp +imem=work/wave_demo.hex || exit 1
ls -l work/wave_demo.vcd
if [ "$1" = "view" ]; then
    # nạp sẵn danh sách tín hiệu nếu có file .gtkw
    if [ -f tb/wave/wave_demo.gtkw ]; then gtkwave work/wave_demo.vcd tb/wave/wave_demo.gtkw & else gtkwave work/wave_demo.vcd & fi
fi
