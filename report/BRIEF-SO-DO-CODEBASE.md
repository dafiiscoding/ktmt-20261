# Brief sơ đồ codebase: vai trò từng file (11/11/2026)

Mục đích: thầy hỏi xoáy code, mỗi người phải biết file nào làm gì, ai gọi ai. Làm **cho KTMT trước** (bảo vệ 25/11), Kho làm sau nếu còn giờ.
Người dựng: Sonnet. Chỉ ghi trong `report/` và `.ai/`.

## 1. Đầu ra

1. `report/SO-DO-CODEBASE.md`: bảng tất cả file có ý nghĩa, mỗi file một dòng.
2. `report/SO-DO-CODEBASE.html`: bản đọc, có sơ đồ tương tác (một file, không phụ thuộc mạng). Dựng từ file md, không viết tay lại nội dung.
3. Hình `report/latex/hinh/h_codebase.tex` (TikZ) cho phụ lục báo cáo: chỉ cấp thư mục và các khối chính, không quá 15 hộp.

## 2. Bảng mỗi file

| Cột | Ghi gì |
|---|---|
| Đường dẫn | tương đối từ gốc project |
| Loại | RTL, testbench, firmware, công cụ Python, spec, evidence, báo cáo |
| Vai trò | một câu, bằng lời thường, lấy từ comment đầu file (nhiều file đã có "ĐỌC NHANH") |
| Vào / ra | tín hiệu hoặc dữ liệu chính vào và ra, cụ thể |
| Gọi bởi | module/file nào dùng nó (grep `module` đã nêu, không đoán) |
| Gọi tới | module/file nó dùng |
| Chủ lát | TV nào theo bảng chia lát ở `BRIEF-25-11.md` mục 1; file chưa có chủ ghi "chung" |
| Test | lệnh `run_unit.sh <tên>` hoặc test nào bắt lỗi của nó |
| Dòng | số dòng thật (`wc -l`) |

Phạm vi: `src/` (21 file), `tb/`, `fw/` (`main.s`, `fmt.s`, `tests/`), `tools/`, `docs/`, `evidence/` (chỉ cấp thư mục), `report/`, `learn/`. Bỏ `work/`, `.toolchain/`, `build/`.

## 3. Sơ đồ

Bốn lớp, mỗi lớp một sơ đồ:

1. **Cây thư mục:** thư mục nào chứa gì, một dòng mỗi thư mục.
2. **Phân cấp module RTL:** `soc_top` chứa cái gì; `cpu_g1` và `cpu_pipe` dùng module nào. Dựng bằng cách grep tên module được khởi tạo (instance), không suy từ tên file. Mỗi hộp ghi tên file và số dòng.
3. **Đường đi của một lệnh qua file:** từ `fw/main.s` → `tools/asm.py` → bộ nhớ lệnh → `cpu_*.v` → `control.v`, `alu.v`, `regfile.v` → `soc_top.v` → ngoại vi. Mỗi mũi tên ghi tên tín hiệu trên đường nối.
4. **Đường đi của kiểm thử:** test → `run_unit.sh` → iverilog/vvp → so với ISS (`tools/iss.py`, `cmp_trace.py`) → evidence. Ghi file nào do ai tạo ra.

Màu: RTL xanh dương, testbench xanh lá, công cụ Python cam, firmware tím, tài liệu xám. Chú giải cuối hình.

## 4. Luật

- Vai trò lấy từ comment đầu file và đọc code; khi hai nguồn lệch, tin code. File nào không đọc kỹ được thì ghi `chưa đọc`, không bịa vai trò.
- "Gọi bởi", "Gọi tới": bằng grep. Ghi lệnh grep đã dùng vào cuối file md.
- Tên tín hiệu trên sơ đồ phải tồn tại trong `src/`. Liệt kê danh sách đã grep.
- Bảng "lệch đã biết" ở `learn/on-tap-btl/PLAN.md` mục 3: đọc trước, viết theo cột phải (ví dụ `cpu_pipe` và `cpu_g1` không chạy qua `run_unit.sh` mà qua `cosim_iss.py`).
- Không sửa code. Không commit.

## 5. Nghiệm thu

- Số file trong bảng = số file đếm bằng `find` trong phạm vi mục 2 (nêu cả hai số).
- Mỗi module `src/*.v` xuất hiện trong sơ đồ lớp 2; module không ai gọi được nêu riêng.
- HTML mở được offline, in được ra A4.
- Báo: số file `chưa đọc`, các chỗ comment đầu file lệch với code.

## 6. Cách dùng sau khi có

- Bài V0 và P1–P5 của bộ dạy code trỏ về bảng này ở mục "Bản đồ".
- Slide dự phòng của bảo vệ lấy sơ đồ lớp 2 và 3.
- Mỗi người học thuộc hàng của lát mình: file nào gọi, file nào bị gọi, test nào bắt.

## 7. Prompt dán cho Sonnet

```
Đọc .ai/state.md, đuôi .ai/worklog.md, report/BRIEF-SO-DO-CODEBASE.md, rồi bảng chia lát ở report/BRIEF-25-11.md mục 1 và bảng "lệch đã biết" ở learn/on-tap-btl/PLAN.md mục 3.
Làm đúng mục 1–5. Đọc comment đầu mỗi file và grep quan hệ gọi, không đoán.
Chỉ ghi trong report/ và .ai/. Báo số file trong bảng so với find, số file chưa đọc, danh sách tín hiệu đã grep. Append worklog. Dừng.
```
