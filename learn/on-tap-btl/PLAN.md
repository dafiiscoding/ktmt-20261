# PLAN bộ ôn BTL Kiến trúc máy tính (MI4344, WatchChip)

Viết 08/11/2026, cập nhật tối 08/11 sau khi soát K1 (§9). Đây là hợp đồng tự đủ cho người dựng. Không đọc lại cả repo, không tự nghĩ thêm phạm vi.
Bộ ôn Kho dữ liệu là việc khác, ở repo khác: `hoc-tap/study-mi4214-kho-du-lieu/learn/on-tap-btl/PLAN.md`. Không dùng chung nội dung.

## 0. Bài này cần gì

| Câu hỏi | Trả lời |
|---|---|
| Ai dùng | 5 thành viên (TV1–TV5) và Long, tự đọc. |
| Để làm gì | Hiểu con chip đủ để qua 3 cổng vấn đáp và buổi bảo vệ, nói được bằng lời mình, chỉ được dòng code. |
| Thi kiểu gì | Cổng: vấn đáp ≥ 8/10, ≥ 3/5 câu chéo, sửa tại chỗ 30 phút, chạy lại test, nêu ứng dụng. Nguồn: `report/KHUNG-BAO-CAO.md`, `docs/hop-nhom-01-ban-giao.md` §2. |
| Mốc | 14/11 Cổng 1 · 21/11 Cổng 2 · 05/12 Cổng 3 · tuần 14 bảo vệ (≈ 07–13/12, `unverified`). |
| Trục kiến thức | Đường đi của tín hiệu và bảng chu kỳ. Không đi theo barem, vì **chưa có đề và barem gốc** (§7). |
| Câu hỏi xuyên suốt | Muốn đồng hồ chuẩn tới 1 ms thì phần nào phải là phần cứng? |

**Cần hiểu chính xác, thành viên nào cũng phải đạt:**

1. Viết được đường đi của `lw` đọc `MS_OF_DAY` qua chip, ở G1 và ở 5 tầng G2.
2. Vẽ tay được bảng chu kỳ cho forwarding, load-use, nhánh nhảy thật, `div` (bảng T1, T2, T3, T5 ở `docs/pipeline-policy.md` §7).
3. Tính được: 1 ppm = 3 276,8 đơn vị `CAL`; thời gian = số lệnh × CPI / tần số.
4. Giải thích vì sao capture phần cứng sai 0 chu kỳ còn polling và ngắt thì không, bằng số E3.
5. Nói được vì sao tin chip đúng và giới hạn của niềm tin đó: chỉ mô phỏng, phần lớn code do Claude viết.

**Không cần trong bộ ôn này:** viết code mới, học thêm ISA ngoài 28 lệnh, số Fmax (chưa có Vivado), thiết kế lại chip.

## 1. Long chốt và mặc định t đã chọn

Yêu cầu của Long (08/11): bộ ôn HTML kiểu ĐA2, riêng cho KTMT, có phần **học nhanh** gồm ý chính, làm những gì, ý nghĩa gì, tóm tắt kiến thức. Không lẫn với Kho.

Long chốt thêm tối 08/11 sau khi xem K1: **bỏ hết chữ dạy** (lời nhắc người dạy, lịch buổi dạy), từ ngữ phải chi tiết và dễ hiểu hơn. Trang viết cho người đọc tự học.

Mặc định chưa được Long chốt riêng (sửa được khi duyệt plan):

- Phần học nhanh nằm ngay trong `ON-TAP-KTMT.html`, không tách file. Các phiên sau thêm chương vào cùng file.
- Không ghép tên thật vào TV1–TV5, vì `docs/hop-tuan.md` còn trống bảng tên.

## 2. Lịch phiên

| Phiên | Hạn | Việc | Đầu ra | Gate |
|---|---|---|---|---|
| K1 | **Đã xong 08/11** | Khung + Phần 0 Học nhanh + 15 MCQ | `ON-TAP-KTMT.html`, `nguon/00-hoc-nhanh.md` | Codex dựng, Claude viết lại sau soát (§9) |
| K2 | 10/11 | Bài mẫu A2 (G1 + đường đi `lw`) đúng khuôn 9 mục, file `nguon/01-khoi-a.md` | Thêm 1 bài | **Claude soát (§6.3) rồi Long duyệt khuôn.** Chưa duyệt thì không làm K3 |
| K3 | 12/11 | Khối A còn lại: A1, A3, A4, A5 + đề nhanh A (25 MCQ) | Đủ khối A | Trước Cổng 1 hai ngày |
| K4 | 15/11 | Khối B phần CPU: B1 pipeline + forwarding, B2 load-use + nhánh + busy, B3 ngắt G1/G2, file `nguon/02-khoi-b.md` | Thêm 3 bài | |
| K5 | 18/11 | Khối B phần chip: B4 timers + nút, B5 firmware + sync, đề nhanh B (25 MCQ) | Đủ khối B | Trước Cổng 2 ba ngày |
| K6 | 28/11 | Khối C: C1 E1′–E4′, C2 CPI + DSE, C3 bảo vệ (câu chéo, sửa tại chỗ, ứng dụng), đề nhanh C (25 MCQ), `nguon/03-khoi-c.md`; đề tổng 30 MCQ `nguon/99-de-tong.md`, ID `KT-R-nn` | Bộ ôn đủ | Trước Cổng 3 một tuần |

Mỗi phiên đúng một lượt, tự dừng sau nghiệm thu §6. Trước mỗi phiên đọc §9. Nếu đề/barem gốc xuất hiện, dừng và báo Long trước khi viết tiếp.

## 3. Luật cứng

**Ghi:** chỉ trong `learn/on-tap-btl/` và `.ai/`. Không sửa `src/ fw/ tb/ tools/ docs/ report/ evidence/`. Không commit, không push.

**Ưu tiên nguồn khi lệch nhau:** code → evidence log mới nhất → `docs/*-spec.md` + `pipeline-policy.md` → `report/` → `hop-nhom-01` → `ngan-hang-cau-hoi.md`. Ngân hàng câu hỏi soạn 01/10, trước khi có code.

**Lệch đã biết, phải viết theo cột phải:**

| Chỗ lệch | Dùng |
|---|---|
| `report/3.6-bang-dat.md:42` ghi "Ngắt chính xác ở pipeline CHƯA LÀM" | Đã làm: `src/cpu_pipe.v:122`, `:202`, `pipeline-policy.md` §10 |
| `ngan-hang-cau-hoi.md` X7 "không làm ngắt trong pipeline", 4.2 bóng ma bản trước 27/10, X10 `run_all_tests` | Theo code và `tools/run_unit.sh` |
| `hop-nhom-01` ghi `alu.v` dòng 17, `div` 32 chu kỳ | `lt` ở `src/alu.v:26`. `div` = 33 chu kỳ CPU: start + 32 bước (`src/muldiv.v:7`) |
| G2 "lệnh ở IF/ID bị hủy" (hop-nhom) | Lệnh ở ID và ID/EX bị hủy, EX/MEM và MEM/WB chạy nốt, EPC = lệnh cũ nhất chưa xong (`src/cpu_pipe.v:11`, `:122`) |
| pytest 96, `bcd` ≈ 27 | Log: 97 passed 1 skipped. Đo `bcd` theo `report/3.4-dse.md`: 162 chu kỳ cho cả phép đổi tuần tự, không trộn với B ở T8 |
| "bảo vệ S11" trong `PLAN-TRINH-BAY.md` | Tuần 14, `unverified` |
| `cpu_pipe`, `cpu_g1` qua `run_unit.sh` | FAIL (`thieu +imem=`), đã chạy 08/11; hai tb này có `(cosim)` ở dòng đầu. G2 chạy qua `python tools/cosim_iss.py --rand 0`. `hop-nhom-01:97` đã sửa theo Long chọn A |
| `docs/de-bai.md:10` "chỉ mô phỏng" | Long điền, không phải lời thầy. Không viết "thầy đồng ý không cần board" |

**Nhánh cloud chưa merge:** `origin/claude/keen-euler-97msdk` (`f027840`). Không đọc số từ nhánh đó. Khi nói E1′ phải kèm câu: "≤ 0,1 ppm là kết quả mô phỏng tách riêng firmware với timebase; review cloud nói CAL học lệch −16,7…−20 ppm khi PC gửi mỗi phút, chưa kiểm local". Nhãn `unverified`.

**Nói thật, có trong bài:** chỉ mô phỏng, không board; `G_N = 50` nén 1 ms để mô phỏng; số LUT/FF là Yosys, không phải Vivado (`inference`); phần lớn code do Claude viết, cách khai với thầy chưa chốt (`docs/kich-ban-demo.md` §5); G2 chỉ chạy hồi quy, demo là G1.

**Chống lẫn với Kho (`CHUOI_CAM`, build fail nếu thấy):** `DuckDB`, `Power BI`, `SCD2`, `Fact_`, `Dim_`, `HistGB`, `Parquet`, `Kechinov`, `ĐA2`, `Freddie`, `Bích`. Key localStorage `on-tap-ktmt-v1`. ID MCQ tiền tố `KT-`.

**Câu chữ:** tiếng Việt có dấu, câu ngắn, viết cho người chưa từng đọc Verilog. Không viết công thức LaTeX. Thuật ngữ lần đầu phải giải thích bằng một ví dụ đời thường. Trình bày tên lệnh và thanh ghi trong backtick.

**Người đọc:** Long và cả nhóm chưa có kiến thức nền. Coi như người học ngành khác, chưa biết bit, bộ nhớ, clock là gì. Tiêu chuẩn: đọc một lượt hiểu được ý chính mà không phải hỏi thêm. Cụ thể:

1. Từ chuyên môn nào cũng giải thích ngay câu đó ở lần đầu trong bài, kể cả đã có trong từ điển H1. Không dùng từ chưa giải thích để giải thích từ khác.
2. Cơ chế nào cũng có một hình dung đời thường đúng bản chất, rồi mới tới tên kỹ thuật. Vẫn giữ tên kỹ thuật vì thầy hỏi bằng tên đó.
3. Bảng, sơ đồ nào cũng có câu hướng dẫn cách đọc. Phép tính viết từng bước, nói mỗi bước để làm gì.
4. Lệnh phải nói gõ ở đâu, kết quả trông thế nào, đọc ra sao.

**Giọng văn mẫu:** `nguon/00-hoc-nhanh.md`, mục H0, H2 và thẻ 5, 6, 8. Đọc các chỗ này trước khi viết. Từ đã có trong từ điển ở H1 thì dùng đúng nghĩa đó.

**Không đưa vào trang:** lời nhắc người dạy, lịch buổi học, câu kiểu "hỏi cả nhóm", ký hiệu `§`, tên plan, tên model. Trang chỉ có kiến thức.

**Câu hỏi nào cũng phải có câu trả lời ngay trong bài.** Dàn bài trong plan ghi câu hỏi nghĩa là phải viết cả lời giải, không phải chép câu hỏi.

## 4. Khung và sự kiện dùng chung

### 4.1 Khung đã có, không làm lại

`dung.py`, `so_ktmt.py`, `nguon_chuan.csv`, `kiem/`, `thu_trinh_duyet.py` đã chạy thật 08/11 (`verified`). **Không sửa `kiem/noi_dung.py`.** Không sửa builder trừ khi `--check` báo lỗi của chính builder; khi đó ghi rõ vào báo cáo.

Cú pháp dùng được:

| Viết | Dùng cho |
|---|---|
| `{{so:cpi-g2}}` | Mọi số có trong sổ §4.2 |
| `{{doc:src/alu.v:26}}` | Mỏ neo `file:dòng` (có kiểm dòng tồn tại) |
| `{{code:...}}`, `{{trich:...}}` | Trích code, cú pháp xem `dung.py:145` |
| `:::bay`, `:::thay-hoi`, `:::ban-do`, `:::trong-chip`, `:::sua-tai-cho`, `:::dung-o-dau` … `:::` | Các hộp |
| `:::suy-dan`, `:::tu-luan` … `---` … `:::` | Câu hỏi, dòng `---`, lời giải |
| `:::mcq id=KT-A2-01` … `:::` | Trắc nghiệm, cú pháp bên dưới |

```
:::mcq id=KT-A2-01
? Câu hỏi?
- [x] Đáp án đúng
- [ ] Sai một
- [ ] Sai hai
- [ ] Sai ba
> Giải thích: vì sao đúng, vì sao ngộ nhận chính sai. Không nhắc chữ A/B/C/D vì lựa chọn bị xáo.
:::
```

Ba lựa chọn sai phải là ngộ nhận thật, dài xấp xỉ đáp án đúng. Máy chấm: đáp án đúng dài nhất ở quá 40% số câu là fail.

### 4.2 Sổ số `so_ktmt.py` (đã có 21 ID)

Không gõ tay các số này. Chạy `python so_ktmt.py` để xem giá trị.

| ID | Giá trị | Nguồn |
|---|---|---|
| `system-tb`, `system-tb-poll` | 589, 589 | `evidence/20261027_regress_rbuf.log` |
| `cosim-iss`, `cosim-mars` | 25, 19 | cùng log |
| `pytest` | 97 passed, 1 skipped | cùng log |
| `cpi-g1`, `cpi-g2` | 1,428, 2,027 | `evidence/20261026_cpi.log` |
| `g2-loaduse`, `g2-nhanh`, `g2-busy` | 33857, 157608, 157114 chu kỳ | cùng log |
| `tang-sum100`, `tang-fact10`, `tang-bcd` | ×1,21, ×1,34, ×1,39 | `report/3.3-cpi.md:35` |
| `e3-poll-tb`, `e3-poll-max` | 740,44 µs, 1358,12 µs | `evidence/20261026_exp_e3.log` |
| `e3-ngat-tb`, `e3-ngat-max` | 466,40 µs, 1037,28 µs | cùng log |
| `e3-capture` | 6 000/6 000 | `report/2.5-e3-thi-nghiem.md:31` |
| `e1-cal-20`, `e1-con-20`, `e1-cal-250` | 65500, +0,020 ppm, 0 | `evidence/20261026_exp_cal.log` |

Được chép nguyên bảng (không cần sổ): bảng E3 `report/2.5-e3-thi-nghiem.md` dòng 25–31, bảng T2 và T3 `docs/pipeline-policy.md` dòng 202–216.

`python so_ktmt.py` còn kiểm log có đúng 41 dòng PASS và `EXIT 0`. Câu "41 mục PASS" viết tay được sau khi lệnh này qua. `kiem/H.py` đã assert mọi phép tính ở §4.3.

### 4.3 Sự kiện đã chốt

Soát với code ngày 08/11. Dùng nguyên, đừng suy lại.

**Đường đi `lw $t0, -252($zero)`.** −252 mở rộng dấu thành `0xFFFFFF04`, tức vùng ngoại vi, thanh ghi `MS_OF_DAY`.

G1, một chu kỳ CPU gồm 2 pha (`docs/mmio-map.md` §1.1):
1. Pha A: thanh ghi đầu ra IMEM đã có lệnh, vì IMEM chốt `mem[next_pc]`.
2. Giữa A và B: giải mã, đọc `$zero`, ALU cộng ra địa chỉ.
3. Pha B: `bus_re = ph_b && mem_read && in_mmio` (`src/cpu_g1.v:128`). Ngoại vi chốt địa chỉ, đọc `MS_OF_DAY` kèm chụp ngày.
4. Giữa B và A: `bus_rdata` qua MUX về cổng ghi regfile (`src/cpu_g1.v:130`).
5. Pha A kế tiếp: `$t0` được ghi.

G2 (`src/cpu_pipe.v:9`): IF lấy lệnh · ID giải mã, đọc `$zero` · EX ALU tính địa chỉ · MEM đọc bus đúng 1 bước · WB ghi `$t0`. Lệnh ngay sau mà dùng `$t0` thì đứng 1 chu kỳ (load-use).

**`CAL` cho thạch anh nhanh +20 ppm.** Công thức ở `fw/main.s:739`:
- I = 60 phút = 3 600 000 ms. D = I × p / 10⁶ = 72 ms.
- ΔCAL = ((D × 65536) / (I / 1000)) × 50, chia nguyên.
- 72 × 65536 / 3600 = 1310,72, cắt còn 1310. Nhân 50 = **65 500**.
- Lý tưởng là 20 × 3 276,8 = 65 536. Thiếu 36 là do phép chia nguyên.
- Đo trên RTL: 1 000 ms có C = 50 000 999 chu kỳ, lý tưởng 50 001 000. Thiếu 1 chu kỳ trên 50 triệu, tức +0,020 ppm.
- Vì sao 1 ppm = 3 276,8: 1 ms có 50 000 chu kỳ, 1 ppm của nó là 0,05 chu kỳ, phần lẻ tính theo 1/65 536 chu kỳ, 0,05 × 65 536 = 3 276,8.
- +250 ppm: D = 900 ms lớn hơn I / 5000 = 720 ms, firmware **từ chối**, giữ `CAL` cũ. Bộ lọc này chính là ngưỡng 200 ppm, để chặn câu `$T` sai. Không phải kẹp về biên.

**Vì sao ngắt vẫn trễ (D = 1526).** 1 lệnh = 1 526 chu kỳ hệ thống. Nút đến đúng lúc `div` vừa bắt đầu thì phải chờ, chậm nhất 34 lệnh (`report/2.5-e3-thi-nghiem.md:35`). Việc nền chiếm phần lớn bởi `div` (33/41 thời gian vòng lặp), nên số này không đại diện cho `main.s`.

**G2 vì sao CPI cao hơn mà nhanh hơn.** Thời gian = số lệnh × CPI / tần số. Giả sử cùng 1 000 lệnh: G1 = 1000 × 1,428 / 25 MHz = 57,12 µs; G2 = 1000 × 2,027 / 50 MHz = 40,54 µs. Con số thật theo chương trình: `sum100` ×1,21, `fact10` ×1,34, `bcd` ×1,39. CPI 2,027 của firmware cao vì nhánh và `busy`, không vì load-use.

## 5. Bộ ôn sâu (K2 trở đi)

### 5.1 Khuôn một bài, 9 mục, khác ĐA2

File `nguon/01-khoi-a.md` mở đầu `# Khối A · <tên>`, ngay sau đó là `### Hỏi lại bức tranh` chứa một khối `:::nhac`. Cuối khối có `## Đề nhanh khối A` gồm đúng 25 MCQ, ID `KT-A-D01`…; thiếu mục này builder chỉ ghi chú nên K2 chưa cần. Trong mỗi bài, tên `###` phải đúng từng chữ, builder kiểm (thử 08/11): Bản đồ · Câu hỏi mở bài · Trực giác · Cơ chế theo đường tín hiệu · Bảng chu kỳ hoặc tính tay · Trong chip (`file:dòng`, trích ≤ 15 dòng, đọc từng dòng) · Bẫy và thầy hay hỏi · Sửa tại chỗ và ứng dụng (cài lỗi rồi test nào bắt, kiến thức này dùng được ở đâu ngoài bài) · Tự kiểm và quay lại bức tranh. Cần đúng 1 `:::ban-do`, 1 `:::trong-chip`, 1 `:::sua-tai-cho`, 1 `:::dung-o-dau`, 3–5 `:::bay`, 1 `:::suy-dan` hoặc câu "Bài này không có suy dẫn"; MCQ và `:::tu-luan` nằm ở mục cuối; ID dạng `KT-A2-01`; heading `## A2 · <tên>` trong file `# Khối A …`.

Độ dày tối thiểu: ≥ 200 dòng nguồn, 5 MCQ (≥ 2 gắn chip), ≥ 3 câu vấn đáp, ≥ 1 bài cài lỗi. Có `kiem/<bài>.py` assert cho từng số tính tay. Ý bắt buộc từng bài nằm trong `BAT_BUOC` của `kiem/noi_dung.py`, thiếu là fail.

### 5.2 Cây bài và nguồn

| Bài | Gói | Cổng | Đọc | Lệnh test thật |
|---|---|---|---|---|
| A1 ALU, `muldiv`, `bcd` | TV1 | 1 | `isa-spec` §3–4, `alu.v`, `muldiv.v`, `bcd_unit.v` | `run_unit.sh alu muldiv bcd` |
| A2 G1 và đường đi `lw` (bài mẫu) | TV3 | 1 | `control-table`, `mmio-map` §1.1, `cpu_g1.v`, `control.v`, `regfile.v` | `run_unit.sh regfile control` |
| A3 `asm`, ISS, co-sim, MARS, đột biến | TV2 | 1 | `isa-spec` §7–8, `tools/` | `pytest tools/`, `cosim_iss.py --rand 0` |
| A4 `timebase`, `CAL`, RTC | TV5 | 1 | `timer-spec`, `timebase.v`, `2.4-cal-thi-nghiem` | `run_unit.sh timebase rtc exp_cal` |
| A5 7 đoạn, VGA, còi, UART | TV4 | 1 | `display-spec`, `seg7_scan.v`, `uart.v`, `2.3-bongma-e4` | `run_unit.sh seg7 display_ctrl uart` |
| B1 Pipeline, forwarding | TV3 + TV2 | 2 | `pipeline-policy` §0–3, §7 T1, `cpu_pipe.v`, `hazard.v` | `run_unit.sh hazard`, `cosim_iss.py --rand 0` |
| B2 Load-use, nhánh, `busy` | TV2 | 2 | `pipeline-policy` §4–6, §7 T2–T8 | `run_unit.sh hazard` |
| B3 CP0, ngắt G1 và G2 | TV3 | 2 | `pipeline-policy` §10, `irq_ctrl.v` | `run_unit.sh irq` |
| B4 `timers`, `buttons`, stopwatch | TV5 | 2 | `timer-spec`, `timers.v`, `buttons.v` | `run_unit.sh stopwatch cdtimer alarm buttons` |
| B5 Firmware và sync | TV2 + TV5 | 2 | `fw/main.s:131`, `:565`, `:614`, `:866` | `run_unit.sh system` |
| C1 E1′–E4′ | mọi TV | 3 | `2.4`, `2.5`, `2.3`, `evidence/` | lệnh trong từng report |
| C2 CPI, DSE, Yosys | TV2 + TV3 | 3 | `3.3`, `3.4`, `evidence/20261026_cpi.log` | `tools/cpi.py` theo `3.3` |
| C3 Bảo vệ | mọi TV | 3 | `hop-nhom-01` §5, `ngan-hang-cau-hoi` (đối chiếu code), `KHUNG-BAO-CAO` | đề tổng 30 MCQ |

Các lệnh `run_unit.sh`, `pytest`, `cosim_iss`, `cosim_mars` ở trên đã chạy PASS ngày 08/11 (`verified`); `cpi.py` chưa chạy. Người dựng vẫn chạy lại lệnh của bài mình viết và dán dòng PASS vào báo cáo; không chạy được thì trong bài ghi "chưa chạy".

### 5.3 Dàn từng bài

Cột "Phải giải thích" là tối thiểu. Mỗi ý viết thành đoạn có ví dụ, đọc nguồn ở §5.2. Câu vấn đáp viết cả lời giải. Cài lỗi lấy nguyên từ `hop-nhom-01` §4 nếu có; `src/` không được sửa nên chỉ mô tả và ghi "chưa chạy" trừ khi evidence có sẵn.

| Bài | Câu mở bài | Phải giải thích | Cài lỗi | Vấn đáp ít nhất |
|---|---|---|---|---|
| A1 | Vì sao máy trừ hai số mà so sánh vẫn có thể sai? | `slt` khi tràn, `tb/alu_tb.v` kiểm gì; chia khôi phục từng bước với ví dụ 7 / 2; `−7 / 2`; chia 0; double dabble đổi tay một số 3 chữ số | Đổi dòng `lt` thành `diff[31]` | `slt` · `div` 33 chu kỳ · vì sao cộng 3 |
| A2 | Cùng một lệnh cần hai bộ nhớ, BRAM phải chờ cạnh clock, CPU 1 chu kỳ làm sao? | BRAM đọc đồng bộ; pha A, pha B; `next_pc`; đường `lw` theo §4.3, từng tín hiệu `bus_re`, `bus_rdata`; `regfile`; `control` bật gì; 25 MHz; đọc thì chụp ngày | IMEM chốt `PC` thay vì `next_pc` | Vẽ datapath G1 · vì sao `next_pc` · −252 là gì |
| A3 | Làm sao biết chip đúng khi chính mình viết đáp án? | `asm.py` hai lượt và vì sao cần; ISS; `cmp_trace` so gì; co-sim; MARS để tránh cùng sai; đột biến | Sửa sai một lệnh trong ISS rồi xem ai bắt | ISS sai thì sao · hai lượt để làm gì · đột biến chứng minh gì |
| A4 | Không đếm được nửa nhịp thì 1 ms dài 50 002,5 nhịp bằng cách nào? | Phần lẻ 16 bit với bảng từng ms ở +50 ppm; suy dẫn 3 276,8; +20 ppm ra 65 500; +250 ppm bị từ chối; dịch số học; cảnh báo E1′ `unverified` | Dịch logic thay vì số học | 1 ppm · `CAL` âm · còn lệch 0,02 ppm do đâu |
| A5 | 8 chữ số chung 7 chân đoạn thì sao sáng cùng lúc? | Quét, 125 Hz; bóng ma và `G_BLANK` theo code hiện tại, không theo ngân hàng cũ; VGA không frame buffer; UART 8N1, lấy mẫu giữa bit; xé hình | Dùng chân đoạn mới trong khoảng tắt | 125 Hz · bóng ma · lấy mẫu giữa bit |
| B1 | Vì sao chia lệnh thành 5 trạm lại chạy nhanh hơn? | 5 trạm và thanh ghi giữa các trạm; bảng T1; forwarding, EX/MEM trước MEM/WB; `dst ≠ 0`; dự đoán không nhảy; không delay slot | Bỏ điều kiện `dst ≠ 0` | Vẽ bảng T1 · ưu tiên nguồn forward · vì sao 50 MHz |
| B2 | Khi nào dây chuyền buộc phải dừng? | Load-use vì dữ liệu cuối MEM, bubble; nhánh phạt 2 ở EX; `busy`; thứ tự busy > flush > load-use; số chu kỳ mất trong CPI | Bỏ `stall_lu` | Vẽ T2, T3 · `div` giữa dây chuyền · vì sao CPI G2 cao |
| B3 | Đang chạy dở mà có việc gấp thì lưu chỗ nào để quay lại? | CP0, `Status`, `EPC`; G1 `next_pc`; G2 ID/EX, lệnh nào hủy lệnh nào chạy nốt (theo code, không theo hop-nhom); `0x180`, `eret`; chờ `busy`; `IRQ_PENDING` | `EPC ← pc` thay vì `next_pc` | Ngắt lúc `div` · chặn ngắt sau `mtc0`, `eret` · handler quên xóa `IRQ_PENDING` |
| B4 | Vì sao lap chính xác hơn mọi thứ CPU đọc được? | capture, nút nối thẳng; bộ chia riêng của bấm giờ; chống rung 10 ms; hẹn giờ qua 0 sang số âm; báo thức | Bỏ khóa 10 ms | Capture khác polling · chống rung cạnh đầu · nạp giờ đúng phút báo thức |
| B5 | Firmware làm gì trong một vòng lặp? | `events → ringchk → sync → draw`; handler `0x180` chỉ cho UART; câu `$T` và checksum; từ chối câu sai | Handler quên xóa `IRQ_PENDING` | Vì sao chụp giờ lúc `\n` · sync sai thì sao · vì sao không dùng ngắt cho nút |
| C1 | Bốn thí nghiệm chứng minh gì và không chứng minh gì? | Mỗi thí nghiệm: giả định, số, phạm vi. E1′ kèm cảnh báo; E3 bảng 3 mức D; E4′ `T_OFF` là giả định | Không | Đời thực đâu · số nào là giả định · E3 có phải `main.s` không |
| C2 | G2 tốn thêm bao nhiêu ô để nhanh hơn bao nhiêu? | Thời gian = lệnh × CPI / tần số; ×1,21, ×1,34, ×1,39; Yosys không phải Vivado, nhãn `inference`; 4 cách đổi ms ra chữ số | Không | CPI cao mà nhanh hơn · vì sao số LUT chỉ là ước lượng |
| C3 | Thầy hỏi gì mà trả lời sai sẽ mất điểm nhất? | 6 câu chéo `hop-nhom-01` §5 với lời giải đã sửa theo code; Claude viết phần lớn code, nói thế nào cho thật; chỉ mô phỏng; sửa tại chỗ 30 phút | Theo từng gói | Cả 6 câu chéo |

### 5.4 Ý thêm từ đối chiếu báo cáo Nhóm 3 (08/11)

Đối chiếu bộ ôn với `BaoCaoCK_Nhom3.pdf` (kỳ 2025.1, nằm ở `study-2026-1/tai-lieu/kien-truc-may-tinh/`, không có trong repo này). Chỉ học cấu trúc, không chép chữ hay hình. Nhóm 3 được cho là điểm cao theo lời Long, điểm thật và barem chưa có (`unverified`).

| Bài | Ý phải thêm | Nhóm 3 làm gì | Máy kiểm |
|---|---|---|---|
| A2 | Bảng chân lý tín hiệu `control` cho 28 lệnh (`docs/control-table.md`), nói đọc một dòng ra sao | Bảng 6 dòng cho 14 lệnh | `bảng chân lý` |
| A3 | Đọc waveform và trace log: chỉ vào một chu kỳ, nói lệnh nào đang ở trạm nào | Một hình waveform, dò bằng mắt | `waveform` |
| B1 | Ba loại hazard (cấu trúc, dữ liệu, điều khiển); vì sao tách IMEM và DMEM (Harvard) | Phần lý thuyết hazard đủ ba loại | `Harvard`, `cấu trúc` |
| B2 | Vì sao quyết định nhánh ở EX, không ở ID: ID phạt 1, nhưng nhánh sau `lw` chờ 2 chu kỳ thay vì 1 (`pipeline-policy.md` §7 T4, `verified`) | Nhánh ở ID, phạt 1, so với 3 ở kiến trúc gốc | `nhánh ở ID` |
| C2 | Trả lời "CPI nhóm trước 1,34, vì sao của em cao hơn?": họ có 14 lệnh, không `div`, `bcd`, ngắt, và đo một chương trình tổng 1 đến 10; CPI của mình cao chủ yếu do nhánh và `busy` | Bảng lý thuyết 1,0 và thực tế 1,34, "chênh do phạt nhánh" | `1,34` |
| H0, H7 | Nêu tiền lệ: Nhóm 3 cũng chỉ mô phỏng, ghi rõ "chưa tổng hợp và nạp lên các kít" | Có, ở phần giới thiệu | Đã có trên trang |

Điều mình làm khác và hơn: 28 lệnh so với 14, có ngắt và `div`, tự động so trace với ISS thay vì dò waveform. Điều không so thẳng được với Nhóm 3: CPI, số lệnh. Điểm yếu họ để lại mà mình đã tránh: hình lấy cắt từ sách, chỉ một chương trình thử, số chu kỳ ghi "≈55".

## 6. Nghiệm thu mỗi phiên K2–K6

### 6.1 Máy kiểm

```
cd hoc-tap/ktmt-2026-1-casio
PYTHONUTF8=1 python learn/on-tap-btl/so_ktmt.py
PYTHONUTF8=1 python learn/on-tap-btl/kiem/chay_het.py
PYTHONUTF8=1 python learn/on-tap-btl/dung.py --check
PYTHONUTF8=1 python learn/on-tap-btl/dung.py
PYTHONUTF8=1 python learn/on-tap-btl/thu_trinh_duyet.py learn/on-tap-btl/ON-TAP-KTMT.html work/thu-trang.png
```

Lệnh cuối mở trang trên Chrome hoặc Edge headless, bấm một câu MCQ, tải lại, in dòng `THU|...`. Sandbox không cho chạy thì ghi "chưa chạy" và đưa lệnh cho Long.

### 6.2 Báo cáo cuối phiên phải có

1. Output nguyên văn của từng lệnh §6.1, không tóm tắt.
2. Dòng PASS của lệnh test thật trong bài (§5.2).
3. Danh sách câu đã viết lời giải, và bài nào có cài lỗi "chưa chạy".
4. Chỗ phát hiện lệch giữa code và tài liệu.
5. Đã append `.ai/worklog.md` và sửa `.ai/state.md`.

Mọi `file:dòng` được grep lại; không in số ngoài sổ; `system_tb`, `cosim`, `pytest` chỉ chép từ log, chạy lại mà khác thì báo. Không đạt thì báo thẳng output lỗi, không báo xong.

### 6.3 Soát sau phiên

Máy PASS chưa đủ. Sau K2 và mỗi khi hết một khối, Long dán prompt soát ở cuối mục này cho Claude.

### 6.4 Prompt

Chạy từ `hoc-tap/ktmt-2026-1-casio`. Mở `codex`, dán prompt, hoặc:

```
codex exec -s workspace-write --skip-git-repo-check -C . -c model_reasoning_effort="high" - < prompt.md
```

Prompt phiên K2:

```
Đọc .ai/state.md, đuôi .ai/worklog.md, rồi learn/on-tap-btl/PLAN.md §3, §4, §5, §6, §9.
Đọc learn/on-tap-btl/nguon/00-hoc-nhanh.md mục H0, H2 và thẻ 5, 6, 8 để lấy giọng văn.
Làm phiên K2: bài mẫu A2 trong nguon/01-khoi-a.md theo khuôn §5.1 và dàn §5.3. Đọc nguồn ở §5.2 trước khi viết.
Người đọc chưa có kiến thức nền, làm đúng mục Người đọc ở §3. Mỗi câu hỏi phải có lời giải ngay trong bài. Không đưa lời nhắc người dạy, ký hiệu §, tên plan vào bài.
Chỉ ghi trong learn/on-tap-btl/ và .ai/. Không sửa dung.py, kiem/noi_dung.py trừ khi --check báo lỗi của chính builder. Không commit.
Chạy đủ §6.1 rồi báo theo §6.2. Dừng ở gate để Long duyệt khuôn.
```

Prompt phiên K3–K6, thay `<n>`:

```
Đọc .ai/state.md, đuôi .ai/worklog.md, rồi learn/on-tap-btl/PLAN.md §2, §3, §4, §5, §6, §9.
Đọc bài A2 trong nguon/01-khoi-a.md đã được Long duyệt, viết đúng độ dày và giọng đó. Người đọc chưa có kiến thức nền, làm đúng mục Người đọc ở §3.
Làm phiên K<n> theo §2, dàn §5.3. Đọc nguồn ở §5.2 trước khi viết từng bài.
Mỗi câu hỏi phải có lời giải ngay trong bài. Không đưa lời nhắc người dạy, ký hiệu §, tên plan vào bài.
Nếu phát hiện lệch code và tài liệu, theo thứ tự nguồn §3 và ghi vào báo cáo.
Chỉ ghi trong learn/on-tap-btl/ và .ai/. Không sửa kiem/noi_dung.py. Không commit. Chạy đủ §6.1 rồi báo theo §6.2.
```

Prompt soát, dán cho Claude:

```
Soát phiên K<n> của Codex trong hoc-tap/ktmt-2026-1-casio, theo PLAN.md §9 của learn/on-tap-btl.
Đọc thẳng nguon/, không tin báo cáo. Tự chạy lại §6.1 và lệnh test của bài. Đối chiếu từng khẳng định kỹ thuật với code,
tìm chỗ có câu hỏi mà giải thích sơ sài, từ chuyên môn chưa giải thích, hình dung đời thường sai bản chất, số gõ tay. Đọc thử như người ngoài ngành. Báo trước, chưa sửa.
```

## 7. Hở chưa giải quyết (Long cần biết)

- **Chưa có đề và barem BTL gốc.** `MI4344. Du an - Nhap mon KTMT.doc` là bộ câu hỏi khác, không phải đề (`verified`, đã đọc file). Vì thế bộ ôn đi theo cổng nội bộ, không theo điểm thầy.
- Điểm môn: GK 30% + CK 70%, chưa rõ BTL tính vào đâu (`unverified`).
- Bảng tên ↔ TV1–TV5 còn trống. Số thành viên chưa chốt.
- Sửa của nhánh cloud chưa vào `main`. Nếu merge, số hồi quy và số E1′ phải kiểm lại, sổ tự báo lệch.

## 8. Dấu vết ba vòng

- **Soát sau khi Long chọn B (08/11, 19:44):** chạy thử builder và soát K1 với code. Sinh các sửa: `RE_SO` không nhận dấu gạch, thiếu `nguon_chuan.csv` thì builder sập; 65 500 đến từ phép chia nguyên chứ không phải làm tròn chung chung; +250 ppm bị bộ lọc `|D| ≤ I / 5000` chặn; D = 2 cho thấy polling chỉ tệ khi CPU chậm; mốc 18:30 đã trôi nên bỏ đường lui HTML tay. Vẫn chưa kiểm hiển thị trên trình duyệt.
- **V1:** đọc state, README, hop-nhom, ngân hàng câu hỏi, report thí nghiệm, evidence; lập cây bài theo gói và cổng.
- **V2 (sai ở đâu?):** phát hiện đề `.doc` không phải đề BTL; `3.6-bang-dat` lệch code về ngắt; ngân hàng câu hỏi lỗi thời; số dòng `alu.v` cũ; `div` 32 vs 33; mô tả hủy lệnh của hop-nhom lệch `cpu_pipe.v`. Mỏ neo trong plan được grep lại bằng script sau khi viết.
- **V3 (câu hỏi chưa ai hỏi?):** Buổi tối dài bao lâu thì chưa biết, nên có đường cắt 35 phút. Số E3 chỉ đúng ở thí nghiệm riêng, firmware thật dùng ngắt cho UART, nên phải ghi phạm vi để không bị đọc sai. Plan không tự chứng minh đề tài đạt yêu cầu thầy, vì thiếu barem.
- Chưa có reviewer ngữ cảnh mới soát độc lập: muốn thì Long nói, t mới spawn.

## 9. Kinh nghiệm từ K1 (08/11)

Codex dựng K1: 4 lệnh nghiệm thu PASS, đủ H0–H9. Soát lại thì chưa dùng được. Claude phải viết lại gần hết `00-hoc-nhanh.md`.

| Chuyện đã xảy ra | Vì sao | Từ giờ | Máy bắt? |
|---|---|---|---|
| 11 thẻ có câu hỏi, không có câu trả lời | Plan nói "mỗi thẻ đúng 4 dòng", Codex làm đúng khuôn mà rỗng ý | Câu hỏi nào cũng kèm lời giải; §5.3 ghi rõ ý phải có | Có: `noi_dung.py` |
| Thiếu bảng E3, suy dẫn ppm, lý do CPI dù plan có ghi | Thả các ý này ở nhiều mục, cắt sớm vì sợ hết giờ | Danh sách ý bắt buộc từng bài | Có: `BAT_BUOC` |
| Đáp án đúng dài nhất ở 9/15 câu | Bài kiểm chỉ đếm số câu | Giới hạn 40%, giải thích ≥ 60 ký tự | Có |
| Lộ "§4.3" vào trang, "năm pha G1", hiểu sai số 589 | Chép từ plan, không đối chiếu | Cấm chữ plan; Claude soát | Một phần |
| Chữ dạy trong mọi mục, Long phải bỏ hết | Plan t viết yêu cầu vậy, đoán nhu cầu thay vì hỏi | Trang chỉ có kiến thức | Có |
| Từ chuyên môn không giải thích; bản viết lại đầu tiên vẫn khó, Long nói cả nhóm không có kiến thức gì | Plan và cả Claude đều giả định người đọc biết bit, clock, bộ nhớ | Mục Người đọc ở §3, kiến thức nền ở H0, hình dung đời thường | Rất ít: `BAT_BUOC_H0`, còn lại Claude soát |
| Lệnh `cpu_pipe` FAIL, cả plan lẫn lần soát đầu đều sai | Chép từ `hop-nhom-01`, không ai chạy | Chạy thật mọi lệnh đưa vào bài | Có với `run_unit` |
| Tiêu đề lỗi dấu, số 0 trông như chữ o | Chưa ai mở trang | `thu_trinh_duyet.py` chụp ảnh, phải xem ảnh | Một phần |
| Codex hiểu "giờ dạy" là 21:00 | Prompt để ô trống cho Long điền | Không dùng ô điền trong prompt | Không cần |
| `.ai/state.md` không được cập nhật | Chỉ dặn ở cuối | Thành mục bắt buộc của báo cáo §6.2 | Không, Claude soát |

**Điều rút ra:** nghiệm thu máy chỉ chứng minh đúng định dạng. Model rẻ tối ưu theo cái được kiểm, nên ý nào cần có thì phải kiểm được, và luôn có một lượt soát độc lập đọc thẳng nguồn.

**Chưa bắt được bằng máy, Claude soát phải xem:** giải thích có thật dễ hiểu không, khẳng định kỹ thuật có đúng code không, ví dụ có chạy tay được không. `BAT_BUOC` chỉ thấy từ khóa, viết chữ đúng mà giải thích sai vẫn PASS.
