# HOI-DAP-CODE — 20 phút thầy hỏi xoáy code (bảo vệ 25/11/2026)

File cho người đọc là nhóm, để tập. Theo `report/BRIEF-25-11.md` mục 3b. Gồm 6 câu chắc chắn bị hỏi, 5 đến 7 câu cho mỗi lát TV1–TV5 (thêm B6, C6, F6 ngày 12/11 cho ca chia có dấu, thí nghiệm bấm nút E3 và hiệu chỉnh `CAL`).

**Nguồn và mức chắc chắn.**
- Brief mục 3b ghi "lấy từ bài P và C0". Các bài P1–P5, C0 và U1 nay đã có trong `learn/on-tap-btl/nguon/02-code.md` (12/11); phần đã viết ở đây lấy từ V0, code trong `src/` và `docs/pipeline-policy.md`, chưa đối chiếu lại từng câu với bài P (unverified). Câu mới B6, C6, F6 lấy từ bài P1, C0, U1.
- Mọi `file:dòng` đã grep/đọc lại ngày 12/11/2026 trên `src/` hiện tại. Nếu ai sửa `src/` thì dòng lệch, kiểm lại bằng `grep -n`. (verified, nhưng chỉ đúng tại thời điểm này)
- Lát TV1–TV5 theo bảng mục 1 của brief. Tên người ứng với TV chưa chọn.
- Chưa có số "mất bao lâu" của từng lệnh test. Chạy thử trên máy trình chiếu trước ngày bảo vệ. (unverified)

**Cách dùng.** Thầy chỉ vào đâu thì chủ lát mở đúng `file:dòng`, đọc dòng đó trước, rồi mới trả lời. Chưa chắc thì nói "em chưa chắc, em mở code kiểm". Không đoán.

---

## A. Sáu câu chắc chắn bị hỏi

### A1. Vì sao nhánh quyết định ở EX mà không ở ID?
**Chỉ vào:** `src/cpu_pipe.v:175-178` (`take`), `:131-132` (`opA`/`opB` sau forwarding), `:293-294` (nạp đích, hủy lệnh vừa lấy); lý do ghi ở `docs/pipeline-policy.md` §5 (dòng 135 trở xuống).
**Đáp:** Ở tầng EX hai toán hạng đã đi qua forwarding (`opA`, `opB`), nên so sánh `eq` dùng lại đường sẵn có. Đặt ở ID thì phải thêm bộ so sánh, thêm đường forwarding về ID, và phải stall khi nhánh phụ thuộc lệnh ngay trước (ALU 1 chu kỳ, `lw` 2 chu kỳ). Cái giá là phạt 2 chu kỳ mỗi lần nhảy thật, bài mẫu ở ID chỉ phạt 1. Em chọn ít ca đặc biệt hơn để ít lỗi hơn; số đo: 157 608 chu kỳ mất vì nhánh, 22,9 % (`so_ktmt.py`).

### A2. Vì sao G1 cần 2 pha?
**Chỉ vào:** `src/cpu_g1.v:19-21` (comment giải thích), `:58-59` (`ph_a`, `ph_b`), `:192` (IMEM chốt lệnh ở pha A), `:202` và `:211` (`phb` đổi pha).
**Đáp:** IMEM và DMEM trong FPGA là BRAM đọc đồng bộ: địa chỉ chốt ở một cạnh clock thì dữ liệu mới có ở cạnh sau. Vì vậy một chu kỳ CPU chia hai cạnh `cpu_ce`: pha B làm việc với bộ nhớ dữ liệu và ngoại vi, pha A cập nhật PC, regfile, CP0 và chốt lệnh kế. Ghi nhớ: B (bộ nhớ) trước, A (cập nhật) sau. Hệ quả: G1 chạy D = 2, tức CPU bước mỗi 2 chu kỳ hệ thống.

### A3. `slt` khi tràn thì đúng không?
**Chỉ vào:** `src/alu.v:26` (`lt`), `:35` (`ALU_SLT: y = {31'd0, lt}`), comment giải thích ở `:21-25`.
**Đáp:** Đúng. Nếu chỉ nhìn bit dấu của `a - b` thì sai khi phép trừ tràn: ví dụ `a = 0`, `b = 0x80000000` thì `diff[31] = 1` nên ra 1, trong khi đúng là 0 vì `b` là số âm nhỏ nhất. Dòng 26 xử lý bằng cách: nếu hai bit dấu khác nhau thì lấy `a[31]`, ngược lại mới lấy `diff[31]`. Kiểm chứng: cài lỗi `lt = diff[31]` thì `alu_tb` báo `FAIL` đúng ca `ctl=5 a=0 b=80000000` (V0, mục Sửa tại chỗ).

### A4. Forwarding ưu tiên nguồn nào?
**Chỉ vào:** `src/hazard.v:46-48` (toán hạng A), `:51-53` (toán hạng B), `src/cpu_pipe.v:131-132` (MUX chọn).
**Đáp:** Ưu tiên EX/MEM (mã `10`) trước MEM/WB (mã `01`), còn không trùng thì dùng giá trị đã đọc ở ID (`00`). Vì EX/MEM giữ kết quả mới hơn: nếu hai lệnh liền trước cùng ghi một thanh ghi thì lệnh gần hơn mới đúng. Điều kiện còn có đích khác `$zero` (`dst != 0`), vì `$0` luôn bằng 0, không được lấy tắt.

### A5. Ngắt đến lúc đang `div` thì sao?
**Chỉ vào:** `src/cpu_pipe.v:202-204` (`take_irq` có `!stall_busy` và `idex_multi == 2'b00`), `:148` (`stall_busy`), `:122` (`irq_epc`); `docs/pipeline-policy.md` §10 (dòng 276, bảng "Sự kiện đến khi `div` đang chạy").
**Đáp:** Ngắt không được nhận khi `div`/`bcd` chưa xong: chờ `div` xong rồi mới nhận, EPC là lệnh sau `div`. Lý do (inference, suy từ code, chưa thấy ghi rõ): `div` đã chiếm trạm EX và sắp ghi HI/LO, hủy giữa chừng thì trạng thái nửa vời. G1 tương tự: `take_irq` có `!stall` (`src/cpu_g1.v:166`). Kiểm chứng: đột biến "bỏ chặn `div`" bị cosim bắt (`pipeline-policy.md` §10).

### A6. Code này ai viết, em hiểu tới đâu?
**Chỉ vào:** phụ lục A của báo cáo; `report/BRIEF-25-11.md` mục 0; lát của mình (bảng mục 1).
**Đáp:** Nói thật: phần lớn code do AI viết, nhóm đã khai ở phụ lục A. Mỗi người đã đọc từng dòng lát của mình, tự chạy lệnh test của lát đó và biết một đột biến nào thì test nào bắt. Phần mở rộng (UART, VGA, `CAL`, phụ lục D) có AI hỗ trợ, đã khai. Chỗ nào chưa chắc thì mở code kiểm, không đoán.

---

## B. TV1 — EX, số học (`alu.v`, `muldiv.v`, `cpu_g1.v:87-106`, `cpu_pipe.v:129-183`)
Lệnh chạy khi bị yêu cầu: `bash tools/run_unit.sh alu muldiv`.

### B1. ALU làm những phép gì, chọn bằng gì?
**Chỉ vào:** `src/alu.v:17-18` (8 mã), `:28-39` (`case (ctl)`), `:38` (`default`).
**Đáp:** Tám phép (cộng, trừ, and, or, xor, `slt`, dịch trái, dịch phải số học), chọn bằng `ctl` 4 bit qua một `case`. Đây là MUX 8 đường: các phép đều có mạch riêng chạy song song, `ctl` chỉ chọn kết quả nào ra `y`. Mã lạ thì `y = 0` nhờ `default`.

### B2. `output reg [31:0] y` có phải ô nhớ không?
**Chỉ vào:** `src/alu.v:13` (khai `reg`), `:28` (`always @*`), `:38` (`default`).
**Đáp:** Không. `reg` chỉ là kiểu biến Verilog bắt dùng cho tín hiệu gán trong `always`. Ô nhớ chỉ có khi khối chờ cạnh clock (`always @(posedge clk)`) hoặc có đường chạy không gán. Ở đây là `always @*` có đủ `default`, nên đổi `a`, `b`, `ctl` thì `y` đổi ngay, không cần clock.

### B3. Chia hoạt động thế nào, mất bao nhiêu chu kỳ?
**Chỉ vào:** `src/muldiv.v:44-48` (một bước chia khôi phục), `:51` (`last`), `:53-54` (`busy`, `done`).
**Đáp:** Chia khôi phục từng bit: dịch số dư sang trái, thử trừ (33 bit để thấy bit âm), nếu không âm thì bit thương là 1 và lấy hiệu, nếu âm thì giữ số dư cũ. Làm 32 bước, cộng 1 chu kỳ bắt đầu, nên 33 chu kỳ (bảng 7 chia 2 trên slide 10). Suốt thời gian đó `busy` bật và CPU phải chờ.

### B4. Chia cho 0 xử lý thế nào?
**Chỉ vào:** `src/muldiv.v:50` (`div0`), `:54` (`done` ngay), `:64-66` (`lo <= 0`, `hi <= a`, `dz <= 1`).
**Đáp:** Chia 0 không chạy 32 bước: `done` lên ngay ở chu kỳ đầu, nên chỉ 1 chu kỳ. Kết quả quy ước `LO = 0`, `HI = a`, và cờ `dz` bật để biết đã chia 0. Quy ước này khớp với ISS, test `multi` có ca `div` chia 0 (slide dự phòng 5).

### B5. Ở G2, ALU lấy toán hạng từ đâu?
**Chỉ vào:** `src/cpu_pipe.v:131-132` (`opA`, `opB`), `:148` (`stall_busy`), `:175-178` (`take`, dùng `opA`/`opB`).
**Đáp:** Từ MUX forwarding: `fwd = 10` lấy `exm_res`, `01` lấy `wb`, `00` lấy giá trị `idex_a`/`idex_b` đã đọc ở ID. Cùng hai toán hạng đó đi vào ALU, vào so sánh nhánh, và vào bộ chia. Khi `div` đang chạy, `stall_busy = 1` giữ trạm EX nên toán hạng đứng yên đến khi xong.


### B6. Chia có dấu: `0x80000000` chia `0xFFFFFFFF` ra bao nhiêu?
**Chỉ vào:** `src/muldiv.v:72` (`quo <= a[31] ? -a : a`), `:84-85` (sửa dấu `lo`, `hi`), `tb/vectors/div.txt:68`.
**Đáp:** `0x80000000` là −2 147 483 648, chia −1 lẽ ra ra +2 147 483 648 mà 32 bit không chứa được. Code lấy trị tuyệt đối (`|0x80000000| = 2^31` vẫn đúng khi hiểu không dấu), chia 32 bước ra thương `2^31`, hai số cùng dấu nên không đổi dấu: `LO = 0x80000000`, `HI = 0`. Dòng `80000000 FFFFFFFF 80000000 00000000 0` có trong `div.txt`, bài thử `muldiv_tb` PASS. (verified: dòng vector; kết luận "không tràn" theo nghĩa LO giữ nguyên bit là inference từ code)

---

## C. TV2 — hazard, forwarding, MEM, WB (`hazard.v`, `cpu_pipe.v:112-128, 184-206, 260-277`, `cpu_g1.v:119-147`)
Lệnh chạy: `bash tools/run_unit.sh hazard`, `python tools/cosim_iss.py --g2 --rand 0`.

### C1. Điều kiện forwarding đủ những gì?
**Chỉ vào:** `src/hazard.v:46` (`exmem_reg_write && exmem_dst != 0 && exmem_dst == idex_rs`).
**Đáp:** Ba điều kiện cùng đúng: lệnh ở tầng sau có ghi thanh ghi, đích khác `$zero`, và đích trùng thanh ghi nguồn của lệnh ở EX. Thiếu `dst != 0` thì lệnh ghi vào `$0` có thể bị lấy tắt, sai vì `$0` luôn bằng 0. Test `zero_reg` kiểm đúng chỗ này.

### C2. Load-use dừng khi nào, vì sao forwarding không cứu được?
**Chỉ vào:** `src/hazard.v:39-40` (`stall_lu`), `src/cpu_pipe.v:292` (`if (!stall_lu)` giữ PC/IF-ID).
**Đáp:** `lw` chỉ có dữ liệu ở cuối tầng MEM, trong khi lệnh sau cần nó ở đầu EX, nên chuyển thẳng không kịp. Điều kiện: lệnh ở EX là `lw` đích khác 0, và lệnh ở ID thật sự dùng `rs` hoặc `rt` trùng đích (`uses_rs`, `uses_rt`). Kết quả: dừng đúng 1 chu kỳ, lệnh ở EX thành bong bóng một nhịp.

### C3. Dòng nào chèn bong bóng khi nhảy? `flush` dùng làm gì?
**Chỉ vào:** `src/hazard.v:41` (`assign flush = taken`), `src/cpu_pipe.v:205` (`id_ok`), `:279` (`idex_v <= id_ok`), `:294` (`ifid_v <= !take`).
**Đáp:** Trung thực: dây `flush` có trong `hazard.v` nhưng ở `cpu_pipe.v` chỉ được khai (dòng 115), nối vào `hazard` (127) và nhét vào `unused_ok` (302), không điều khiển gì. Bong bóng thật được tạo bằng cờ hợp lệ: `id_ok = 0` thì `idex_v` ghi 0 (bong bóng vào ID/EX), `ifid_v <= !take` thì lệnh vừa lấy nhầm thành bong bóng. Em nói thẳng điều này nếu thầy hỏi "flush ở đâu". (verified: grep `flush` trong `src/cpu_pipe.v` ra 3 dòng 115, 127, 302)

### C4. MEM/WB ghi regfile cùng lúc ID đọc thì sao?
**Chỉ vào:** `src/cpu_pipe.v:109` (`regfile #(.G_BYPASS(1))`), `src/regfile.v:41-46`.
**Đáp:** G2 bật `G_BYPASS = 1`: nếu đang ghi vào đúng ngăn đang đọc thì cổng đọc trả luôn `wd` (dòng 45-46), không chờ cạnh clock sau. Nếu thiếu, lệnh ở ID cách lệnh ở WB 3 nhịp sẽ đọc giá trị cũ. G1 đặt `G_BYPASS = 0` (`src/cpu_g1.v:84`) vì ghi ở pha A, đọc ở lệnh kế, không chồng nhau.

### C5. Lệnh `lw`/`sw` chạm bộ nhớ ở tầng nào, ngoại vi thì sao?
**Chỉ vào:** `src/cpu_pipe.v:190-191` (`bus_we`, `bus_re`), `:198` (`retire`), `src/cpu_g1.v:119-147` (G1 pha B).
**Đáp:** Ở G2, `bus_we`/`bus_re` bật khi lệnh ở tầng MEM, hợp lệ, là `sw`/`lw` và địa chỉ nằm trong vùng MMIO. Lệnh sai nhánh (đã bị hủy) có `exm_v = 0` nên không chạm bus: đây là điều test `mmio_once` kiểm. Ở G1 việc này nằm ở pha B (`bus_re = ph_b && mem_read && in_mmio`).


### C6. Thí nghiệm bấm nút E3: ngắt hay polling chính xác hơn?
**Chỉ vào:** `fw/exp/e3_irq.s:9-10` (lệnh đầu handler đọc `MS_OF_DAY`), `evidence/20261026_exp_e3.log` (bảng trễ), `report/2.5-e3-thi-nghiem.md`.
**Đáp:** Ở `CPU_CLK_DIV = 1526` (CPU như đồng hồ 32 kHz) ngắt trễ trung bình 466 µs còn polling 740 µs, nên ngắt tốt hơn khoảng 37 %; ở D = 2 cả hai dưới 1 µs. Capture phần cứng (stopwatch `SRC = 1`) và dấu thời gian trong `BTN_EVENT` cho trễ 0, đúng chu kỳ nhấn, 6 000 trên 6 000 lần. Ngắt chậm nhất khoảng 34 lệnh vì nếu nút đến lúc `div` (33 chu kỳ) vừa bắt đầu thì ngắt phải chờ. (verified: số từ log; số 37 % là phép tính của file này `1 − 466/740`)

---

## D. TV3 — ID, điều khiển (`control.v`, `regfile.v`, `cpu_g1.v:61-86`, `cpu_pipe.v:85-111`, `:278-290`)
Lệnh chạy: `bash tools/run_unit.sh regfile control`.

### D1. Chọn một lệnh, nói nó bật tín hiệu nào.
**Chỉ vào:** `src/control.v:87` (`lw`), `:89` (`sw`), `:82` (`addiu`).
**Đáp:** `lw` bật `alu_src` (dùng immediate), `mem_read`, `mem_to_reg`, `reg_write`, và ALU làm phép cộng ra địa chỉ. `sw` bật `alu_src`, `mem_write`, không ghi regfile. `addiu` chỉ qua ALU, không động bộ nhớ. Toàn bộ 28 lệnh là một bảng chân lý như vậy, 17 tín hiệu ra (slide 7 chỉ hiện 6 cột).

### D2. `$zero` được bảo vệ thế nào?
**Chỉ vào:** `src/regfile.v:33` (ghi: `wa != 5'd0`), `:45-46` (đọc: `ra == 5'd0 ? 0`).
**Đáp:** Hai lớp che nhau: khi ghi, bỏ qua `wa = 0`; khi đọc, ngăn số 0 luôn trả 0. Bỏ riêng một lớp thì test vẫn PASS vì lớp kia che (lỗi tương đương), phải bỏ cả hai mới thấy. Đây là ca đột biến thứ 3 trong V0.

### D3. Regfile đọc tổ hợp, ghi theo clock nghĩa là gì?
**Chỉ vào:** `src/regfile.v:28` (`always @(posedge clk)` ghi), `:45-46` (`assign` đọc).
**Đáp:** Đọc là `assign`: đổi `ra1` thì `rd1` đổi ngay, không chờ clock. Ghi nằm trong khối cạnh lên clock, dùng `<=`, nên 32 ô cùng đổi một lúc. Ngăn không được ghi thì giữ nguyên giá trị.

### D4. Immediate mở rộng thế nào?
**Chỉ vào:** `src/cpu_g1.v:76-77` (`imm_x`).
**Đáp:** Ba kiểu chọn bằng `ext`: `01` thêm 16 bit 0 phía trước (không dấu, cho `andi`/`ori`), `10` đặt `imm` lên 16 bit cao (`lui`), còn lại mở rộng dấu bằng cách chép bit `imm[15]` 16 lần. Ba MUX nối nhau. Sai kiểu thì `addiu` với số âm hoặc `ori` với số lớn sẽ ra sai.

### D5. `uses_rs`, `uses_rt` để làm gì?
**Chỉ vào:** `src/control.v:30-31` (khai), `:76` (`jr` dùng `rs`), `src/hazard.v:39-40`.
**Đáp:** Để hazard biết lệnh ở ID có đọc thanh ghi nguồn thật hay không. `addiu` không đọc `rt` (`rt` là đích), nếu hazard cứ so `rt` thì sẽ dừng thừa. Thiếu `uses_rt` thì có thêm stall oan, không sai kết quả nhưng chậm.

---

## E. TV4 — IF, PC, nhánh, G1 2 pha, `bcd` (`cpu_g1.v:46-60, 148-231`, `cpu_pipe.v:56-60, 291-304`, `bcd_unit.v`)
Lệnh chạy: `bash tools/run_unit.sh bcd`, `python tools/cosim_iss.py --rand 0`.

### E1. PC kế tiếp chọn thế nào?
**Chỉ vào:** `src/cpu_g1.v:154-161`.
**Đáp:** Chuỗi `if / else if` bảy mức, trên thắng dưới: reset → `stall` (giữ PC) → `eret` (`epc`) → `jr` → `j`/`jal` → nhánh đúng (`pc4 + imm<<2`) → `pc4`. Có ngắt thì `pc_new = 0x180` đè lên cả chuỗi (`:167`). Đảo thứ tự thì ví dụ `stall` xuống dưới sẽ làm CPU nhảy khi đang chờ `div`.

### E2. Tại sao `phb` đổi ở hai chỗ?
**Chỉ vào:** `src/cpu_g1.v:196` (reset: `phb <= 1`), `:202` (`phb <= 0` sau pha B), `:211` (`phb <= 1` sau pha A).
**Đáp:** `phb` là cờ "cạnh kế là pha B". Sau reset đặt 1 vì IMEM đã chứa lệnh 0 nên cạnh đầu là pha B của lệnh 0 (comment dòng 9). Pha B xong thì `phb = 0` để cạnh sau là pha A, pha A xong lại 1. Hai pha luân phiên mãi.

### E3. Khi `div` đang chạy, PC làm gì ở G1?
**Chỉ vào:** `src/cpu_g1.v:105` (`stall`), `:156` (`else if (stall) next_pc = pc`), `:212` (`started`).
**Đáp:** `stall = 1` khi lệnh là `div`/`bcd` mà `done` chưa lên, và `next_pc = pc` nên PC đứng yên, regfile không ghi (`rf_we` có `!stall`, `:83`). Khi `done` lên thì `stall` tụt, lệnh hoàn tất và PC mới chạy tiếp. Đây cũng là lý do ngắt không được nhận lúc đang `stall` (`:166`).

### E4. `bcd` làm gì, bao nhiêu chu kỳ, số quá lớn thì sao?
**Chỉ vào:** `src/bcd_unit.v:7-10` (comment lịch chu kỳ), `:55-57` (bản tổ hợp `G_COMB`), `:68-70` (bản tuần tự).
**Đáp:** Đổi số nhị phân ra BCD, mỗi chữ số 4 bit để hiển thị 8 chữ số. Bản tuần tự mất 28 chu kỳ (1 bắt đầu + 27 bước), bản tổ hợp 27 tầng cho kết quả ngay (`busy = 0`, tốn thêm LUT). Số lớn hơn 99 999 999 thì `done` ngay và `y = 0xFFFFFFFF`.

### E5. Ở G2, dòng nào nạp PC và hủy lệnh nhầm?
**Chỉ vào:** `src/cpu_pipe.v:293` (`pc <= take_irq ? 0x180 : take ? tgt : pc + 4`), `:294` (`ifid_v <= !take && !take_irq`).
**Đáp:** Mỗi chu kỳ PC lấy một trong ba: `0x180` nếu nhận ngắt, đích `tgt` nếu nhánh/nhảy đúng, còn lại `pc + 4`. Cùng lúc `ifid_v = 0` nên lệnh vừa lấy ở nhịp này thành bong bóng. Cả khối đóng băng khi `stall_lu` (`:292`).

---

## F. TV5 — CP0, ngắt, xung CPU (`irq_ctrl.v`, `soc_regs.v`, `cpu_g1.v:107-118`, `cpu_pipe.v:246-259`, `pipeline-policy.md` §10)
Lệnh chạy: `bash tools/run_unit.sh irq soc_clock`.

### F1. Điều kiện nhận ngắt gồm những vế nào?
**Chỉ vào:** `src/cpu_g1.v:166` (G1), `src/cpu_pipe.v:202-204` (G2).
**Đáp:** G1 có năm vế: có yêu cầu `irq`, `Status.IE = 1`, `EXL = 0`, không `stall`, và lệnh không phải CP0. G2 thêm vì có nhiều lệnh dở dang: không `stall_lu`, không `stall_busy`, không có lệnh CP0 ở các tầng sau. (Brief ghi "bốn vế", code có năm vế ở G1: tiêu đề slide 23 viết "năm vế".)

### F2. EPC lưu địa chỉ nào?
**Chỉ vào:** G1 `src/cpu_g1.v:221` (`epc <= next_pc`); G2 `src/cpu_pipe.v:122` (`irq_epc`), `:255`.
**Đáp:** G1: lệnh vừa xong đã chạy trọn, nên EPC là lệnh kế tiếp. G2: EPC là lệnh cũ nhất chưa xong, lấy theo thứ tự `idex_pc`, nếu không có thì `ifid_pc`, nếu không thì `pc`. Vì vậy lệnh bị hủy sẽ chạy lại sau `eret`, không mất lệnh.

### F3. `eret` làm gì?
**Chỉ vào:** `src/cpu_g1.v:157` (`next_pc = epc`), `src/cpu_pipe.v:252` (`status[1] <= 0`), `:179` (`tgt = epc`).
**Đáp:** `eret` nạp PC bằng `epc` và xóa `EXL` về 0 để cho phép ngắt lại. `EXL = 1` từ lúc vào ngắt chặn ngắt lồng nhau (G1 và G2 giống nhau). `Status = $12`, `Cause = $13`, `EPC = $14`.

### F4. Bộ ngắt `irq_ctrl` lấy sự kiện thế nào?
**Chỉ vào:** `src/irq_ctrl.v:33-34` (`ip`, `irq`), `:37` (`clr`), `:46` (`pending`), `:49` (`stamp`).
**Đáp:** Có 8 sự kiện; mỗi sự kiện đến thì bit `pending` bật, chỉ tính nguồn đã `enable`. `irq` là OR của các nguồn đó. Ghi 1 vào `PEND` thì xóa bit; nếu sự kiện đến cùng chu kỳ với lệnh xóa thì sự kiện thắng (dòng 46). `stamp` ghi lại `CYCLE_COUNT` lúc `irq` lên, dùng đo độ trễ (phụ lục E3).

### F5. CPU không có clock riêng, vậy "CPU clock" là gì?
**Chỉ vào:** `src/soc_regs.v:53` (`assign cpu_ce`), `:45-48` (`norm`, luật ép D), `:65-66` (nạp `p` ở mỗi `cpu_ce`).
**Đáp:** CPU chạy cùng clock hệ thống 50 MHz, chỉ khác là được phép bước khi có xung `cpu_ce`, phát mỗi `D/2` hoặc `D` chu kỳ. Ghi `D` mới chỉ có hiệu lực từ chu kỳ CPU kế (`:66`). Luật ép: G1 cần D chẵn và tối thiểu 2 (mỗi chu kỳ CPU dùng 2 xung), G2 tối thiểu 1. Vì vậy G1 25 MHz (D=2) và G2 50 MHz (D=1).


### F6. `CAL` hiệu chỉnh đồng hồ thế nào, 1 ppm bằng bao nhiêu?
**Chỉ vào:** `src/timebase.v:34-37` (`s_now`, `s_cur`, `len`), `:40` (`tick`), `:50-52` (giữ phần lẻ), `evidence/20261026_exp_cal.log`.
**Đáp:** Mỗi mili giây cộng `CAL` vào phần lẻ `frac` (16 bit, đơn vị 1/65 536 chu kỳ); phần nguyên `s >>> 16` là số chu kỳ thêm vào độ dài mili giây `len = 50 000 + (s >>> 16)`. 1 ppm của 50 000 chu kỳ là 0,05 chu kỳ, nên bằng 3 276,8 đơn vị `CAL`; `CAL = 163 840` ra 2,5 chu kỳ thêm mỗi mili giây, dài 50 002 và 50 003 xen kẽ. `CAL` dương làm đồng hồ chậm lại. Dùng `>>>` vì `CAL` âm cần dịch số học. `exp_cal_tb` PASS 10. (verified: dòng code và log; tính tay trong bài U1)

---

## G. Việc cần làm trước ngày bảo vệ
- Mỗi người chạy lệnh test của lát mình trên máy trình chiếu, ghi thời gian chạy. (unverified)
- Mở sẵn các `file:dòng` ở trên trong editor có số dòng. Nếu `src/` đổi thì grep lại.
- Tập trả lời theo thứ tự: chủ lát nói trước, lát kề bổ sung.
