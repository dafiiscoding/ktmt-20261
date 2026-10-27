# control-table.md — Bảng chân lý điều khiển, 28 lệnh

> **Trạng thái:** BẢN NHÁP v2 (01/10/2026, đổi đề sang đồng hồ điện tử: bỏ 5 lệnh ML, thêm `xor`, `bcd`, `mfc0`, `mtc0`, `eret`). Claude viết; TV3 duyệt ở S1′–S2, TV2 đối chiếu với `asm.py` và ISS.
> Dùng chung cho **G1 (single-cycle)** và **G2 (pipeline)**. Tên tín hiệu khớp `docs/pipeline-policy.md` §1.
> Mã hóa: MIPS32 chuẩn cho phần chuẩn; `bcd` = SPECIAL2 funct 0x10 (vùng UDI, TV2 kiểm *MIPS32 Vol. II* ở S1′); COP0 theo MIPS32. Spec: `PLAN_DONG_HO.md` §4.4–4.5.

## 1. Quy ước

- **Giải mã một cấp:** control sinh thẳng `alu_ctl` từ opcode + funct ở ID, không đi qua ALUOp 2 cấp như sách.
  - Lý do: có 28 lệnh và 4 nhóm opcode (R, I/J, SPECIAL2, COP0), nên một bảng phẳng dễ kiểm hơn.
  - Đổi lại, khối control lớn hơn một chút.
- `dst`: `rd` = instr[15:11], `rt` = instr[20:16], `31` = `$ra`, `–` = không ghi (`reg_write = 0`, `dst` ép về 0).
- `ext` (mở rộng immediate): `SE` dấu, `ZE` zero, `LUI` = `imm << 16`, `–` = không dùng.
- `uses_rs` / `uses_rt` = lệnh **thật sự đọc** thanh ghi đó. Dùng cho load-use (policy §4); **không** dùng cho forwarding.
- Opcode hoặc funct không có trong bảng → mọi tín hiệu = 0 (coi như NOP), và testbench `assert` báo "lệnh lạ".
  - `control.v` có thêm cổng `valid` (1 = thuộc 28 lệnh) chỉ để mô phỏng báo lệnh lạ; không nằm trong 16 tín hiệu và không vào `control.txt`.
- `cp0_op`: 01 `mtc0` (ghi CP0 ở EX), 10 `eret` (PC ← EPC, EXL ← 0, xóa 2 lệnh như nhảy). `mfc0` chỉ cần `res_sel = CP0`.
- `bcd`: bản tuần tự `multi = 10`; bản tổ hợp `multi = 00`. Hai bản cùng `res_sel = BCD`, chọn bằng parameter khi tổng hợp.
- Ô trống = 0.

### 1.1. Mã hóa nhị phân (hợp đồng giữa `control.v`, testbench và `tb/vectors/control.txt`)
| Tín hiệu | Rộng | Mã |
|---|---|---|
| `dst` | 2 | 00 `–` · 01 `rd` · 10 `rt` · 11 `31` |
| `ext` | 2 | 00 `SE` (và `–`) · 01 `ZE` · 10 `LUI` |
| `alu_ctl` | 4 | 0 ADD · 1 SUB · 2 AND · 3 OR · 4 XOR · 5 SLT · 6 SLL · 7 SRA (`–` = 0) |
| `res_sel` | 3 | 0 ALU (và `–`) · 1 MUL · 2 HI · 3 LO · 4 BCD · 5 CP0 · 6 PC4 |
| `branch` | 2 | 00 · 01 `beq` · 10 `bne` |
| `multi` | 2 | 00 · 01 `div` · 10 `bcd` tuần tự |
| `cp0_op` | 2 | 00 · 01 `mtc0` · 10 `eret` |
| `alu_src`, các cờ 1 bit | 1 | `–` = 0 |

- ALU: `SLL`/`SRA` dịch toán hạng B (`rt`) theo `shamt`; toán hạng A bị bỏ. Cờ `zero` = (kết quả = 0). Vector: `tb/vectors/alu.txt`.

## 2. Bảng

| # | Lệnh | op / funct | reg_write | dst | alu_src | ext | alu_ctl | res_sel | mem_read | mem_write | mem_to_reg | branch | jump | jump_reg | multi | cp0_op | uses_rs | uses_rt |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `addu rd,rs,rt` | 00 / 21 | 1 | rd | 0 | – | ADD | ALU |  |  |  |  |  |  |  |  | 1 | 1 |
| 2 | `subu rd,rs,rt` | 00 / 23 | 1 | rd | 0 | – | SUB | ALU |  |  |  |  |  |  |  |  | 1 | 1 |
| 3 | `and rd,rs,rt` | 00 / 24 | 1 | rd | 0 | – | AND | ALU |  |  |  |  |  |  |  |  | 1 | 1 |
| 4 | `or rd,rs,rt` | 00 / 25 | 1 | rd | 0 | – | OR | ALU |  |  |  |  |  |  |  |  | 1 | 1 |
| 5 | `xor rd,rs,rt` | 00 / 26 | 1 | rd | 0 | – | XOR | ALU |  |  |  |  |  |  |  |  | 1 | 1 |
| 6 | `slt rd,rs,rt` | 00 / 2A | 1 | rd | 0 | – | SLT | ALU |  |  |  |  |  |  |  |  | 1 | 1 |
| 7 | `sll rd,rt,sa` | 00 / 00 | 1 | rd | 0 | – | SLL | ALU |  |  |  |  |  |  |  |  | 0 | 1 |
| 8 | `sra rd,rt,sa` | 00 / 03 | 1 | rd | 0 | – | SRA | ALU |  |  |  |  |  |  |  |  | 0 | 1 |
| 9 | `jr rs` | 00 / 08 | 0 | – | – | – | – | – |  |  |  |  |  | 1 |  |  | 1 | 0 |
| 10 | `div rs,rt` | 00 / 1A | 0 | – | – | – | – | – |  |  |  |  |  |  | 01 div |  | 1 | 1 |
| 11 | `mfhi rd` | 00 / 10 | 1 | rd | – | – | – | HI |  |  |  |  |  |  |  |  | 0 | 0 |
| 12 | `mflo rd` | 00 / 12 | 1 | rd | – | – | – | LO |  |  |  |  |  |  |  |  | 0 | 0 |
| 13 | `addiu rt,rs,imm` | 09 | 1 | rt | 1 | SE | ADD | ALU |  |  |  |  |  |  |  |  | 1 | 0 |
| 14 | `slti rt,rs,imm` | 0A | 1 | rt | 1 | SE | SLT | ALU |  |  |  |  |  |  |  |  | 1 | 0 |
| 15 | `andi rt,rs,imm` | 0C | 1 | rt | 1 | ZE | AND | ALU |  |  |  |  |  |  |  |  | 1 | 0 |
| 16 | `ori rt,rs,imm` | 0D | 1 | rt | 1 | ZE | OR | ALU |  |  |  |  |  |  |  |  | 1 | 0 |
| 17 | `lui rt,imm` | 0F | 1 | rt | 1 | LUI | OR (rs = `$0`) | ALU |  |  |  |  |  |  |  |  | 0 | 0 |
| 18 | `lw rt,imm(rs)` | 23 | 1 | rt | 1 | SE | ADD | ALU | 1 |  | 1 |  |  |  |  |  | 1 | 0 |
| 19 | `sw rt,imm(rs)` | 2B | 0 | – | 1 | SE | ADD | – |  | 1 |  |  |  |  |  |  | 1 | 1 |
| 20 | `beq rs,rt,L` | 04 | 0 | – | 0 | SE | – (bộ so sánh riêng) | – |  |  |  | 01 |  |  |  |  | 1 | 1 |
| 21 | `bne rs,rt,L` | 05 | 0 | – | 0 | SE | – (bộ so sánh riêng) | – |  |  |  | 10 |  |  |  |  | 1 | 1 |
| 22 | `j L` | 02 | 0 | – | – | – | – | – |  |  |  |  | 1 |  |  |  | 0 | 0 |
| 23 | `jal L` | 03 | 1 | 31 | – | – | – | PC4 |  |  |  |  | 1 |  |  |  | 0 | 0 |
| 24 | `mul rd,rs,rt` | 1C / 02 | 1 | rd | 0 | – | – | MUL |  |  |  |  |  |  |  |  | 1 | 1 |
| 25 | `bcd rd,rs` | 1C / 10 | 1 | rd | – | – | – | BCD |  |  |  |  |  |  | 10 bcd (bản tuần tự) |  | 1 | 0 |
| 26 | `mfc0 rt,rd` | 10 / rs=00 | 1 | rt | – | – | – | CP0 |  |  |  |  |  |  |  |  | 0 | 0 |
| 27 | `mtc0 rt,rd` | 10 / rs=04 | 0 | – | – | – | – | – |  |  |  |  |  |  |  | 01 mtc0 | 0 | 1 |
| 28 | `eret` | 10 / CO=1, 18 | 0 | – | – | – | – | – |  |  |  |  |  |  |  | 10 eret | 0 | 0 |

## 3. Vị trí các trường của lệnh không theo khuôn R/I chuẩn (TV2 cài vào `asm.py`)

| Lệnh | op [31:26] | rs [25:21] | rt [20:16] | rd [15:11] | shamt [10:6] | funct [5:0] |
|---|---|---|---|---|---|---|
| `mul rd,rs,rt` | 0x1C | nguồn 1 | nguồn 2 | đích | 0 | 0x02 |
| `bcd rd,rs` | 0x1C | nguồn (0..99 999 999) | 0 | đích | 0 | 0x10 |
| `mfc0 rt,rd` | 0x10 | 0x00 | đích GPR | số thanh ghi CP0 | 0 | 0 |
| `mtc0 rt,rd` | 0x10 | 0x04 | nguồn GPR | số thanh ghi CP0 | 0 | 0 |
| `eret` | 0x10 | 0x10 (bit CO) | 0 | 0 | 0 | 0x18 |

- Thanh ghi CP0 dùng: `$12` Status (bit0 IE, bit1 EXL), `$13` Cause (IP [15:8] = `IRQ_PENDING & IRQ_ENABLE`, `isa-spec.md` §5), `$14` EPC. Thanh ghi khác → đọc ra 0, ghi bị bỏ.
- `bcd` vượt 99 999 999 → kết quả `0xFFFFFFFF` (cờ lỗi do nhóm tự định nghĩa; TV1 có thể đổi, ghi lại ở đây).

## 4. Tự kiểm bảng (chạy lại khi sửa, 01/10)

- Có 28 dòng: 12 R, 9 I, 2 J, 2 SPECIAL2, 3 COP0.
- Mọi dòng `reg_write = 1` đều có `dst` ≠ `–`; mọi dòng `reg_write = 0` đều có `dst = –`.
- Không lệnh nào vừa `mem_read` vừa `mem_write`. Chỉ `lw` có `mem_to_reg = 1`.
- Tất cả lệnh ghi vào `rt` đều có `uses_rt = 0` (tránh load-use oan). `sw`, `beq`, `bne`, `mtc0` có `uses_rt = 1`.
- Chỉ đúng một trong các nhóm {`branch`, `jump`, `jump_reg`, `multi`, `cp0_op`, `mem_*`} được bật trên mỗi dòng.

## 5. Ghi chú cho G1 (single-cycle)
- Dùng cùng bảng.
- `branch`, `jump`, `jump_reg`, `cp0_op = 10` điều khiển trực tiếp MUX PC.
- `multi ≠ 00` → giữ PC tới khi `done`, cùng logic `start`/`started` với `pipeline-policy.md` §6 (thay `ID/EX.multi` bằng `multi` của lệnh hiện tại): `start` chỉ là 1 xung dù lệnh được giải mã lại mỗi chu kỳ; `stall = multi ≠ 00 and not done` (không dùng `busy`, vì ở chu kỳ start `busy` còn 0).
- Khối nhiều chu kỳ bước **1 lần mỗi chu kỳ CPU** (G1: ở cạnh pha A; G2: mỗi `cpu_ce`), nên `div` = 32 chu kỳ CPU ở cả hai core.
- Ngắt ở G1 (tầng 2): nhận ở **cuối** lệnh, khi không `busy` và lệnh vừa xong không phải `mtc0`/`eret`; `EPC ← next_pc` (lệnh kế tiếp chưa chạy), `PC ← 0x180`, `EXL ← 1` (`isa-spec.md` §5).
- Thời điểm bộ nhớ ở G1 (2 pha trên cùng clock): `mmio-map.md` §1.1.
- Các cột `uses_*` không dùng ở G1.
