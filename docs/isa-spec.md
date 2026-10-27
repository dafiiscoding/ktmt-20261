# isa-spec.md — Tập lệnh WatchChip (28 lệnh), hợp đồng S1′

> **Trạng thái:** BẢN NHÁP v1 (01/10/2026). Claude viết; **chủ: TV2**, người duyệt: TV3. Freeze cuối S1′ (07/10).
> Sửa sau freeze: cả nhóm đồng ý + sửa cùng lúc `asm.py`, `iss.py`, `control.v`, vector `tb/vectors/`.
> Đi kèm: `control-table.md` (tín hiệu điều khiển), `pipeline-policy.md` (G2), `mmio-map.md` (địa chỉ).
> Nhãn: `unverified` = theo trí nhớ, TV2 đối chiếu *MIPS32 Architecture Vol. II* + MARS ở S1′.

## 1. Mô hình lập trình
- 32 thanh ghi 32 bit, `$0` luôn đọc ra 0 (ghi bị bỏ). HI, LO 32 bit. CP0: `$12` Status, `$13` Cause, `$14` EPC (§5).
- PC 32 bit, địa chỉ byte, lệnh luôn căn 4. **Không có delay slot**: lệnh ngay sau nhánh/nhảy chỉ chạy khi nhánh không nhảy.
- Reset: `PC = 0x0000_0000`, mọi GPR = 0, HI = LO = 0, Status = 0 (ngắt tắt), EPC = 0.
- Harvard:
  - **IMEM** `2^G_IMEM_AW` word, địa chỉ ngoài vùng → quay vòng (chỉ dùng bit [G_IMEM_AW+1:2]). Lõi một mình (`cpu_g1`, `cpu_pipe`): mặc định 10 → 1024 word `0x000`–`0xFFC`. **`soc_top` từ 26/10: 11 → 2048 word `0x0000`–`0x1FFC`** (`main.s` + sync = 1093 lệnh; xem §7).
  - **DMEM** 1024 word, địa chỉ dữ liệu `0x0000_0000`–`0x0000_0FFF`.
  - **MMIO** `0xFFFF_FF00`–`0xFFFF_FFFF` (truy cập bằng `lw/sw offset($zero)`, offset âm; chi tiết `mmio-map.md`).
  - Địa chỉ dữ liệu khác → đọc ra 0, ghi bị bỏ.
- `lw/sw` lệch 4 byte: **bỏ 2 bit thấp** (truy cập word chứa địa chỉ đó). Không có ngoại lệ căn lề.
- Không có ngoại lệ tràn số, lệnh lạ, hay địa chỉ sai. Nguồn duy nhất vào vector `0x180` là **ngắt** (§5).

## 2. Định dạng lệnh
| Khuôn | [31:26] | [25:21] | [20:16] | [15:11] | [10:6] | [5:0] |
|---|---|---|---|---|---|---|
| R | op = 0 | rs | rt | rd | shamt | funct |
| I | op | rs | rt | imm[15:11] | imm[10:6] | imm[5:0] |
| J | op | target[25:0] |||||
| SPECIAL2 | 0x1C | rs | rt | rd | 0 | funct |
| COP0 | 0x10 | sub (00 mf, 04 mt, 10 CO) | rt | rd (số thanh ghi CP0) | 0 | 0 hoặc 0x18 |

- `SE(imm)` = mở rộng dấu 16 → 32. `ZE(imm)` = mở rộng 0.
- Đích nhánh = `PC + 4 + (SE(imm) << 2)`. Đích `j/jal` = `(PC + 4)[31:28] ‖ target ‖ 00`.

## 3. Bảng 28 lệnh: mã hóa và ngữ nghĩa
Ký hiệu: `R[x]` thanh ghi, `M[a]` word bộ nhớ, `s(x)` hiểu có dấu, `u(x)` không dấu. Mọi phép cộng/trừ lấy 32 bit thấp, **không bẫy tràn**.

| # | Lệnh | op / funct | Ngữ nghĩa |
|---|---|---|---|
| 1 | `addu rd,rs,rt` | 00 / 0x21 | `R[rd] = R[rs] + R[rt]` |
| 2 | `subu rd,rs,rt` | 00 / 0x23 | `R[rd] = R[rs] − R[rt]` |
| 3 | `and rd,rs,rt` | 00 / 0x24 | `R[rd] = R[rs] & R[rt]` |
| 4 | `or rd,rs,rt` | 00 / 0x25 | `R[rd] = R[rs] \| R[rt]` |
| 5 | `xor rd,rs,rt` | 00 / 0x26 | `R[rd] = R[rs] ^ R[rt]` |
| 6 | `slt rd,rs,rt` | 00 / 0x2A | `R[rd] = s(R[rs]) < s(R[rt]) ? 1 : 0` |
| 7 | `sll rd,rt,sa` | 00 / 0x00 | `R[rd] = R[rt] << sa` (`sll $0,$0,0` = `nop` = 0x00000000) |
| 8 | `sra rd,rt,sa` | 00 / 0x03 | `R[rd] = s(R[rt]) >> sa` (dịch số học, chép bit dấu) |
| 9 | `jr rs` | 00 / 0x08 | `PC = R[rs]` (2 bit thấp bị bỏ) |
| 10 | `div rs,rt` | 00 / 0x1A | có dấu: `LO = thương làm tròn về 0`, `HI = dư` (cùng dấu số bị chia). Ca đặc biệt §4 |
| 11 | `mfhi rd` | 00 / 0x10 | `R[rd] = HI` |
| 12 | `mflo rd` | 00 / 0x12 | `R[rd] = LO` |
| 13 | `addiu rt,rs,imm` | 0x09 | `R[rt] = R[rs] + SE(imm)` |
| 14 | `slti rt,rs,imm` | 0x0A | `R[rt] = s(R[rs]) < s(SE(imm)) ? 1 : 0` |
| 15 | `andi rt,rs,imm` | 0x0C | `R[rt] = R[rs] & ZE(imm)` |
| 16 | `ori rt,rs,imm` | 0x0D | `R[rt] = R[rs] \| ZE(imm)` |
| 17 | `lui rt,imm` | 0x0F | `R[rt] = imm << 16` |
| 18 | `lw rt,imm(rs)` | 0x23 | `R[rt] = M[(R[rs] + SE(imm)) & ~3]` |
| 19 | `sw rt,imm(rs)` | 0x2B | `M[(R[rs] + SE(imm)) & ~3] = R[rt]` |
| 20 | `beq rs,rt,L` | 0x04 | nếu `R[rs] == R[rt]` thì nhảy |
| 21 | `bne rs,rt,L` | 0x05 | nếu `R[rs] != R[rt]` thì nhảy |
| 22 | `j L` | 0x02 | nhảy |
| 23 | `jal L` | 0x03 | `R[31] = PC + 4`; nhảy |
| 24 | `mul rd,rs,rt` | 0x1C / 0x02 | `R[rd] = 32 bit thấp của s(R[rs]) × s(R[rt])`. **HI, LO không đổi** (MIPS32 để "không xác định"; nhóm chốt "không đổi") |
| 25 | `bcd rd,rs` | 0x1C / 0x10 | nếu `u(R[rs]) ≤ 99 999 999`: `R[rd]` = 8 chữ số thập phân, mỗi chữ số 4 bit, chữ số hàng đơn vị ở [3:0]. Ngược lại `R[rd] = 0xFFFF_FFFF` |
| 26 | `mfc0 rt,rd` | 0x10 / rs = 0x00 | `R[rt] = CP0[rd]` |
| 27 | `mtc0 rt,rd` | 0x10 / rs = 0x04 | `CP0[rd] = R[rt]` (chỉ các bit ghi được, §5) |
| 28 | `eret` | 0x42000018 | `PC = EPC`, `Status.EXL = 0` |

- Mọi mã khác (opcode, funct, hay trường `rs` của COP0 không có trong bảng) → **NOP**: không ghi gì, PC + 4. Testbench báo `assert` "lệnh lạ".
- `bcd` ví dụ: `12 345 678` → `0x12345678`; `0` → `0x00000000`; `100 000 000` → `0xFFFFFFFF`; `−1` (= `0xFFFFFFFF`) → `0xFFFFFFFF`.
- Funct 0x10 của SPECIAL2 nằm trong vùng UDI (funct 16–31) của MIPS32 (`unverified`, TV2 kiểm Vol. II ở S1′).

## 4. `div`: ca đặc biệt (nhóm tự định nghĩa, MIPS để "không xác định")
| Ca | LO | HI | `DIV_FLAGS.DZ` |
|---|---|---|---|
| chia cho 0 | `0` | `R[rs]` | 1 |
| `0x8000_0000 / −1` | `0x8000_0000` | `0` | 0 |
| ca thường | thương trunc | dư | 0 |

- `DZ` phản ánh **lệnh `div` gần nhất** (không dính): `div` kế tiếp không chia 0 thì DZ về 0.
- Ví dụ: `−7 / 2` → LO = −3, HI = −1. `7 / −2` → LO = −3, HI = 1. `−7 / −2` → LO = 3, HI = −1.
- Thời gian: `div` chạy **32 chu kỳ CPU** + chu kỳ phát lệnh (TV1 ghi số thật vào báo cáo). `bcd` bản tuần tự ≤ 32 chu kỳ. Trong thời gian `busy`, core đứng (G1 giữ PC; G2 theo `pipeline-policy.md` §6).
- `mfhi/mflo` ngay sau `div`: core đã đứng đến khi `busy = 0` nên luôn đọc đúng; **không có luật "cách 2 lệnh" của MIPS cũ**.

## 5. CP0 và ngắt
| Thanh ghi | Bit | Đọc | Ghi bằng `mtc0` | Reset |
|---|---|---|---|---|
| `$12` Status | [0] IE (cho phép ngắt), [1] EXL (đang trong handler) | có | [1:0] ghi được, bit khác bỏ | 0 |
| `$13` Cause | [15:8] IP = `IRQ_PENDING & IRQ_ENABLE` (đọc trực tiếp, không chốt), bit khác 0 | có | bỏ qua | — |
| `$14` EPC | 32 bit | có | ghi được (2 bit thấp ép 0) | 0 |
| khác | — | 0 | bỏ qua | — |

Vị trí IE, EXL, IP giống MIPS32 thật (`unverified`, TV2 kiểm Vol. III), nên `mfc0`/`mtc0` trong MARS dùng được để thử logic.

**Điều kiện nhận ngắt (G1, tầng 2):** `irq = 1` và `IE = 1` và `EXL = 0` và lệnh vừa xong **không** phải `mtc0`/`eret` và core **không** `busy`.
- Ngắt được nhận **ở cuối** một lệnh: lệnh đó chạy xong bình thường (kể cả ghi bộ nhớ, MMIO), rồi:
  - `EPC ← next_pc` (địa chỉ lệnh **kế tiếp chưa chạy**; nếu lệnh vừa xong là nhánh nhảy thì là đích nhánh);
  - `PC ← 0x180`, `EXL ← 1`.
- Lý do chọn "nhận ở cuối lệnh": không phải hủy lệnh đang chạy, nên không có nguy cơ đọc MMIO có tác dụng phụ rồi bỏ kết quả.
- Lý do chặn sau `mtc0`/`eret`: cùng chu kỳ đó Status đang bị ghi; nhận ngắt sẽ đụng hai lệnh ghi EXL.
- `irq` là mức (level): handler phải ghi 1 vào bit tương ứng của `IRQ_PENDING` để xóa, rồi `eret`. Quên xóa → lệnh tại `EPC` chạy đúng 1 lệnh (vì sau `eret` bị chặn) rồi vào lại handler.
- Ngắt lồng nhau: không hỗ trợ (EXL = 1 chặn).
- **G2:** có ngắt chính xác từ 21/10 (`pipeline-policy.md` §10, cosim + ModelSim PASS). `fw/main.s` bật ngắt UART_RX (`USE_IRQ = 1`) trên cả G1 và G2 từ 26/10 (Long chốt sửa spec theo thực tế); `USE_IRQ = 0` là bản polling, vẫn chạy trong hồi quy.

## 6. Quy ước phần mềm
- Thanh ghi theo o32: `$a0–$a3` tham số, `$v0–$v1` trả về, `$t*` tạm (người gọi lưu), `$s*` (người bị gọi lưu), `$ra`, `$sp`.
- `$sp` khởi tạo `0x0000_1000` (đỉnh DMEM), stack đi xuống. `$k0`, `$k1` dành riêng cho handler ngắt.
- Handler ở `0x180` phải lưu mọi thanh ghi nó dùng (trừ `$k0/$k1`) vào vùng DMEM riêng.
- Bố cục IMEM: `0x000` = `j main`; `0x180` = handler (hoặc `eret` nếu không dùng ngắt).

## 7. Assembler (`tools/asm.py`, TV2)
- Cú pháp MARS: nhãn, `#` chú thích, thanh ghi tên (`$t0`) hoặc số (`$8`), số thập phân/hex.
- Chỉ thị: `.text`, `.data`, `.word`, `.space`, `.org <địa chỉ>` (cho `0x180`), `.eqv`.
- Lệnh giả (mở rộng **giống MARS**, `unverified`, TV2 kiểm bằng cách dịch cùng file trên MARS):
  - `nop` → `sll $0,$0,0`; `move rd,rs` → `addu rd,$0,rs`;
  - `li rt,k`: vừa 16 bit có dấu → `addiu rt,$0,k`; vừa 16 bit không dấu → `ori rt,$0,k`; còn lại → `lui $at,hi` + `ori rt,$at,lo`;
  - `la rt,nhãn` → `lui $at,hi` + `ori rt,$at,lo`. **Khác MARS (verified 02/10):** MARS 4.5 dịch `la` với nhãn nhỏ thành `addi rt,$0,nhãn` — `addi` không thuộc 28 lệnh → `asm.py` phải dùng `lui`+`ori` (hoặc `ori` khi vừa 16 bit), không chép MARS; chương trình so với MARS không dùng `la` (`fw/tests/cpu/README.md`);
  - `b L` → `beq $0,$0,L`.
- Đầu ra: `imem.hex`, `dmem.hex`: mỗi dòng 8 chữ số hex, đủ `2^G_IMEM_AW` dòng (mặc định 1024; thiếu thì 0). `asm.py` **cảnh báo khi chương trình > 900 lệnh** (theo tỉ lệ IMEM: `--aw 11` → > 1 800, từ 26/10); firmware lớn hơn thì đặt `G_IMEM_AW = 11` (2048 lệnh, BRAM board còn dư), đọc bằng `hread` trong VHDL. **Đã đặt 11 cho `soc_top` ngày 26/10, Long duyệt giữ (Q5)** (`fw_build.py` dịch `--aw 11`); so với MARS dùng cấu hình `Default` khi > 1024 lệnh (`CompactTextAtZero` chỉ có 4 KB .text), đích `j/jal` trừ lại `0x00400000 >> 2`. Thêm `*.lst` (địa chỉ, mã, dòng nguồn) để gỡ lỗi.
- Báo lỗi có số dòng: nhãn trùng/thiếu, offset nhánh vượt 16 bit, thanh ghi sai, lệnh không có trong 28 lệnh + lệnh giả trên.
- So với MARS: dùng cấu hình bộ nhớ "Compact, Text at Address 0" (`unverified` tên chính xác), chỉ so chương trình không có nhãn `.data` (vì `.data` của MARS không ở 0).
- **`asm.py` bản đầu 03/10** (Claude viết) chốt thêm những chỗ trên chưa nói (TV2 duyệt):
  - `li` xét giá trị theo **32 bit** như MARS (verified 03/10): `li $t,0xffffffff` = −1 → `addiu`; `0x8000…0xFFFF` → `ori`; còn lại `lui $at` + `ori`.
  - `la` luôn 2 lệnh (`lui $at` + `ori`), kể cả nhãn nhỏ, để kích thước biết ngay ở lượt 1.
  - `.space n`: `n` byte, phải là bội của 4 (bộ nhớ theo word). `.data` bắt đầu ở địa chỉ DMEM 0 (Harvard); `.data <địa chỉ>` / `.text <địa chỉ>` đổi chỗ đặt.
  - Nhánh: offset 16 bit có dấu đủ khoảng −32 768 … +32 767 lệnh (B1-4 ghi "±32 767"; lùi −32 768 vẫn mã hóa được nên cho phép).
  - Không có `.globl`, `.align`, biểu thức (`X+4`), `lw $t, nhãn` → báo "chỉ thị/lệnh không hỗ trợ".
  - So với MARS (B1-2, `tools/test_asm.py`): 13 file trong `fw/` (gồm `main.s` 856 word) + 15 ca biên `li` giống từng word. `all28.s` không so vì có `la`/`b` (khác MARS có chủ đích).

## 8. Trace (dùng chung ISS, RTL G1, RTL G2)
Mỗi lệnh **hoàn thành** (G1: cuối chu kỳ; G2: khi qua WB) ghi đúng 1 dòng CSV:

```
cycle,pc,instr,rd,value,mop,maddr,mdata
```
- `cycle`: số chu kỳ hệ thống (ISS ghi số thứ tự lệnh). `cmp_trace.py` **bỏ qua** cột này khi so.
- `pc`, `instr`: hex 8 chữ số.
- `rd`, `value`: thanh ghi đích (thập phân) và giá trị ghi (hex). Không ghi GPR → `rd = 0`, `value = 00000000`.
- `mop`: `-` không truy cập, `R` đọc, `W` ghi. `maddr`, `mdata`: hex; `-` → `00000000`.
  - `maddr` = địa chỉ word đã bỏ 2 bit thấp (`lw/sw` lệch truy cập word chứa nó, §1); `mdata` = giá trị đọc về (`R`) hoặc ghi ra (`W`). (RTL G1 ghi theo quy ước này từ 02/10; ISS phải giống.)
- Lệnh `div`/`mtc0` không ghi GPR → `rd = 0` (`mul` **có** ghi `rd`). Muốn so HI/LO thì so ở `mfhi/mflo` sau đó.
- Vào handler ngắt: thêm 1 dòng `pc = 00000180`, `instr = INTERRUPT` trước lệnh đầu của handler.
- **Chế độ replay MMIO:** khi so RTL với ISS, ISS lấy giá trị các `lw` vào vùng MMIO **từ trace RTL** (cột `mdata`) thay vì tự mô phỏng ngoại vi, và **nhận ngắt đúng chỗ** trace RTL có dòng `INTERRUPT`. Nhờ vậy đồng hồ, nút, UART không làm lệch co-sim; chỉ cần lệnh của CPU khớp.
- **Chế độ chạy độc lập:** ISS có mô hình ngoại vi tối thiểu (`MS_OF_DAY` tăng 1 sau mỗi `K` lệnh, nút và byte UART lấy từ file kịch bản) để chạy firmware khi chưa có RTL.
- **Replay còn một chỗ mù (03/10):** `mfc0 Cause` cũng lấy giá trị từ trace RTL (Cause phụ thuộc ngoại vi), nên RTL đặt sai bit IP trong Cause thì trace vẫn khớp. Lỗi đó chỉ bắt được bằng dòng `# expect` (vd. `cp0.s` `$t2 = 0x100`) hoặc tb đơn vị. Tương tự, replay chỉ bắt được RTL nhận ngắt **khi không được phép**; RTL **bỏ lỡ** một ngắt lẽ ra phải nhận thì replay không thấy (vì không biết mức `irq`) — phần này do `irq_tb`/`soc_irqlat_tb` kiểm.
