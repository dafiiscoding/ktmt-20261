# goi-viec.md — Gói việc: output, giao tiếp, yêu cầu, test, tiêu chí xong

> **Trạng thái:** BẢN NHÁP v1 (01/10/2026), Claude viết; duyệt qua nhóm chat, Long chốt (không cần họp). Sau đó mỗi người **tự chép phần mình** vào `docs/hop-tuan.md` khi nhận việc.
> Cách đọc: mỗi gói có **ID**, chủ, sprint (lịch ở `PLAN_DONG_HO.md` §11), phụ thuộc, file output, cổng (port), yêu cầu (trỏ sang spec), test và tiêu chí xong.
> Spec gốc: `isa-spec.md`, `control-table.md`, `pipeline-policy.md`, `mmio-map.md`, `timer-spec.md`, `display-spec.md`. Gói việc chỉ trỏ, không chép lại. Lệch nhau thì spec thắng.

## 0. Luật chung cho mọi gói
### 0.1. Xong = đủ 5 điều (DoD, `KE-HOACH` §4)
1. Code trong repo, **tự gõ** (luật §4b). Đầu file ghi: tên, chủ, spec đang theo (file + §).
2. Testbench tự kiểm: in đúng một dòng cuối `PASS <tên_tb> <số ca>` hoặc `FAIL <tên_tb> ...` (các ca sai, tối đa 10 ca đầu, in ở các dòng `loi ...` phía trên). **Không dò waveform bằng mắt để kết luận.**
3. Log chạy lưu `evidence/YYYYMMDD_<module>.log` (lệnh chạy + dòng PASS).
4. Một đoạn báo cáo + một hình hoặc bảng trong `report/` (`KE-HOACH` §3).
5. Người duyệt (cột "Duyệt") đọc code + chạy lại test trên máy mình, ghi tên vào `hop-tuan.md`.

### 0.2. Quy ước chung
- **Verilog-2005** (Long chốt 01/10), viết sao cho chạy được cả Icarus Verilog lẫn ModelSim: `always @(posedge clk)` cho thanh ghi, `always @*` cho tổ hợp, `reg`/`wire`, `localparam` cho hằng; không dùng cú pháp chỉ có trong SystemVerilog. Parameter kiểu đúng/sai viết 1/0 (spec ghi `true`/`false` = 1/0).
- Mô phỏng: **Icarus Verilog** (`iverilog -g2005 … && vvp …`) + GTKWave; lint `verilator --lint-only -Wall`. Cài: `bash tools/setup_env.sh` (portable), mỗi terminal `source tools/env.sh`.
- **Chỉ mô phỏng, không có board** (Long chốt 01/10). Số LUT/FF cho §8: Yosys `synth_xilinx` (có trong gói). Fmax: tùy chọn, ai cài Vivado/Quartus (không cần board) thì chạy; không thì bỏ cột Fmax, báo LUT + số chu kỳ.
- Một clock `clk`, reset `rst` đồng bộ mức cao. Mọi tốc độ khác dùng clock enable (`mmio-map.md` §1).
- Tên file = tên module. Testbench: `tb/<module>_tb.v`. Mô phỏng-chỉ (trace, kiểm) bọc trong `` `ifndef SYNTHESIS `` … `` `endif ``.
- Parameter thời gian có bản mô phỏng nhỏ: `G_N = 50`, `G_SLOT = 40`, `G_BLANK = 4`, `G_BIT = 8`.
- **Đối chiếu độc lập (chống lỗi chung nguồn):** RTL và ISS cùng so với vector do script sinh, nên golden sai thì cả hai vẫn PASS. TV1 lấy 50 ca mỗi file `alu`/`mul`/`div` (bỏ ca chia 0) chạy trong MARS, so tay → `evidence/YYYYMMDD_mars_crosscheck.log`. Cách đọc từng file vector: `tb/vectors/README.md`.
- **Vector:** `tb/vectors/*.txt`, sinh bằng `python tb/vectors/gen_vectors.py`. Dòng `#` là chú thích; các trường cách nhau một dấu cách, hex không có `0x`, đọc bằng `$fopen`/`$fgetc`/`$fscanf` (mẫu: `tb/vectors/README.md`). **Không sửa tay file vector**: sửa spec → sửa script → chạy lại.
- Testbench in số ca đã chạy để người duyệt biết test không rỗng.

### 0.3. Thứ tự phụ thuộc (đường găng)
```
WP0 → A1 ALU ─┐
       C1 regfile ─┼→ C2 control → C3 G1 ──→ C6 soc_top G1 → C8 system_tb (M1 15/11) → C7 G2 (M2 22/11)
       B1 asm → B2 ISS ─┘         ↑                ↑
E1 timebase → E2 RTC → E3 SW/TMR → E4 alarm+nút ───┤
D1 seg7 → D2 display_ctrl → D3 beeper → D4 UART ───┘
```
Ai trễ trên đường `A1/C1 → C2 → C3 → C6 → C8` là trễ cả nhóm → báo ngay ở nhóm chat, không đợi họp tuần.

## 1. Tổng quan gói việc
| ID | Gói | Chủ | Duyệt | Sprint | Phụ thuộc | Output chính |
|---|---|---|---|---|---|---|
| WP0 | Môi trường + repo | mọi người | Long | S1′ | — | `evidence/*_wp0.log` |
| H | Freeze 6 file hợp đồng | chủ từng file | cả nhóm | S1′ | — | `docs/*.md` có dòng "FREEZE <ngày>" |
| L | Đề bài + câu hỏi thầy | Long | — | S1′ | — | `docs/de-bai.md` |
| A1 | ALU | TV1 | TV3 | S2 | WP0 | `src/alu.v` |
| A2 | mul + div | TV1 | TV2 | S2 | WP0 | `src/muldiv.v` |
| A3 | `bcd_unit` 2 bản | TV1 | TV4 | S4 (tuần tự), S8 (tổ hợp) | A2 (giao diện `busy`) | `src/bcd_unit.v` |
| A4 | Script DSE | TV1 | Long | S8–S9 | A3, C6 | `tools/dse_report.py`, bảng §8.1–8.2 |
| B1 | Assembler | TV2 | TV3 | S2–S3 | H | `tools/asm.py` |
| B2 | ISS | TV2 | TV1 | S3 | B1 | `tools/iss.py` |
| B3 | So trace | TV2 | TV3 | S4 | B2 | `tools/cmp_trace.py` |
| B4 | Chạy toàn bộ test | TV2 | mọi người | S5 → S9 | B1–B3 | `tools/run_all_tests.(sh\|bat)` |
| B5 | Hazard + forwarding unit | TV2 | TV3 | S6–S7 | C7 khung | `src/hazard.v` |
| B6 | Bộ test hazard | TV2 | TV3 | S5–S7 | B1 | `fw/tests/hazard/*.s` |
| B7 | Firmware `main.s` + `fmt.s` | TV2 | TV5 | S4–S8 | B2, mọi spec | `fw/main.s`, `fw/fmt.s` |
| C1 | Regfile | TV3 | TV2 | S2 | WP0 | `src/regfile.v` |
| C2 | Control | TV3 | TV2 | S3 | H | `src/control.v` |
| C3 | CPU G1 | TV3 | TV2 | S3–S4 | A1, A2, C1, C2 | `src/cpu_sc.v`, `src/imem.v`, `src/dmem.v` |
| C4 | Bus + giải mã MMIO + thanh ghi soc | TV3 | TV4 | S5 | C3 | `src/bus_decode.v` |
| C5 | CP0 + `irq_ctrl` + ngắt G1 | TV3 | TV2 | S5 | C3, C4 | `src/cp0.v`, `src/irq_ctrl.v` |
| C6 | `soc_top` | TV3 | TV4, TV5 | S5 | C3, C4, D*, E* | `src/soc_top.v` |
| C7 | CPU G2 pipeline | TV3 | TV2 | S5–S8 | C3, B5 | `src/cpu_pipe.v` |
| C8 | `system_tb` 7 kịch bản | TV3 (đề xuất chuyển TV1, xem §4) | TV2 | S5–S7 | C6, B7 | `tb/system_tb.v` |
| D1 | ROM ký tự + quét 7 đoạn | TV4 | TV1 | S2 | WP0 | `src/char_rom.v`, `src/seg7_scan.v` |
| D2 | `display_ctrl` | TV4 | TV3 | S3 | D1 | `src/display_ctrl.v` |
| D3 | Bộ tạo âm | TV4 | TV5 | S4 | E1 | `src/beeper.v` |
| D4 | UART | TV4 | TV5 | S5 | WP0 | `src/uart.v` |
| D5 | VGA đuổi tia (T2) | TV4 | TV1 | S9 | D2 | `src/vga_digits.v` |
| D6 | Firmware `alarm.s` + `chime.s` | TV4 | TV5 | S6–S7 | B2, E4 | `fw/alarm.s`, `fw/chime.s` |
| D7 | Màn hình ảo (thay board) | TV4 | TV3 | S7 | C6 | `tb/screen_dump.v`, `tools/screen.py` |
| E1 | Timebase | TV5 | TV1 | S2 | WP0 | `src/timebase.v` |
| E2 | RTC | TV5 | TV3 | S3 | E1 | `src/timers.v` (phần rtc) |
| E3 | Stopwatch + timer âm | TV5 | TV1 | S3 | E1 | `src/timers.v` |
| E4 | Alarm + nút | TV5 | TV4 | S4 | E2 | `src/timers.v`, `src/buttons.v` |
| E5 | Firmware `set.s` | TV5 | TV2 | S6 | B2 | `fw/set.s` |
| E6 | Sync: `sync.s` + PC giả trong tb | TV5 | TV4 | S8 | D4, B2 | `fw/sync.s`, `tb/uart_host.v` |
| E7 | RTC BCD (T2, DSE) | TV5 | TV1 | S8 | E2 | `src/rtc_bcd.v` |
| X | Thí nghiệm E1′, E2′, E3, E4′ (mô phỏng) | TV5 (E1′, E2′), TV3 + TV2 (E3), TV4 (E4′) | Long | S9 | C8 | `evidence/exp_E*/` |
| R | Báo cáo + biên tập | biên tập + mọi người | Long | S1′ → S10 | — | `report/` |

**Phân việc mới so với plan §7:** `set.s` giao TV5 (biết luật ngày tháng), `alarm.s` + `chime.s` giao TV4 (gần bộ tạo âm). Plan §7 đã cập nhật theo.

## 2. Chi tiết từng gói

### WP0 — Môi trường (mọi người, S1′)
- Cài: `bash tools/setup_env.sh` → Icarus Verilog, GTKWave, Verilator, Yosys, MARS 4.5 vào `.toolchain/` (portable); cần sẵn Python ≥ 3.10, Java, git.
- Tạo repo nhóm theo cây `KE-HOACH` §6 (đã dựng sẵn ở thư mục này), mỗi người clone.
- **Test:** tự viết `tb/hello_tb.v` (đếm 0…9, kiểm bằng `if`, in `PASS hello_tb 10`), chạy bằng `iverilog` + `vvp`, mở `.vcd` trong GTKWave. Chạy `python tb/vectors/gen_vectors.py` ra dòng `PASS`.
- **Xong khi:** 5 log `evidence/YYYYMMDD_wp0_<tên>.log`.

### H — Freeze hợp đồng (S1′, hạn 07/10)
- Mỗi chủ file **đọc hết**, ghi câu hỏi vào cuối file / nhóm chat, Long chốt rồi thêm dòng `FREEZE dd/mm — <tên các người duyệt>` ở đầu.
- Chủ: `isa-spec` TV2 · `control-table` TV3 · `pipeline-policy` TV2 + TV3 · `mmio-map` TV3 · `timer-spec` TV5 · `display-spec` TV4.
- Cách duyệt bắt buộc: `pipeline-policy` thì TV2, TV3 tự vẽ tay T2/T4/T8 rồi so (`pipeline-policy.md` đầu file).

### A1 — ALU (TV1, S2)
- Cổng: `input [31:0] a, b; input [4:0] shamt; input [3:0] ctl; output [31:0] y; output zero`. Tổ hợp.
- Yêu cầu: `control-table.md` §1.1 (mã `ctl`, `SLL/SRA` dịch `b`), `isa-spec.md` §3.
- Test: `alu.txt` (4 200 ca, có biên `0x7FFFFFFF`, `0x80000000`, `−1`). `SLT` phải đúng cả ca tràn (ví dụ `0x80000000 < 0x7FFFFFFF` → 1).
- Xong khi: `PASS alu_tb 4200`; báo cáo: bảng mã `ctl` + hình khối ALU.

### A2 — mul + div (TV1, S2)
- Cổng: `clk, rst, ce, start, a, b → mul_y (tổ hợp), busy, done, lo, hi, dz`. `ce` = clock enable của CPU (G1: cạnh pha A; G2: `cpu_ce`), khối chỉ bước khi `ce = 1`.
- Yêu cầu: `isa-spec.md` §3 (#10, #24), §4.
  - `start` là xung 1 chu kỳ CPU; toán hạng **chốt ở chu kỳ start**. `busy` = 1 trong suốt 32 chu kỳ tính; `done` (tổ hợp) = 1 ở chu kỳ bước chia cuối, `lo/hi` ghi ở cạnh kết thúc chu kỳ đó (`pipeline-policy.md` §6). Tổng: start + 32 = 33 chu kỳ CPU, đứng 32.
  - Chia 0: không cần 32 chu kỳ, nhưng vẫn phải phát `done` (chọn và ghi rõ số chu kỳ). Bản 01/10: `done` ngay ở chu kỳ start (1 chu kỳ, không đứng).
- Test: `mul.txt` (825 ca), `div.txt` (830 ca, gồm chia 0 và `0x80000000 / −1`). Thêm: đổi `a, b` ngay sau `start` → kết quả không đổi. Đo đúng số chu kỳ `busy`.
- Xong khi: PASS 2 file; báo cáo: thuật toán restoring + số chu kỳ thật.

### A3 — `bcd_unit` (TV1, tuần tự S4, tổ hợp S8)
- **Code + tb xong 02/10** (Claude viết, cần cho CPU chạy đủ 28 lệnh): `src/bcd_unit.v` (double dabble 27 bước), `tb/bcd_tb.v` → PASS 112 537 (bcd.txt × 2 bản + 10^5 số ngẫu nhiên; một lần chạy 10^6 số cũng PASS 1 012 537). Quét hết 10^8: `PLUSARGS=+full`, chưa chạy.
- Parameter `G_COMB` (0/1). Cổng như A2: `start, x → busy, done, y` (tổ hợp: `busy` luôn 0, `y` có ngay).
- Yêu cầu: `isa-spec.md` §3 #25, `control-table.md` (`multi = 10` bản tuần tự).
- Test: `bcd.txt` (3 134 ca) cho cả 2 bản. Bản tổ hợp: thêm vòng lặp **toàn bộ 0…99 999 999** trong tb với golden tính bằng `mod/÷ 10` (chạy lâu thì chia 4 khoảng chạy song song; không kịp thì mẫu 10⁶ và ghi rõ).
- Số đo cho §8.1: số chu kỳ bản tuần tự; LUT + Fmax của từng bản sau tổng hợp.

### A4 — Script DSE (TV1, S8–S9)
- `tools/dse_report.py`: chạy Yosys `synth_xilinx` cho từng khối, đọc `stat` (LUT/FF/BRAM/DSP) → bảng Markdown cho plan §8.1 + §8.2. Có Vivado/Quartus thì đọc thêm Fmax (tùy chọn).
- **Bản đầu 26/10** (Claude viết theo lời Long "A"): 16 khối (SoC G1/G2, 2 lõi, irq, display, seg7, VGA, timebase, rtc, stopwatch, cdtimer, alarm, uart, muldiv, alu), ~2 phút. `synth_xilinx -run :map_luts` + `abc -lut 6` thay abc9 (assertion) → có số LUT thật thay "ô". Bảng điền plan §8.2 + `report/3.4-dse.md`. Chưa có: Fmax, cấu hình `G_BCD_COMB`/`G_BCD_RTC` trong script (§8.1 vẫn đo tay bằng `-run :map_ffs`).
- Test: chạy trên ALU + regfile; số in ra khớp số đọc tay từ log Yosys.

### B1 — Assembler (TV2, S2–S3)
- Yêu cầu: `isa-spec.md` §2, §3, §7 (cú pháp, lệnh giả, `.org`, đầu ra `.hex` + `.lst`, lỗi có số dòng).
- Test:
  - B1-1: một file `.s` có **đủ 28 lệnh** → mã máy khớp tay từng dòng (bảng trong `isa-spec` §3).
  - B1-2: 3 chương trình MIPS thuần (không `.data`) dịch bằng MARS và `asm.py` → `.hex` giống từng byte.
  - B1-3: mọi lỗi trong §7 → báo đúng dòng, không sinh `.hex`.
  - B1-4: nhánh lùi/tiến xa nhất ±32 767 lệnh; vượt → lỗi.
- Xong khi: 4 nhóm test PASS bằng `python -m pytest tools/` hoặc script tự kiểm.
- **Bản đầu 03/10** (Claude viết): `tools/asm.py` (lệnh: `python tools/asm.py x.s [-o x.hex] [--aw N]` → `.hex` + `.lst` + `.dmem.hex` nếu có `.data`). `tools/test_asm.py` B1-1…4 PASS 41 + 1 skip: B1-1 `fw/tests/asm/all28.s` 37 dòng mã tính tay; B1-2 **13 file `fw/` (gồm `main.s`)** + 15 ca biên `li` giống MARS từng word (đề yêu cầu 3); B1-3 22 lỗi đúng dòng, không sinh file; B1-4 tiến +32 767 / lùi −32 768 được, vượt 1 → lỗi. Đột biến 10/10 bị bắt (`work/mut_asm_20261003.log`). Quyết định ghi ở `isa-spec` §7 (`li` theo 32 bit như MARS, `la`/`b` khác MARS có chủ đích). `tools/fw_build.py` dùng `asm.py` từ 03/10 (`--mars` để dùng MARS).

### B2 — ISS (TV2, S3)
- Yêu cầu: `isa-spec.md` toàn bộ (gồm §4 `div`, §5 CP0 + ngắt, §8 trace + 2 chế độ).
- Test:
  - B2-1: dùng lại `alu.txt`, `mul.txt`, `div.txt`, `bcd.txt` qua hàm tính của ISS (cùng golden với RTL).
  - B2-2: chương trình tính tổng 1…100 → `$v0 = 5050`; đệ quy giai thừa 10 qua stack.
  - B2-3: ngắt: kịch bản bật `IRQ` sau lệnh thứ 50 → trace có dòng `INTERRUPT`, `EPC` đúng, `eret` quay lại đúng.
  - B2-4: chương trình khung `fw/tests/fmt_test.s` gọi từng hàm định dạng với `$a0` lấy từ `fmt_*.txt` (ISS nạp `$a0`, đọc `DISP7…0`) → khớp từng dòng. (Mô hình ngoại vi ISS không có stopwatch/timer/`RTC_BCD`, nên không chạy qua `main.s`.)
- Xong khi: 4 nhóm PASS; trace đúng định dạng §8.
- **Bản đầu 03/10** (Claude viết): `tools/iss.py` (chạy độc lập có mô hình ngoại vi tối giản, hoặc replay MMIO theo trace RTL). `tools/test_iss.py` B2-1…3 PASS 18. **B2-4 xong 26/10** (xem B7: Python gọi thẳng nhãn thay cho khung `fmt_test.s`). Đồng mô phỏng RTL ↔ ISS từng lệnh: `tools/cosim_iss.py` — 17 chương trình CPU (`fw/tests/cpu` + 6 ngẫu nhiên có `mfhi` sau `mul` và chia 0) + 4 tb SoC chạy firmware thật (`soc_bus`, `soc_clock`, `soc_irqlat`, `system` với `main.s` 236 746 dòng trace) → PASS 21; thêm `--rand 30` → PASS 43. Đột biến 12 ISS + 8 RTL bị bắt 20/20 (`work/mut_iss_20261003.log`). Chỗ mù của replay ghi ở `isa-spec` §8.

### B3 — `cmp_trace.py` (TV2, S4)
- So 2 file trace theo `isa-spec.md` §8 (bỏ cột `cycle`), dừng ở **dòng đầu tiên lệch**: in số dòng, 2 dòng, cột lệch. Có chế độ replay MMIO.
- Test: 2 trace giống nhau → PASS; sửa 1 giá trị ở dòng 137 → báo đúng dòng 137; trace RTL dài hơn → báo "thừa".
- **Bản đầu 03/10** (Claude viết): `tools/cmp_trace.py` (`a.csv b.csv` hoặc `a.csv --replay prog.hex`). `tools/test_cmp_trace.py` PASS 6 (3 test của đề + từng cột + dòng đầu/cuối + replay có ngắt sai luật). Đột biến 6/6 bị bắt (`work/mut_cmp_20261003.log`).

### B4 — `run_all_tests` (TV2, S5 bản đầu, S9 bản đủ)
- Một lệnh chạy: sinh vector → mọi tb đơn vị → co-sim G1/G2 với ISS → `system_tb` → in bảng PASS/FAIL + tổng thời gian.
- Test: cố ý làm hỏng 1 tb → lệnh trả mã lỗi ≠ 0, chỉ đúng tb đó FAIL (đây cũng là bài cổng §4b mục 3).

### B5 — Hazard + forwarding (TV2, S6–S7)
- Yêu cầu: `pipeline-policy.md` §3–§6 (biểu thức forwarding, load-use theo `uses_rs/uses_rt`, flush, busy, thứ tự ưu tiên).
- Test: tb đơn vị đưa vào các tổ hợp (`dst`, `reg_write`, `rs`, `rt`) và so với bảng chân lý tự lập; rồi B6.

### B6 — Bộ test hazard (TV2, S5–S7)
- Đủ danh sách `pipeline-policy.md` §8, thêm `mmio_once.s`: `lw SW_LAP` nằm trong bóng nhánh nhảy (không được lấy khỏi FIFO), trong lúc load-use và lúc `busy` (lấy đúng 1 lần) — chạy trên `soc_top` G2. Mỗi file `.s` tự kiểm: cuối chương trình ghi `0x600D` (đúng) hoặc mã lỗi vào DMEM[0], và trace G2 phải trùng ISS.
- Số chu kỳ từng file khớp bảng T1–T8 (§7) ± 0.

### B7 — Firmware `main.s` + `fmt.s` (TV2, S4–S8)
- `main.s`: máy trạng thái 5 chế độ theo plan §2, bố cục màn theo `display-spec.md` §8; cờ biên dịch `.eqv USE_IRQ 0/1`.
  - MODE: TIME → STOPWATCH → TIMER → ALARM → SET → TIME. Nút A/B/C theo bảng plan §2.
  - STOPWATCH bật `SRC = 1` (capture phần cứng) khi vào chế độ, `SRC = 0` khi ra.
  - Bíp nút: `BEEP_PATTERN = 0x00001`, trừ khi đang có chuông ưu tiên cao hơn.
- `fmt.s`: 3 hàm cùng đầu vào `$a0 = ms` → ghi `DISP7…0` bố cục TIME 24 h: `fmt_div` (chỉ `div`), `fmt_bcd` (lệnh `bcd`), `fmt_hw` (đọc `RTC_BCD`). Đo `CYCLE_COUNT` trước/sau mỗi hàm → plan §8.1.
- Test trên ISS qua `fmt_test.s` (B2-4): mọi dòng `fmt_time.txt` (`fmt_div`, `fmt_bcd` cùng kết quả), `fmt_sw.txt`, `fmt_timer.txt` (gồm −2³¹), `fmt_alarm.txt`, trang 2 của `date.txt`. `fmt_hw` chỉ test trên RTL (E7 + `system_tb`), vì `RTC_BCD` độc lập với RTC nhị phân (`timer-spec.md` §8).
- Test trên RTL: `system_tb` kịch bản 1–6 (C8).
- **`main.s` bản đầu 03/10** (Claude viết, gộp B7 + E5 SET + D6 alarm/chime trong 1 file, 856 word; tách file khi có `asm.py`). Polling, không ngắt. Quyết định bản này (TV2 duyệt hoặc đổi): TIME — B xoay giờ → giây.ms → ngày (nút chỉ báo lúc nhấn, không biết "giữ"), A 12/24 h, C độ sáng; STOPWATCH — A/B nối phần cứng, C xem lap với DISP7 = số lap; đang chuông thì nút đầu chỉ tắt chuông; khối cấu hình khởi động DMEM 0x7E0 (tb ghi giờ đầu + giá trị đặt timer). Cờ `.eqv USE_IRQ` có từ 26/10 (mặc định 1, chỉ ngắt UART_RX — xem E6).
- **`fmt.s` bản đầu 26/10** (Claude viết theo lời Long "A"): `fw/fmt.s` = 3 hàm (ghi thẳng DISP, không nhánh) + bench đo Δ`CYCLE_COUNT` (DMEM 0x100…, DMEM 0x7F0 ≠ 0 → đặt `CPU_CLK_DIV`). **B2-4** trong `tools/test_iss.py`: thay vì chương trình khung `fmt_test.s`, Python đặt PC = nhãn, `$a0`, `$ra` = địa chỉ canh và dựng sẵn biến DMEM + giá trị MMIO → so DISP7…0: `fmt_time` (3 hàm, `fmt_hw` với `RTC_BCD` dựng sẵn), và **`draw` của `main.s`** cho TIME 24/12 h, giây.ms, `fmt_sw`, `fmt_timer`, `fmt_alarm`, `date.txt` trang 2 → 7 test PASS. RTL: `tb/fmt_bench_tb.v` (G1 mặc định; `-DG2`, `-DBCD_COMB`, `-DSLOW` chạy tay) PASS 11 mọi cấu hình; số đo điền plan §8.1 (`evidence/20261026_fmt.log`).

### C1 — Regfile (TV3, S2)
- 32 × 32, 2 cổng đọc tổ hợp, 1 cổng ghi sườn lên, `$0` = 0, **bypass nội bộ theo parameter `G_BYPASS`** (G1 = false, G2 = true; `pipeline-policy.md` §2).
- Test: `G_BYPASS = true`: ghi rồi đọc cùng chu kỳ → ra giá trị mới; `false` → ra giá trị cũ; ghi `$0` → vẫn 0; 1 000 thao tác ngẫu nhiên so với mảng mô hình trong tb.

### C2 — Control (TV3, S3)
- **Code + tb xong 02/10** (Claude viết theo yêu cầu Long): `src/control.v`, `tb/control_tb.v` → PASS 82 646 (89 dòng × 2 bản + 100 000 mã ngẫu nhiên: lạ ⇒ toàn 0).
- Tổ hợp: `instr → 16 tín hiệu` đúng thứ tự và mã ở `control-table.md` §1.1.
- Test: `control.txt` (84 ca + 5 mã lạ phải ra toàn 0). Bản `bcd` tổ hợp (parameter): dòng `bcd` ra `multi = 00`, còn lại như file.

### C3 — CPU G1 (TV3, S3–S4)
- Yêu cầu: `mmio-map.md` §1.1 (2 pha), `isa-spec.md`, `control-table.md` §5. IMEM/DMEM khởi tạo từ `.hex` (parameter tên file).
- Phát dòng trace theo `isa-spec.md` §8 (chỉ trong mô phỏng: `` `ifndef SYNTHESIS ``).
- Test:
  - C3-1: chương trình 28 lệnh của B1-1 → trace == ISS.
  - C3-2: tổng 1…100, giai thừa đệ quy → trace == ISS.
  - C3-3: `div` rồi `mflo` ngay → đúng; PC đứng đúng 32 chu kỳ CPU; `start` của `muldiv` chỉ 1 xung (`control-table.md` §5).
  - C3-5: `addu $t0,$t0,$t1` và `lw $t0,0($t0)` → đúng (kiểm regfile G1 không bypass).
  - C3-4: `lw/sw` lệch 4 byte → dùng word chứa nó.
- Xong khi: **co-sim G1 PASS** (mốc S4).
- **Bản đầu 02/10** (Claude viết): `src/cpu_g1.v`, `tb/cpu_g1_tb.v`, `tools/cosim_mars.py`, `fw/tests/cpu/*.s`. Chưa có ISS/asm.py nên golden **tạm** = MARS 4.5: so 32 GPR + vùng nhớ + số lệnh sau khi chạy (không phải so trace từng lệnh). C3-1 tách `all27.s` (MARS) + `bcd.s` (expect); C3-3 kiểm trong tb cho mọi chương trình (div 33 / bcd 28 chu kỳ CPU, 1 xung start); C3-4 `unaligned.s`; C3-5 `hazard.s`; thêm `mmio.s`, `cp0.s`, chương trình ngẫu nhiên. Trace §8 đã ghi ra `work/cosim/*.csv` để B3 so với ISS sau. Ngắt chưa có (C5).

### C4 — Bus + MMIO + thanh ghi soc (TV3, S5)
- Yêu cầu: `mmio-map.md` §2–§4. Test: `mmio-map.md` §6 BUS-1…5.
- Khối đã có (`rtc`, `display_ctrl`, 02/10) nhận `bus_addr/bus_wdata/bus_we/bus_re` và trả `bus_rdata` = 0 với địa chỉ không phải của mình → bộ giải mã có thể OR các khối, hoặc chốt "khối nào" như §2.
- **Bản đầu 02/10** (Claude viết): `src/soc_regs.v` (`CYCLE_COUNT`, `CAL`, `CPU_CLK_DIV` + sinh `cpu_ce`, `DIV_FLAGS`), giải mã = OR trong `src/soc_top.v`. Test `tb/soc_bus_tb.v` chạy firmware tự kiểm `fw/tests/soc/bus.s` trên `soc_top`: BUS-2, BUS-3, BUS-5, `D = 1526` (1 chu kỳ CPU = 1 526), D mới có hiệu lực từ chu kỳ CPU kế, `DIV_FLAGS`, `CAL`, `CYCLE_COUNT` = 0 ở lệnh đầu, mỗi lw/sw MMIO đúng 1 xung bus. BUS-4 thêm 03/10 (FIFO lap 5 phần tử, `D = 1526`, 3 `lw SW_LAP` → còn đúng 2). BUS-1 kiểm gián tiếp.

### C5 — CP0 + ngắt G1 (TV3, S5)
- Yêu cầu: `isa-spec.md` §5, `mmio-map.md` §5. Test: `mmio-map.md` §6 IRQ-1…4 và:
  - C5-1: ngắt đến khi `div` đang `busy` → nhận sau khi `div` xong, `EPC` = lệnh sau `div`.
  - C5-2: ngắt đến ngay sau `beq` nhảy → `EPC` = đích nhánh.
  - C5-3: ngắt đến khi lệnh vừa xong là `mtc0` → nhận ở lệnh kế tiếp, không trước.
  - C5-4: handler quên xóa PENDING → `eret`, chạy đúng 1 lệnh tại `EPC`, rồi vào lại handler (trace có dòng `INTERRUPT` thứ 2 sau đúng 1 lệnh).
  - C5-5: đo độ trễ: Δ(`CYCLE_COUNT` đầu handler − `IRQ_STAMP`) ở `D = 2` và `D = 1526` (chỉ bật 1 nguồn).
- **Bản đầu 02/10** (Claude viết): `src/irq_ctrl.v` + `tb/irq_tb.v` (IRQ-1…4, PASS 12); nhận ngắt trong `src/cpu_g1.v` (`take_irq`, dòng trace `INTERRUPT`). `fw/tests/cpu/irq.s` (cosim, tb có máy phát sự kiện ở −16): C5-1…C5-4 + "IE = 0 không vào" + "`mtc0` bật IE rồi `mtc0` tắt IE liền sau → không vào", PASS với `cpu_ce` 1/1, 1/3, 1/7. C5-5: đo ở `D = 2` trong `soc_clock_tb` = 3 chu kỳ hệ thống (vòng chờ toàn lệnh 1 chu kỳ); `D = 1526` đo 03/10 bằng `tb/soc_irqlat_tb.v` + `fw/tests/soc/irq_lat.s` (chỉ TICK_1S, 6 + 6 ngắt): vòng chờ 1 lệnh min 1 795 / max 2 963 chu kỳ hệ thống (lý thuyết (D, 2D + 3] — chờ tới pha A kế + lệnh đầu handler); vòng có `div` min 2 417 / max 43 261 (ngắt bị chặn khi `div` stall, ≤ 33 + 2 chu kỳ CPU). Số này cho plan §8 (E3 vẫn đo 3 cách bấm stopwatch). Ghi chú: chặn sau `eret` thừa trong thực tế (eret chạy trong handler thì EXL cũ = 1 đã chặn), giữ theo spec.

### C6 — `soc_top` (TV3, S5)
- Ghép CPU (parameter chọn G1/G2) + bus + mọi khối D*, E* + IMEM/DMEM. Cổng ra: chân đoạn, anode, âm, UART TX/RX, VGA (chỉ để testbench quan sát).
- Test: `system_tb` kịch bản 1–3 PASS (mốc S5).
- **Bản đầu 02/10** (Claude viết): `src/soc_top.v` = `cpu_g1` + `soc_regs` + `irq_ctrl` + `timebase` + `rtc` + `display_ctrl` (reset qua 2 FF). Từ 03/10 thêm `stopwatch`, `cdtimer`, `alarm`, `buttons` (cổng `btn[3:0]`, `G_BTN_ACTIVE_LOW`), ngắt bit 2–5 nối thật; `soc_bus_tb` kiểm từng bit qua firmware (TMR_ZERO → 2, ALARM → 3 + nạp RTC đúng target không kêu, nút C → chỉ 5, nút A → 4 + 5). Chưa có UART/VGA/G2 (D4, D5, C7); bit 6–7 nối 0. Từ 03/10 có `beeper` (`tmr_beep` → mẫu 0x10F0F, chân `beep`) và `system_tb` 1–6 PASS (C8) — đạt mốc "system_tb 1–3" của gói này. Demo `tb/soc_clock_tb.v` + `fw/demo/clock.s` (firmware thật, ngắt `TICK_1S`, `div` + `mul` + `bcd`): 23:59:55 → 00:00:05 qua nửa đêm, PASS 24; màn ảo `work/screen_soc_clock.log`. `fw/demo/clock.s` **không phải** `main.s` (B7 của TV2).

### C7 — CPU G2 (TV3, S5–S8)
- Yêu cầu: `pipeline-policy.md` toàn bộ. Dùng chung control, ALU, muldiv, bcd_unit, regfile; hazard từ B5.
- Test: B6 (mọi file `fw/tests/hazard/*.s` PASS, trace == ISS, số chu kỳ == bảng T1–T8); toàn bộ firmware chạy `system_tb` 1–6 ở chế độ polling.
- Xong khi: **M2 (22/11)**.

### C8 — `system_tb` (TV3, S5–S7)
- 7 kịch bản ở plan §10, `G_N = 50`. Nút do tb tạo **có rung** theo mẫu BTN-1. tb đọc trực tiếp `DISP0…7` và `BLINK_MASK` (tín hiệu nội bộ) để so với `fmt_*.txt`.
- Mỗi kịch bản in `PASS sys_k` / `FAIL sys_k <lý do>`. Chạy cho cả G1 và G2.
- **Bản đầu 03/10** (Claude viết): `tb/system_tb.v` kịch bản 1–6 trên G1 + `fw/main.s`, PASS 565 (~27 s). sys_0 kiểm chính hàm mong đợi của tb với `fmt_*.txt` + `date.txt` (491 dòng); sys_1 quét thêm 215 dòng `date.txt` qua màn trang ngày; sys_4 thêm biên −359 999 999 / −360 000 000 / −2³¹; sys_5 thêm sửa giờ báo thức (C → A → B → A → C); sys_6 thêm 31/01 + 1 tháng → 28/02/2027 và "lưu SET không kêu chuông giờ"; sys_1 thêm 12 h buổi chiều (P). "Khung" = lúc firmware ghi `DISP7`. Hai kỹ thuật chỉ có trong tb (ghi trong báo cáo): **tua giờ** (gán `u_rtc.ms/day/dow`, thay mô phỏng hàng giờ) và **đóng băng** (force `en` bộ chia ms / `tick` timer để firmware vẽ xong 1 khung ở giá trị đứng yên — G_N = 50 với D = 2 chỉ còn 25 lệnh/ms). Đột biến `main.s`: 15/15 bị bắt (`work/mut_fw_20261003.log`), lần đầu 12/15 → thêm 3 ca kiểm và tìm ra 1 lỗi firmware thật (chuông giờ kêu sai khi lưu SET). Kịch bản 7 (UART) thêm 26/10 (E6), PASS 586. Chưa có: chạy trên G2 (C7), so ảnh màn ảo `screen_dump` (D7).

### D1 — ROM ký tự + quét 7 đoạn (TV4, S2)
- Yêu cầu: `display-spec.md` §3, §4. Test: D-1, D-2, D-3, D-6 (`display-spec.md` §9).
- Bản 01/10: `seg7_scan` nhận `disp` (8 × 8 bit), `blink_mask`, `blink_restart` (xung khi CPU ghi `BLINK_MASK`, D2 phát), `bright`; chỉ hỗ trợ `G_MUX = 1`. Bộ đếm nháy nằm trong `seg7_scan`, nên tb D1 kiểm luôn biên D-4 (tick 249/250/499/500) và D-5 ở mức module; D2 vẫn kiểm lại qua bus.

### D2 — `display_ctrl` (TV4, S3)
- Display RAM + `BLINK_MASK` + `BRIGHT` + nối bus (`mmio-map.md` §2). Test: D-4, D-5; ghi `DISPi` qua bus rồi kiểm chân đoạn ở khe i.

### D3 — Bộ tạo âm (TV4, S4)
- Yêu cầu: `display-spec.md` §5. Test: BP-1…3.
- **Bản đầu 03/10** (Claude viết): `src/beeper.v` + `tb/beeper_tb.v` (BP-1…3, REPEAT, ghi 0 = tắt, hw thắng CPU cùng chu kỳ, FREQ = 0 câm, ghi lại → khe 0) PASS 14; nối `tmr_beep` trong `soc_top`, `soc_bus_tb` bit 14 (chân `beep` đảo, mẫu chạy hết). Khe 0 dài 63–64 ms tùy pha lúc ghi (ghi trong header).

### D4 — UART (TV4, S5)
- Yêu cầu: `display-spec.md` §6. Test: U-1…5; thêm U-6: ghi `UART_TX` khi bộ đệm đầy → `TX_DROP = 1`, byte bị bỏ.
- **Bản đầu 26/10** (Claude viết theo lời Long "làm tiếp btl"): `src/uart.v` (TX bộ đệm 1 byte + thanh ghi dịch; `TX_READY` = bộ đệm trống; RX 2 FF + kiểm start ở `G_BIT/2` + FIFO 64 byte; cờ dính "sự kiện thắng lệnh xóa"; `rx_ev` chỉ khi byte vào FIFO, byte bị bỏ do đầy không báo ngắt) + `tb/uart_tb.v` U-1…U-6 + nhiễu ngắn, FIFO rỗng, xóa cờ cùng chu kỳ sự kiện, 2 khung liền đúng 10 bit → PASS 28. Nối `soc_top` (cổng `uart_rx`/`uart_tx`, parameter `G_BIT`, ngắt bit 6/7). `fw/tests/soc/uart.s` + `tb/soc_uart_tb.v` (vòng lại tx → rx, chạy G1 và `-DG2`) PASS 9; thêm vào `cosim_iss` SOC. Đột biến 15/15 (`evidence/20261026_uart.log`). Lỗi thật tìm được: bản đầu nghỉ thừa 1 chu kỳ giữa 2 khung. Kịch bản 7 xong 26/10 (E6, `system_tb` chạy `G_BIT = 8`). Chưa có: test ở `G_BIT = 434`.

### D5 — VGA (TV4, S9, tầng 2)
- Yêu cầu: `display-spec.md` §7. Test: V-1…3 (`vga_points.txt` 595 điểm). Số đo: LUT/BRAM (BRAM phải = 0).
- **Bản đầu 26/10** (Claude viết theo lời Long "A"): `src/vga_digits.v` (module `vga_map` tổ hợp (x, y) → (ô, đoạn) + `vga_digits` bộ đếm 800 × 525, pixel enable mỗi 2 chu kỳ, `char_rom` dùng lại, hsync/vsync/rgb chốt cùng cạnh). Gắn **trong `display_ctrl`** (cùng Display RAM; `seg7_scan` xuất `blink_ph` để VGA nháy cùng pha LED); `soc_top` thêm chân `vga_hs`, `vga_vs`, `vga_rgb[11:0]`. Test `tb/vga_digits_tb.v`: V-1 (4 kiểm thời gian), V-2 (595 điểm), V-3 (so **mọi** pixel 640 × 480 với mô hình trong tb + `work/vga_frame.ppm`); `display_ctrl_tb` +2 kiểm cùng pha nháy. Đột biến RTL 9/9 bị bắt. Số đo (Yosys, `inference` — chưa có Vivado): VGA riêng 143 LUT6 + 25 FF + 0 BRAM (`synth; abc -lut 6`); `soc_top` G1 `-run :map_ffs` 16 303 → 16 933 ô, RAMB36E1 vẫn 1 (BRAM của VGA = 0). `evidence/20261026_vga.log`.

### D6 — `alarm.s` + `chime.s` (TV4, S6–S7)
- `alarm.s`: chế độ ALARM (chọn, bật/tắt, chỉnh giờ phút → ghi `ALARMi` dạng `MINUTE`); khi `HIT`: chuông `0x10F0F` tới khi bấm nút bất kỳ; nút C = snooze 5 phút (firmware tự so `MS_OF_DAY`); tự tắt sau 60 s.
- `chime.s`: bật/tắt chuông giờ; kêu `0x00005` khi qua mỗi giờ tròn.
- Test: kịch bản 5 của `system_tb` + test ISS: snooze qua nửa đêm (23:58 + 5 phút → 00:03 ngày sau).
- **Bản đầu 03/10** nằm trong `fw/main.s` (xem B7): AL1 mặc định 07:00 thứ 2–6; ALARM: B chọn AL1…AL4 → trang chuông giờ `CH o`, A bật/tắt, C (không chuông) sửa giờ/phút báo thức; snooze = 5 phút tính từ dấu thời gian `BTN_EVENT`; chuông giờ bỏ qua lần nhảy giờ do SET (chờ `ARM` xong mới đặt lại). sys_5 PASS; snooze qua nửa đêm có xử lý (mod 86 400 000) nhưng chưa có test (chờ ISS).

### D7 — Màn hình ảo, thay board (TV4, S7)
- `tb/screen_dump.v`: trong `system_tb`, mỗi khi quét xong 1 vòng 8 khe **mà ảnh khác lần trước** thì ghi 1 dòng `t_ms S7…S0 LIT` (Si = `{dp, gfedcba}` thấy trên chân lúc anode i sáng; LIT bit i = chữ số i có sáng — đọc từ chân đoạn + anode, **không** đọc thanh ghi) vào file log. **Bản đầu xong 02/10** cùng `tools/screen.py` (chữ / `--big` / `--gif` / `--png`), dùng trong `tb/clock_demo_tb.v`.
- `tools/screen.py`: đọc log → vẽ 8 chữ số 7 đoạn ra ảnh PNG/GIF (đổi chế độ, nháy, đếm sang âm). Đây là "demo" thay cho board và là hình H10.
- Test: kịch bản 1–6 → ảnh khớp `fmt_*.txt` (so tự động từ log, ảnh chỉ để xem).
- **So tự động 26/10** (Claude, Long chọn B): `screen_dump` gắn vào `system_tb` (log `work/screen_system.log`, có thêm `event round`). Mỗi vòng quét mà Display RAM / BLINK_MASK / pha nháy / BRIGHT không đổi suốt vòng: ảnh từ **chân** = RAM qua `seg7.txt` (chữ số tắt do nháy → không sáng). Cùng với các kiểm RAM = `fmt_*.txt` của kịch bản 1–7 → chân = `fmt_*.txt` (bắc cầu; so trong tb lúc chạy thay cho so log bằng Python). sys_6 thêm chờ 600 ms ở SET để có vòng nháy tắt. Kết quả: 1 677 vòng so, 38 vòng có ô tắt, 0 sai; đột biến RTL đường RAM → chân 4/4 bị bắt (ROM mã 3, thứ tự anode, dp, pha nháy) — trước đó `system_tb` không thấy được loại lỗi này. `evidence/20261026_d7.log`.

### E1 — Timebase (TV5, S2)
- Cổng + yêu cầu: `timer-spec.md` §2. Test: TB-1…5 (`timebase_len.txt`, `timebase_total.txt`).

### E2 — RTC (TV5, S3)
- Yêu cầu: `timer-spec.md` §3. Test: RTC-1…5; thêm RTC-6: `TICK_1S` sau đúng 1 000 tick, bị xóa khi `ARM` nạp; RTC-7: reset → `ms = 0`, `day = 0`, `dow = 6`.

### E3 — Stopwatch + timer âm (TV5, S3)
- Yêu cầu: `timer-spec.md` §4, §5. Test: SW-1…5, TM-1…5; thêm SW-6: `SRC = 0`, CPU ghi lap → vào FIFO đúng giá trị.
- **Bản đầu 03/10** (Claude viết): `stopwatch`, `cdtimer` trong `src/timers.v`. `tb/stopwatch_tb.v` (SW-1…6, nút có rung qua `buttons` thật, va chạm cùng chu kỳ: RESET `SRC = 1` + nhấn A, `SRC = 0` + nhấn A, FIFO đầy + lap + đọc) PASS 32; `tb/cdtimer_tb.v` (TM-1…5, ghi CTL không xóa ZERO, ghi `TMR_VALUE` trùng tick khi = 1 → không ZERO) PASS 20. Quyết định: CPU chỉ thắng nút A khi ghi `SRC = 0` (đặt RUN); ghi `SRC = 1` (vd RESET) cùng chu kỳ không nuốt nút A — bản đầu sai chỗ này, mutation bắt.

### E4 — Alarm + nút (TV5, S4)
- Yêu cầu: `timer-spec.md` §6, §7. Test: AL-1…5, BTN-1…4; thêm AL-6: ghi 1 vào `HIT` → xóa, ghi 0 → giữ.
- **Bản đầu 03/10** (Claude viết): `alarm` trong `src/timers.v` (`target` = dịch-cộng, không dùng DSP), `src/buttons.v`. `tb/alarm_tb.v` (AL-1…6 với `rtc` thật, chỉ ALARM3 khớp, `MINUTE` = 1440) PASS 15; `tb/buttons_tb.v` (BTN-1…4, 2 nút cùng chu kỳ → số nhỏ trước, giữ 500 ms → 1 sự kiện, quét 50 pha cạnh nhấn so với tick cho dấu thời gian, bản `G_ACTIVE_LOW = 1` khớp từng chu kỳ) PASS 20. Lỗi tìm được: reset đưa 2 FF đồng bộ về 0 → bản active-low sinh 1 lần nhấn ma sau reset (đã sửa: reset về mức nhả). BTN-4 với G_N = 50: xung nhiễu 1 chu kỳ (không phải 1 µs thật).

### E5 — `set.s` (TV5, S6)
- Chế độ SET: chỉnh giờ, phút, (giây → 00), ngày, tháng, năm; giới hạn trường (giờ 0–23, ngày theo tháng, 29/02 chỉ năm nhuận); `BLINK_MASK` theo `display-spec.md` §8; lưu = ghi `SET_MS`, `SET_DAY` (đổi ngày-tháng-năm → số ngày từ 2000) rồi `ARM`.
- Test trên ISS: mọi dòng `date.txt` (đổi qua lại số ngày ↔ ngày-tháng-năm-thứ); 31/01 + 1 tháng → 28/02 hoặc 29/02 (chọn và ghi rõ); kịch bản 6 của `system_tb`.
- **Bản đầu 03/10** nằm trong `fw/main.s` (xem B7): chọn **kẹp** (31/01 + 1 tháng → 28/02, năm nhuận 29/02). Đổi số ngày → ngày-tháng-năm theo chu kỳ 4 năm (1 461 ngày), từ 01/03/2100 cộng 1 để bỏ 29/02/2100 → đúng cả 215 dòng `date.txt` (tới 2179, kiểm trên RTL qua sys_1 thay cho ISS chưa có). SET chỉ chỉnh năm 2000–2099.

### E6 — Sync (TV5, S8)
- Yêu cầu: `timer-spec.md` §9. Test: SY-1 (`sync_sentences.txt`), SY-2 (`sync_cal.txt`), kịch bản 7 của `system_tb` (testbench đóng vai PC: gửi câu qua chân RX, đọc câu trả lời ở chân TX). Không có `sync_host.py` (không có board).
- **Bản đầu 26/10** (Claude viết theo lời Long "A"): phần sync nằm **trong `fw/main.s`** (asm chưa có `.include`; mục "đồng bộ giờ"), gọi mỗi vòng chính sau `ringchk`. Gom câu tới `\n` (1 byte/word, ≤ 32), chụp giờ ngay khi lấy `\n`, kiểm khung/checksum hex hoa/số 1–9 chữ số/phạm vi; `$Q` → `$R`; `$T` → CAL (công thức §9, chia trước, chênh ngày 0/±1, chặn |CAL| ≤ 655 360 theo §2) rồi `rtcset` (hàm chung với SET); timer về 0 → `$Z`. Quyết định spec chưa nói: ~~câu `$T` hợp lệ nào cũng thành T1~~ → **Long chốt 26/10: giữ T1 khi 0 ≤ I < 10 phút, cộng dồn D (timer-spec §9)**, test `test_e6_t1_kept_when_under_10_min`, đột biến 6/6, sys_7 bước 5 CAL 66 100; SET bằng nút xóa T1; `$R`/B2 là giờ lúc **firmware lấy** `\n` khỏi FIFO (polling: trễ ≤ 1 vòng chính); phát bằng chờ `TX_READY` từng byte (≤ 21 byte ≈ 1,8 ms, vòng chính đứng). Test: SY-1 + SY-2 trong `tools/test_iss.py` (6 test, thêm ca biên không có trong vector), kịch bản 7 `system_tb` (G1 và G2 qua `cosim_iss --g2`). Đột biến 22/22 trên ISS (+1 tương đương) + 3/3 trên RTL (`evidence/20261026_sync.log`). Kéo theo: IMEM `soc_top` 2048 (Q5), `system_tb` `G_BIT = 8`.
- **Ngắt UART_RX 26/10** (Long chọn B): `USE_IRQ = 1` → handler 0x180 (cất `$t0–$t2`, `$ra` vào `$k1`; xóa PENDING bit 6 **trước** khi lấy byte) gọi `sy_rx` = gom byte + chụp giờ ở `\n` + cờ `V_SRDY`; `sync` ở vòng chính chỉ xử lý câu (và gọi `sy_rx` với ngắt tắt để vét byte còn lại → `USE_IRQ = 0` là polling như cũ). Câu trước chưa xử lý thì byte nằm lại FIFO. 3 cặp đọc `MS_OF_DAY` → `DAY_SHADOW` của vòng chính bọc tắt ngắt (handler đọc `MS_OF_DAY` sẽ chụp lại `DAY_SHADOW`). Đo: `$R` = ms lúc LF vào FIFO ±1 ms ở G_N = 50 (polling: +7 ms), G1 và G2. Test thêm: `test_e6_irq_handler_saves_registers` (803 ngắt từ boot, so thanh ghi ở mỗi `eret`). main.s 1 136 lệnh. `evidence/20261026_irq.log`. Hồi quy: `run_unit.sh` chạy thêm `system_tb` với bản `USE_IRQ = 0` (`work/main_poll.s`, `+poll`), tb kiểm `IRQ_ENABLE` khớp chế độ (lắp nhầm firmware ↔ cờ: FAIL cả hai chiều).

### E7 — RTC BCD (TV5, S8, tầng 2)
- Yêu cầu: `timer-spec.md` §8. Test: 23:59:59.999 → 00:00:00.000; 09:59:59.999 → 10:00:00.000; 19:59:59.999 → 20:00:00.000; so với RTC nhị phân 1 ngày mô phỏng (`G_N = 50`).
- **Bản đầu 26/10** (Claude viết, cần cho `fmt_hw` của B7): `src/rtc_bcd.v` (ghi thắng tick cùng chu kỳ; so "≥ giá trị cuối" nên chữ số sai tự về 0) + `tb/rtc_bcd_tb.v` PASS 11. "1 ngày ở `G_N = 50`" = 4,3·10⁹ chu kỳ, quá lâu → thay bằng mọi ranh giới giây (86 400 lần nạp + 2 tick) và 1 000 000 tick liền qua nửa đêm, so với mô hình ms → BCD trong tb. `soc_top` parameter `G_BCD_RTC` (mặc định 0 → 15 442 ô như cũ; 1 → +311). Đột biến 8/8.

### X — Thí nghiệm (S9; kết quả điền plan §8.3)
| ID | Chủ | Cách làm | File ra |
|---|---|---|---|
| E1′ | TV5 | **mô phỏng thạch anh lệch:** `timebase` riêng, `G_N = 50 000` thật, tb đặt chu kỳ clock = 20 ns × (1 − e) với e = +50, −37, +200 ppm; đo giờ "thật" của 1 000 tick → ppm; tính `CAL` bằng công thức firmware (`sync_cal`) → chạy lại → ppm còn lại | `evidence/exp_E1/bang.md` + đồ thị |
| E2′ | TV5 | timer 2 000 ms ở `G_N = 50 000` (1·10⁸ chu kỳ, module timer riêng): `ZERO` đúng chu kỳ 100 000 000 khi `CAL = 0`; với `CAL` ≠ 0 khớp công thức tổng `timebase_total` | `evidence/exp_E2/` |
| E3 | TV3 + TV2 | G1, `D` = 2 / 100 / 1526; tb tạo 1 000 lần bấm stopwatch; so 3 cách: polling đọc `MS_OF_DAY`, ngắt, capture phần cứng → sai số + độ trễ ngắt | `evidence/exp_E3/bang.md` |
| E4′ | TV4 | waveform chân anode/đoạn quanh ranh giới khe, 3 giá trị `G_SLOT`, có/không `G_BLANK` → chỉ ra khoảng chồng gây bóng ma; ảnh VGA 1 khung (`.ppm`) | `evidence/exp_E4/` ảnh waveform |
- Mỗi số phải ghi: cách đo, số lần, sai số, nhãn `verified` khi có file log.

### R — Báo cáo (biên tập + mọi người)
- Lịch đoạn viết theo sprint: `KE-HOACH` §3. Hình H1–H10: `KE-HOACH` §5.
- Kiểm cuối (S10): mọi con số trong báo cáo trỏ được về 1 file trong `evidence/`.

## 3. Ma trận "yêu cầu → test" (người duyệt dùng để soát thiếu)
| Yêu cầu | Test |
|---|---|
| 28 lệnh đúng ngữ nghĩa | A1, A2, A3 vector · B1-1 · C3-1 · co-sim |
| Không delay slot, nhánh ở EX, phạt 2 | B6 + bảng T3/T4 |
| Forwarding, load-use, busy | B5, B6 |
| 2 pha G1 / BRAM đồng bộ | C3-3, C3-4, BUS-4 |
| MMIO đúng 1 lần mỗi lệnh | BUS-4 |
| Ngắt G1 | C5-1…5, IRQ-1…4 |
| Chuẩn ms: bộ chia + `CAL` | TB-1…5, SY-2, E1′, E2′ |
| Không lệch pha khi start/stop | SW-1…3, TM-1 |
| Thời gian âm | TM-1…4, `fmt_timer.txt`, kịch bản 4 |
| Báo thức | AL-1…5, D6, kịch bản 5 |
| Nút chống rung, dấu thời gian | BTN-1…4, kịch bản 2 |
| Hiển thị (quét, nháy, sáng) | D-1…6, D7, E4′ |
| Âm thanh | BP-1…3 |
| Sync + UART | U-1…6, SY-1…2, kịch bản 7 |
| VGA | V-1…3 |
| Hiệu năng / DSE | A4, plan §8.1–8.2 |
| Golden không sai chung nguồn | đối chiếu MARS (§0.2) |

## 4. Quyết định mặc định (Claude đề xuất, **áp dụng luôn**; ai phản đối thì báo nhóm chat trước 07/10, Long chốt)
| # | Đề xuất | Lý do |
|---|---|---|
| Q1 | G1 chạy 2 pha (`mmio-map.md` §1.1) thay "BRAM sườn xuống" | bản sườn xuống không còn chỗ cho `lw` |
| Q2 | Công thức `CAL` + bộ lọc chia trước (`timer-spec.md` §9) | bản cũ sai 8% / tràn 32 bit |
| Q3 | `set.s` → TV5; `alarm.s` + `chime.s` → TV4 | chia tải firmware khỏi TV2 |
| Q4 | Chuyển C8 `system_tb` từ TV3 sang TV1 | TV3 giữ 8 gói trên đường găng; TV1 rảnh S5–S7 |
| Q5 | IMEM parameter `G_IMEM_AW` (mặc định 10 → 1 024 lệnh) | ước firmware ~1 000 lệnh, sát giới hạn. **26/10:** `main.s` + sync = 1 093 lệnh → `soc_top` đặt 11 (2 048 lệnh) theo đường đã ghi trong isa-spec §7; **Long duyệt giữ 2 048 (26/10)**. Không có Vivado trên máy → kiểm bằng Yosys: IMEM G1 trước đó bị dựng bằng LUT (cổng đọc `imem[0]` lúc reset); sửa `cpu_g1.v` về 1 cổng → IMEM vào BRAM, `soc_top` G1 16 933 → 13 364 ô, 3 RAMB36E1 (`evidence/20261026_imem_bram.log`). Vivado vẫn chưa chạy |
| Q6 | UART 434 chu kỳ/bit, lấy mẫu giữa bit; VGA = clock enable; khóa chống rung 10 ms; alarm theo `MINUTE` | giữ đơn giản, một miền clock |
| — | **Đã chốt bởi Long 01/10:** Verilog-2005 · chỉ mô phỏng · thời gian âm = đếm ngược qua 0 sang âm · bảo vệ tuần 14 | |
