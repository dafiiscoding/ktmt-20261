# tb/vectors — vector test sinh tự động

- Sinh lại: `python tb/vectors/gen_vectors.py`. Script tính mỗi golden **bằng 2 cách** và `assert` khớp; in `PASS` ở dòng cuối. Seed cố định 20261001 → chạy lại ra từng byte như cũ.
- **Không sửa tay file `.txt`.** Sai thì: sửa spec → sửa script → chạy lại → ghi worklog.
- Dòng bắt đầu `#` là chú thích (bỏ qua). Hex không có `0x`. Trường cách nhau 1 dấu cách.
- Golden do AI sinh → có thể sai **chung nguồn** với ISS. Đối chiếu MARS: `docs/goi-viec.md` §0.2.

## Cách đọc trong Verilog (chạy được cả Icarus và ModelSim)
Mẫu chung: bỏ dòng `#`, rồi `$fscanf` đúng số trường; phần thừa cuối dòng đọc bỏ bằng `$fgets`.
```verilog
integer fd, c, r;  reg [8*200:1] rest;
fd = $fopen("tb/vectors/alu.txt", "r");
while (!$feof(fd)) begin
  c = $fgetc(fd);
  if (c == "#" || c == "\n") r = $fgets(rest, fd);        // dòng chú thích / dòng trống
  else if (c != -1) begin
    r = $ungetc(c, fd);
    r = $fscanf(fd, "%h %h %h %h %h %d\n", ctl, a, b, shamt, exp_y, exp_zero);
    // ... đưa vào DUT, so, đếm ca
  end
end
```
(Mẫu này là hướng dẫn cách đọc file; testbench thật mỗi người tự viết.)

| File | Dùng ở | Định dạng `$fscanf` |
|---|---|---|
| `alu.txt` | A1 | `"%h %h %h %h %h %d"` = ctl, a, b, shamt (lấy 5 bit thấp), y, zero |
| `mul.txt` / `div.txt` / `bcd.txt` | A2, A3, B2 | `"%h %h %h"` / `"%h %h %h %h %d"` (a, b, LO, HI, DZ) / `"%h %h"` |
| `control.txt` | C2 | `"%h"` + 16 lần `"%d"`; phần `# tên lệnh` cuối dòng đọc bỏ bằng `$fgets` |
| `seg7.txt` | D1 | `"%h %h"` |
| `timebase_len.txt` / `timebase_total.txt` | E1 | `"%d %d"` + 20 lần `"%d"` / `"%d %d %d %d"` |
| `vga_points.txt` | D5 | `"%d %d %d %d"` (x, y, ô −1 = ngoài, đoạn 0…6 = a…g, 7 = dp, −1 = nền) |
| `fmt_sw.txt`, `fmt_timer.txt` | B2, B7, C8 | `"%d | %h %h %h %h %h %h %h %h"` (DISP7…DISP0) |
| `fmt_alarm.txt` / `date.txt` | B7, E5 | `"%d %d %d | "` + 8 `%h` / `"%d %d %d %d %d | "` + 8 `%h` |
| `fmt_time.txt` | B7, C8 | `"%d | "` + 3 nhóm 8 `%h` cách nhau `" | "` (TIME24, TIME12, giữ-B) |
| `sync_sentences.txt`, `sync_cal.txt` | E6, ISS | đọc bằng Python (tách TAB / dấu cách); kịch bản 7 tb lấy câu từ đây |

- `$fscanf` với ký tự `|` trong chuỗi định dạng: đã kiểm trên Icarus 14.0 (01/10): đọc đủ 42/42 dòng `fmt_timer.txt`, mỗi dòng 9 trường, kể cả số âm −2147483648 (`verified`). ModelSim chưa kiểm.
