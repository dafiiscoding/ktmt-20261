# pipeline-policy.md — Chính sách pipeline 5 tầng (G2)

> **Trạng thái:** BẢN NHÁP v1. Claude viết ngày 24/09/2026; nhóm duyệt ở S1′ (01–07/10) rồi mới freeze.
> **Cách duyệt:** TV2 và TV3 **tự vẽ tay** 3 bảng T2, T4, T8 (§7) mà không nhìn đáp án, rồi so với file này. Lệch chỗ nào thì ghi vào §9 và cả nhóm quyết.
> **Đi kèm:** `docs/control-table.md` (28 lệnh: tín hiệu điều khiển, `uses_rs`, `uses_rt`). Spec tổng: `PLAN_DONG_HO.md` §4.4–4.5.
> **01/10/2026:** đổi đề sang đồng hồ điện tử → bỏ `tmac4/mtacc/mfacc/qrelu/mlrun`, thêm `xor`, `bcd`, `mfc0/mtc0/eret`. Ngắt trong pipeline là tầng 3, **chưa** có trong file này (Q5).
> Mọi thứ ở đây là **thiết kế** (`unverified`) cho tới khi bộ test hazard (§8) PASS.

---

## 0. Tóm tắt 10 dòng

1. Có 5 tầng IF, ID, EX, MEM, WB. Không có delay slot. Dự đoán **không nhảy**.
2. **Mọi nhánh và nhảy đều quyết định ở EX** (`beq`, `bne`, `j`, `jal`, `jr`). Khi nhảy thật thì xóa 2 lệnh (đang ở IF/ID và ID/EX), **phạt 2 chu kỳ**.
3. **Forwarding** từ EX/MEM và MEM/WB về **cả hai toán hạng ở EX**. Nguồn EX/MEM được ưu tiên hơn.
4. **Regfile ghi ở sườn lên, đọc tổ hợp, có bypass nội bộ**. Tác dụng tương đương "ghi nửa đầu, đọc nửa sau" trong sách, nhưng không dùng sườn xuống.
5. **Load-use:** phát hiện ở ID, stall 1 chu kỳ. Chỉ xét những toán hạng lệnh **thật sự đọc** (`uses_rs`, `uses_rt`) để tránh stall thừa.
6. **Khối nhiều chu kỳ** (`div`, `bcd` bản tuần tự) nằm ở EX và báo `busy`. Khi đó đóng băng PC, IF/ID, ID/EX; EX/MEM nhận bubble; MEM và WB chạy tiếp. Toán hạng được **chốt ở chu kỳ start**.
7. **HI, LO, CP0** chỉ đọc và ghi ở EX, nên không sinh hazard riêng.
8. Ưu tiên khi nhiều sự kiện trùng nhau: **busy > flush > load-use > bình thường**.
9. IMEM và DMEM dùng BRAM **đọc đồng bộ**: IF/ID có bit `valid` để flush; dữ liệu đọc DMEM đi thẳng vào MEM/WB.
10. `eret` quyết định ở EX như một lệnh nhảy (đích = `EPC`), xóa 2 lệnh.

---

## 1. Thanh ghi tầng: trường và độ rộng

`pc` (32 bit) được mang theo mọi tầng **chỉ để ghi trace và gỡ lỗi**. Trace (`isa-spec.md` §8) còn cần ở WB: `instr`, `mem_read`/`mem_write`, `maddr` (= `ex_result`), `mdata` (`store_data` hoặc `mem_data`) → mang `instr` từ ID và `store_data`, `mem_*` sang MEM/WB như trường debug (`` `ifndef SYNTHESIS ``). Khi tổng hợp có thể bỏ nếu thiếu tài nguyên; tính riêng trong cột "Debug".

### IF/ID — 65 bit (+0 debug)
| Trường | Bit | Ghi chú |
|---|---|---|
| `valid` | 1 | 0 = bubble. Flush xóa bit này vì **không xóa được thanh ghi đầu ra của BRAM** (§5) |
| `pc4` | 32 | PC + 4 |
| `instr` | 32 | chính là đầu ra đồng bộ của IMEM |

### ID/EX — 20 bit điều khiển + 174 bit dữ liệu = 194 bit (+32 debug)
| Nhóm | Trường | Bit | Ghi chú |
|---|---|---|---|
| WB | `reg_write` | 1 | |
| WB | `mem_to_reg` | 1 | 0: `ex_result`, 1: dữ liệu bộ nhớ |
| MEM | `mem_read` | 1 | `lw` (cả vùng MMIO) |
| MEM | `mem_write` | 1 | `sw` |
| EX | `alu_src` | 1 | 0: rt, 1: immediate |
| EX | `alu_ctl` | 4 | ADD, SUB, AND, OR, XOR, SLT, SLL, SRA (dư mã cho mở rộng) |
| EX | `res_sel` | 3 | ALU, MUL, HI, LO, BCD, CP0, PC4 → `ex_result` |
| EX | `branch` | 2 | 00 không nhánh, 01 `beq`, 10 `bne` |
| EX | `jump` | 1 | `j`, `jal` |
| EX | `jump_reg` | 1 | `jr` |
| EX | `multi` | 2 | 00 không, 01 `div`, 10 `bcd` bản tuần tự (bản tổ hợp: `multi = 00`, `res_sel = BCD`), 11 dự trữ |
| EX | `cp0_op` | 2 | 00 không, 01 `mtc0` (CP0[`j_target[15:11]`] ← opB), 10 `eret` (PC ← EPC, EXL ← 0) |
| Dữ liệu | `pc4` | 32 | cho `jal` (địa chỉ trở về) và đích nhánh |
| Dữ liệu | `rs_val`, `rt_val` | 32 + 32 | đọc từ regfile, đã qua bypass nội bộ |
| Dữ liệu | `imm` | 32 | đã mở rộng ở ID: dấu (SE), zero (ZE) hoặc `imm<<16` (LUI) |
| Dữ liệu | `shamt` | 5 | cho `sll`/`sra` |
| Dữ liệu | `rs`, `rt` | 5 + 5 | số thanh ghi, **dùng cho forwarding** |
| Dữ liệu | `dst` | 5 | thanh ghi đích **đã chọn ở ID** (rd / rt / 31). Bằng 0 nếu không ghi |
| Dữ liệu | `j_target` | 26 | `instr[25:0]`; với `mfc0`/`mtc0`, số thanh ghi CP0 = `j_target[15:11]` (trường rd) nên không cần trường riêng |

### EX/MEM — 4 + 69 = 73 bit (+32 debug)
| Trường | Bit | Ghi chú |
|---|---|---|
| `reg_write`, `mem_to_reg`, `mem_read`, `mem_write` | 4 | |
| `ex_result` | 32 | kết quả **đã chọn** theo `res_sel`; cũng là địa chỉ bộ nhớ cho `lw`/`sw` |
| `store_data` | 32 | **`rt` sau forwarding**, không lấy `rt_val` thô, để `sw` nhận đúng giá trị mới nhất |
| `dst` | 5 | |

### MEM/WB — 2 + 69 = 71 bit (+32 debug)
| Trường | Bit | Ghi chú |
|---|---|---|
| `reg_write`, `mem_to_reg` | 2 | |
| `ex_result` | 32 | |
| `mem_data` | 32 | **thanh ghi đầu ra đồng bộ** của DMEM (hoặc đầu ra MMIO đã chốt) |
| `dst` | 5 | |

Giá trị ghi về regfile: `wb_data = mem_to_reg ? mem_data : ex_result`.

**Bubble** = ghi 0 vào **mọi bit điều khiển** của thanh ghi đó (quan trọng nhất là `reg_write`, `mem_write`, `mem_read`, `branch`, `jump*`, `multi`, `cp0_op`). Riêng IF/ID thì bubble là `valid = 0`.

---

## 2. Regfile

- Có 32 × 32 bit, `$0` luôn bằng 0. **Ghi ở sườn lên** khi `MEM/WB.reg_write = 1` và `dst ≠ 0`.
- **Đọc tổ hợp + bypass nội bộ:** nếu cổng đọc trùng `MEM/WB.dst` (≠ 0) và `MEM/WB.reg_write = 1` thì trả ra ngay `wb_data`.
  → Lệnh ở ID đọc được giá trị do lệnh ở WB ghi **trong cùng chu kỳ**. Đây là cách làm tương đương "ghi nửa đầu, đọc nửa sau" của P&H.
- Lý do chọn cách này: không cần sườn xuống, nên cả core pipeline chỉ dùng một sườn clock.
- **Parameter `G_BYPASS`:** G2 = `true`, **G1 = `false`**. Ở G1 cổng ghi là của chính lệnh đang đọc: bypass sẽ tạo vòng tổ hợp `rs → ALU → wb_data → rs` (`addu $t0,$t0,$t1`) và làm `lw $t0,0($t0)` tính sai địa chỉ.

---

## 3. Forwarding (về EX)

`dst` là thanh ghi đích **thật** (đã chọn rd / rt / 31 ở ID), không phải trường `rd` thô của lệnh.

```
ForwardA =
  10  nếu EX/MEM.reg_write  và EX/MEM.dst ≠ 0  và EX/MEM.dst = ID/EX.rs
  01  ngược lại, nếu MEM/WB.reg_write và MEM/WB.dst ≠ 0 và MEM/WB.dst = ID/EX.rs
  00  ngược lại
ForwardB: giống hệt, thay rs bằng rt.
```

| Forward | Nguồn | Ý nghĩa |
|---|---|---|
| 00 | `ID/EX.rs_val` / `rt_val` | giá trị đọc ở ID (đã qua bypass) |
| 10 | `EX/MEM.ex_result` | kết quả của lệnh ngay trước |
| 01 | `wb_data` | kết quả của lệnh trước đó 2 lệnh (kể cả dữ liệu từ `lw`) |

- **Ưu tiên EX/MEM** vì đó là giá trị mới hơn. Ca `add $1…; add $1…; add …,$1` lấy từ lệnh gần nhất.
- Toán hạng **sau forwarding** (gọi là `opA`, `opB`) được dùng cho: ALU, `mul`, so sánh nhánh, `jr`, `mtc0`, `bcd` tổ hợp, `div` và `bcd` tuần tự (chốt ở start), và `store_data` của `sw`.
- **Ràng buộc bất biến (assert trong testbench):** không bao giờ forward từ EX/MEM khi `EX/MEM.mem_read = 1`. Load chưa có dữ liệu ở tầng đó; load-use (§4) phải chặn trước. Assert nổ nghĩa là bộ phát hiện load-use sai.
- Forward cho một toán hạng lệnh không dùng (ví dụ `rs` của `sll`) thì vô hại, nên **không cần** chặn bằng `uses_*` ở đây.
- `ex_result` của `mfhi`, `mflo`, `mfc0`, `mul`, `bcd`, `jal` được tính ở EX, nên forward như lệnh ALU thường.

---

## 4. Load-use (phát hiện ở ID)

```
stall_lu = ID/EX.mem_read  and  ID/EX.dst ≠ 0  and  IF/ID.valid  and
           ( (uses_rs(IF/ID) and ID/EX.dst = IF/ID.rs)
          or (uses_rt(IF/ID) and ID/EX.dst = IF/ID.rt) )
```

- `uses_rs` và `uses_rt` lấy từ `control-table.md`. Ví dụ `addiu`, `lw`, `lui` **không** đọc `rt` (với `addiu`/`lw`, `rt` là thanh ghi đích), nên không bị stall oan. Nhóm 3 so `rt` cho mọi lệnh nên có thể stall thừa (`inference`).
- Khi `stall_lu = 1`:
  - `PCWrite = 0`, `IFIDWrite = 0`, IMEM `en = 0` (giữ lệnh);
  - ID/EX ← bubble.
- Chu kỳ sau, lệnh `lw` đã ở MEM/WB, nên toán hạng được forward bằng `01`.
- **`sw` sau `lw` cùng thanh ghi** (`lw $t0…; sw $t0,…`) vẫn stall 1 chu kỳ vì `sw` đọc `rt`. P&H có forwarding MEM→MEM để bỏ chu kỳ này; nhóm **không làm**, chấp nhận mất 1 chu kỳ để đơn giản.

---

## 5. Nhánh và nhảy (quyết định ở EX)

```
taken = (branch=01 and opA = opB) or (branch=10 and opA ≠ opB) or jump or jump_reg or (cp0_op=10)
target =
  cp0_op=10         → EPC                                  (eret)
  jump_reg          → opA                                  (jr)
  jump              → {ID/EX.pc4[31:28], j_target, 00}      (j, jal)
  branch            → ID/EX.pc4 + (imm << 2)               (beq, bne)
```

- Khi `taken = 1` (flush):
  - `pc_next = target`;
  - IF/ID ← `valid = 0`;
  - ID/EX ← bubble.
  - Phạt 2 chu kỳ.
- `jal`: `res_sel = PC4`, `dst = 31`, nên `ex_result = pc4` (không có delay slot, địa chỉ trở về là PC + 4).
- **An toàn khi xóa:** hai lệnh bị xóa mới qua IF và ID, mà ở đó không có tác dụng phụ nào. Regfile chỉ ghi ở WB; HI, LO, CP0, DMEM, MMIO và start `div`/`bcd` chỉ xảy ra từ EX trở đi.
- **Vì sao chọn nhánh ở EX, không ở ID như Nhóm 3:**
  - Nhánh ở ID cần thêm bộ so sánh, thêm đường forwarding về ID, và **stall thêm** khi lệnh nhánh phụ thuộc lệnh ngay trước (ALU: 1 chu kỳ; `lw`: 2 chu kỳ).
  - Nhánh ở EX dùng lại forwarding sẵn có, số ca đặc biệt ít hơn nên ít lỗi hơn.
  - Đổi lại, mất thêm 1 chu kỳ mỗi lần nhảy.
  - Nhóm **không làm** bản nhánh ở ID; lý do chọn EX trình bày bằng bảng T3, T4 (§7).
- **Không có delay slot**, để khớp MARS và code viết tay.

---

## 6. Khối nhiều chu kỳ: `busy` freeze

```
ex_multi   = ID/EX.multi ≠ 00
start      = ex_multi and not started        -- 1 xung ở chu kỳ đầu tiên lệnh nằm ở EX
started    <= (ex_multi and not done)        -- thanh ghi 1 bit, xóa khi lệnh rời EX
stall_busy = ex_multi and not done
```

- **`done`** của từng khối:
  - `div`: kết thúc bước chia cuối cùng;
  - `bcd` tuần tự: xong bước dịch-cộng-3 cuối (27 bước + chu kỳ start = 28 chu kỳ CPU; số tràn > 99 999 999 → `done` ngay chu kỳ start. Đo 02/10 bằng `tb/bcd_tb.v`).
- Khi `stall_busy = 1`:
  - giữ PC, IF/ID, ID/EX; IMEM `en = 0`;
  - EX/MEM ← bubble;
  - MEM/WB chạy bình thường, nên các lệnh cũ hơn vẫn ghi xong.
- Ở chu kỳ `done = 1`, pipeline chạy bình thường và lệnh nhiều chu kỳ rời EX (`div` ghi HI/LO ở cạnh này).
- **Chốt toán hạng ở `start`:** `div` chốt `opA` và `opB`; `bcd` chốt `opA`.
  - Lý do: trong lúc freeze, EX/MEM là bubble và MEM/WB rút dần, nên nguồn forwarding biến mất. Nếu không chốt, toán hạng sẽ đổi giữa chừng.
- `bcd` tuần tự ghi kết quả vào `ex_result` ở chu kỳ `done` rồi rời EX như lệnh ALU, nên lệnh sau dùng ngay qua forwarding `10`.
- **Thứ tự ưu tiên:** lệnh nhiều chu kỳ nằm ở EX thì không thể đồng thời là lệnh nhánh, nên busy và flush không bao giờ trùng. Busy và load-use có thể trùng; busy thắng, load-use tính lại ở chu kỳ sau.

### HI, LO, CP0 (không có hazard riêng)
- Chỉ **đọc và ghi ở EX**. Lệnh sau (`mfhi`, `mfc0`…) tới EX sau khi lệnh trước đã ghi xong ở cạnh clock.
- `mflo` ngay sau `div` bị giữ ở ID suốt lúc freeze, nên luôn đọc LO mới.

---

## 7. Bảng diễn biến theo chu kỳ (bản nháp cho báo cáo §2.8)

Ký hiệu: `—` = bubble hoặc lệnh bị xóa; `*` = stall (giữ nguyên tầng); `F→` = có forward vào EX.

**T1. RAW liên tiếp, forwarding đủ, 0 stall**
| Lệnh | c1 | c2 | c3 | c4 | c5 | c6 | c7 |
|---|---|---|---|---|---|---|---|
| `subu $2,$1,$3` | IF | ID | EX | MEM | WB | | |
| `and $12,$2,$5` | | IF | ID | EX F→(10 từ EX/MEM) | MEM | WB | |
| `or $13,$6,$2` | | | IF | ID | EX F→(01 từ MEM/WB) | MEM | WB |
| `addu $14,$2,$2` | | | | IF | ID (bypass regfile, `$2` đang WB) | EX | MEM |

**T2. Load-use: 1 bubble**
| Lệnh | c1 | c2 | c3 | c4 | c5 | c6 | c7 |
|---|---|---|---|---|---|---|---|
| `lw $t0,0($s0)` | IF | ID | EX | MEM | WB | | |
| `addu $t1,$t0,$t2` | | IF | ID (phát hiện) | ID* | EX F→(01) | MEM | WB |
| (bubble) | | | | EX — | MEM — | WB — | |
| `lệnh kế` | | | IF | IF* | ID | EX | MEM |

**T3. `beq` nhảy thật: xóa 2 lệnh, phạt 2**
| Lệnh | c1 | c2 | c3 | c4 | c5 | c6 |
|---|---|---|---|---|---|---|
| `beq $s0,$s2,L` | IF | ID | EX (taken) | MEM | WB | |
| `i+1` | | IF | ID | — | | |
| `i+2` | | | IF | — | | |
| `L:` | | | | IF | ID | EX |

**T4. `lw` rồi `beq` dùng ngay kết quả (ca Nhóm 3 dễ sót)**
| Lệnh | c1 | c2 | c3 | c4 | c5 | c6 |
|---|---|---|---|---|---|---|
| `lw $t0,0($s0)` | IF | ID | EX | MEM | WB | |
| `beq $t0,$zero,L` | | IF | ID (load-use) | ID* | EX F→(01), quyết định | MEM |
→ Nhánh ở EX chỉ cần **1** bubble; nhánh ở ID sẽ cần **2**.

**T5. `div` giữa chuỗi phụ thuộc (K = số chu kỳ `div` nằm ở EX, dự kiến 32–33, tb đo)**
| Lệnh | c1 | c2 | c3 | c4 … c(K+1) | c(K+2) | c(K+3) | c(K+4) |
|---|---|---|---|---|---|---|---|
| `addu $s0,$a0,$a1` | IF | ID | EX | MEM, WB, rồi xong | | | |
| `div $s0,$s1` | | IF | ID | EX (start ở c4, F→10 cho `$s0`, chốt toán hạng) … EX | EX | EX, `done` | MEM |
| `mflo $t0` | | | IF | ID* | ID* | ID | EX (đọc LO mới) |
| `addu $t1,$t0,$t2` | | | | IF* | IF* | IF | ID |
Mỗi chu kỳ freeze, EX/MEM nhận bubble. Bảng thật sẽ lấy từ waveform ở S8; bảng này chỉ để thống nhất ngữ nghĩa.

**T6. `mtc0` rồi `mfc0` cùng thanh ghi CP0: 0 stall**
| Lệnh | c1 | c2 | c3 | c4 | c5 |
|---|---|---|---|---|---|
| `mtc0 $s5,$12` | IF | ID | EX (Status ←) | MEM | WB |
| `mfc0 $t0,$12` | | IF | ID | EX (đọc Status mới) | MEM |

**T7. `jal` rồi `jr $ra` ngay ở hàm đích**
| Lệnh | c1 | c2 | c3 | c4 | c5 | c6 |
|---|---|---|---|---|---|---|
| `jal F` | IF | ID | EX (taken, `ex_result = pc4`) | MEM | WB (`$31` ghi) | |
| `i+1` | | IF | ID | — | | |
| `i+2` | | | IF | — | | |
| `F: jr $ra` | | | | IF | ID (bypass regfile lấy `$31`) | EX (taken) |

**T8. `bcd` tuần tự rồi dùng ngay kết quả (B ≈ 27 chu kỳ ở EX, tb đo)**
| Lệnh | c1 | c2 | c3 | c4 … c(B+1) | c(B+2) | c(B+3) | c(B+4) |
|---|---|---|---|---|---|---|---|
| `bcd $t0,$s0` | IF | ID | EX start (chốt `opA`) | EX … | EX `done` | MEM | WB |
| `sw $t0,DISP0($zero)` | | IF | ID* | ID* … | ID | EX F→(10) | MEM |

---

## 8. Bộ test "tra tấn hazard" (`fw/tests/hazard/*.s`)

Mỗi file tự kiểm bằng cách so trace pipeline với ISS từng dòng (`tools/cmp_trace.py`), và **đếm chu kỳ** so với số dự kiến trong bảng §7.

| File | Nội dung | Số bubble dự kiến |
|---|---|---|
| `raw_chain.s` | T1 + ca `add $1; add $1; add ..,$1` (ưu tiên EX/MEM) | 0 |
| `load_use.s` | T2 với `rs`, với `rt`, `lw`→`sw` cùng thanh ghi, `lw`→`addiu` dùng `rt` làm đích (**không** được stall) | 1, 1, 1, 0 |
| `branch.s` | `beq`/`bne` nhảy và không nhảy, nhánh ngay sau ALU, nhánh ngay sau `lw` (T4) | 2 khi nhảy, 0 khi không nhảy, +1 sau `lw` |
| `jump.s` | `j`, `jal` + `jr` ngay (T7), `jr` sau `lw $ra` | 2 mỗi lần nhảy |
| `multi.s` | T5; `div` chia 0; `lw` → `div` (load-use rồi busy) | K−1 + … (ghi theo đo) |
| `cp0.s` | T6; `mtc0`/`mfc0` xen `mfhi`; `eret` nhảy về `EPC` | 0; `eret` phạt 2 |
| `bcd_busy.s` | T8; `bcd` tuần tự rồi `sw` ngay; `bcd` tổ hợp rồi `addu` ngay | B−1 + … (ghi theo đo); 0 |
| `zero_reg.s` | ghi vào `$0` rồi dùng `$0` (không được forward) | 0 |

- Assert chạy trong mọi test: không forward từ EX/MEM khi `mem_read = 1` (§3).
- **CPI** của từng file được ghi vào `evidence/` để dùng cho báo cáo §3.3.

---

## 10. Ngắt chính xác (G2, Q5)

Quy tắc (khớp ISS `tools/iss.py` và G1 `src/cpu_g1.v`; kiểm bằng `fw/tests/cpu/irq.s` qua cosim và ModelSim):

- **Nhận ngắt ở ID/EX-boundary**, chỉ khi cả ba đúng: `irq` = 1, `Status.IE` = 1, `Status.EXL` = 0.
- **Không nhận** khi: EX đang bận nhiều chu kỳ (`div`/`bcd`, `stall_busy`), đang chờ load-use (`stall_lu`), lệnh ở ID/EX là CP0 (mtc0/eret), hoặc lệnh retire gần nhất (ở EX/MEM, hoặc MEM/WB nếu EX/MEM rỗng) là CP0. Quy tắc "sau CP0" này trùng `block` của ISS.
- **Khi nhận:** lệnh ở ID và ID/EX bị hủy (không retire, không ghi gì); lệnh ở EX/MEM và MEM/WB hoàn thành bình thường; `PC ← 0x180`; `EXL ← 1`.
- **EPC** = PC của lệnh cũ nhất chưa retire: `idex_pc` nếu ID/EX có lệnh, không thì `ifid_pc`, không thì `pc`.
- **Trace:** dòng `INTERRUPT` được ghi ở chu kỳ *sau* khi lệnh EX/MEM đã retire (cờ `irq_tr`), để thứ tự trace khớp ISS.
- Không ngắt lồng: EXL = 1 chặn tới khi eret.

Bảng chu kỳ (1 chu kỳ CPU = 1 chu kỳ hệ thống với `cpu_ce` = 1):

| Tình huống | Kết quả |
|---|---|
| Sự kiện đến khi `div` đang chạy | Chờ `div` xong; EPC = lệnh sau `div` (mflo) |
| Sự kiện ngay sau `mtc0 IE←1` | Không nhận ở lệnh kế; nhận sau lệnh đó |
| Sự kiện ngay sau `eret`/`mtc0` khác | Không nhận (quy tắc CP0) |
| Sự kiện khi load-use stall | Chờ stall xong |
| Sự kiện khi nhảy `beq` taken | EPC = đích nhánh (lệnh ở ID/EX bị hủy) |

Kiểm chứng: `irq.s` 5 ngắt PASS trên G1, G2 (cosim `--g2`, `--rand 30`, `COSIM_CEDIV=3`), ModelSim G2 48/48. Đột biến M7/M8/M9 (bỏ chặn `div`, bỏ chặn CP0, EPC = PC hiện tại) đều bị bắt. Thêm `fw/tests/cpu/irq_bcd.s` (ngắt trong `bcd`: EPC = lệnh sau bcd, 0x1d4) và `irq_lu.s` (ngắt lúc load-use stall: EPC = addu bị stall, 0x1d8; trễ sự kiện 1 chu kỳ). Đột biến M10 (bỏ `!stall_lu`) bị `irq_lu` bắt ở trễ 1 và 8. M7b (bỏ `idex_multi==0`, giữ `!stall_busy`) là hành vi hợp lệ khác, cho cùng kết quả chương trình, nên không đưa vào danh sách bắt buộc.

**Ghi chú thứ tự:** Q5 yêu cầu §10 viết trước khi code. Lần này code được viết trước, §10 viết sau (ghi nhận 21/10). Quy tắc ở trên là mô tả code đã chạy, không phải thiết kế đi trước.

**Đổi test:** `fw/tests/cpu/irq.s` C5-1 đổi trễ sự kiện 40 → 20 chu kỳ hệ thống. Lý do: với 40, G2 (div 33 chu kỳ) nhận ngắt sau `mflo` (EPC sai so với mục đích "sự kiện đến khi div busy"); G1 không đổi kết quả. 20 nằm trong div ở cả hai lõi.

## 9. Câu hỏi mở và nhật ký duyệt

| # | Câu hỏi | Mặc định nếu nhóm không đổi |
|---|---|---|
| Q1 | Có làm forwarding MEM→MEM cho `lw`→`sw` không? | Không (mất 1 chu kỳ, chấp nhận) |
| Q2 | Đưa `j`/`jal` lên quyết định ở ID (phạt 1, không cần forwarding)? | Không |
| Q3 | Bỏ bớt trường `pc` debug khi tổng hợp? | Giữ, trừ khi thiếu tài nguyên |
| Q4 | K của `div` là 32 hay 33? | Theo RTL `muldiv` của TV1, ghi vào bảng T5 |
| Q5 | Ngắt chính xác trong pipeline (tầng 3): chèn ở ID? `EPC` = PC lệnh nào khi đang flush hoặc `busy`? | Đã làm và Long duyệt phương án A (21/10): xem §10 (code trước, §10 sau — ghi nhận) |

Nhật ký duyệt (S1): _ghi ngày · người · lệch gì · quyết gì_
