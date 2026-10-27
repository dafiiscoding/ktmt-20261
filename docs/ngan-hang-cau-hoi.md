# ngan-hang-cau-hoi.md — Ngân hàng câu hỏi xoáy + bài sửa code tại chỗ

> **Trạng thái:** bản nháp v2. Claude soạn 01/10/2026 cho đề đồng hồ điện tử (`PLAN_DONG_HO.md`), giữ phần TV2/TV3 của bản v1 (24/09). Dùng cho **cổng bảo vệ** (`KE-HOACH-LAM-VIEC.md` §4b).
> Mỗi người **tự bổ sung** câu cho module của mình khi viết code. Câu nào hỏi mà cả nhóm bí → thêm vào đây.
> Cột "Ý phải có" chỉ là **gợi ý chấm**. Khi đã có code, đáp án đúng là **dòng code + kết quả test**, không phải câu trong file này.
> Code chưa có (10/2026), nên mọi "chỉ dòng" hiện chỉ trỏ tới tài liệu. Từ S2 trở đi, thay bằng `file.v:dòng`.
> Viết tắt: **plan** = `PLAN_DONG_HO.md` · **policy** = `docs/pipeline-policy.md` · **control** = `docs/control-table.md`.

## 0. Luật chấm (tóm tắt §4b)
- **Vấn đáp:** 10 câu module mình (đạt ≥ 8) + 5 câu chéo (đạt ≥ 3). Chỉ nói lý thuyết mà **không chỉ được dòng code/test** → nửa điểm.
- **Sửa tại chỗ:** bốc 1 bài ở §9, 30 phút, test PASS.
- **Chạy lại test** trên máy người khác + giải thích 1 test FAIL do người hỏi cài bug.
- **Ứng dụng:** 1 chức năng đồng hồ + 1 con số E1–E4 (§8).

---

## 1. TV1 — ALU & khối số học
| # | Câu hỏi | Ý phải có | Ở đâu |
|---|---|---|---|
| 1.1 | `xor` dùng ở đâu trong firmware? Không có `xor` thì làm sao? | checksum câu sync; `a xor b = (a or b) − (a and b)`, tốn 3 lệnh | plan §6; control #5 |
| 1.2 | `slt` với −1 và 1 ra gì? Vì sao TIMER âm cần `slt` có dấu? | 1; giá trị TIMER là số bù 2 có dấu | plan §4.1, §4.5 |
| 1.3 | `addu` tràn thì sao? | không bẫy, quay vòng modulo 2³² | control #1 |
| 1.4 | `sra $t0,$t1,31` cho gì? Dùng nó lấy trị tuyệt đối TIMER âm thế nào? | 0 hoặc −1 (mặt nạ dấu); `abs = (x xor m) − m` | plan §2 |
| 1.5 | `div` −7 cho 2 ra LO, HI bao nhiêu? | thương làm tròn về 0: LO = −3, HI = −1 | plan §4.5 |
| 1.6 | Chia 0 thì phần cứng trả gì, firmware biết bằng cách nào? | LO = 0, HI = số bị chia, cờ `dz` ở `DIV_FLAGS` (nhóm tự định nghĩa) | plan §4.5, §5 |
| 1.7 | Double-dabble: vì sao cộng 3 khi chữ số ≥ 5? | sau khi dịch trái, chữ số ≥ 10; cộng 3 trước dịch = cộng 6 sau dịch = bù từ hệ 16 sang hệ 10 | plan §4.5 |
| 1.8 | `bcd` tổ hợp và tuần tự đánh đổi gì? Đo ở đâu? | LUT + đường găng (Fmax) vs ≈ 27 chu kỳ `busy`; timing report sau P&R + `CYCLE_COUNT` | plan §4.5, §8.1 |
| 1.9 | Vì sao 99 999 999 cần 27 bit? | 2²⁶ = 67 108 864 < 10⁸ − 1 < 2²⁷ | plan §4.5 |
| 1.10 | `mul` dùng DSP: có được nói "CPU không dùng DSP" không? | không; ghi rõ trong bảng tài nguyên | plan §4.5, §8.2 |

## 2. TV2 — assembler, ISS, hazard
| # | Câu hỏi | Ý phải có | Ở đâu |
|---|---|---|---|
| 2.1 | `div ms, 1000` rồi `mflo`, `mfhi` → cái nào là giây, cái nào là ms lẻ? | LO = thương = giây, HI = dư = ms | plan §6 `fmt.s` |
| 2.2 | Mã máy của `eret` là gì? `asm.py` sinh ra sao? | `0x42000018` (op 0x10, bit CO, funct 0x18) | control §3 |
| 2.3 | Làm sao biết `asm.py` đúng? | so mã máy với MARS trên cùng file `.s` (phần MIPS thuần) | plan §7 TV2 |
| 2.4 | ISS mô phỏng ngoại vi (timer, nút) tới mức nào? Thiếu thì test gì không được? | mô hình tối thiểu theo MMIO; độ chính xác thời gian thật chỉ kiểm trên RTL/board | plan §7 TV2 |
| 2.5 | Viết đoạn 3 lệnh gây **load-use**. Dự kiến bao nhiêu bubble? | `lw $t0`; `addu _,$t0,_` → 1 bubble | policy §4, T2 |
| 2.6 | `lw $t0,0($s0)` rồi `addiu $t0,$s1,4`: có stall không? Vì sao? | không; `addiu` ghi `rt` chứ không đọc, `uses_rt = 0` | policy §4; control §4 |
| 2.7 | EX/MEM và MEM/WB cùng ghi `$t0`: forward từ đâu? | EX/MEM (mới hơn), ưu tiên | policy §3 |
| 2.8 | Dòng nào chặn forward khi `dst = $0`? Bỏ đi thì lỗi ở ca nào? | `dst ≠ 0`; ca lệnh ghi `$0` làm bẩn toán hạng | policy §3 |
| 2.9 | File test hazard nào kiểm `lw` → `beq`? Dự kiến bao nhiêu chu kỳ? | T4; nhánh ở EX: 1 bubble | policy §7 T4, §8 |
| 2.10 | Nếu nhánh đặt ở ID (như Nhóm 3) thì T4 thay đổi gì? | cần 2 bubble + phải forward về ID; lợi: phạt nhảy 1 thay vì 2 | policy §5, T4 |

## 3. TV3 — CPU, CP0/ngắt, chip
| # | Câu hỏi | Ý phải có | Ở đâu |
|---|---|---|---|
| 3.1 | Kể độ rộng 4 thanh ghi tầng. Vì sao ID/EX lớn nhất? | 65 / 194 / 73 / 71 (+ debug); ID/EX mang 2 toán hạng + imm + control | policy §1 |
| 3.2 | Bỏ bit `valid` ở IF/ID thì lỗi gì? | BRAM đọc đồng bộ: thanh ghi ra không xóa được khi flush → lệnh bị flush vẫn chạy | policy §1, §5 |
| 3.3 | Regfile: ghi và đọc cùng chu kỳ cùng thanh ghi thì đọc ra gì? | giá trị mới (bypass nội) | policy §2 |
| 3.4 | Flush khi nhánh nhảy: xóa những thanh ghi tầng nào? Vì sao phạt 2? | IF/ID + ID/EX; nhánh quyết ở EX | policy §5, T3 |
| 3.5 | `busy`: đóng băng tầng nào, tầng nào vẫn chạy? | PC, IF/ID, ID/EX giữ; EX/MEM nhận bubble; MEM/WB chạy | policy §6 |
| 3.6 | Vì sao toán hạng `div`/`bcd` phải chốt ở chu kỳ `start`? | nguồn forward trôi đi trong lúc freeze → toán hạng đổi | policy §6 |
| 3.7 | Ngắt ở G1: khi nào được nhận? `EPC` bằng gì? Vì sao không nhận lúc `div` đang `busy`? | ranh giới lệnh, IE = 1, EXL = 0; `EPC` = PC lệnh chưa chạy; giữa `busy` thì lệnh chưa xong, quay lại sẽ chạy lại nửa chừng | plan §4.4; control §5 |
| 3.8 | `eret` làm gì? Trong pipeline phạt bao nhiêu? | PC ← EPC, EXL ← 0; quyết ở EX → phạt 2 | policy §5; control #28 |
| 3.9 | `lw` từ `0xFFFFFF00` bằng `$zero`: vì sao offset âm lại ra địa chỉ đó? | imm mở rộng dấu: −256 → 0xFFFFFF00 | plan §5 |
| 3.10 | Đọc `SW_LAP` có tác dụng phụ: vì sao an toàn trong pipeline polling? Có ngắt ở G2 thì sao? | chỉ tác động ở MEM, lệnh tới MEM không bị xóa; có ngắt chính xác thì phải kiểm lại (tầng 3) | plan §5 |

## 4. TV4 — Hiển thị, âm thanh, UART
| # | Câu hỏi | Ý phải có | Ở đâu |
|---|---|---|---|
| 4.1 | 8 chữ số, mỗi chữ số ≥ 100 Hz → khe quét tối thiểu bao nhiêu? Nhóm chọn bao nhiêu? | ≥ 800 Hz; chọn 1 kHz → 125 Hz/chữ số | plan §4.2 |
| 4.2 | Bóng ma là gì? Khoảng tắt sửa nó thế nào? | transistor tắt chậm → chữ số trước sáng mờ sang chữ số sau; tắt hết vài µs giữa hai khe | plan §4.2 |
| 4.3 | Nếu nạp lên board LED anode chung tích cực thấp thì sửa ở đâu? Chỉ dòng code đảo mức. | parameter `G_AN_ACTIVE_LOW`/`G_SEG_ACTIVE_LOW` ở `seg7_scan` | display §4 |
| 4.4 | Ai làm chữ số nhấp nháy? Vì sao không để CPU bật tắt? | phần cứng theo `BLINK_MASK`; CPU khỏi tốn vòng lặp, nháy đều kể cả khi CPU bận hoặc chạy xung thấp | plan §4.2 |
| 4.5 | PWM độ sáng 25% làm thế nào trong một khe quét? | chỉ bật đoạn trong 1/4 đầu khe | plan §4.2 |
| 4.6 | VGA 640×480@60: xung pixel và tổng số xung một dòng, một khung? | ≈ 25,175 MHz (dùng 25 MHz); 800 × 525 | plan §4.2 |
| 4.7 | Đuổi tia so với framebuffer: tốn gì, tiết kiệm gì? | 0 BRAM, tốn LUT so tọa độ vs 307 200 bit ≈ 37,5 KB BRAM + CPU phải vẽ | plan §4.2 |
| 4.8 | Vì sao VGA 25 MHz mà không có clock domain crossing? Đọc trúng lúc CPU ghi thì sao? | 25 MHz là clock enable trên clock 50 MHz chung; khung đó có thể nửa cũ nửa mới, vô hại | display §7 |
| 4.9 | Tiếng bíp 2 kHz từ 50 MHz: đếm tới bao nhiêu thì đảo chân? | nửa chu kỳ = 12 500 xung | plan §4.3 |
| 4.10 | UART 115 200: số chu kỳ/bit và sai số baud? Vì sao lấy mẫu ở giữa bit? | 50·10⁶ / 115 200 ≈ 434,03 → 434 → lệch +0,006%; giữa bit xa 2 cạnh nhất, chịu được lệch baud ~±4% tích lũy qua 10 bit | display §6 |

## 5. TV5 — Định thời chuẩn ms, sync
| # | Câu hỏi | Ý phải có | Ở đâu |
|---|---|---|---|
| 5.1 | "Độ phân giải 1 ms" khác "chính xác 1 ms" ở đâu? | phân giải = bước đếm; chính xác phụ thuộc ppm; 1 ms/giờ cần ≤ 0,28 ppm | plan §1 |
| 5.2 | `CAL` = 1 đơn vị (2⁻¹⁶ chu kỳ mỗi ms) bằng bao nhiêu ppm? | 2⁻¹⁶ / 50 000 ≈ 3·10⁻⁴ ppm | plan §4.1 |
| 5.3 | Hai lần sync cách 3 600 s, board **nhanh** 72 ms. Bao nhiêu ppm? Chỉnh `CAL` thế nào? Firmware tính ra bao nhiêu, vì sao lệch? | 20 ppm; mỗi ms dài thêm 1 chu kỳ → đúng là +65 536; firmware ra 65 500 vì công thức chống tràn cắt thương rồi nhân 50 | timer §2, §9 |
| 5.4 | Vì sao dấu thời gian nút lấy ở cạnh đầu, không lấy sau chống rung? | sau chống rung thì trễ không đều giữa các lần bấm → sai số start/stop không triệt tiêu | plan §4.1 |
| 5.5 | TIMER qua 0: cờ bật ở chu kỳ nào? Có bật lại ở −1, −2 không? | đúng lúc giá trị thành 0; không, chỉ một lần | plan §4.1 |
| 5.6 | Đọc giờ rồi đọc ngày đúng lúc 23:59:59.999 thì xé số thế nào? Thanh ghi bóng chặn ra sao? | giờ cũ + ngày mới; đọc `MS_OF_DAY` thì chụp `DAY`, firmware đọc bản chụp | plan §4.1 |
| 5.7 | Chỉnh giờ nhảy qua đúng phút báo thức: có kêu không? | phải nêu hành vi nhóm đã chọn + test chứng minh | plan §4.1, §10 |
| 5.8 | Nút đi qua 2 flip-flop đồng bộ để làm gì? | chống metastability (tín hiệu ngoài không đồng bộ với clock) | plan §4.1 |
| 5.9 | Vì sao 27 bit cho ms trong ngày, 29 bit cho stopwatch? | 86 399 999 < 2²⁷; 359 999 999 < 2²⁹ | plan §4.1 |
| 5.10 | E2: trễ USB-UART loại trừ thế nào? | đo trễ khứ hồi trước rồi trừ, báo kết quả kèm ± | plan §8.3 |

## 6. Câu chéo (ai cũng phải trả lời được)
| # | Câu hỏi | Ở đâu |
|---|---|---|
| X1 | Đi một lệnh `lw` qua 5 tầng: mỗi tầng làm gì, tín hiệu control nào bật? | control §2, policy §1 |
| X2 | Bấm START: tín hiệu đi qua những khối nào tới khi chữ số đổi trên LED? | plan §3, §4.1, §4.2 |
| X3 | G1 và G2 khác nhau ở đâu? Firmware có khác không? | plan §4.4 |
| X4 | Muốn chuẩn tới ms thì phần nào bắt buộc là phần cứng? Vì sao? | plan §1 |
| X5 | Chip của nhóm giống và khác chip Casio F-91W ở đâu? | plan §1, §12 |
| X6 | Kể 1 hazard, và file test nào chứng minh đã xử lý nó. | policy §8 |
| X7 | Phạm vi: đề tài **không** làm gì? (cache, ngắt trong pipeline, giây nhuận, bù nhiệt, LCD trần…) | plan §9 |
| X8 | Nếu G2 chưa xong vào 22/11 thì nhóm làm gì? | plan §9 luật cắt |
| X9 | ISA có bao nhiêu lệnh? Vì sao `bcd` dùng SPECIAL2 còn ngắt dùng COP0? | control §2–3 |
| X10 | 1 lệnh chạy test toàn bộ là lệnh gì? Mất bao lâu? | `run_all_tests` (S9) |

## 7. Kiểm thử (thầy dí phần này)
| # | Câu hỏi | Ý phải có |
|---|---|---|
| K1 | "Test PASS" nghĩa chính xác là gì trong nhóm? | khớp golden/ISS 100% trên bộ vector cụ thể; nói rõ bộ vector |
| K2 | Test của bạn **không** phủ cái gì? | nêu ít nhất 2 chỗ: timing thật, board, tổ hợp hazard chưa liệt kê, trôi nhiệt… |
| K3 | Cài 1 bug (ví dụ đảo ưu tiên forward): test nào bắt? Nếu không test nào bắt thì sao? | chạy thật tại cổng; không bắt → thêm test (mutation test) |
| K4 | Vì sao mô phỏng PASS mà board vẫn có thể sai? | timing, reset, clock domain, BRAM init, I/O thật, rung nút thật |
| K5 | Nguồn vector test sinh từ đâu? Nếu golden sai thì mọi test sai theo — chặn thế nào? | kiểm chéo độc lập: ISS vs golden Python vs ca tính tay |
| K6 | Ca biên nào của ALU, DIV, `bcd`, TIMER được test? | tràn, chia 0, `$0`, dịch 31; `bcd` 0, 99 999 999 và 10⁸; TIMER qua 0; nửa đêm |
| K7 | Test flush thế nào? | sau nhánh nhảy, 2 lệnh ghi thanh ghi; kiểm rằng chúng **không** ghi |
| K8 | Số bubble dự kiến ở mỗi test hazard lấy từ đâu? Đo bằng gì? | bảng T1–T8; `CYCLE_COUNT` hoặc trace |
| K9 | `system_tb` kịch bản 4 kiểm cái gì? | TIMER về 0 đúng ms, chuông kêu, rồi đếm âm đúng |
| K10 | Chạy lại toàn bộ test trên máy khác cần gì? | clone + 1 lệnh; không đường dẫn cứng |

## 8. Ứng dụng (thầy dí phần này)
| # | Câu hỏi | Ý phải có |
|---|---|---|
| U1 | E1: trôi bao nhiêu ppm trước và sau `CAL`, đo mấy lần, bao lâu? | số thật + điều kiện đo |
| U2 | So với Casio ±30 s/tháng thì hơn hay kém? So vậy có công bằng không? | quy ra ppm; nhóm chỉ đo 1–2 h, không qua nhiệt độ → nêu giới hạn |
| U3 | Đếm ngược 10 phút lệch bao nhiêu ms? Đã trừ trễ UART chưa? | số E2 kèm ± |
| U4 | Vì sao đồng hồ thật hiện 1/100 s chứ không phải ms? | ở 32 kHz phần mềm không kịp; E3 |
| U5 | Ở 32 kHz, cách nào còn đúng ms? | capture phần cứng; polling lỡ tick (số E3) |
| U6 | Mất sync nhiều ngày thì sao? | chạy tự do với `CAL` cuối; trôi theo nhiệt độ |
| U7 | Đếm ngược sang âm dùng ở đâu ngoài đời? | thuyết trình, thi đấu, bếp: biết đã quá giờ bao lâu |
| U8 | Ngắt hơn polling ở điểm nào trên đồng hồ thật? | độ trễ phản hồi; CPU được ngủ (nhóm không làm ngủ) |
| U9 | Chữ số ms đổi khi đang chạy có ý nghĩa không? | mắt không đọc kịp; ý nghĩa nằm ở lúc stop/lap |
| U10 | Nhiệt độ đổi thì sao? | thạch anh lệch ppm theo nhiệt; DS3231 có bù nhiệt, nhóm không → giới hạn |

---

## 9. Bài sửa code tại chỗ (30 phút, trừ khi ghi khác)
Người hỏi bốc 1 bài. Đạt = sửa xong + chạy test cũ vẫn PASS + tự viết 1 test mới PASS.

| # | Bài | Chạm những đâu | Dành cho |
|---|---|---|---|
| D1 | Thêm lệnh `nor rd,rs,rt` (R, funct 0x27) | control-table, `control.v`, `alu.v`, `asm.py`, `iss.py`, test | mọi người |
| D2 | Thêm `sltu` (funct 0x2B), giải thích khác `slt` ở ca nào | như D1 + ca âm/dương | TV1, TV3 |
| D3 | Tắt forward từ MEM/WB → chỉ ra test hazard nào FAIL và vì sao, rồi bật lại | forwarding unit | TV2, TV3 |
| D4 | Bỏ điều kiện `dst ≠ 0` → viết test bắt được bug này | forwarding unit + test mới | TV2, TV3 |
| D5 | **Trên giấy:** chuyển quyết định nhánh sang ID — liệt kê khối phải thêm, tín hiệu, stall mới; vẽ lại T3, T4 | policy §5, §7 | TV2, TV3 |
| D6 | Map công tắc vào địa chỉ trống `-108`; firmware đọc để chọn 12/24 h | giải mã MMIO, `mmio-map.md`, firmware | TV3, TV4 |
| D7 | Đổi số chữ số quét 8 → 6 (parameter), tính lại tần số quét | `seg7_scan.v`, tb | TV4 |
| D8 | Đổi snooze 5 → 10 phút; sửa kịch bản 5 của `system_tb` | `alarm.s`, `system_tb` | TV4, TV3 |
| D9 | `bcd` tuần tự xử lý 2 bit mỗi chu kỳ; đo lại chu kỳ và LUT | `bcd_unit.v`, tb | TV1 |
| D10 | Người hỏi **cài 1 bug bí mật** vào module của bạn; bạn tìm bằng testbench + waveform | module mình | mọi người |
