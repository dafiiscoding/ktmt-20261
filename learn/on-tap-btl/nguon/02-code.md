# Phần V · Đọc code Verilog của WatchChip

Phần này dành cho người chưa từng đọc một dòng Verilog. Mục tiêu: mở được bất kỳ file nào trong `src/`, biết dòng nào sinh ra dây, dòng nào sinh ra ô nhớ, và tự chạy được bài thử của file đó.

## V0 · Đọc Verilog trong một buổi

### Bản đồ

:::ban-do
Con chip WatchChip được viết bằng **Verilog**, ngôn ngữ mô tả mạch điện: trông giống code nhưng mô tả dây và ô nhớ, không phải danh sách việc làm lần lượt. Mỗi file `.v` trong `src/` mô tả một khối của chip. Bài này dùng hai khối nhỏ nhất làm mẫu để học cách đọc, rồi cách đọc ấy dùng được cho mọi khối khác, kể cả hai CPU.

| Việc | File | Vì sao chọn làm mẫu |
|---|---|---|
| Khối làm toán (ALU) | `src/alu.v` | Không có đồng hồ bên trong: đổi đầu vào thì đầu ra đổi ngay. Dễ đọc nhất. |
| Tập 32 thanh ghi (regfile) | `src/regfile.v` | Có ô nhớ, có đồng hồ. Cho thấy phần còn lại của ngôn ngữ. |
| Nơi hai khối trên được gắn vào CPU G1 | `src/cpu_g1.v` | Cho thấy một khối được "cắm" vào mạch lớn thế nào. |
| Nơi chọn CPU G1 hay G2 | `src/soc_top.v` | Cho thấy cách một file chứa hai phương án. |
| Bài thử của ALU | `tb/alu_tb.v` | Cách đọc một testbench (file riêng để thử khối, không nằm trong chip). |
| Bài thử của regfile | `tb/regfile_tb.v` | Testbench có clock. |

**Cách đọc bảng:** cột giữa là file cần mở. Cột phải là lý do bài này dừng ở file đó. Hai file đầu đọc kỹ từng dòng. Bốn file sau chỉ đọc đúng một đoạn nhỏ đã trích.

Câu lệnh chạy bài thử của hai khối đầu: `bash tools/run_unit.sh alu regfile`. Gõ ở đâu và đọc kết quả ra sao nằm ở mục Cơ chế.
:::

### Câu hỏi mở bài

Verilog trông như code, nhưng một chương trình thường chạy từng dòng từ trên xuống, còn chip thì mọi dây đều có điện cùng lúc. Vậy khi gặp một dòng Verilog, **làm sao biết nó sinh ra thứ gì trong chip, và đọc file theo thứ tự nào cho khỏi lạc?**

Câu trả lời ngắn, các mục sau chứng minh từng ý:

- Mỗi dòng Verilog thuộc đúng một trong hai loại. Loại thứ nhất mô tả **dây và cổng logic** (đổi đầu vào là đầu ra đổi ngay). Loại thứ hai mô tả **ô nhớ** (chỉ đổi giá trị đúng lúc đồng hồ nhích một nhịp).
- Muốn biết dòng thuộc loại nào chỉ cần nhìn nó nằm trong khối nào: `assign` hoặc `always @*` là dây, còn `always @(posedge clk)` là ô nhớ.
- Thứ tự đọc: bình luận đầu file, rồi cổng vào ra, rồi hằng số, rồi tìm các chỗ có ô nhớ, rồi phần dây còn lại, cuối cùng mới tới file thử.

### Trực giác

Hình dung chip là một nhà xưởng.

- **Module** là một cái máy trong xưởng, có vỏ ngoài và các lỗ cắm. Máy ALU có lỗ vào cho hai con số và một lỗ nhận lệnh "cộng hay trừ", có lỗ ra cho kết quả.
- **Cổng (port)** là các lỗ cắm đó. Có cổng vào (`input`) và cổng ra (`output`).
- **Wire (dây)** là ống dẫn nối hai chỗ. Ống không giữ gì, chất lỏng chảy qua ống bao nhiêu thì đầu kia nhận bấy nhiêu, tức thì.
- **Reg (ô nhớ)** là ngăn kéo có khóa. Ngăn kéo giữ nguyên đồ bên trong cho tới khi chuông reo, lúc đó nó mới được mở ra để thay đồ mới. Chuông chính là clock (đồng hồ nhịp của chip).

Có hai loại máy trong xưởng:

- **Máy không nhớ** giống máy ép nước cam: bỏ cam vào thì nước chảy ra ngay, bỏ cam khác thì nước khác chảy ra ngay, máy không giữ gì lại. Giới chuyên môn gọi là mạch **tổ hợp**. Trong Verilog, chúng được viết bằng `assign` hoặc `always @*`.
- **Máy có nhớ** giống chiếc bàn có ngăn kéo: đồ trong ngăn chỉ đổi đúng lúc chuông reo. Giới chuyên môn gọi là mạch **tuần tự**. Trong Verilog, chúng được viết bằng `always @(posedge clk)`. Chữ `posedge` (positive edge) là **cạnh lên** của clock, tức khoảnh khắc clock chuyển từ 0 lên 1.

Còn hai ký hiệu gán `=` và `<=`. Hình dung một lớp học đang truyền giấy:

- Gán kiểu `=` giống "làm ngay, lần lượt": bạn A chép giấy của B, rồi bạn B chép giấy mới của A. Hai bạn kết thúc với cùng một tờ giấy.
- Gán kiểu `<=` giống "cả lớp đọc giấy của nhau trước, rồi khi chuông reo thì đồng loạt đổi". Hai bạn hoán đổi giấy cho nhau, đúng như mong muốn của ô nhớ.

Vì vậy quy ước của project: trong khối có clock thì dùng `<=`, trong khối không clock thì dùng `=`.

### Cơ chế theo đường tín hiệu

Theo đường đi của một lệnh cộng, tín hiệu đi từ cổng vào của ALU tới cổng ra. Ta đọc `src/alu.v` theo đúng đường đó, rồi sang `src/regfile.v`.

**Bước 1. Đọc vỏ ngoài (module và cổng).** Dòng đầu mở bằng `module alu (` và liệt kê các cổng. Mỗi cổng có dạng:

`input  wire [31:0] a`

đọc là: cổng vào, kiểu dây, gồm 32 dây đánh số từ 31 đến 0, tên là `a`. Dây số 31 ở ngoài cùng bên trái, là **bit dấu**: bằng 1 nghĩa là số âm, bằng 0 nghĩa là số không âm. (Bit là một giá trị 0 hoặc 1; số ghép từ 32 bit.) Cổng `[3:0] ctl` chỉ có 4 dây, đủ để ghi 16 mã khác nhau, mà ALU dùng 8 mã.

**Bước 2. Đọc cách viết số.** Verilog viết số theo dạng `độ-rộng'hệ-số giá-trị`:

| Viết | Đọc là | Giá trị |
|---|---|---|
| `4'd0` | rộng 4 bit, hệ thập phân, giá trị 0 | `0000` |
| `5'd0` | rộng 5 bit, hệ thập phân, giá trị 0 | `00000` |
| `2'b10` | rộng 2 bit, hệ nhị phân, giá trị 10 | số 2 |
| `32'hFFFFFF04` | rộng 32 bit, hệ 16 (mỗi chữ thay cho 4 bit), giá trị FFFFFF04 | 32 bit, 24 bit đầu toàn 1 |

**Cách đọc bảng:** chữ cái sau dấu nháy đơn cho biết hệ số (`d` thập phân, `b` nhị phân, `h` hệ 16). Số đứng trước dấu nháy luôn là số bit.

**Bước 3. Đọc hằng số có tên (`parameter`).** `localparam ALU_ADD = 4'd0` đặt tên `ALU_ADD` cho số 0 để khỏi viết số trần. Anh em của nó là `parameter`: cũng là hằng số có tên, nhưng **chỉnh được từ bên ngoài** khi gắn khối vào mạch lớn. Ví dụ `regfile` có `parameter G_BYPASS`, và CPU G1 gắn nó bằng `regfile #(.G_BYPASS(0))`, nghĩa là "cắm một regfile, đặt G_BYPASS bằng 0".

**Bước 4. Đọc phần dây (`wire` và `assign`).** Dòng `wire [31:0] diff = a - b;` khai báo một dây 32 bit tên `diff` và nối luôn nó vào kết quả của một bộ trừ. Từ giờ `diff` luôn bằng `a - b`, đổi `a` hoặc `b` thì `diff` đổi ngay. Dòng `assign zero = (y == 32'd0);` làm tương tự: dây `zero` luôn bằng 1 khi `y` bằng 0. Hai cách viết này là một: `wire x = ...;` chỉ là gộp khai báo và `assign`.

Dấu `? :` là **bộ chọn (MUX)**: `điều_kiện ? giá_trị_nếu_đúng : giá_trị_nếu_sai`. Mạch thật là một công tắc chọn một trong hai đường dây. Dòng của `lt` dùng nó để chọn bit dấu của `a` hoặc bit dấu của `diff`.

**Bước 5. Đọc khối `always @*` và `case`.** Khối này dùng khi kết quả cần "nếu thế này thì thế kia" mà vẫn là mạch không nhớ. `@*` nghĩa là "bất kỳ đầu vào nào đổi thì tính lại". `case (ctl)` là bộ chọn nhiều đường: `ctl` bằng 0 thì `y` lấy kết quả cộng, bằng 1 thì lấy kết quả trừ, và cứ thế. Điều dễ hiểu sai: **cả tám phép tính đều có mạch riêng và đều chạy cùng lúc**; `case` chỉ quyết định kết quả nào được đưa ra `y`. Nhánh `default` bảo đảm mọi giá trị của `ctl` đều có kết quả; thiếu nhánh này thì có trường hợp `y` không được gán, công cụ sẽ dựng một ô nhớ chốt ngoài ý muốn.

Ba toán tử đáng nhớ:

- `{31'd0, lt}`: ngoặc nhọn là **ghép bit**, 31 bit 0 đứng trước, bit `lt` đứng sau, thành số 32 bit chỉ có thể là 0 hoặc 1.
- `b << shamt`: dịch `b` sang trái `shamt` bit, bit trống điền 0. Giống thêm `shamt` chữ số 0 vào cuối một số thập phân, nhân với lũy thừa của 2.
- `$unsigned($signed(b) >>> shamt)`: `$signed(b)` nói với công cụ "coi `b` là số có dấu". `>>>` là dịch phải **số học**: bit trống điền bằng bit dấu, nên số âm vẫn âm. `$unsigned` đưa kiểu về không dấu để gán cho `y`.

**Bước 6. Đọc phần ô nhớ (`reg` và `always @(posedge clk)`).** `src/regfile.v` có dòng `reg [31:0] r [0:31];`: một mảng 32 ngăn, mỗi ngăn 32 bit. Khối `always @(posedge clk)` chỉ chạy ở cạnh lên của clock. Bên trong:

- `if (rst)` là **reset đồng bộ**: tín hiệu `rst` chỉ có tác dụng ở cạnh lên, vì nó nằm trong khối chờ cạnh lên. Vòng `for` xóa cả 32 ngăn về 0. Đây không phải vòng lặp chạy theo thời gian: công cụ trải nó thành 32 dòng, và cả 32 ngăn cùng bị xóa trong một cạnh.
- `else if (we && wa != 5'd0)`: `&&` là "và", `!=` là "khác". Nghĩa là chỉ ghi khi được phép (`we`, write enable) và số ngăn khác 0. Ngăn số 0 là `$zero`, luôn bằng 0.
- `r[wa] <= wd;` ghi giá trị `wd` vào ngăn số `wa`, bằng gán `<=`.

**Bước 7. Đọc phần đọc ra của regfile.** Hai dòng `assign rd1 = ...` đọc ngăn `ra1` ra **ngay lập tức**, không chờ clock, vì đây là dây (đọc khác với ghi). Mỗi dòng là hai lớp bộ chọn lồng nhau: nếu số ngăn bằng 0 thì ra 0; nếu không thì xét tiếp `byp1` để chọn giữa giá trị đang ghi (`wd`) và giá trị trong ngăn (`r[ra1]`).

**Bước 8. Cắm vào mạch lớn (instance).** Trong `src/cpu_g1.v`, dòng `alu u_alu (.a(rs_v), .b(...), ...)` nghĩa là "đặt một cái `alu` tên `u_alu`, nối cổng `a` của nó vào dây `rs_v` của CPU". Dấu chấm trước tên là tên **cổng của module**, trong ngoặc là **dây phía ngoài** nối vào đó. Cách đọc này giống nhau ở mọi file.

**Bước 9. Hai phiên bản trong một file (`` `ifdef ``).** Dòng bắt đầu bằng dấu nháy ngược (`` ` ``) là chỉ thị cho công cụ, xử lý trước khi dịch. `` `ifdef G2 `` nghĩa là "nếu lúc dịch có đặt cờ `G2`, dùng đoạn này; không thì dùng đoạn sau chữ `` `else ``". Trong `src/soc_top.v` cờ này chọn CPU G2 hoặc G1, và cờ được đặt bằng `-DG2` ở lệnh dịch.

**Bước 10. Mở rộng dấu (sign extension).** Lệnh có hằng số 16 bit, nhưng ALU tính trên 32 bit, nên phải kéo dài. Với số không âm thì thêm 16 bit 0 phía trước. Với số âm thì thêm 16 bit 1, để giá trị vẫn là số âm đó. Verilog làm việc này bằng cách lặp lại bit dấu 16 lần rồi ghép phía trước, đúng dòng cuối của `imm_x` trong `src/cpu_g1.v`.

**Bước 11. Đọc testbench.** Testbench là file riêng để thử một khối, không có trong chip thật. Khác với khối chip, nó có:

- `initial begin ... end`: chạy **một lần**, từ trên xuống, như chương trình thường. Đây là nơi duy nhất trong Verilog mà các dòng chạy lần lượt.
- `reg` cho tín hiệu mà testbench **đặt giá trị** vào khối cần thử, `wire` cho tín hiệu testbench **chỉ nhìn**.
- `#1`: chờ 1 đơn vị thời gian mô phỏng, để mạch tổ hợp kịp tính xong rồi mới đối chiếu.
- `!==`: so sánh khác nhau, **kể cả** khi giá trị là `x` (chưa biết). Phép `!=` thường cho kết quả không rõ khi có `x`, `!==` thì không.
- `$display`: in một dòng ra màn hình. `$finish`: kết thúc mô phỏng.
- `always #10 clk = ~clk;` ở `tb/regfile_tb.v`: cứ 10 đơn vị thì đảo clock một lần. Vì khai `timescale 1ns/1ps` ở đầu file, một đơn vị là 1 ns, nên chu kỳ 20 ns, tức clock 50 MHz như chip.

**Chạy thử.** Mở cửa sổ dòng lệnh bash, ở **thư mục gốc của project** (thư mục có `src/`, `tb/`, `tools/`), gõ:

```bash
bash tools/run_unit.sh alu regfile
```

Máy làm hai việc cho mỗi tên: `iverilog` dịch `tb/<tên>_tb.v` cùng mọi file `src/*.v` thành một file chạy thử, rồi `vvp` chạy nó. Kết quả có hai dòng cho mỗi khối:

- Dòng bắt đầu bằng `PASS alu_tb` (hoặc `FAIL`), theo sau là một số. Với `alu_tb` đó là số ca thử, hiện là {{so:alu-tb}}; với `regfile_tb` là số lần kiểm, hiện là {{so:regfile-tb}}. Đây là dòng quyết định.
- Dòng `tb/alu_tb.v:41: $finish called at ...`. Đây chỉ là lời thông báo của `$finish` rằng mô phỏng đã dừng, **không phải** dấu hiệu đạt hay hỏng. Hỏng cũng in dòng này.

Mã thoát của lệnh bằng 0 khi mọi khối đều `PASS`.

### Bảng chu kỳ hoặc tính tay

Bảng sau cho thấy vì sao `<=` và `=` khác nhau. Hai cặp ô nhớ cùng bắt đầu với a = 1, b = 2. Cặp đầu viết `a <= b; b <= a;`, cặp sau viết `a = b; b = a;`, cả hai trong khối `always @(posedge clk)`.

| Thời điểm | Cặp dùng `<=`: a | Cặp dùng `<=`: b | Cặp dùng `=`: a | Cặp dùng `=`: b |
|---|---|---|---|---|
| Trước cạnh lên | 1 | 2 | 1 | 2 |
| Ngay sau cạnh lên | 2 | 1 | 2 | 2 |

**Cách đọc bảng:** mỗi hàng là một thời điểm, mỗi cột là một ô nhớ. Cặp dùng `<=` đã hoán đổi, cặp dùng `=` mất giá trị cũ của `a` vì `b = a` đọc `a` sau khi `a` đã bị thay. Kết quả này đã chạy thật trên Icarus Verilog.

:::suy-dan
Đề bài. Ba phép tính tay quanh hai file mẫu.

1. Với `a = 32'h00000000` và `b = 32'h80000000`, tính `diff`, `lt` theo đúng dòng của `src/alu.v`, rồi cho biết `slt` ra bao nhiêu và vì sao nếu chỉ nhìn bit dấu của `diff` thì sai.
2. Với `b = 32'hFFFFFFF8` (số −8) và `shamt = 1`, tính kết quả của `>>>` và của dịch phải thường `>>`.
3. Với `imm = 16'hFF04` và `imm = 16'h0004`, tính `imm_x` theo cách mở rộng dấu.
---
**Lời giải từng bước.**

1. `0x80000000` là số âm nhỏ nhất của 32 bit, bằng −2147483648. Bit dấu của nó là 1, của `a` là 0.
   - `diff = a - b = 0 - 0x80000000`. Kết quả toán học là +2147483648, nhưng 32 bit chỉ chứa tối đa +2147483647 nên số này tràn quay vòng thành `0x80000000`. Bit dấu của `diff` là 1.
   - Nếu chỉ nhìn bit dấu của `diff`, ta kết luận "kết quả âm, tức `a` nhỏ hơn `b`", tức `slt` ra 1. Sai, vì 0 không nhỏ hơn −2147483648.
   - Theo dòng thật: `a[31] != b[31]` (0 khác 1) nên `lt = a[31] = 0`. `slt` ra `{31'd0, 0}` = 0. Đúng. Đây chính là dòng {{doc:tb/vectors/alu.txt:40}} của file ca thử: mã `5`, hai số trên, kết quả `00000000`.
2. `0xFFFFFFF8` là −8. `>>>` điền bit dấu (1) vào chỗ trống: `0xFFFFFFFC`, tức −4 (đúng là −8 chia 2). Dịch phải thường `>>` điền 0 vào chỗ trống: `0x7FFFFFFC`, một số dương lớn, sai về ý nghĩa. Kết quả này đã chạy thật trên Icarus Verilog.
3. `0xFF04`: bit 15 (bit trái nhất của 16 bit) bằng 1, nên lặp 1 mười sáu lần phía trước: `imm_x = 0xFFFFFF04`. `0x0004`: bit 15 bằng 0, lặp 0 mười sáu lần: `imm_x = 0x00000004`. Đây là cách số −252 và số +4 cùng đúng một cách viết 16 bit mà vẫn ra hai giá trị 32 bit đúng.
:::

### Trong chip

:::trong-chip
Mỗi đoạn trích dưới đây có đường dẫn file và số dòng, phía sau giải thích từng dòng sinh ra phần cứng gì.

**ALU, vỏ ngoài (`src/alu.v`).**

{{trich:src/alu.v:8-15@module alu (}}

- **Dòng 8** mở module tên `alu`.
- **Dòng 9, 10** hai cổng vào 32 bit `a` và `b`: hai con số cần tính.
- **Dòng 11** cổng vào 5 bit `shamt`: số bit cần dịch, từ 0 đến 31 (5 bit ghi được 32 giá trị).
- **Dòng 12** cổng vào 4 bit `ctl`: mã chọn phép tính.
- **Dòng 13** cổng ra `y` khai `reg`. Đây là chỗ dễ nhầm: `reg` ở đây **không** có ô nhớ. `y` được gán trong khối `always @*` bên dưới, mà Verilog bắt biến được gán trong `always` phải khai là `reg`.
- **Dòng 14** cổng ra `zero`, kiểu dây.

**ALU, hằng số và bộ so sánh nhỏ hơn.**

{{trich:src/alu.v:17-18@localparam ALU_ADD}}

- **Dòng 17, 18** tám tên cho tám mã 0 đến 7. Chỉ để dễ đọc, không sinh phần cứng.

{{trich:src/alu.v:20-26@wire [31:0] diff}}

- **Dòng 20** một bộ trừ 32 bit luôn nối vào `a` và `b`.
- **Dòng 21 đến 25** là lời bình luận (bắt đầu bằng `//`), công cụ bỏ qua. Chúng giải thích vì sao không được chỉ nhìn bit dấu của `diff`.
- **Dòng 26** một bộ so sánh hai bit dấu và một MUX chọn giữa `a[31]` và `diff[31]`. Kết quả ra dây `lt`, bằng 1 khi `a` nhỏ hơn `b` theo số có dấu.

**ALU, khối chọn phép tính.**

{{trich:src/alu.v:28-40@always @*}}

- **Dòng 28** mở khối không có đồng hồ: mạch tổ hợp.
- **Dòng 29** `case (ctl)`: MUX 8 đường, `ctl` chọn đường.
- **Dòng 30 đến 37** mỗi dòng là một đường: kết quả của một phép tính đi vào `y` khi `ctl` đúng mã. Các phép tính đều có mạch riêng, chạy song song. Hai dòng đặc biệt: dòng 35 dùng ghép bit để biến 1 bit `lt` thành số 32 bit, dòng 37 là dịch phải số học.
- **Dòng 38** nhánh `default`: mã lạ thì `y` bằng 0.
- **Dòng 39, 40** đóng `case` và khối.

{{trich:src/alu.v:42-42@assign zero}}

- **Dòng 42** một bộ so sánh 32 bit với 0 nối vào dây `zero`. Lệnh rẽ nhánh dùng dây này để biết hai số có bằng nhau không.

**Regfile, vỏ ngoài và ô nhớ (`src/regfile.v`).**

{{trich:src/regfile.v:12-24@module regfile #(}}

- **Dòng 12, 13** module có `parameter G_BYPASS` mặc định 1; bên ngoài đổi được.
- **Dòng 15, 16** `clk` là clock, `rst` là tín hiệu reset.
- **Dòng 17 đến 19** nhóm cổng ghi: `we` (có được ghi không), `wa` (ghi vào ngăn số mấy, 5 bit đủ cho 32 ngăn), `wd` (giá trị cần ghi).
- **Dòng 20, 21** hai cổng chọn ngăn đọc `ra1` và `ra2`.
- **Dòng 22, 23** hai cổng ra `rd1` và `rd2`: hai ngăn đọc được cùng lúc.

{{trich:src/regfile.v:25-36@reg [31:0] r}}

- **Dòng 25** khai 32 ô nhớ, mỗi ô 32 bit. Đây là **ô nhớ thật**.
- **Dòng 26** `integer i` là biến đếm chỉ dùng cho vòng `for`, không thành phần cứng.
- **Dòng 28** khối chỉ chạy ở cạnh lên của `clk`: mọi dòng bên trong là mạch tuần tự.
- **Dòng 29 đến 32** nếu `rst` bằng 1: cả 32 ngăn nhận 0 (ghi bằng `<=`).
- **Dòng 33, 34** nếu không reset, `we` bằng 1 và `wa` khác 0: ngăn `wa` nhận `wd`.
- **Dòng 35, 36** đóng khối. Không có nhánh nào khác nên mọi ngăn còn lại **giữ nguyên** giá trị.

**Regfile, bypass và đọc ra.**

{{trich:src/regfile.v:41-46@wire byp1}}

- **Dòng 41, 42** `byp1`, `byp2` bằng 1 khi chế độ bypass bật (`G_BYPASS` khác 0), đang ghi, và số ngăn ghi trùng số ngăn đọc. Ở G1, `G_BYPASS` bằng 0 nên hai dây này luôn bằng 0.
- **Dòng 45, 46** hai dây `rd1`, `rd2`: MUX hai lớp. Lớp ngoài chọn 0 khi ngăn đọc là ngăn số 0. Lớp trong chọn `wd` (khi bypass) hoặc giá trị ngăn. Đây là mạch tổ hợp nên ra ngay, không chờ clock.

**Cách cắm vào CPU (`src/cpu_g1.v`).**

{{trich:src/cpu_g1.v:76-77@wire [31:0] imm_x}}

- **Dòng 76** nếu `ext` bằng `2'b01` thì thêm 16 bit 0 phía trước (số không dấu); **dòng 77** nếu `ext` bằng `2'b10` thì đặt `imm` lên 16 bit cao (lệnh `lui`), còn lại thì mở rộng dấu: ghép 16 bản sao của `imm[15]` đứng trước `imm`. Ba MUX nối nhau chọn một trong ba kiểu.

{{trich:src/cpu_g1.v:84-85@regfile #(.G_BYPASS(0))}}

- **Dòng 84, 85** gắn một `regfile` tên `u_rf` với `G_BYPASS` bằng 0. `.rd1(rs_v)` nghĩa là cổng ra `rd1` nối vào dây `rs_v` của CPU, rồi dây này đi vào cổng `a` của `alu` ở dòng 90.

**Chọn CPU bằng cờ dịch (`src/soc_top.v`).**

{{trich:src/soc_top.v:69-77@`ifdef G2}}

- **Dòng 69** nếu có `-DG2`: dùng đoạn 70 đến 72, gắn `cpu_pipe` (CPU G2).
- **Dòng 73** `` `else ``: không có cờ thì dùng đoạn 74 đến 76, gắn `cpu_g1` (CPU G1). **Dòng 77** `` `endif `` đóng chỉ thị.
- Cả hai đoạn cùng đặt tên instance `u_cpu` và cùng nối các cổng ở các dòng sau, nên phần còn lại của SoC không cần biết đang dùng lõi nào.

**Testbench của ALU (`tb/alu_tb.v`).**

{{trich:tb/alu_tb.v:17-31@initial begin}}

- **Dòng 17** `initial begin`: khối chạy một lần, từ trên xuống.
- **Dòng 18** đặt hai bộ đếm (số ca, số lỗi) về 0.
- **Dòng 19, 20** mở file ca thử `tb/vectors/alu.txt`; nếu không mở được thì báo FAIL.
- **Dòng 21 đến 25** đọc từng ký tự: dòng bắt đầu bằng `#` là bình luận thì bỏ, còn lại trả ký tự về để đọc cả dòng.
- **Dòng 26** đọc một ca: mã, `a`, `b`, `shamt`, kết quả mong đợi, cờ `zero` mong đợi.
- **Dòng 27** đặt các giá trị vào cổng của ALU.
- **Dòng 28** `#1`: chờ cho mạch tổ hợp tính xong.
- **Dòng 29** đếm ca.
- **Dòng 30, 31** nếu `y` hoặc `zero` khác mong đợi (so bằng `!==`) thì tăng bộ đếm lỗi.

{{trich:tb/alu_tb.v:38-41@$fclose(fd)}}

- **Dòng 39** nếu không lỗi và đủ số ca thì in `PASS alu_tb` kèm số ca, ngược lại **dòng 40** in `FAIL`. Dòng 41 kết thúc mô phỏng.

**Testbench của regfile, clock và hai bản.**

{{trich:tb/regfile_tb.v:9-14@regfile #(.G_BYPASS(1))}}

- **Dòng 9 đến 12** gắn **hai** regfile cùng nhận các tín hiệu như nhau, một cái `G_BYPASS` bằng 1 và một cái bằng 0. Nhờ vậy một bài thử kiểm cả hai chế độ.
- **Dòng 14** tạo clock: đảo mức mỗi 10 đơn vị thời gian.
:::

### Bẫy và thầy hay hỏi

:::bay
**Bẫy 1: "Đã khai `reg` thì chắc chắn có ô nhớ."** Sai. `reg` chỉ là kiểu biến mà Verilog bắt dùng cho mọi thứ được gán trong khối `always`. Ô nhớ thật chỉ xuất hiện khi khối đó chờ cạnh clock (`always @(posedge clk)`), hoặc khi có đường chạy không gán giá trị (thiếu `default`). Trong `src/alu.v`, `y` khai `reg` nhưng nằm trong `always @*` có đủ `default`, nên là dây thuần túy. Thầy hay hỏi: "ALU của em có ô nhớ không?" Trả lời: không, đổi `a`, `b` hoặc `ctl` thì `y` đổi ngay, không cần clock.
:::

:::bay
**Bẫy 2: lẫn `=` và `<=`.** Trong khối có clock phải dùng `<=`, vì nó mô tả đúng ô nhớ cùng đổi ở một cạnh. Nếu dùng `=` thì các dòng chạy lần lượt và dòng sau đọc giá trị đã bị dòng trước đổi, như bảng ở mục trên: hai ô cùng nhận giá trị của `b`, `a` biến mất. Quy ước của project: khối `always @(posedge clk)` dùng `<=` (như `r[wa] <= wd` ở `src/regfile.v`), khối `always @*` dùng `=` (như `y = a + b` ở `src/alu.v`). Thầy hay hỏi: "Vì sao dòng này dùng `<=`?" Trả lời: vì nó nằm trong khối có clock, mọi ô nhớ phải cùng đổi một lúc.
:::

:::bay
**Bẫy 3: đọc Verilog như chương trình chạy từ trên xuống.** Hai dòng `assign` rời nhau, hay hai khối `always`, đảo chỗ cho nhau thì mạch không đổi: chúng đều đang chạy cùng lúc, như hai cái máy trong xưởng (chỉ có điều tên dây phải được khai báo trước khi dùng). Thứ tự các dòng không phải thứ tự tính toán. Ngoại lệ duy nhất là bên trong `initial begin ... end` của testbench, nơi các dòng chạy lần lượt như code thường. Khi tìm một tín hiệu đi đâu, hãy lần theo tên dây (dây này lấy từ đâu, đi vào đâu) thay vì lần theo số dòng.
:::

:::bay
**Bẫy 4: thấy chữ `$finish called` là tưởng đạt, hoặc chạy lệnh không phải bài thử.** Dòng `$finish called at ...` xuất hiện **cả khi PASS lẫn khi FAIL**. Kết quả nằm ở dòng bắt đầu bằng `PASS` hoặc `FAIL`. Thêm nữa, không phải tên nào cũng chạy được bằng `run_unit.sh`: đưa tên `cpu_pipe` (hoặc `cpu_g1`) cho nó thì báo FAIL, vì bài thử của CPU cần một chương trình nạp vào bộ nhớ. CPU thử bằng `python tools/cosim_iss.py`. Thầy hay hỏi: "Em chạy test thế nào, đạt hay chưa?" Trả lời bằng đúng lệnh, và đọc ra dòng `PASS` kèm số ca.
:::

### Sửa tại chỗ và ứng dụng

:::sua-tai-cho
**Cài lỗi rồi xem bài thử nào bắt.** Ba lỗi, thử lần lượt. Mỗi lần **chép file ra bản nháp rồi sửa bản nháp, không sửa file gốc**. Ở thư mục gốc project:

```bash
source tools/env.sh
mkdir -p work/mut
cp src/alu.v work/mut/alu.v
```

**Lỗi 1: bỏ phần xử lý tràn của `slt`.** Mở `work/mut/alu.v`, đổi dòng 26 thành `wire lt = diff[31];`. Dịch và chạy với bản nháp:

```bash
iverilog -g2005 -Wno-timescale -o work/mut/alu_tb.vvp tb/alu_tb.v work/mut/alu.v
vvp -n work/mut/alu_tb.vvp
```

Bắt được. Dòng báo lỗi đầu tiên trông như sau, và dòng cuối là `FAIL alu_tb` kèm số lỗi và tổng số ca ({{so:alu-tb}} ca):

```text
loi ctl=5 a=00000000 b=80000000 sh=0: y=00000001 zero=0, can 00000000 1
```

Đọc: `ctl=5` là phép `slt`, `a` bằng 0, `b` bằng số âm nhỏ nhất, chip ra 1 nhưng đáp án đúng là 0. Đúng ca ở bài tính tay phía trên.

**Lỗi 2: `byp1` so với `ra2` thay vì `ra1`.** Chép `src/regfile.v` thành `work/mut/regfile.v`, sửa dòng 41 để `wa == ra2`. Dịch với `tb/regfile_tb.v` và bản nháp (giống lệnh trên). Bắt được ở dòng đầu:

```text
loi G_BYPASS=1 tra wd: we=1 wa=5 wd=12345678 ra1=5 ra2=6 byp=00000000 00000000 nob=00000000 00000000
```

Đọc: ghi vào ngăn 5 và đọc ngăn 5 ở cổng 1 cùng lúc, đáng lẽ cổng 1 trả `12345678` nhưng trả 0.

**Lỗi 3: bỏ điều kiện `wa != 5'd0` ở dòng 33 của regfile.** Thử xong, **bài thử vẫn `PASS regfile_tb`**. Không phải bài thử yếu: đây là lỗi **tương đương** (không đổi hành vi nhìn thấy được). Ngăn số 0 có thể bị ghi, nhưng hai dòng đọc ra vẫn chặn riêng bằng `ra1 == 5'd0`, nên không ai thấy được giá trị lạ trong ngăn 0. Hai lớp bảo vệ che nhau. Muốn thấy lỗi, phải bỏ **cả hai** lớp (thêm việc bỏ dòng chặn ở dòng 45): lúc đó bài thử mới báo lỗi `loi $0 sau ghi` ở ca ghi vào ngăn 0.

Bài học: một lỗi cài vào mà bài thử vẫn PASS có hai khả năng, hoặc bài thử thiếu ca, hoặc lỗi tương đương. Phải đọc code mới phân biệt được.
:::

:::dung-o-dau
**Kỹ năng này dùng ở đâu khác.**

- **Đọc bất kỳ file Verilog nào.** Nhận ra loại dòng (dây hay ô nhớ), đọc cổng vào ra, lần theo tên dây. Cách đọc không đổi dù file lớn hay nhỏ, kể cả với code của người khác.
- **Đọc sơ đồ sóng (waveform).** Công cụ xem sóng vẽ mỗi dây thành một đường theo thời gian. Biết dây nào là tổ hợp (đổi ngay theo đầu vào) và ô nhớ nào đổi ở cạnh clock giúp đọc sóng nhanh.
- **Đọc báo cáo tổng hợp.** Các con số LUT và FF (hai loại ô của FPGA) ở báo cáo của project chính là số dây-cổng và số ô nhớ mà các dòng Verilog sinh ra.
- **Bài thử viết đúng và kiểm được.** Cách viết `!==`, `#1`, và đọc ca thử từ file dùng lại được cho mọi bài thử đơn giản.
:::

### Tự kiểm và quay lại bức tranh

:::tu-luan
Giải thích dòng `output reg [31:0] y` trong `src/alu.v`: `reg` ở đây có nghĩa gì, và `y` có phải ô nhớ không?
---
**Đáp án hoàn chỉnh.** `y` không phải ô nhớ. `reg` là kiểu biến mà Verilog bắt dùng cho tín hiệu được gán trong khối `always`, không phải "ô nhớ". Có ô nhớ hay không phụ thuộc khối nào gán: ở đây `y` được gán trong `always @*` (mạch không chờ clock) và nhánh `default` bảo đảm mọi giá trị `ctl` đều gán `y`. Công cụ vì vậy dựng một MUX 8 đường chứ không dựng ô nhớ. Nếu `y` được gán trong `always @(posedge clk)` thì mới có ô nhớ thật.
:::

:::tu-luan
Đọc bằng lời dòng `assign rd1 = (ra1 == 5'd0) ? 32'd0 : (byp1 ? wd : r[ra1]);` ở `src/regfile.v`. Nói rõ giá trị của `rd1` trong ba trường hợp: đọc ngăn 0; đọc ngăn 5 khi `G_BYPASS` bằng 1 và đang ghi `wd` vào ngăn 5; đọc ngăn 5 khi `G_BYPASS` bằng 0.
---
**Đáp án hoàn chỉnh.** Dòng này là hai bộ chọn lồng nhau, tổ hợp, nên `rd1` đổi ngay theo `ra1`, `we`, `wa`, `wd`.

- **Đọc ngăn 0:** điều kiện ngoài `ra1 == 0` đúng, `rd1` bằng 0 bất kể bên trong ngăn 0 có gì.
- **Đọc ngăn 5, `G_BYPASS` bằng 1, đang ghi ngăn 5:** `byp1` bằng 1 nên `rd1` bằng `wd`, tức giá trị **sắp** được ghi, lệnh đọc thấy nó ngay trong cùng chu kỳ.
- **Đọc ngăn 5, `G_BYPASS` bằng 0:** `byp1` luôn bằng 0 nên `rd1` bằng `r[5]`, giá trị **cũ** đang nằm trong ngăn. Giá trị mới chỉ vào ngăn ở cạnh lên kế tiếp.
:::

:::tu-luan
Trong `tb/alu_tb.v` vì sao có `#1` trước khi so sánh, và vì sao dùng `!==` thay vì `!=`?
---
**Đáp án hoàn chỉnh.**

- **`#1`:** testbench vừa đặt `a`, `b`, `ctl` mới; mạch tổ hợp cần một khoảnh khắc mô phỏng để tính xong. Nếu đối chiếu ngay trong cùng khoảnh khắc đó thì không có gì bảo đảm `y` đã cập nhật, và có thể so nhầm với kết quả của ca trước. Chờ 1 đơn vị cho mạch ổn định rồi mới so.
- **`!==`:** phép so này coi `x` (giá trị chưa biết, ví dụ dây chưa được nối) là một giá trị cụ thể để so. Phép `!=` thường cho ra kết quả không xác định khi có `x`, nên bài thử có thể bỏ sót lỗi dây chưa nối. Với `!==`, một dây ra `x` bị tính là khác đáp án và bị báo lỗi.
:::

:::tu-luan
Muốn dịch SoC với lõi G2 thì thêm gì vào lệnh dịch, và vì sao không cần sửa bất kỳ file `.v` nào?
---
**Đáp án hoàn chỉnh.** Thêm cờ `-DG2` vào lệnh `iverilog`. Cờ này đặt macro `G2`, nên `` `ifdef G2 `` ở `src/soc_top.v` chọn đoạn gắn `cpu_pipe` thay vì `cpu_g1`. Hai đoạn dùng cùng tên instance `u_cpu` và cùng nối cổng giống nhau nên phần còn lại của SoC không đổi. Công cụ `tools/cosim_iss.py` làm đúng việc này khi chạy với `--g2`: nó thêm `-DG2` vào lệnh dịch.
:::

:::mcq id=KT-V0-01
? Trong `src/alu.v`, cổng ra `y` được khai `output reg [31:0] y`. Vì sao ALU vẫn là mạch không có ô nhớ?
- [x] Vì `y` được gán trong khối `always @*` và mọi nhánh của `case`, kể cả `default`, đều gán `y`, nên công cụ dựng bộ chọn thay vì ô nhớ
- [ ] Vì chữ `reg` trong Verilog luôn có nghĩa là một sợi dây nối thẳng, không bao giờ là ô nhớ nào trong mọi trường hợp
- [ ] Vì ALU có một clock ngầm ở cổng `ctl`, và ô nhớ của `y` chỉ giữ giá trị trong khoảng thời gian rất ngắn
- [ ] Vì lệnh `case` chỉ chạy đúng một lần lúc bắt đầu mô phỏng nên `y` giữ nguyên giá trị đầu tiên của nó
> Giải thích: `reg` chỉ là kiểu biến bắt buộc cho tín hiệu gán trong `always`, không quyết định có ô nhớ. Ô nhớ chỉ có khi khối chờ cạnh clock hoặc có đường không gán giá trị. Ở ALU, khối `always @*` có đủ `default` nên là mạch tổ hợp. Ba lựa chọn sai đều gán cho `reg` hoặc `case` một nghĩa không có trong ngôn ngữ.
:::

:::mcq id=KT-V0-02
? Dòng `r[wa] <= wd;` ở `src/regfile.v` làm giá trị `wd` vào ngăn `wa` vào lúc nào?
- [ ] Ngay khi `wd` đổi giá trị, vì đây là phép gán nên cập nhật liền không cần chờ gì khác
- [ ] Mỗi khi `ra1` hoặc `ra2` đổi, vì lúc đó mạch cần nạp lại giá trị cần đọc cho khớp
- [x] Chỉ ở cạnh lên của `clk`, và chỉ khi không reset, `we` bằng 1 và `wa` khác 0
- [ ] Ở mọi lúc `we` bằng 1, kể cả giữa hai cạnh clock, rồi giữ nguyên tới khi `we` về 0
> Giải thích: Dòng nằm trong khối `always @(posedge clk)`, nên chỉ có hiệu lực ở cạnh lên. Hai điều kiện `we` và `wa` khác 0 chặn ghi khi không được phép. Ghi diễn ra ở cạnh, không theo mức của `we`, cũng không theo việc đọc.
:::

:::mcq id=KT-V0-03
? Cho `a = 32'h00000000` và `b = 32'h80000000`. Theo dòng {{doc:src/alu.v:26}}, `lt` bằng bao nhiêu, và vì sao?
- [ ] 1, vì `diff` là `0x80000000` có bit dấu bằng 1 nên mạch kết luận `a` nhỏ hơn `b` mà không cần so sánh gì thêm
- [x] 0, vì `a[31]` khác `b[31]` nên `lt` lấy chính `a[31]`, mà `a` không âm nên không nhỏ hơn `b`
- [ ] 1, vì `b` là số âm nên mọi số đứng cạnh nó đều bị coi là nhỏ hơn theo quy ước của `slt`
- [ ] Không xác định, vì phép trừ tràn nên `diff` mang giá trị `x` và `lt` cũng thành `x`
> Giải thích: Hai bit dấu khác nhau nên mạch bỏ qua `diff` (có thể tràn) và dùng bit dấu của `a`. Bit đó bằng 0, nên `lt` bằng 0: 0 không nhỏ hơn số âm nhỏ nhất. Ca này nằm ở dòng 40 của `tb/vectors/alu.txt`. Phép trừ tràn trong Verilog cho kết quả quay vòng, không cho `x`.
:::

:::mcq id=KT-V0-04
? Với `imm = 16'hFF04` và kiểu mở rộng dấu, `imm_x` ở dòng {{doc:src/cpu_g1.v:77}} có giá trị nào?
- [ ] `0x0000FF04`, vì mở rộng chỉ thêm 16 bit 0 vào phía trước, như với mọi hằng số 16 bit
- [ ] `0xFF040000`, vì hằng số được đặt lên 16 bit cao của từ 32 bit như trong lệnh `lui`
- [x] `0xFFFFFF04`, vì bit 15 của `imm` bằng 1 nên 16 bit thêm phía trước đều là 1
- [ ] `0xFFFF04FF`, vì mở rộng dấu đảo thứ tự hai byte của hằng số rồi mới thêm bit dấu
> Giải thích: Kiểu mở rộng dấu lặp bit 15 mười sáu lần rồi ghép phía trước `imm`. Bit 15 của `FF04` bằng 1 nên ra `FFFFFF04`, vẫn là số âm −252. Thêm toàn 0 là mở rộng không dấu; đặt lên 16 bit cao là lệnh `lui`; không có phép đảo byte nào trong dòng này.
:::

:::mcq id=KT-V0-05
? Sau `bash tools/run_unit.sh alu`, cuối kết quả có dòng `tb/alu_tb.v:41: $finish called at ...`. Dòng đó cho biết điều gì về WatchChip?
- [ ] ALU đã đạt, vì mô phỏng chạy tới tận `$finish` mà không bị dừng giữa chừng
- [ ] ALU chưa đạt, vì lệnh `$finish` chỉ được gọi khi bài thử gặp lỗi nghiêm trọng
- [ ] Bài thử chưa chạy xong, vì `$finish` chỉ được in ra khi mô phỏng bị ngắt giữa chừng trước khi kiểm hết các ca thử
- [x] Chỉ cho biết mô phỏng đã dừng; đạt hay không phải đọc dòng `PASS` hoặc `FAIL` ngay phía trên
> Giải thích: Mô phỏng nào dừng bằng `$finish` cũng in dòng này, dù đạt hay hỏng; khi cài lỗi vào ALU, dòng này vẫn in ngay dưới dòng `FAIL`. Dòng quyết định là dòng bắt đầu bằng `PASS alu_tb` kèm số ca, hiện là {{so:alu-tb}}.
:::

Quay lại bức tranh. Sau bài này, mỗi file `.v` là một thứ đọc được: nhìn vào cổng để biết khối nhận và trả gì, nhìn `always` để biết chỗ nào có nhớ, nhìn `assign` để biết dây nào nối với dây nào, rồi chạy bài thử của nó để thấy dòng `PASS`. Từ bài tiếp theo, hai CPU được cắt thành năm lát; mỗi lát đều chỉ dùng đúng những ký hiệu đã học ở đây. Đường đi của một lệnh qua các lát này đã được kể ở {{bai:A2}}.

## P1 · EX và số học (ALU, nhân, chia)

### Bản đồ

:::ban-do
Bài này dành cho người giữ chặng **tính toán**: nơi CPU làm toán thật sự. Lệnh đã được giải mã xong, hai số cần tính đã lấy ra khỏi thanh ghi, và chặng này cho ra kết quả. Chặng gồm bốn mảnh, nằm ở bốn chỗ:

| Mảnh | File và dòng | Làm gì |
|---|---|---|
| ALU, máy tính bỏ túi của CPU | `src/alu.v` (43 dòng) | Cộng, trừ, and, or, xor, so sánh nhỏ hơn, dịch trái, dịch phải giữ dấu. Không có đồng hồ bên trong. |
| Khối nhân và chia | `src/muldiv.v` (91 dòng) | Nhân có kết quả ngay. Chia mất nhiều chu kỳ, kết quả nằm ở hai thanh ghi riêng `LO` và `HI`. |
| Nối ALU và khối chia vào CPU G1 | `src/cpu_g1.v` dòng 87–106 | Cắm hai khối trên vào lõi một-lệnh-một-lần. Quyết định khi nào CPU phải đứng chờ. |
| Nối vào CPU G2 (đường ống năm tầng) | `src/cpu_pipe.v` dòng 129–183 | Cùng việc đó ở tầng EX, thêm chọn kết quả và quyết định nhánh. |

**Cách đọc bảng:** cột giữa là chỗ phải mở ra đọc. Hai file đầu đọc từng dòng, hai file sau chỉ đọc đúng đoạn đã nêu số dòng.

Hai bài thử của chặng này: `bash tools/run_unit.sh alu muldiv`. Kết quả mong đợi là hai dòng `PASS alu_tb {{so:alu-tb}}` và `PASS muldiv_tb {{so:muldiv-tb}}`. Hai con số đó là số ca thử đã được kiểm.
:::

### Câu hỏi mở bài

Máy tính bỏ túi chia hai số mất một cái chớp mắt. Vậy vì sao CPU của nhóm cần **33 chu kỳ** để chia hai số 32 bit, và trong 33 chu kỳ đó cả CPU đứng im chờ? Và vì sao lệnh so sánh `slt` không được phép chỉ nhìn dấu của phép trừ?

Câu trả lời ngắn, các mục sau chứng minh từng ý:

- **Phép chia** được làm như chia tay trên giấy: mỗi lần chỉ tìm ra **một** chữ số của thương. Số 32 bit có 32 chữ số nhị phân, nên cần 32 bước. Cộng thêm một chu kỳ để chốt hai toán hạng ban đầu là 33.
- **Trong lúc chia**, kết quả chưa có mà lệnh sau có thể đang cần, nên CPU phải **giữ nguyên** mọi thứ cho tới khi chia xong.
- **Phép trừ có thể tràn**: kết quả đúng không nằm vừa trong 32 bit nên bit dấu của hiệu bị sai. `slt` phải nhìn **dấu của hai số gốc** trước, chỉ khi cùng dấu mới tin dấu của hiệu.

### Trực giác

Hình dung CPU là một **nhà bếp**, và chặng tính toán là **khu bếp có lửa**: món đã được sơ chế (giải mã, lấy nguyên liệu), giờ nấu.

- **ALU** là một chiếc **bếp đa năng** có tám núm xoay. Xoay đúng núm nào thì ra đúng món đó, vặn núm khác thì món đổi ngay, bếp không nhớ món vừa nấu. Núm xoay chính là mã `ctl` (4 bit, dùng 8 giá trị).
- **Nhân** giống bấm **máy tính bỏ túi**: bấm xong có ngay.
- **Chia** giống **bài chia tay trên giấy**. Mỗi dòng trên giấy tìm một chữ số của thương và còn lại một số dư. Ở đây giấy là hai ô nhớ, mỗi chu kỳ làm một dòng.

Còn hai ý nền cần có trước khi đọc code.

**Số có dấu trong máy.** Máy lưu số âm theo kiểu **bù 2**. Với 32 bit, bit trái nhất (bit 31) là bit dấu: 0 là không âm, 1 là âm. Số `0xFFFFFFFF` là −1, số `0x80000000` là số âm nhỏ nhất, bằng −2147483648. Muốn đổi dấu một số thì đảo mọi bit rồi cộng 1. Chữ `0x` báo "số này viết theo hệ mười sáu".

**Tràn.** Hình dung đồng hồ cơ chỉ có 12 giờ: 11 giờ cộng 3 tiếng cho ra 2 giờ, vì vượt 12 thì quay vòng. Số 32 bit cũng quay vòng như vậy. Phép trừ `0 − 0x80000000` đáng lẽ ra +2147483648, một số **không nằm vừa** trong khoảng cho phép, nên quay vòng và ra lại đúng `0x80000000`, tức một số **âm**. Đó là tràn.

### Cơ chế theo đường tín hiệu

Theo dõi một lệnh `addu $t0, $t1, $t2` đi qua chặng này, rồi một lệnh `div`.

**1. Lệnh cộng.** Hai số đến từ hai thanh ghi `$t1` (cổng `a` của ALU) và `$t2` (cổng `b`). Mã `ctl = 0` chọn phép cộng. `y = a + b`, và **ngay trong chu kỳ đó** `y` đã có giá trị, vì ALU không có ô nhớ. Kết quả đi tiếp sang chặng sau để được ghi vào `$t0`.

**2. Lệnh có hằng số**, ví dụ `addiu $t0, $t1, 5`. Cổng `b` không lấy từ thanh ghi mà lấy hằng số 5 đã mở rộng dấu lên 32 bit. Một bộ chọn quyết định: tín hiệu `alu_src` bằng 1 thì chọn hằng, bằng 0 thì chọn thanh ghi. Bộ chọn này nằm ngay đầu vào `b` của ALU.

**3. Lệnh `div`.** Khác hẳn lệnh cộng ở ba điểm:

- Kết quả **không** đi vào thanh ghi thường mà vào hai thanh ghi riêng: `LO` giữ thương, `HI` giữ số dư. Muốn lấy ra phải dùng `mflo` và `mfhi`.
- **Chu kỳ 1** chỉ chốt hai toán hạng (start). **Chu kỳ 2 đến 33**, tức 32 chu kỳ, mỗi chu kỳ làm một bước chia, và tín hiệu `busy` bằng 1.
- Trong suốt thời gian đó CPU **đứng chờ**: tín hiệu `stall` bằng 1. Khi chu kỳ cuối xong, `done` bằng 1 và CPU đi tiếp.

**4. Chọn kết quả của chặng.** Chặng không chỉ có ALU. Nó còn có nhân, `HI`, `LO`, lệnh `bcd`, thanh ghi CP0 và địa chỉ quay về của `jal`. Mã `rsel` chọn **một** trong các nguồn đó làm kết quả (đây là bộ chọn tám đường ở `cpu_pipe.v`).

**5. Một khác biệt nhỏ giữa hai lõi.** Ở G1, các khối chạy theo xung `ph_a` (chỉ một nửa số chu kỳ clock, vì G1 làm mỗi lệnh trong hai pha). Ở G2 chúng chạy theo xung phép `cpu_ce`. Bên trong `muldiv.v`, hai thứ này đều đi vào cổng tên `ce` và khối không cần biết nó đến từ đâu.

### Bảng chu kỳ hoặc tính tay

:::suy-dan
**Đề bài.** Ba phép tính tay quanh chặng này.

1. Với `slt`, tính `0 < 0x80000000` bằng đúng cách của `src/alu.v:26`, rồi cho thấy cách "nhìn dấu của hiệu" sẽ sai ở đâu.
2. Chia **7 cho 2** theo kiểu khôi phục, thu nhỏ còn 4 bit và 4 bước. Viết bảng từng bước gồm số dư, thương, kết quả thử trừ.
3. Chia **−7 cho 2** với số 32 bit: cho biết `LO`, `HI`, và chặng nào sửa dấu.
---
**Phép 1: `slt` khi `a = 0`, `b = 0x80000000`.**

- `a` có bit dấu bằng 0 (không âm). `b` có bit dấu bằng 1 (âm, là −2147483648). Hai bit dấu **khác nhau**.
- Đúng toán học: `0` lớn hơn −2147483648, nên `0 < b` là **sai**, kết quả phải bằng 0.
- Theo dòng 26: `a[31] != b[31]` đúng, nên `lt = a[31] = 0`. Kết quả đúng bằng 0.
- Nếu chỉ nhìn bit dấu của hiệu: `a − b = 0 − 0x80000000` tràn thành `0x80000000`, bit 31 bằng 1, tức "có vẻ âm", nên đoán `a < b` là **đúng**. Sai. Đây là lý do dòng 26 phải xét dấu hai số gốc trước.
- Ca này có thật trong file thử `tb/vectors/alu.txt`: dòng `5 00000000 80000000 00 00000000 1` (mã 5, `a`, `b`, `shamt`, kết quả 0, cờ `zero` bằng 1).

**Phép 2: chia 7 cho 2, 4 bit, 4 bước.** Bắt đầu `rem = 0000`, `quo = 0111` (7). Mỗi bước: (1) dịch dư sang trái và kéo bit cao nhất của `quo` vào; (2) thử trừ 2; (3) trừ được thì giữ hiệu và đẩy bit 1 vào thương, không trừ được thì giữ dư cũ và đẩy bit 0.

| Bước | Bit kéo vào | Dư sau khi dịch | Thử trừ 2 | Vừa không? | Dư mới | Thương mới |
|---|---|---|---|---|---|---|
| 1 | 0 | 0 | 0 − 2 = âm | Không | 0 | 1110 |
| 2 | 1 | 1 | 1 − 2 = âm | Không | 1 | 1100 |
| 3 | 1 | 3 | 3 − 2 = 1 | Có | 1 | 1001 |
| 4 | 1 | 3 | 3 − 2 = 1 | Có | 1 | 0011 |

Sau bước 4, `quo = 0011` = 3 và `rem = 1`. Kiểm: `3 × 2 + 1 = 7`. Đúng. Phiên bản thật của nhóm làm y hệt nhưng với 32 bit nên cần 32 bước.

**Phép 3: chia −7 cho 2, 32 bit.**

- Khối chốt `dvs = |b| = 2`, `quo = |a| = 7`, nhớ `neg_q = a[31] ^ b[31] = 1 ^ 0 = 1` và `neg_r = a[31] = 1`.
- Sau 32 bước phần dương cho ra thương 3, dư 1.
- Bước cuối sửa dấu (`src/muldiv.v:84-85`): `lo = −3 = 0xFFFFFFFD`, `hi = −1 = 0xFFFFFFFF`. Dư lấy dấu của **số bị chia**, vì quy ước `−7 = (−3) × 2 + (−1)`.
- Khớp file thử `tb/vectors/div.txt` dòng 827: `FFFFFFF9 00000002 FFFFFFFD FFFFFFFF 0`.
:::

### Trong chip

:::trong-chip
Mỗi đoạn trích dưới đây có đường dẫn file và số dòng, phía sau giải thích từng dòng sinh ra phần cứng gì. Bắt đầu từ ALU.

**ALU, vỏ ngoài (`src/alu.v`).**

{{trich:src/alu.v:8-15@module alu (}}

- **Dòng 8** mở module `alu`.
- **Dòng 9, 10** hai cổng vào 32 bit: `a` và `b`, hai số cần tính.
- **Dòng 11** cổng vào 5 bit `shamt`: số bit cần dịch, 0 đến 31. Chỉ lệnh dịch dùng.
- **Dòng 12** cổng vào 4 bit `ctl`: mã phép tính. 4 bit ghi được 16 giá trị, dùng 8.
- **Dòng 13** cổng ra `y`. Khai `reg` chỉ vì nó được gán trong khối `always`. Nó **không** là ô nhớ.
- **Dòng 14** cổng ra `zero`: bằng 1 khi `y` bằng 0. Lệnh `beq` và `bne` dùng cờ này để biết hai số có bằng nhau.

**ALU, bảng mã và so sánh nhỏ hơn.**

{{trich:src/alu.v:17-26@localparam ALU_ADD}}

- **Dòng 17, 18** tám mã phép tính đặt tên: `ALU_ADD` là 0, `ALU_SUB` 1, `ALU_AND` 2, `ALU_OR` 3, `ALU_XOR` 4, `ALU_SLT` 5, `ALU_SLL` 6, `ALU_SRA` 7. Đặt tên để khỏi viết số trần. Bảng này phải khớp `control.v` của người giữ chặng giải mã.
- **Dòng 20** `diff = a − b`, một dây 32 bit. Một phép trừ dùng chung cho cả `sub` và `slt`.
- **Dòng 21 đến 25** là chú thích giải thích vì sao không chỉ nhìn dấu của `diff`.
- **Dòng 26** `lt`: nếu bit dấu của `a` và `b` khác nhau thì `lt` bằng bit dấu của `a` (a âm thì a nhỏ hơn), ngược lại lấy bit dấu của `diff`. Đây là một **bộ chọn hai đường** với điều kiện là phép so sánh `!=` của hai bit.

**ALU, khối chọn phép tính.**

{{trich:src/alu.v:28-40@always @*}}

- **Dòng 28** `always @*`: mạch tổ hợp, chạy lại mỗi khi bất kỳ đầu vào nào đổi.
- **Dòng 29** `case (ctl)`: tám nhánh, mỗi nhánh một phép. Phần cứng là một bộ chọn tám đường (cộng thêm đường mặc định).
- **Dòng 30, 31** cộng và trừ. Nhánh trừ dùng lại `diff`.
- **Dòng 32 đến 34** and, or, xor từng bit.
- **Dòng 35** `slt`: ghép 31 bit không với `lt`, nên kết quả chỉ là 0 hoặc 1.
- **Dòng 36** dịch trái `b` đi `shamt` bit. Lưu ý dịch **toán hạng `b`** (thanh ghi `rt`), `a` bị bỏ qua. Đúng với `sll rd, rt, shamt` của MIPS.
- **Dòng 37** dịch phải **giữ dấu**: `$signed(b) >>> shamt` chép bit dấu vào các chỗ trống bên trái, nên số âm vẫn âm. `$unsigned(...)` chỉ để gán lại cho `y` không dấu.
- **Dòng 38** `default`: mã lạ thì `y = 0`. Nhánh này bảo đảm **mọi** trường hợp đều có gán, nên công cụ dựng bộ chọn chứ không dựng ô nhớ.
- **Dòng 39, 40** đóng `case` và `always`.

**ALU, cờ bằng không.**

{{trich:src/alu.v:42-43@assign zero}}

- **Dòng 42** `zero` là dây bằng 1 khi cả 32 bit của `y` bằng 0. Một cổng so sánh với số 0.
- **Dòng 43** đóng module. Hết ALU: 43 dòng, mọi dòng đã nêu.

**Khối nhân chia, vỏ ngoài (`src/muldiv.v`).**

{{trich:src/muldiv.v:20-34@module muldiv (}}

- **Dòng 20** mở module `muldiv`.
- **Dòng 21, 22** `clk` và `rst`: clock và reset.
- **Dòng 23** `ce`: "chu kỳ này được phép bước". Khối chỉ đổi trạng thái khi `ce` bằng 1. Nhờ vậy cùng một khối chạy được trong G1 (nửa số chu kỳ clock) lẫn G2.
- **Dòng 24** `start`: xung báo "bắt đầu chia", chỉ có tác dụng khi `ce` bằng 1 và khối đang rảnh.
- **Dòng 25, 26** hai toán hạng `a` (số bị chia, thanh ghi `rs`) và `b` (số chia, `rt`).
- **Dòng 27** `mul_y` là 32 bit thấp của `a × b`. Nhân có dấu hay không dấu đều cho cùng 32 bit thấp, nên không cần phân biệt.
- **Dòng 28, 29** `busy` bằng 1 khi đang chia, `done` bằng 1 ở chu kỳ có kết quả.
- **Dòng 30, 31** `lo` (thương) và `hi` (số dư), khai `reg` vì được ghi trong khối có clock: **đây là ô nhớ thật**.
- **Dòng 32** `dz`: cờ "lần chia gần nhất chia cho 0".
- **Dòng 34** `assign mul_y = a * b`: nhân là một phép nhân tổ hợp duy nhất. Kết quả có ngay, không đợi chu kỳ nào.

**Khối nhân chia, các ô nhớ nội bộ.**

{{trich:src/muldiv.v:36-42@reg        run;}}

- **Dòng 36** `run`: 1 bit, bằng 1 khi phép chia đang chạy.
- **Dòng 37** `cnt`: bộ đếm 5 bit, đếm bước từ 0 đến 31.
- **Dòng 38** `rem`: số dư đang tính. Luôn nhỏ hơn số chia.
- **Dòng 39** `quo`: ban đầu chứa số bị chia. Mỗi bước dịch trái một bit: bit cao nhất rời đi để vào `rem`, bit thương mới được đẩy vào bên phải. Một thanh ghi **dùng chung hai việc**, nên không cần thêm 32 bit.
- **Dòng 40** `dvs`: trị tuyệt đối số chia.
- **Dòng 41, 42** `neg_q` và `neg_r`: nhớ dấu của thương và của số dư để sửa ở cuối.

**Khối nhân chia, một bước chia là những dây nào.**

{{trich:src/muldiv.v:44-54@wire [32:0] rem_sh}}

- **Dòng 44** `rem_sh = {rem, quo[31]}`: dư dịch trái một bit, kéo bit cao nhất của `quo` xuống. Là 33 bit vì `rem` 32 bit cộng thêm một bit.
- **Dòng 45** `trial = rem_sh − dvs`: thử trừ số chia. Dùng 33 bit để **thấy được bit âm** (bit thứ 33).
- **Dòng 46** `fits = ~trial[32]`: nếu bit thứ 33 bằng 0, nghĩa là hiệu không âm, số chia "vừa" vào dư, bit thương bằng 1.
- **Dòng 47** `rem_n`: vừa thì lấy hiệu, không vừa thì **khôi phục** bằng dư cũ đã dịch. Đây là chữ "restoring" (chia khôi phục).
- **Dòng 48** `quo_n`: dịch `quo` trái một bit rồi đẩy `fits` vào bên phải.
- **Dòng 50** `div0`: dây bằng 1 khi số chia bằng 0.
- **Dòng 51** `last`: đang chạy và bộ đếm bằng 31, tức bước thứ 32, bước cuối.
- **Dòng 53** `busy = run`.
- **Dòng 54** `done`: bằng 1 khi `ce` bật **và** (hoặc là vừa bấm start với số chia 0, hoặc là đang ở bước cuối). `done` là tổ hợp, không phải ô nhớ, nên CPU thấy nó ngay trong chu kỳ cuối.

**Khối nhân chia, nhịp clock và reset.**

{{trich:src/muldiv.v:56-62@always @(posedge clk)}}

- **Dòng 56** `always @(posedge clk)`: mọi thứ trong khối này là ô nhớ, đổi ở cạnh lên của clock.
- **Dòng 57 đến 61** nhánh `rst`: xóa hết về 0 (cờ chạy, bộ đếm, dư, thương, số chia, hai cờ dấu, `lo`, `hi`, `dz`).
- **Dòng 62** `else if (ce)`: chỉ khi được phép bước mới làm các việc dưới đây.

**Khối nhân chia, bắt đầu chia.**

{{trich:src/muldiv.v:63-76@if (start && !run)}}

- **Dòng 63** điều kiện bắt đầu: có `start` và đang rảnh.
- **Dòng 64 đến 66** chia cho 0: `lo = 0`, `hi = a`, `dz = 1`, **xong ngay** trong một chu kỳ, không chạy 32 bước. Đây là quy ước của nhóm.
- **Dòng 69** `run` bằng 1: bắt đầu chạy.
- **Dòng 70, 71** bộ đếm và số dư về 0.
- **Dòng 72** `quo` nhận `|a|`: nếu `a` âm thì lấy `−a`. Trường hợp riêng `0x80000000` đổi dấu vẫn ra `0x80000000`, và khi hiểu **không dấu** thì đó đúng là 2147483648, nên vẫn đúng.
- **Dòng 73** `dvs` nhận `|b|` tương tự.
- **Dòng 74** `neg_q`: thương âm khi `a`, `b` **khác dấu**, phép xor hai bit dấu.
- **Dòng 75** `neg_r`: số dư cùng dấu số bị chia.

**Khối nhân chia, từng bước và bước cuối.**

{{trich:src/muldiv.v:77-90@end else if (run)}}

- **Dòng 77** đang chạy: mỗi chu kỳ có `ce` làm các dòng sau.
- **Dòng 78, 79** `rem` và `quo` nhận giá trị mới tính ở dòng 47, 48.
- **Dòng 80** `cnt` tăng một.
- **Dòng 81** bước cuối.
- **Dòng 83** `run` về 0: xong.
- **Dòng 84** `lo` nhận thương, **đổi dấu nếu `neg_q`**.
- **Dòng 85** `hi` nhận số dư, đổi dấu nếu `neg_r`.
- **Dòng 86** `dz` về 0.
- **Dòng 87 đến 90** đóng các khối. Hết `muldiv.v`.

**Nối vào CPU G1 (`src/cpu_g1.v`).**

{{trich:src/cpu_g1.v:87-100@ALU, mul/div, bcd}}

- **Dòng 88, 89** hai dây `alu_y` và `alu_zero` nhận đầu ra ALU.
- **Dòng 90** gắn ALU: `a` lấy thẳng `rs_v`; `b` lấy `imm_x` (hằng số) khi `alu_src` bằng 1, ngược lại lấy `rt_v`. Dấu `?:` ở đây là bộ chọn hai đường.
- **Dòng 92, 93** các dây kết quả và cờ bận của hai khối nhiều chu kỳ (`muldiv` và `bcd_unit`).
- **Dòng 94, 95** `is_div` và `is_bcd` đọc từ mã hai bit `multi` do `control.v` sinh ra: `01` là chia, `10` là `bcd`, `00` là lệnh thường.
- **Dòng 96** chú thích: `start` chỉ được có **một** xung dù lệnh được giải mã lặp mỗi chu kỳ.
- **Dòng 97, 98** gắn `muldiv`: `ce` nhận `ph_a` (pha A của G1), `start` bằng `is_div && !started`. Chữ `!started` là chốt chặn: lệnh `div` bị giải mã lại ở mỗi chu kỳ chờ nên phải nhớ "đã bấm start rồi".
- **Dòng 99, 100** gắn khối `bcd` theo cùng khuôn.

{{trich:src/cpu_g1.v:102-106@wire mdone}}

- **Dòng 102** `mdone`: chia thì lấy `md_done`, `bcd` thì lấy `bcd_done`, lệnh thường thì 0.
- **Dòng 103, 104** chú thích: không dùng `busy` vì ở chu kỳ start `busy` còn bằng 0; `done` đã gồm `ce` nên chỉ cần xét ở pha A.
- **Dòng 105** `stall`: đang là lệnh nhiều chu kỳ (`multi` khác 0) **mà chưa xong**. Khi `stall` bằng 1, CPU đứng chờ.

**Nối vào CPU G2, tầng EX (`src/cpu_pipe.v`).**

{{trich:src/cpu_pipe.v:129-136@EX}}

- **Dòng 129 đến 130** chú thích: `opA`, `opB` là toán hạng thật đưa vào ALU, **đã chuyền thẳng** từ tầng sau nếu cần (forwarding, bài của người giữ chặng hazard).
- **Dòng 131, 132** `opA`, `opB` là bộ chọn ba đường: `fwd = 10` lấy `exm_res` (kết quả đang ở tầng sau EX), `01` lấy `wb`, còn lại lấy giá trị đọc từ thanh ghi.
- **Dòng 133** `alu_b`: nếu lệnh dùng hằng (`idex_asrc`) thì lấy hằng, ngược lại `opB`.
- **Dòng 136** gắn ALU với `opA`, `alu_b`.

{{trich:src/cpu_pipe.v:138-148@wire [31:0] mul_y, lo, hi, bcd_y}}

- **Dòng 138, 139** dây kết quả và cờ bận.
- **Dòng 140, 141** `md_go` và `bc_go` là xung start: có `cpu_ce`, đúng loại lệnh (`idex_multi`) và chưa `started`.
- **Dòng 142 đến 145** gắn `muldiv` và `bcd_unit` với `opA`, `opB`, và `ce` là `cpu_ce`.
- **Dòng 147** `mdone`: ở đường ống, lệnh thường coi như "xong" luôn, nên nhánh cuối là 1.
- **Dòng 148** `stall_busy`: lệnh chia hoặc `bcd` chưa xong thì **giữ tầng EX**. Các tầng phía trước cũng đứng.

{{trich:src/cpu_pipe.v:150-172@reg [31:0] cp0_rd}}

- **Dòng 150 đến 158** đọc thanh ghi CP0: số 12 là `Status`, 13 là `Cause`, 14 là `EPC`, còn lại 0. Phần này thuộc bài của người giữ ngắt, ở đây chỉ cần biết nó là một đầu vào của bộ chọn kết quả.
- **Dòng 160** chú thích: chọn kết quả của tầng EX.
- **Dòng 161 đến 172** `ex_res`: mã `idex_rsel` chọn 1 trong 7 nguồn: 1 nhân, 2 `HI`, 3 `LO`, 4 `bcd`, 5 CP0, 6 `PC+4` (cho `jal`), còn lại ALU.

{{trich:src/cpu_pipe.v:174-183@nhánh/nhảy quyết định ở EX}}

- **Dòng 174, 175** chú thích: nhánh quyết định ở EX, `take` bằng 1 nghĩa là đổi hướng.
- **Dòng 176** `eq = (opA == opB)`: so hai toán hạng bằng nhau.
- **Dòng 177, 178** `take`: lệnh ở EX hợp lệ, EX không bận, và (là `beq` mà bằng, hoặc `bne` mà khác, hoặc nhảy `j`/`jal`, hoặc `jr`, hoặc `eret`).
- **Dòng 179 đến 182** `tgt`: địa chỉ đích, chọn bằng chuỗi `?:`. `eret` nhảy về `EPC`, `jr` nhảy tới thanh ghi, `j` ghép địa chỉ, còn lại là nhánh có điều kiện: `PC+4` cộng hằng số dịch trái 2 bit.
:::

### Bẫy và thầy hay hỏi

:::bay
**Bẫy 1: "Chia mất 32 chu kỳ."** Sai một chu kỳ. Chu kỳ đầu chỉ chốt toán hạng (start), 32 chu kỳ sau mới là 32 bước chia. Tổng là **33**. Bài thử `muldiv_tb` kiểm đúng hai con số: `cyc == 33` và `busy_cyc == 32`. Trường hợp chia cho 0 thì xong ngay trong **1** chu kỳ.
:::

:::bay
**Bẫy 2: "Chia số âm thì bỏ dấu đi chia rồi dán dấu lại."** Gần đúng nhưng **thiếu hai quy tắc**. Thương âm khi hai số khác dấu. Số dư lấy dấu của **số bị chia**, không phải dấu của thương. Hai quy tắc đó là hai ô nhớ `neg_q`, `neg_r`. Đổi nhầm thì `−7 / 2` ra dư `+1` thay vì `−1`.
:::

:::bay
**Bẫy 3: "`slt` chỉ cần nhìn bit dấu của `a − b`."** Sai khi phép trừ **tràn**, đúng ví dụ `0 < 0x80000000`. Bài thử `alu_tb` có ca này và sẽ báo FAIL nếu sửa dòng 26 thành `diff[31]`.
:::

:::bay
**Bẫy 4: "`sra` và `srl` như nhau."** Khác. Dịch phải **giữ dấu** (`sra`, dòng 37) chép bit dấu vào chỗ trống, nên `−8 >> 1` ra `−4`. Dịch thường điền số 0, và `0xFFFFFFF8` dịch một bit ra `0x7FFFFFFC`, một số **dương** rất lớn. ISA của nhóm chỉ có dịch phải giữ dấu (`sra`).
:::

### Sửa tại chỗ và ứng dụng

:::sua-tai-cho
**Cài lỗi rồi xem bài thử nào bắt.** Hai lỗi. Mỗi lần **chép file ra bản nháp rồi sửa bản nháp, không sửa file gốc**. Ở thư mục gốc project:

```bash
source tools/env.sh
mkdir -p work/mut
cp src/alu.v work/mut/alu.v
cp src/muldiv.v work/mut/muldiv.v
```

**Lỗi 1: bỏ phần xử lý tràn của `slt`.** Mở `work/mut/alu.v`, đổi dòng 26 thành `wire lt = diff[31];`. Dịch và chạy với bản nháp:

```bash
iverilog -g2005 -Wno-timescale -o work/mut/alu_tb.vvp tb/alu_tb.v work/mut/alu.v
vvp work/mut/alu_tb.vvp | head -3
```

Kết quả đã chạy (12/11): dòng đầu là `loi ctl=5 a=00000000 b=80000000 sh=0: y=00000001 zero=0, can 00000000 1`. Đọc ra: ở mã `ctl=5` (`slt`), `a = 0`, `b = 0x80000000`, ALU trả `y = 1` nhưng đúng phải là `0`. Đúng là ca tràn ở phép tính tay. Dòng cuối của bài thử là `FAIL alu_tb ...` thay vì `PASS`.

**Lỗi 2: số dư lấy dấu của thương.** Đổi dòng 75 của `work/mut/muldiv.v` thành `neg_r <= a[31] ^ b[31];`. Chạy:

```bash
iverilog -g2005 -Wno-timescale -o work/mut/md_tb.vvp tb/muldiv_tb.v work/mut/muldiv.v
vvp work/mut/md_tb.vvp | head -3
```

Kết quả đã chạy: `loi div: a=00000001 b=80000000 lo=00000000 hi=ffffffff dz=0 busy_cyc=32 (can 00000000 00000001 0)`. Đọc ra: chia `1` cho `0x80000000` (một số âm lớn), thương đúng là 0 và dư đúng là 1, nhưng bản lỗi trả dư `0xFFFFFFFF` (tức −1), vì lấy dấu của thương (âm, do hai số khác dấu) áp lên dư.

**Thử thêm (không bắt buộc): dịch bộ đếm.** Đổi `5'd31` ở dòng 51 thành `5'd30`. Bài thử sẽ báo `loi so chu ky div ... busy_cyc=31`: phép chia chạy 31 bước thay vì 32 và kết luận "33 chu kỳ" bị phá. Nhờ vậy biết bài thử kiểm cả **thời gian**, không chỉ kết quả.

Xong thì xóa thư mục `work/mut/` hoặc để đó, nó không nằm trong chip.
:::

:::dung-o-dau
**Kỹ năng này dùng ở đâu khác.**

- **Mọi bộ xử lý đều có ALU và bộ chia**, chỉ khác độ rộng và tốc độ. Hiểu "mỗi chu kỳ một bit thương" là hiểu tại sao chia luôn chậm hơn nhân ở phần cứng.
- **Tràn số** gặp ở mọi chương trình: cộng hai số int lớn, tính trung bình hai chỉ số mảng. Cách nghĩ "xét dấu hai số gốc trước" dùng lại được.
- **Số bù 2** là cách mọi ngôn ngữ lập trình lưu số nguyên có dấu. Biết nó để đọc được dữ liệu thô và log.
- **Đếm chu kỳ** (33 cho `div`) là cách ước lượng thời gian chạy trước khi chạy thật, và là lý do báo cáo có phần CPI.
:::

### Tự kiểm và quay lại bức tranh

:::tu-luan
Giải thích dòng 26 của `src/alu.v`: `wire lt = (a[31] != b[31]) ? a[31] : diff[31];`. Nêu giá trị của `lt` trong hai trường hợp `a = 0, b = 0x80000000` và `a = 5, b = 3`.
---
**Đáp án hoàn chỉnh.** Dòng này chọn giữa hai nguồn. Nếu bit dấu hai số khác nhau thì kết quả "nhỏ hơn" chính là bit dấu của `a` (a âm tức a nhỏ hơn). Nếu cùng dấu thì hiệu không tràn, nên bit dấu của `diff` đúng.

- `a = 0, b = 0x80000000`: bit dấu khác nhau (0 và 1), nên `lt = a[31] = 0`. `0` không nhỏ hơn số âm.
- `a = 5, b = 3`: cùng dấu (cả hai không âm), `diff = 2`, bit 31 bằng 0, nên `lt = 0`. Đúng: 5 không nhỏ hơn 3.
:::

:::tu-luan
Lệnh `div` bắt đầu ở chu kỳ 1. Cho biết trạng thái `run`, `busy`, `done` ở chu kỳ 1, chu kỳ 2, chu kỳ 33 và chu kỳ 34, khi số chia khác 0.
---
**Đáp án hoàn chỉnh.**

- **Chu kỳ 1** (có `start`): `run` còn 0 vì chỉ được đặt thành 1 ở cạnh cuối chu kỳ. `busy = run = 0`, `done = 0`. Đây là lý do CPU không dùng `busy` để xét xong.
- **Chu kỳ 2**: `run = 1`, `busy = 1`, `done = 0` (bước chia thứ nhất).
- **Chu kỳ 33**: bước thứ 32, `cnt = 31` nên `last = 1`, `done = 1`, `busy` vẫn 1. `lo` và `hi` được ghi ở cuối chu kỳ này.
- **Chu kỳ 34**: `run = 0`, `busy = 0`, `done = 0`. Khối rảnh, kết quả nằm ở `lo` và `hi`.
:::

:::tu-luan
Vì sao `quo` vừa chứa số bị chia vừa chứa thương, và điều này có làm mất số bị chia không?
---
**Đáp án hoàn chỉnh.** Mỗi bước, bit **cao nhất** của `quo` (bit cuối cùng chưa dùng của số bị chia) được kéo xuống `rem`, đồng thời `quo` dịch trái một bit và bit thương mới được đẩy vào **bên phải**. Số bit số bị chia còn lại giảm một thì số bit thương tăng một, tổng luôn là 32. Không mất gì vì mỗi bit số bị chia đã được dùng đúng một lần trước khi bị đẩy ra. Sau 32 bước, `quo` chỉ còn thương. Cách này tiết kiệm một thanh ghi 32 bit.
:::

:::tu-luan
Chia `0x80000000` cho `0xFFFFFFFF` (tức −2147483648 chia −1) ra `LO` và `HI` bao nhiêu, và vì sao không tràn như lẽ ra phải có?
---
**Đáp án hoàn chỉnh.** Kết quả file thử `tb/vectors/div.txt` ghi `80000000 FFFFFFFF 80000000 00000000 0`: `LO = 0x80000000`, `HI = 0`, không chia cho 0. Về toán, −2147483648 chia −1 đáng lẽ ra +2147483648, **không nằm vừa** số 32 bit có dấu. Khối chia không có đường báo tràn: dòng 72 chốt `|a| = 0x80000000` (đổi dấu số âm nhỏ nhất ra chính nó), dòng 73 chốt `|b| = 1`, 32 bước cho thương `0x80000000`, và vì `a, b` cùng dấu nên `neg_q = 0`, `LO` giữ `0x80000000`. Kết quả này **đọc theo số có dấu là −2147483648**, tức là sai về toán nhưng đây là quy ước của nhóm, ghi trong tài liệu ISA. Người giữ chặng nên nói thẳng điều này nếu thầy hỏi.
:::

:::tu-luan
Vì sao `start` của `muldiv` phải có thêm điều kiện `!started` ở `src/cpu_g1.v:97`?
---
**Đáp án hoàn chỉnh.** Ở G1, lệnh `div` đứng trong tầng giải mã nhiều chu kỳ liền, và **mỗi chu kỳ nó vẫn được giải mã lại**, nên `is_div` vẫn bằng 1 suốt thời gian chờ. Nếu `start` chỉ phụ thuộc `is_div` thì khối chia sẽ được "bấm start" liên tục, mỗi lần chốt lại toán hạng và chạy lại từ đầu, không bao giờ xong. `started` là một ô nhớ (ghi ở `cpu_g1.v:212`) nhớ "đã bấm start cho lệnh này rồi". Điều kiện `!started` cho `start` chỉ có đúng **một** xung ở chu kỳ đầu của lệnh.
:::

:::mcq id=KT-P1-01
? Phép trừ `a − b` trong `src/alu.v` có thể tràn. Dòng nào của file xử lý để lệnh `slt` vẫn đúng, và nó làm gì?
- [ ] Dòng 20: dùng phép trừ 33 bit nên hiệu không bao giờ tràn và bit dấu của hiệu luôn đúng trong mọi trường hợp
- [x] Dòng 26: nếu bit dấu của `a` và `b` khác nhau thì lấy bit dấu của `a`, nếu cùng dấu mới lấy bit dấu của `diff`
- [ ] Dòng 35: ghép 31 bit không với `lt`, nên kết quả luôn đúng
- [ ] Dòng 38: nhánh `default` bắt các ca tràn và trả về 0
> Giải thích: dòng 20 chỉ tính hiệu 32 bit và vẫn quay vòng khi tràn. Dòng 35 chỉ ghép bit, không sửa gì. Nhánh `default` ở dòng 38 chỉ xử lý mã `ctl` lạ, không liên quan tràn. Việc sửa tràn nằm hết ở dòng 26.
:::

:::mcq id=KT-P1-02
? Khối `muldiv` của WatchChip chia hai số bình thường (số chia khác 0). Từ lúc `start` tới lúc `done` bằng 1 mất bao nhiêu chu kỳ CPU, kể cả hai đầu?
- [ ] 32 chu kỳ, mỗi chu kỳ một bước chia
- [ ] 31 chu kỳ, vì bước đầu nằm cùng chu kỳ với start
- [x] 33 chu kỳ: một chu kỳ chốt toán hạng, rồi 32 bước chia
- [ ] 34 chu kỳ, vì phải thêm một chu kỳ riêng ở cuối để sửa dấu thương và dấu số dư
> Giải thích: dòng 7 của `muldiv.v` ghi rõ chu kỳ 2 đến 33 là 32 bước, chu kỳ 1 là start. Bước sửa dấu nằm **cùng** chu kỳ với bước thứ 32 (dòng 84, 85) nên không tốn thêm. Bài thử kiểm `cyc == 33`.
:::

:::mcq id=KT-P1-03
? Trong `src/muldiv.v`, dòng 74 `neg_q <= a[31] ^ b[31];` và dòng 75 `neg_r <= a[31];`. Chia −7 cho 2 thì `neg_q`, `neg_r` bằng bao nhiêu, và kết quả `LO`, `HI` là gì?
- [ ] `neg_q = 0`, `neg_r = 1`; `LO = 3`, `HI = −1`
- [ ] `neg_q = 1`, `neg_r = 0`; `LO = −3`, `HI = 1`, vì số dư luôn dương theo kiểu toán học
- [ ] `neg_q = 1`, `neg_r = 1`; `LO = −4`, `HI = 1`
- [x] `neg_q = 1`, `neg_r = 1`; `LO = −3`, `HI = −1`
> Giải thích: `a = −7` có bit dấu 1, `b = 2` có bit dấu 0, xor ra 1 nên thương âm. Dư theo dấu `a` nên cũng âm. `|−7| / 2` cho thương 3, dư 1, sau sửa dấu ra −3 và −1. Kiểm: `(−3) × 2 + (−1) = −7`. Đáp án `LO = −4` là kiểu làm tròn xuống, nhóm dùng làm tròn về 0.
:::

:::mcq id=KT-P1-04
? Ở WatchChip, một lệnh `div` đang chạy trong CPU G1. Tín hiệu nào của `src/cpu_g1.v` khiến CPU đứng chờ, và nó bằng 1 khi nào?
- [x] `stall` (dòng 105): lệnh là loại nhiều chu kỳ (`multi` khác 00) mà `mdone` chưa bằng 1
- [ ] `busy` (dòng 93): bằng 1 ngay từ chu kỳ đầu của lệnh nên CPU dùng nó để biết cần đứng chờ
- [ ] `started` (dòng 54): bằng 1 cho tới khi chia xong
- [ ] `is_div` (dòng 94): bằng 1 khi lệnh là chia
> Giải thích: `busy` còn 0 ở chu kỳ start nên không dùng (dòng 103). `started` chỉ ngăn bấm start lặp, nó về 0 ở chu kỳ done. `is_div` chỉ cho biết loại lệnh. `stall` ghép đúng hai điều kiện "là lệnh nhiều chu kỳ" và "chưa xong".
:::

:::mcq id=KT-P1-05
? Hãy đọc dòng 36 của `src/alu.v`: `ALU_SLL: y = b << shamt;`. Lệnh MIPS `sll $t0, $t1, 2` dịch thanh ghi nào?
- [ ] `$t0`, vì là thanh ghi đích
- [x] `$t1`, vì lệnh dịch toán hạng `rt` và cổng `b` của ALU nhận `rt`
- [ ] Cả hai, rồi cộng lại
- [ ] Không thanh ghi nào, vì `a` mới là số bị dịch còn `b` chỉ là số bit cần dịch
> Giải thích: trong dạng `sll rd, rt, shamt`, số bị dịch là `rt`. Ở ví dụ `rt` là `$t1`. ALU đặt `rt` vào cổng `b` (dòng 36 dịch `b`), còn `a` bị bỏ qua, nên viết `b << shamt` là đúng.
:::

:::mcq id=KT-P1-06
? Trong WatchChip, chia −2147483648 (`0x80000000`) cho −1 ra `LO` bằng bao nhiêu?
- [ ] `0x7FFFFFFF`, giá trị lớn nhất, vì tràn bị chặn lại
- [ ] `0x00000000`, và cờ `dz` bằng 1
- [x] `0x80000000` và `HI = 0`, đúng như `tb/vectors/div.txt` dòng 831
- [ ] `0x00000001`
> Giải thích: khối không có đường chặn tràn. `|a|` vẫn là `0x80000000` (đổi dấu số âm nhỏ nhất ra chính nó), chia cho 1 ra `0x80000000`, hai số cùng dấu nên không đổi dấu. Cờ `dz` chỉ lên khi **số chia** bằng 0. Đáp án bằng 0 là nhầm hai chuyện.
:::

:::mcq id=KT-P1-07
? Tầng EX của lõi G2 nối `md_go` ở `src/cpu_pipe.v:140`. Điều kiện nào **không** có trong biểu thức đó?
- [ ] `cpu_ce`, xung phép của CPU
- [ ] `idex_multi == 2'b01`, lệnh là chia
- [x] `idex_v`, lệnh trong EX hợp lệ
- [ ] `!started`, chưa bấm start
> Giải thích: dòng 140 là `cpu_ce && (idex_multi == 2'b01) && !started`. Điều kiện `idex_v` xuất hiện ở dòng 177 cho nhánh (`take`), không phải ở start của chia. Phân biệt hai biểu thức này là cách đọc code chính xác.
:::

:::mcq id=KT-P1-08
? Với ALU, có đúng không: "đổi thứ tự hai dòng `ALU_AND` và `ALU_OR` trong khối `case` của `src/alu.v` thì mạch đổi hành vi"?
- [ ] Đúng, vì `case` chạy từng nhánh theo thứ tự và nhánh đầu thắng
- [ ] Đúng, vì mã `ctl` đổi theo vị trí dòng
- [x] Sai, vì mỗi nhánh có một mã `ctl` riêng, hoàn toàn không trùng nhau, thứ tự dòng không quyết định gì
- [ ] Sai, nhưng chỉ vì hai nhánh này ngắn
> Giải thích: các nhánh của `case` so sánh bằng nhau với `ctl`, không có hai nhánh nào cùng mã nên không có chuyện "nhánh nào trước". Thứ tự dòng chỉ đổi cách đọc, không đổi mạch. Đây là một chỗ lẫn với ngôn ngữ lập trình thường.
:::

### Thầy chỉ vào dòng này

:::thay-hoi
**`src/alu.v:26`**: Dòng này làm gì, vì sao không viết gọn `diff[31]`? **Trả lời:** Đây là dòng so sánh nhỏ hơn có dấu. Nếu hai số khác dấu thì số âm nhỏ hơn, nên lấy bit dấu của `a`. Nếu cùng dấu thì phép trừ không tràn, nên bit dấu của hiệu đúng. Viết gọn `diff[31]` sai ở ca `0 < 0x80000000`, và bài thử `alu_tb` bắt được.
:::

:::thay-hoi
**`src/alu.v:37`**: Dịch phải kiểu gì, và khác dịch thường ở đâu? **Trả lời:** Dịch phải **giữ dấu** (`>>>` trên số có dấu): bit dấu được chép vào các chỗ trống bên trái, nên số âm vẫn âm. `−8` dịch một bit ra `−4`. Dịch thường điền 0 nên `0xFFFFFFF8` thành số dương lớn.
:::

:::thay-hoi
**`src/muldiv.v:47`**: Chữ "khôi phục" nằm ở đâu? **Trả lời:** Dòng 47 chọn số dư mới: nếu thử trừ **vừa** (`fits`) thì lấy hiệu, nếu **không vừa** thì lấy lại số dư cũ đã dịch. "Lấy lại số cũ" chính là khôi phục. Cùng lúc `fits` đi vào thương làm bit 1 hoặc 0.
:::

:::thay-hoi
**`src/muldiv.v:51`**: Vì sao `cnt == 31` mà gọi là bước 32? **Trả lời:** Bộ đếm bắt đầu từ 0 nên giá trị 31 là lần đếm thứ 32. Bước cuối ghi `lo`, `hi` và kéo `done` lên. Nếu sửa thành 30 thì chỉ chạy 31 bước, bài thử `muldiv_tb` báo sai số chu kỳ.
:::

:::thay-hoi
**`src/muldiv.v:72`**: Số âm nhỏ nhất đổi dấu thì sao? **Trả lời:** `−0x80000000` đổi dấu vẫn ra `0x80000000`, vì không có số dương 2147483648 trong 32 bit có dấu. Khối coi giá trị này là **không dấu**, đúng 2147483648, nên 32 bước vẫn cho kết quả đúng. Đây là lý do `0x80000000 / −1` ra `0x80000000`, ghi trong file thử.
:::

:::thay-hoi
**`src/cpu_pipe.v:148`**: `stall_busy` làm gì với đường ống? **Trả lời:** Bằng 1 khi lệnh ở tầng EX là `div` hoặc `bcd` mà chưa xong. Khi đó tầng EX **giữ nguyên** lệnh và các tầng trước đứng chờ, nên `mflo` đứng ngay sau `div` vẫn đọc được kết quả đúng. Quyết định nhánh (`take`, dòng 177) cũng bị tắt khi `stall_busy` bằng 1.
:::

## P2 · Hazard, forwarding, bộ nhớ và ghi về

### Bản đồ

:::ban-do
Bài này dành cho người giữ chặng **xử lý xung đột giữa các lệnh** và hai tầng cuối của đường ống: tầng bộ nhớ (MEM) và tầng ghi về (WB). Nó gồm năm mảnh:

| Mảnh | File và dòng | Làm gì |
|---|---|---|
| Bộ phát hiện xung đột | `src/hazard.v` (55 dòng) | Quyết định lấy tắt kết quả từ đâu (forwarding) và có phải đứng chờ một chu kỳ không (load-use). |
| Các thanh ghi giữa tầng EX, MEM, WB | `src/cpu_pipe.v` dòng 71–84 | Hai "băng chuyền" mang lệnh từ tầng này sang tầng sau. |
| Cắm bộ phát hiện vào CPU G2 | `src/cpu_pipe.v` dòng 112–128 | Nối các dây của `hazard.v` vào đường ống. |
| Tầng MEM và WB của G2 | `src/cpu_pipe.v` dòng 184–206 | Đọc và ghi bộ nhớ, chọn dữ liệu ghi về thanh ghi, quyết định lệnh nào được đi tiếp. |
| Chuyển lệnh sang tầng sau | `src/cpu_pipe.v` dòng 260–277 | Cập nhật băng chuyền EX/MEM, MEM/WB, và chèn bong bóng khi EX bận. |
| Phần bộ nhớ và ghi về ở G1 | `src/cpu_g1.v` dòng 119–147 | Cùng việc, nhưng ở lõi một-lệnh-một-lần. |

**Cách đọc bảng:** `hazard.v` đọc kỹ từng dòng. Các đoạn của `cpu_pipe.v` đọc đúng khoảng dòng đã nêu.

Bài thử của chặng này: `bash tools/run_unit.sh hazard`, kết quả mong đợi `PASS hazard_tb {{so:hazard-tb}}`. Ngoài ra chín chương trình tra tấn hazard nằm ở `fw/tests/hazard/`, chạy chung với lõi G2 qua `python tools/cosim_iss.py --g2 --rand 0`.
:::

### Câu hỏi mở bài

Đường ống cho nhiều lệnh chạy chồng lên nhau. Lệnh sau cần kết quả của lệnh trước khi lệnh trước chưa kịp ghi vào thanh ghi thì làm sao? Vì sao có chỗ chỉ cần **chuyền tắt** là xong, nhưng lệnh `lw` rồi dùng ngay thì **bắt buộc đứng chờ một chu kỳ**?

Câu trả lời ngắn, các mục sau chứng minh từng ý:

- Kết quả của lệnh `add` đã **có sẵn** ở cuối tầng EX, chỉ chưa được ghi vào thanh ghi. Ta kéo một sợi dây tắt từ băng chuyền sau về đầu tầng EX. Đó là **forwarding**.
- Kết quả của lệnh `lw` chỉ **có ở cuối tầng MEM**, một tầng sau. Lệnh kế bên đang ở EX, cần giá trị ngay, nhưng nó chưa tồn tại. Dây tắt không kéo được ngược thời gian, nên đành chờ **một chu kỳ**.
- Khi nhiều nguồn cùng ghi một thanh ghi, ưu tiên nguồn **mới hơn**, tức nguồn đứng gần EX hơn.

### Trực giác

Hình dung đường ống là **dây chuyền lắp bánh sandwich** có năm trạm: lấy bánh mì (IF), phết bơ (ID), thêm nhân (EX), bọc giấy (MEM), xếp vào hộp (WB). Mỗi trạm làm một việc, mỗi nhịp mỗi chiếc bánh nhích một trạm. Năm chiếc bánh được làm cùng lúc ở năm trạm khác nhau.

- **Xung đột dữ liệu (hazard)**: chiếc bánh sau cần một thứ mà chiếc bánh trước **đang làm dở**. Ví dụ bánh sau cần "loại nhân của bánh trước" nhưng bánh trước chưa tới trạm ghi sổ.
- **Forwarding (lấy tắt)**: người ở trạm thêm nhân **hét sang** trạm bên cạnh "nhân tôi vừa làm là cà chua". Không cần chờ ghi vào sổ.
- **Stall (chờ một nhịp)**: có thứ chỉ biết được ở trạm bọc giấy, còn bánh sau đã đến trạm thêm nhân. Không hét kịp, bánh sau phải **đứng im một nhịp**. Dây chuyền tạo một **bong bóng**: một ô trống chạy qua các trạm.

Còn hai ý cần có.

**Thanh ghi tầng.** Giữa hai trạm có một **băng chuyền** giữ chiếc bánh đang chuyển. Trong chip, đó là một nhóm ô nhớ (nhóm `reg`) đổi giá trị ở mỗi cạnh clock. Ví dụ `exm_res` là kết quả của lệnh đang nằm giữa tầng EX và MEM.

**Thanh ghi `$zero` (số 0).** Thanh ghi số 0 luôn bằng 0, ghi vào cũng không đổi. Vì thế một lệnh "ghi vào `$zero`" **không được** coi là cung cấp kết quả cho lệnh sau. Mọi điều kiện lấy tắt đều phải loại trường hợp này.

### Cơ chế theo đường tín hiệu

Theo dõi đoạn chương trình sau trong đường ống G2:

```
lw   $t0, 0($s0)      # lệnh 1: đọc bộ nhớ vào $t0
addu $t1, $t0, $t2    # lệnh 2: dùng $t0 ngay
sw   $t1, 0($s3)      # lệnh 3: cất $t1
```

**1. Lệnh 1 `lw`.** Ở tầng EX ALU tính địa chỉ `$s0 + 0` và đặt vào `exm_res`. Sang tầng MEM, địa chỉ đó đọc bộ nhớ dữ liệu. Dữ liệu đọc được nằm ở `mw_mdata` ở cuối tầng MEM, rồi mới được ghi vào `$t0` ở tầng WB.

**2. Lệnh 2 `addu` ở tầng ID.** `hazard.v` thấy lệnh trước (đang ở EX) là `lw` ghi vào `$t0`, và lệnh này đọc đúng `$t0`. Tín hiệu `stall_lu` lên 1. Lệnh 2 **đứng im** ở ID thêm một chu kỳ, và một **bong bóng** (lệnh rỗng) được đưa vào EX thay chỗ.

**3. Chu kỳ sau.** `lw` đã tới tầng MEM/WB, dữ liệu đã có. `addu` vào EX và lấy `$t0` bằng **forwarding mã 01** (từ băng chuyền cuối). Không phải chờ ghi vào thanh ghi.

**4. Lệnh 3 `sw`.** Cần `$t1`, là kết quả của `addu` vừa chạy trước nó. `addu` đang ở EX/MEM, nên forwarding mã **10** (từ băng chuyền kề) cho `sw` giá trị ngay, không cần chờ thêm.

**5. Thứ tự ưu tiên của các sự kiện** (khi nhiều thứ cùng xảy ra): EX bận (lệnh `div` hoặc `bcd` chưa xong) thắng nhánh đổi hướng, nhánh đổi hướng thắng load-use, load-use thắng bình thường.

**6. Ở lõi G1** không có đường ống nên không có hazard: một lệnh chạy hết rồi mới tới lệnh sau. Phần MEM và WB ở G1 vẫn tồn tại, chỉ là chạy trong hai pha thay vì năm tầng.

### Bảng chu kỳ hoặc tính tay

:::suy-dan
**Đề bài.** Ba phép tính tay quanh chặng này.

1. Đoạn chương trình ở mục Cơ chế (`lw`, `addu`, `sw`) chạy hết trong bao nhiêu chu kỳ? Vẽ bảng từng lệnh theo từng chu kỳ.
2. Với bốn lệnh `subu $2,$1,$3`, `and $12,$2,$5`, `or $13,$6,$2`, `addu $14,$2,$2`, cho biết lệnh nào lấy tắt, từ nguồn nào, mã forwarding bao nhiêu.
3. Nếu viết `lw $t0,0($s0)` rồi `addiu $t1,$s1,5` (không đọc `$t0`) thì có phải chờ không? Vì sao?
---
**Phép 1: ba lệnh, tính chu kỳ.** Chữ `*` là lệnh đứng chờ một chu kỳ.

| Lệnh | c1 | c2 | c3 | c4 | c5 | c6 | c7 | c8 |
|---|---|---|---|---|---|---|---|---|
| `lw $t0,0($s0)` | IF | ID | EX | MEM | WB | | | |
| `addu $t1,$t0,$t2` | | IF | ID (phát hiện) | ID* | EX (lấy tắt 01) | MEM | WB | |
| `sw $t1,0($s3)` | | | IF | IF* | ID | EX (lấy tắt 10) | MEM | WB |

- Cả ba lệnh xong ở **chu kỳ 8**. Nếu không có xung đột thì ba lệnh cần `3 + 4 = 7` chu kỳ (lệnh đầu mất 5 chu kỳ để đi hết đường ống, mỗi lệnh sau xong muộn hơn một chu kỳ). Mất **một** chu kỳ do load-use, nên 8.
- Đọc bảng: `ID*` nghĩa là lệnh ở lại tầng ID một chu kỳ nữa, `IF*` nghĩa là lệnh kế bị giữ lại ở tầng IF vì tầng ID chưa nhả.

**Phép 2: bốn lệnh RAW liên tiếp.** `$2` do `subu` ghi, ba lệnh sau đều đọc `$2`.

- `and $12,$2,$5`: khi ở EX, `subu` nằm ở EX/MEM. Trùng `rs = $2`, nên `fwd_a = 10` (lấy tắt từ băng chuyền kề).
- `or $13,$6,$2`: khi ở EX, `subu` nằm ở MEM/WB. `$2` là `rt`, nên `fwd_b = 01`.
- `addu $14,$2,$2`: khi ở EX, `subu` đã xong và ghi `$2` ở chu kỳ trước. Regfile của G2 có **bypass** (đọc thấy cả giá trị đang ghi cùng chu kỳ), nên giá trị `$2` đọc từ tầng ID đã đúng: `fwd_a = fwd_b = 00`. Không cần lấy tắt.
- Cả chuỗi **0 chu kỳ chờ**. Đây là bảng T1 ở tài liệu chính sách pipeline.

**Phép 3: `lw` rồi `addiu` không đọc `$t0`.** Không phải chờ. Điều kiện `stall_lu` chỉ xét `rs` và `rt` mà lệnh **thật sự đọc** (`uses_rs`, `uses_rt`). `addiu` đọc `rs` (`$s1`), còn `rt` là thanh ghi **đích** chứ không phải nguồn, nên `uses_rt = 0`. Dù `rt` của `addiu` trùng thanh ghi `lw` ghi thì vẫn không chờ. Bài thử `load_use.s` có chính ca này, số chu kỳ chờ dự kiến là 0.
:::

### Trong chip

:::trong-chip
Mỗi đoạn trích dưới đây có đường dẫn file và số dòng, phía sau giải thích từng dòng sinh ra phần cứng gì. Bắt đầu từ `hazard.v`.

**Hazard, vỏ ngoài (`src/hazard.v`).**

{{trich:src/hazard.v:16-35@module hazard (}}

- **Dòng 16** mở module `hazard`.
- **Dòng 17** `ifid_valid`: lệnh ở tầng ID có hợp lệ không. Bong bóng thì bằng 0.
- **Dòng 18, 19** `ifid_rs`, `ifid_rt`: hai thanh ghi nguồn của lệnh đang ở tầng ID.
- **Dòng 20, 21** `ifid_uses_rs`, `ifid_uses_rt`: lệnh có **thật sự** đọc `rs`, `rt` không. Giá trị đến từ bảng điều khiển.
- **Dòng 22** `idex_mem_read`: lệnh ở EX có phải `lw` không.
- **Dòng 23** `idex_dst`: thanh ghi đích của lệnh ở EX. Là đích **đã chọn** (rd, rt hoặc 31), 0 nghĩa là không ghi.
- **Dòng 24, 25** `idex_rs`, `idex_rt`: hai nguồn của lệnh ở EX, nơi cần lấy tắt.
- **Dòng 26, 27** lệnh ở tầng MEM có ghi thanh ghi không và đích là gì.
- **Dòng 28, 29** như trên cho tầng WB.
- **Dòng 30** `taken`: nhánh hoặc nhảy ở EX đã quyết định nhảy.
- **Dòng 31 đến 34** bốn đầu ra: `stall_lu`, `flush`, `fwd_a`, `fwd_b`. Hai cái đầu là một bit, hai cái sau là mã hai bit chọn nguồn.

**Hazard, load-use và flush.**

{{trich:src/hazard.v:36-41@// Load-use}}

- **Dòng 36 đến 38** chú thích: load-use chỉ xảy ra khi lệnh ở EX là `lw`, và `idex_dst != 0` vì ghi vào `$zero` là vô nghĩa.
- **Dòng 39** `stall_lu` bằng 1 khi cùng lúc: lệnh ở EX là `lw`, đích khác 0, lệnh ở ID hợp lệ, và...
- **Dòng 40** ...(lệnh ID thật sự đọc `rs` **và** `idex_dst` trùng `rs`) **hoặc** (thật sự đọc `rt` **và** `idex_dst` trùng `rt`). Điều kiện `uses_rs`, `uses_rt` là để tránh **chờ oan**, ví dụ `addiu` không đọc `rt`.
- **Dòng 41** `flush = taken`: một dây nối thẳng. Chú ý: tín hiệu này **chỉ được khai báo và nối dây** ở `cpu_pipe.v`, không có dòng nào dùng nó để xóa lệnh. Việc xóa lệnh thật làm bằng `id_ok` ở `cpu_pipe.v:205` (xem phần sau).

**Hazard, bộ chọn lấy tắt.**

{{trich:src/hazard.v:43-54@always @*}}

- **Dòng 43** `always @*`: mạch tổ hợp, không ô nhớ.
- **Dòng 44, 45** chú thích: ưu tiên EX/MEM (mã 10) vì **mới hơn** MEM/WB (mã 01); điều kiện `!= 0` vì `$zero` không được lấy tắt.
- **Dòng 46** toán hạng A mã **10** khi lệnh ở MEM có ghi, đích khác 0 và đích trùng `idex_rs`.
- **Dòng 47** nếu không, mã **01** khi lệnh ở WB có ghi, đích khác 0 và trùng `idex_rs`. Chữ `else if` là chỗ tạo **ưu tiên**: chỉ xét nguồn thứ hai khi nguồn thứ nhất không khớp.
- **Dòng 48** còn lại mã **00**: dùng giá trị đã đọc ở tầng ID.
- **Dòng 51 đến 53** toán hạng B làm y hệt, chỉ so với `idex_rt`.
- Mọi nhánh đều gán `fwd_a`, `fwd_b`, nên đây là bộ chọn chứ không phải ô nhớ.

**Băng chuyền EX/MEM và MEM/WB (`src/cpu_pipe.v`).**

{{trich:src/cpu_pipe.v:71-84@EX/MEM}}

- **Dòng 71, 72** chú thích: băng chuyền EX/MEM mang kết quả ALU (cũng là địa chỉ cho `lw`, `sw`) và dữ liệu cần ghi `exm_st`.
- **Dòng 73** năm cờ một bit của lệnh ở đây: `exm_v` (hợp lệ), `exm_rw` (có ghi thanh ghi), `exm_m2r` (ghi dữ liệu từ bộ nhớ), `exm_mrd` và `exm_mwr` (đọc, ghi bộ nhớ).
- **Dòng 74** bốn thanh ghi 32 bit: kết quả `exm_res`, dữ liệu ghi `exm_st`, địa chỉ lệnh `exm_pc`, mã lệnh `exm_ins` (hai cái sau dùng cho ghi vết khi kiểm).
- **Dòng 75** `exm_dst`: thanh ghi đích, 5 bit.
- **Dòng 76** `exm_cp0`: cờ CP0 đi theo lệnh, dùng cho quy tắc chặn ngắt.
- **Dòng 78 đến 83** băng chuyền MEM/WB: cùng khuôn, thêm `mw_mdata` (dữ liệu đọc từ bộ nhớ) và `mw_lmmio` (đây có phải đọc từ ngoại vi không).
- **Dòng 82, 83** `mw_dst` và `mw_cp0`.

**Cắm bộ phát hiện vào CPU G2.**

{{trich:src/cpu_pipe.v:112-128@hazard + forwarding}}

- **Dòng 112 đến 114** chú thích: `hazard.v` quyết định chờ hay không và lấy toán hạng từ đâu.
- **Dòng 115 đến 119** khai các dây: `stall_lu`, `flush`, `fwd_a`, `fwd_b`, `stall_busy`, `take`, `take_irq`.
- **Dòng 120, 121** hai ô nhớ phục vụ ghi vết và quy tắc ngắt (người giữ ngắt nói kỹ).
- **Dòng 122** `irq_epc`: địa chỉ quay về khi nhận ngắt (bài của người giữ ngắt).
- **Dòng 123 đến 127** gắn `hazard` với các dây thật của đường ống: `ifid_*` từ tầng ID, `idex_*` từ tầng EX, `exm_*` từ tầng MEM, `mw_*` từ tầng WB, và `taken` là `take` (tín hiệu nhánh nhảy thật ở EX).

**Tầng MEM.**

{{trich:src/cpu_pipe.v:184-191@MEM}}

- **Dòng 185** chú thích: địa chỉ `lw`, `sw` nằm ở `exm_res`; 20 bit cao bằng 0 là bộ nhớ dữ liệu, `0xFFFFFFxx` là ngoại vi.
- **Dòng 186** `in_dmem`: 20 bit cao của địa chỉ bằng 0, tức nằm trong bộ nhớ dữ liệu.
- **Dòng 187** `in_mmio`: 24 bit cao toàn 1, tức nằm ở vùng ngoại vi.
- **Dòng 188** `bus_addr`: lấy 6 bit giữa của địa chỉ, ghép hai bit 0 phía dưới (địa chỉ phải chia hết cho 4).
- **Dòng 189** `bus_wdata = exm_st`: dữ liệu ghi ra ngoại vi.
- **Dòng 190, 191** `bus_we`, `bus_re`: ghi hoặc đọc ngoại vi chỉ khi: CPU được phép bước (`cpu_ce`), lệnh hợp lệ, đúng loại lệnh và địa chỉ nằm ở vùng ngoại vi.

**Tầng WB.**

{{trich:src/cpu_pipe.v:193-198@WB}}

- **Dòng 194** `wb_ld`: dữ liệu của `lw`: nếu đã đánh dấu đọc ngoại vi thì lấy `bus_rdata`, ngược lại lấy `mw_mdata`.
- **Dòng 195** `wb`: giá trị ghi về thanh ghi. Là bộ chọn hai đường: lệnh `lw` (`mw_m2r`) lấy `wb_ld`, còn lại lấy `mw_res` (kết quả ALU).
- **Dòng 197** `pc_out`: địa chỉ lệnh đang nạp.
- **Dòng 198** `retire`: lệnh xong khi rời tầng WB, đồng thời CPU được phép bước. Dùng để ghi vết kiểm.

**Quyết định lệnh có đi tiếp.**

{{trich:src/cpu_pipe.v:200-205@quyết định tầng ID}}

- **Dòng 200 đến 201** chú thích: chặn nhận ngắt khi nào.
- **Dòng 202 đến 204** `take_irq`: điều kiện nhận ngắt. Bài của người giữ ngắt. Chỉ cần nhớ nó **cũng** loại trừ khi `stall_lu` đang bằng 1.
- **Dòng 205** `id_ok`: lệnh ở IF/ID được đi sang ID/EX khi: hợp lệ, **không** có nhánh đổi hướng (`!take`), **không** load-use (`!stall_lu`), **không** nhận ngắt. Bằng 0 thì thay bằng **bong bóng**. Đây là chỗ thật sự tạo bong bóng chứ không phải `flush`.

**Chuyển lệnh sang tầng sau.**

{{trich:src/cpu_pipe.v:260-277@MEM/WB ← EX/MEM}}

- **Dòng 260 đến 264** băng chuyền MEM/WB nhận từ EX/MEM **luôn luôn**, kể cả khi EX đang bận. Các cờ, đích, kết quả, địa chỉ, `pc`, mã lệnh, cờ CP0.
- **Dòng 262** `mw_lmmio` ghi nhớ lệnh này đọc ngoại vi hay không, để tầng WB chọn nguồn dữ liệu.
- **Dòng 265** `mw_mdata`: đọc bộ nhớ dữ liệu bằng địa chỉ `exm_res[11:2]` nếu nằm trong bộ nhớ, ngoài ra đọc bằng 0. Đây là chỗ dữ liệu `lw` xuất hiện, tức **cuối tầng MEM**.
- **Dòng 267 đến 270** nếu EX đang bận (`stall_busy`), EX/MEM nhận **bong bóng**: mọi cờ về 0, đích về 0.
- **Dòng 271 đến 275** nếu không bận, EX/MEM nhận lệnh từ ID/EX: kết quả `ex_res`, dữ liệu ghi `opB`. Cờ `exm_v` còn thêm điều kiện `!take_irq`: lệnh bị ngắt hủy thì không đi tiếp.
- **Dòng 277** mở khối "nếu EX không bận" của phần ID/EX và IF/ID (đã gặp ở bài giải mã).

**Lõi G1: bộ nhớ dữ liệu và ghi ngược (`src/cpu_g1.v`).**

{{trich:src/cpu_g1.v:119-130@bộ nhớ dữ liệu}}

- **Dòng 119 đến 121** chú thích: bộ nhớ dữ liệu chốt ở pha B; 20 bit cao bằng 0 là DMEM, 24 bit cao toàn 1 là ngoại vi.
- **Dòng 122** `maddr = alu_y`: địa chỉ lấy thẳng từ ALU.
- **Dòng 123, 124** hai bộ nhận dạng vùng địa chỉ như ở G2.
- **Dòng 125, 126** `bus_addr` và `bus_wdata`; dữ liệu ghi lấy từ `rt_v`.
- **Dòng 127, 128** ghi hoặc đọc ngoại vi chỉ ở **pha B** của G1.
- **Dòng 130** `load_v`: dữ liệu `lw`: `lsel` bằng 01 thì lấy `dmem_q`, bằng 10 thì lấy từ ngoại vi, ngược lại 0.

{{trich:src/cpu_g1.v:132-146@ghi ngược}}

- **Dòng 134 đến 145** `res`: bộ chọn tám đường chọn kết quả ghi về: ALU (mặc định), nhân, `HI`, `LO`, `bcd`, CP0, hoặc `PC+4` cho `jal`.
- **Dòng 146** `wb`: `lw` lấy `load_v`, các lệnh khác lấy `res`.
:::

### Bẫy và thầy hay hỏi

:::bay
**Bẫy 1: "Forwarding giải quyết mọi xung đột dữ liệu."** Sai ở một ca: `lw` rồi dùng ngay. Dữ liệu của `lw` chỉ có ở **cuối tầng MEM**. Lệnh kế đang ở EX và cần giá trị ngay, không dây tắt nào đưa được thứ chưa tồn tại. Phải chờ **một** chu kỳ.
:::

:::bay
**Bẫy 2: "`flush` là chỗ xóa hai lệnh nạp nhầm."** Đọc code kỹ thì không. `hazard.v` có dây `flush = taken` (dòng 41), nhưng ở `cpu_pipe.v` nó chỉ được khai báo và nối dây, rồi nằm trong một dòng chống cảnh báo (dòng 302). Việc làm bong bóng là `id_ok` (dòng 205 và 279) và `ifid_v <= !take` (dòng 294). Nên nếu thầy hỏi "`flush` ở đâu xóa lệnh", trả lời thật: dây này là khái niệm trong tài liệu, việc xóa nằm ở `id_ok`.
:::

:::bay
**Bẫy 3: "Nguồn nào gần EX nhất thì ưu tiên."** Đúng, và đây là lý do ưu tiên **EX/MEM** (mã 10) trước **MEM/WB** (mã 01). Cho `add $1,..; add $1,..; add ..,$1`: cả hai lệnh trước đều ghi `$1`, lệnh dùng `$1` phải lấy của lệnh **gần nhất**. Nếu ưu tiên ngược thì lấy giá trị cũ.
:::

:::bay
**Bẫy 4: "Lấy tắt từ `$zero` cũng được vì giá trị bằng 0."** Sai chiều ngược lại. Lệnh `addu $zero, $t0, $t1` tính ra một số khác 0 ở `exm_res`, nhưng ghi vào `$zero` là vô nghĩa, `$zero` vẫn bằng 0. Nếu cho lấy tắt từ nó thì lệnh sau đọc `$zero` sẽ nhận giá trị sai. Điều kiện `!= 0` ở dòng 46, 47, 51, 52 chặn ca này.
:::

### Sửa tại chỗ và ứng dụng

:::sua-tai-cho
**Cài lỗi rồi xem bài thử nào bắt.** Hai lỗi. Mỗi lần **chép file ra bản nháp rồi sửa bản nháp, không sửa file gốc**. Ở thư mục gốc project:

```bash
source tools/env.sh
mkdir -p work/mut
cp src/hazard.v work/mut/hazard.v
```

**Lỗi 1: cho lấy tắt từ `$zero`.** Trong `work/mut/hazard.v`, dòng 46, xóa phần `&& (exmem_dst != 5'd0)` để dòng chỉ còn `if (exmem_reg_write && (exmem_dst == idex_rs)) fwd_a = 2'b10;`. Dịch và chạy với bản nháp:

```bash
iverilog -g2005 -Wno-timescale -o work/mut/hz.vvp tb/hazard_tb.v work/mut/hazard.v
vvp work/mut/hz.vvp | head -3
```

Kết quả đã chạy (12/11): dòng đầu là `loi vec 3: lu 0/0 flush 0/0 fwdA 10/00 fwdB 00/00`. Cách đọc: mỗi cặp `a/b` là **giá trị của mạch** trước dấu gạch, **giá trị đúng theo mô hình tham chiếu** sau dấu gạch. `fwdA 10/00` nghĩa là mạch chọn lấy tắt 10, nhưng đúng phải là 00 (không lấy tắt). Vì `exmem_dst` bằng 0, chính là ca `$zero`.

**Lỗi 2: đổi ưu tiên, lấy MEM/WB trước EX/MEM.** Chép lại `src/hazard.v` rồi hoán hai vế của khối `if` toán hạng A (dòng 46 và 47) để MEM/WB được xét trước:

```bash
cp src/hazard.v work/mut/hazard.v
# mở work/mut/hazard.v, đổi chỗ dòng 46 và dòng 47 (nhớ đổi "if" và "else if" cho đúng), rồi:
iverilog -g2005 -Wno-timescale -o work/mut/hz.vvp tb/hazard_tb.v work/mut/hazard.v
vvp work/mut/hz.vvp | head -3
```

Kết quả đã chạy: `loi vec 457: lu 0/0 flush 1/1 fwdA 01/10 fwdB 10/10`. Đọc ra: `fwdA 01/10` nghĩa là mạch chọn nguồn 01 (cũ hơn) trong khi đúng phải là 10 (mới hơn). Bài thử có đủ các tổ hợp trùng thanh ghi nên bắt được ngay.

**Thử thêm (không bắt buộc): bỏ `uses_rt`.** Ở dòng 40 đổi `(ifid_uses_rt && (idex_dst == ifid_rt))` thành `(idex_dst == ifid_rt)`. Bài thử báo `loi vec 13: lu 1/0 ...`: mạch báo load-use (`1`) trong khi đúng là không (`0`). Đây là **chờ oan**. Chương trình vẫn chạy ra kết quả đúng, chỉ chậm hơn, nên nếu chỉ chạy chương trình thì **không phát hiện được**. Đó là lý do bài thử đơn vị của `hazard.v` so với mô hình tham chiếu từng tổ hợp.

Xong thì xóa thư mục `work/mut/` hoặc để đó, nó không nằm trong chip.
:::

:::dung-o-dau
**Kỹ năng này dùng ở đâu khác.**

- **Mọi bộ xử lý có đường ống** (điện thoại, máy tính) đều có bộ phát hiện xung đột và lấy tắt. Cách nghĩ "kết quả có ở tầng nào thì kéo dây từ đó" dùng lại được.
- **Tối ưu chương trình ở mức lệnh**: người viết trình biên dịch xếp lệnh sao cho lệnh dùng kết quả của `lw` cách xa một lệnh, để tránh chờ. Hiểu load-use là hiểu vì sao.
- **Dây chuyền xử lý dữ liệu** (đọc, biến đổi, ghi) trong phần mềm cũng có "xung đột" khi bước sau cần kết quả bước trước. Cách xử lý kiểu "chuyền tắt" và "chờ một nhịp" giống nhau.
- **Đọc waveform**: bong bóng hiện ra thành các chu kỳ mà `exm_v` hoặc `idex_v` bằng 0. Biết bong bóng từ đâu ra giúp đọc sóng nhanh.
:::

### Tự kiểm và quay lại bức tranh

:::tu-luan
Cho `idex_rs = 5`, lệnh ở MEM ghi `$5` (`exmem_dst = 5`, `exmem_reg_write = 1`), lệnh ở WB cũng ghi `$5` (`memwb_dst = 5`, `memwb_reg_write = 1`). `fwd_a` bằng bao nhiêu và vì sao? Nếu `exmem_dst = 6` thì sao? Nếu `memwb_dst = 0` thì sao?
---
**Đáp án hoàn chỉnh.** Ba trường hợp, theo thứ tự các dòng 46, 47, 48 của `src/hazard.v`.

- Cả hai cùng ghi `$5`: `fwd_a = 10`. Điều kiện ở dòng 46 đúng (ghi, đích khác 0, trùng `rs`) nên nguồn EX/MEM thắng. Nó mới hơn MEM/WB.
- `exmem_dst = 6`: dòng 46 sai vì đích không trùng. Xét dòng 47: `memwb_dst = 5` trùng, nên `fwd_a = 01`.
- `memwb_dst = 0` (và `exmem_dst` vẫn không trùng): dòng 47 sai vì đích bằng 0. Rơi xuống dòng 48: `fwd_a = 00`. `$zero` không bao giờ được lấy tắt.
:::

:::tu-luan
Chương trình `lw $t0,0($s0)` rồi `beq $t0,$zero,L` (nhánh dùng ngay kết quả `lw`). Nhánh nhảy thật. Có bao nhiêu chu kỳ chờ bong bóng ở nhánh này, và vì sao quyết định nhánh ở EX lại có lợi so với quyết định nhánh ở ID?
---
**Đáp án hoàn chỉnh.** Có **một** chu kỳ chờ do load-use trước khi nhánh vào EX. Nhánh vào EX, lấy `$t0` bằng forwarding 01 rồi quyết định. Khi nhảy thật mất thêm hai chu kỳ để xóa hai lệnh nạp nhầm (đây là phần của người giữ nhánh).

Nếu nhánh quyết định ở ID, nó cần `$t0` ngay ở ID, mà `$t0` chỉ có sau tầng MEM của `lw`. Khi đó phải chờ **hai** chu kỳ. Quyết định ở EX tận dụng được forwarding sẵn có và chỉ cần một chu kỳ chờ. Đây là ca bài mẫu dễ sót.
:::

:::tu-luan
`sw $t0,...` ngay sau `lw $t0,...` có phải chờ không? Trên thực tế MIPS có cách để bỏ chu kỳ chờ đó, nhóm có làm không?
---
**Đáp án hoàn chỉnh.** Có, vẫn chờ **một** chu kỳ, vì `sw` đọc `rt` làm dữ liệu cần cất (`uses_rt = 1`) nên `stall_lu` bằng 1. Sách của Patterson và Hennessy có kiểu forwarding thứ hai từ MEM sang MEM để bỏ chu kỳ này. Nhóm **không làm**, chấp nhận mất một chu kỳ cho mạch đơn giản. Bài thử `load_use.s` có ca này và dự kiến đúng một chu kỳ chờ.
:::

:::tu-luan
Vì sao ở `hazard.v` có dây `flush = taken` mà `cpu_pipe.v` lại không dùng nó để xóa lệnh?
---
**Đáp án hoàn chỉnh.** Dây này tồn tại để khớp với tài liệu: "nhánh nhảy thật thì xóa hai lệnh". Nhưng khi viết đường ống, việc xóa được làm bằng hai chỗ khác: `id_ok` (dòng 205) bằng 0 khi `take` bằng 1 nên lệnh ở ID không sang ID/EX mà thành bong bóng; và `ifid_v <= !take && !take_irq` (dòng 294) nên lệnh vừa nạp bị đánh dấu không hợp lệ. Hai chỗ này dùng thẳng `take` chứ không đi qua `flush`. Dây `flush` chỉ còn nằm trong dòng chống cảnh báo `unused_ok` (dòng 302). Không sai chức năng, chỉ là một dây thừa. Người giữ chặng nên biết để nói thật nếu bị hỏi.
:::

:::tu-luan
Chương trình ở mục Cơ chế mất 8 chu kỳ. Nếu thêm một lệnh thứ tư không liên quan (`addiu $s5,$s5,1`) ở cuối thì tổng là bao nhiêu và vì sao?
---
**Đáp án hoàn chỉnh.** **9** chu kỳ. Lệnh thứ tư nạp ở chu kỳ 5 (sau khi `sw` thoát tầng IF ở chu kỳ 4), tới WB ở chu kỳ 9. Công thức chung: số chu kỳ = số lệnh + 4 + số chu kỳ chờ. Ở đây `4 + 4 + 1 = 9`. Lệnh thêm không tạo thêm xung đột nên không có thêm chu kỳ chờ.
:::

:::mcq id=KT-P2-01
? Ở `src/hazard.v`, dòng 46 xét nguồn EX/MEM trước, dòng 47 mới xét MEM/WB. Nếu hai lệnh trước cùng ghi `$5` và lệnh đang ở EX đọc `$5`, nó phải lấy từ đâu và vì sao?
- [ ] Lấy từ MEM/WB, vì lệnh đó đã đi xa hơn nên giá trị chắc chắn đã ổn định
- [ ] Lấy từ thanh ghi `$5` đọc ở tầng ID, vì lấy tắt chỉ dùng khi có đúng một nguồn
- [x] Lấy từ EX/MEM, vì đó là lệnh **gần nhất** nên giá trị mới hơn
- [ ] Phải chờ một chu kỳ, vì hai nguồn cùng ghi là xung đột không giải quyết được bằng lấy tắt
> Giải thích: khi hai lệnh cùng ghi một thanh ghi, giá trị đúng là của lệnh **sau** (gần EX hơn). Nó đang ở EX/MEM, còn lệnh cũ hơn đang ở MEM/WB. Chữ `else if` ở dòng 47 bảo đảm chỉ xét nguồn cũ khi nguồn mới không khớp.
:::

:::mcq id=KT-P2-02
? Điều kiện `stall_lu` ở `src/hazard.v` dòng 39 có đoạn `(idex_dst != 5'd0)`. Nếu bỏ đoạn này thì lỗi gì xảy ra ở WatchChip?
- [ ] Lệnh `lw` bị coi là không ghi gì nên không bao giờ chờ
- [x] Lệnh `lw $zero, ...` bị chờ oan một chu kỳ, vì `$zero` luôn trùng với toán hạng bằng 0
- [ ] Mọi lệnh đứng sau `lw` đều bị chờ một chu kỳ, kể cả lệnh hoàn toàn không liên quan đến `lw`
- [ ] Lấy tắt từ MEM/WB hỏng, vì hai điều kiện dùng chung một dây
> Giải thích: `idex_dst` bằng 0 nghĩa là lệnh không ghi thanh ghi nào (hoặc ghi vào `$zero`). Nếu bỏ điều kiện, mọi lệnh sau đọc `$zero` đều thấy "trùng" và bị chờ oan. Chương trình vẫn đúng, chỉ chậm, nên khó thấy nếu chỉ nhìn kết quả.
:::

:::mcq id=KT-P2-03
? Đọc `src/cpu_pipe.v:205`: `wire id_ok = ifid_v && !take && !stall_lu && !take_irq;`. Khi `id_ok` bằng 0, điều gì xảy ra với lệnh ở tầng ID?
- [ ] Lệnh bị xóa hẳn khỏi đường ống, PC lùi về địa chỉ trước đó và nạp lại lệnh từ đầu
- [ ] Lệnh vẫn đi tiếp sang EX nhưng cờ `idex_v` bị bỏ qua nên kết quả không được ghi vào thanh ghi
- [x] Thay vào ID/EX là một bong bóng (mọi cờ bằng 0), lệnh không sang EX
- [ ] Cả năm tầng của đường ống đứng yên đúng một chu kỳ để chờ lệnh ở ID
> Giải thích: các dòng 279 đến 286 ghi vào ID/EX các cờ dạng `id_ok && ...` hoặc `id_ok ? ... : 0`, nên `id_ok` bằng 0 ghi toàn số 0 thành **bong bóng**. Đây là chỗ thực sự tạo bong bóng. Lệnh bị giữ hay xóa tùy lý do (load-use giữ, nhánh xóa) và do khối IF/ID xử lý.
:::

:::mcq id=KT-P2-04
? Trong WatchChip (G2), dữ liệu của lệnh `lw` lần đầu xuất hiện ở tín hiệu nào?
- [ ] `exm_res`, vì ALU tính xong ở cuối tầng EX nên dữ liệu đã sẵn sàng ở đó
- [x] `mw_mdata`, được gán ở dòng 265 bằng `dmem[exm_res[11:2]]` ở cuối tầng MEM
- [ ] `wb`, ngay từ đầu tầng MEM, vì dây này nối thẳng với đầu ra của bộ nhớ dữ liệu
- [ ] `idex_b`, ở tầng ID, nơi giá trị `rt` vừa được đọc từ tập thanh ghi
> Giải thích: `exm_res` chỉ là **địa chỉ** của `lw`. Dữ liệu thật đọc từ bộ nhớ nằm trong `mw_mdata`, cập nhật ở dòng 265 khi lệnh từ EX/MEM sang MEM/WB. Do đó chỉ có thể lấy tắt dữ liệu `lw` từ băng chuyền cuối (mã 01), và lệnh sát sau phải chờ.
:::

:::mcq id=KT-P2-05
? Ở `src/cpu_pipe.v` dòng 268 đến 270, khi `stall_busy` bằng 1 thì băng chuyền EX/MEM nhận gì?
- [ ] Giữ nguyên lệnh cũ, để lệnh chia đứng yên trong EX/MEM cho tới khi phép chia xong
- [ ] Nhận lệnh thật từ ID/EX nhưng chỉ ghi dở một phần các cờ điều khiển của nó
- [x] Nhận một bong bóng: `exm_v`, `exm_rw`, `exm_mrd`, `exm_mwr`, `exm_dst` đều về 0
- [ ] Nhận kết quả tạm của phép chia
> Giải thích: lệnh `div` hoặc `bcd` còn đứng ở EX nhiều chu kỳ. Nếu EX/MEM tiếp tục nhận bản sao của nó thì mỗi chu kỳ sẽ ghi một lần. Nên tầng sau EX nhận bong bóng (ghi vào dòng 270), mọi cờ ghi bằng 0.
:::

:::mcq id=KT-P2-06
? Chương trình `lw $t0,0($s0)` rồi `addu $t1,$t0,$t2` chạy ở G2 mất thêm bao nhiêu chu kỳ vì xung đột, và loại lấy tắt nào được dùng sau đó?
- [ ] 0 chu kỳ thêm, lấy tắt mã 10
- [ ] 2 chu kỳ thêm, lấy tắt mã 10
- [x] 1 chu kỳ thêm, lấy tắt mã 01 khi `addu` vào EX
- [ ] 1 chu kỳ thêm, lấy tắt mã 10 khi `addu` vào EX
> Giải thích: sau một chu kỳ chờ, `lw` đã sang MEM/WB nên `addu` ở EX lấy `$t0` bằng nguồn MEM/WB, mã 01 (bảng T2). Mã 10 là EX/MEM, không dùng được vì `lw` đã đi qua tầng đó. Con số một chu kỳ khớp với `load_use` và `hazard_tb`.
:::

:::mcq id=KT-P2-07
? Ở `src/cpu_g1.v` dòng 127 và 128, `bus_we` và `bus_re` có điều kiện `ph_b`. Vì sao ở G2 (`cpu_pipe.v:190`) không có `ph_b`?
- [ ] Vì G2 không có vùng ngoại vi riêng nên mọi lệnh `lw`, `sw` đều đi thẳng vào bộ nhớ dữ liệu
- [x] Vì G1 chia mỗi lệnh thành hai pha và bộ nhớ chỉ chốt ở pha B, còn G2 mỗi tầng một chu kỳ nên chỉ cần `cpu_ce`
- [ ] Vì G2 ghi ngoại vi ngay ở tầng ID, sớm hơn G1 nhiều chu kỳ, nên không cần chờ pha nào
- [ ] Vì `ph_b` chỉ dùng để chọn địa chỉ chứ không để bật ghi, nên G2 có thể bỏ nó đi mà vẫn đúng
> Giải thích: `ph_b` là pha thứ hai trong một lệnh của G1 (bộ nhớ đồng bộ cần hai pha). G2 không có pha, mỗi tầng một chu kỳ, và `cpu_ce` đã là xung "được phép bước". Nên điều kiện ghi ngoại vi khác nhau nhưng ý nghĩa như nhau: đúng một lần cho mỗi lệnh.
:::

:::mcq id=KT-P2-08
? Chọn khẳng định **đúng** về `hazard.v` của WatchChip.
- [ ] Nó có ô nhớ để nhớ lệnh nào đang bị giữ lại
- [ ] Nó tự xóa hai lệnh nạp nhầm khi nhánh nhảy thật bằng dây `flush`
- [x] Nó chỉ gồm mạch tổ hợp: cùng đầu vào thì cùng đầu ra, không nhớ gì
- [ ] Nó quyết định có nhận ngắt hay không
> Giải thích: dòng đầu file ghi "Mọi tổ hợp, không có trạng thái". `flush` chỉ là dây nối `taken`, việc xóa lệnh làm ở `cpu_pipe.v`. Việc nhận ngắt do `take_irq` ở `cpu_pipe.v`, hazard chỉ cho biết `stall_lu` để ngắt không chen vào lúc đang chờ.
:::

### Thầy chỉ vào dòng này

:::thay-hoi
**`src/hazard.v:39-40`**: Điều kiện load-use là gì, vì sao có `uses_rs` và `uses_rt`? **Trả lời:** `stall_lu` bằng 1 khi lệnh ở EX là `lw` ghi vào thanh ghi khác 0, lệnh ở ID hợp lệ, và lệnh ở ID **thật sự đọc** một thanh ghi trùng với đích của `lw`. Cờ `uses_rs`, `uses_rt` để tránh chờ oan: `addiu`, `lw` không đọc `rt`.
:::

:::thay-hoi
**`src/hazard.v:46`**: Vì sao EX/MEM (10) được xét trước MEM/WB (01)? **Trả lời:** Vì EX/MEM chứa kết quả của lệnh **gần nhất**, mới hơn. Nếu cả hai cùng ghi một thanh ghi thì giá trị đúng là của lệnh sau. Chữ `else if` ở dòng 47 bảo đảm chỉ xét MEM/WB khi EX/MEM không khớp.
:::

:::thay-hoi
**`src/hazard.v:41`**: `flush` dùng để làm gì? **Trả lời:** Nói thật: dây này chỉ nối `taken` ra ngoài và ở `cpu_pipe.v` nó không điều khiển gì (chỉ nằm trong dòng chống cảnh báo, dòng 302). Việc xóa hai lệnh nạp nhầm làm bằng `id_ok` (dòng 205) và `ifid_v <= !take` (dòng 294).
:::

:::thay-hoi
**`src/cpu_pipe.v:205`**: Bong bóng sinh ra ở đâu? **Trả lời:** Ở `id_ok`. Bằng 0 khi có nhánh đổi hướng, load-use, hoặc nhận ngắt. Khi đó các cờ của ID/EX (dòng 279 đến 286) nhận số 0, tức bong bóng.
:::

:::thay-hoi
**`src/cpu_pipe.v:268-270`**: Khi `div` đang chạy thì tầng MEM nhận gì? **Trả lời:** Nhận bong bóng. `stall_busy` bằng 1 thì EX/MEM được ghi toàn số 0 ở các cờ và đích, nên không có lệnh nào bị thực hiện hai lần. Băng chuyền MEM/WB vẫn chạy bình thường (dòng 260), để lệnh đã ở phía sau EX tiếp tục xong.
:::

:::thay-hoi
**`src/cpu_pipe.v:195`**: Giá trị ghi về thanh ghi lấy từ đâu? **Trả lời:** `wb` chọn giữa dữ liệu `lw` (`wb_ld`) và kết quả ALU (`mw_res`) theo cờ `mw_m2r`. Với `lw`, `wb_ld` lấy từ ngoại vi nếu địa chỉ ở vùng ngoại vi, ngược lại lấy từ `mw_mdata`.
:::

## P3 · ID, bộ điều khiển và tập thanh ghi

### Bản đồ

:::ban-do
Bài này dành cho người giữ chặng **giải mã lệnh** (tầng ID): biến một số 32 bit thành các "công tắc" điều khiển, và đọc hai thanh ghi nguồn. Nó gồm bốn mảnh:

| Mảnh | File và dòng | Làm gì |
|---|---|---|
| Bộ điều khiển | `src/control.v` (115 dòng) | Nhận lệnh 32 bit, trả ra 16 công tắc cộng một cờ `valid`. Dùng chung cho G1 và G2. |
| Tập thanh ghi | `src/regfile.v` (47 dòng) | 32 thanh ghi, hai cổng đọc, một cổng ghi, `$0` luôn bằng 0. Có tham số `G_BYPASS`. |
| Tầng ID của G2 | `src/cpu_pipe.v` dòng 85–111, 61–70, 278–290 | Cắm bộ điều khiển và tập thanh ghi vào đường ống, chọn thanh ghi đích, mở rộng hằng số, đẩy kết quả sang băng chuyền ID/EX. |
| Giải mã của G1 | `src/cpu_g1.v` dòng 61–86 | Cùng việc ở lõi một-lệnh-một-lần. |

**Cách đọc bảng:** `control.v` đọc từng dòng, vì nó chính là bảng 28 lệnh viết thành mã. `regfile.v` đọc hết. Các đoạn của `cpu_pipe.v` và `cpu_g1.v` đọc đúng khoảng dòng đã nêu.

Bài thử của chặng này: `bash tools/run_unit.sh regfile control`, kết quả mong đợi `PASS regfile_tb {{so:regfile-tb}}` và `PASS control_tb {{so:control-tb}}`. File vector `tb/vectors/control.txt` có 84 dòng lệnh thật và 5 mã lạ, sinh từ bảng trong tài liệu `control-table.md`.
:::

### Câu hỏi mở bài

Con chip chỉ nhìn thấy một dãy 32 bit không có chữ nào. Làm sao nó biết dãy `0x8D0D3B24` nghĩa là "đọc bộ nhớ vào thanh ghi số 13", còn dãy `0x02BA4821` nghĩa là "cộng hai thanh ghi"? Và vì sao `lw` ghi vào trường `rt` còn `addu` ghi vào trường `rd`?

Câu trả lời ngắn, các mục sau chứng minh từng ý:

- Sáu bit đầu (opcode) cho biết **họ** của lệnh. Riêng họ R và họ SPECIAL2 còn phải xem sáu bit cuối (funct) mới biết đúng lệnh nào.
- Bộ điều khiển là một **bảng tra** viết bằng mạch tổ hợp: vào là lệnh, ra là các công tắc. Không có ô nhớ, không có chu kỳ riêng.
- Mỗi lệnh bật **vài** công tắc nó cần, mọi công tắc khác ở mặc định 0. Nhờ thế một mã lạ tự động ra toàn số 0, tức là lệnh rỗng.

### Trực giác

Hình dung bộ điều khiển là **người phát vé ở cửa tàu điện**. Mỗi hành khách (một lệnh) đưa ra thẻ ghi sáu bit đầu. Người phát vé tra bảng rồi bấm một dãy công tắc: "cho ghi thanh ghi", "đích là rd", "cộng", "không đụng bộ nhớ"... Hành khách thuộc họ R thì chưa đủ thông tin, phải xem thêm tem nhỏ ở cuối thẻ (funct).

Còn ba ý cần có.

**Ba khuôn lệnh.** Mọi lệnh là 32 bit cắt theo một trong ba kiểu:

| Kiểu | Cách cắt | Ví dụ trong WatchChip |
|---|---|---|
| R (thanh ghi) | op 6 bit, rs 5, rt 5, rd 5, shamt 5, funct 6 | `addu`, `subu`, `slt`, `sll`, `jr`, `div` |
| I (hằng số) | op 6 bit, rs 5, rt 5, imm 16 | `addiu`, `ori`, `lui`, `lw`, `sw`, `beq` |
| J (nhảy) | op 6 bit, đích 26 | `j`, `jal` |

**Thanh ghi đích nằm ở chỗ khác nhau.** Lệnh kiểu R ghi vào `rd`. Lệnh kiểu I ghi vào `rt` (vì trường `rd` bị hằng số 16 bit chiếm). `jal` ghi vào thanh ghi cố định số 31. Đây là lý do có tín hiệu `dst` hai bit chọn: không ghi, `rd`, `rt`, hoặc 31.

**Hằng số 16 bit phải nới ra 32 bit.** Có ba cách nới: giữ dấu (sao bit cao nhất vào 16 bit trên), thêm 0, hoặc đặt hằng lên nửa cao (lệnh `lui`). Tín hiệu `ext` chọn cách nào.

### Cơ chế theo đường tín hiệu

Theo dõi lệnh `lw` có mã `0x8D0D3B24` đi qua tầng ID của G2.

**1. Cắt trường.** Viết lại 32 bit: `1000 1101 0000 1101 0011 1011 0010 0100`. Sáu bit đầu `100011` là `0x23`, tức `lw`. Năm bit kế `01000` là `rs = 8`. Năm bit kế `01101` là `rt = 13`. Mười sáu bit cuối `0x3B24` là hằng số `imm`. Phần cứng chỉ **đi dây** cắt các bit này ra, không tính gì (`cpu_pipe.v` dòng 86, 87).

**2. Tra bảng.** `control.v` thấy `op = 0x23` và bật: `reg_write = 1`, `dst = 10` (ghi vào `rt`), `alu_src = 1` (toán hạng B là hằng số), `ext = 00` (giữ dấu), `alu_ctl = 0` (cộng, để tính địa chỉ), `mem_read = 1`, `mem_to_reg = 1`, `uses_rs = 1`, `uses_rt = 0`. Mọi công tắc khác bằng 0. Dòng khớp trong `control.txt`: `8D0D3B24 1 2 1 0 0 0 1 0 1 0 0 0 0 0 1 0`.

**3. Chọn đích.** `d_dst` (dòng 102 đến 105): lệnh hợp lệ và `dst_sel = 10` nên đích là `f_rt = 13`. Nếu tầng ID đang chứa **bong bóng** (`ifid_v = 0`) thì đích bị ép về 0, nghĩa là không ghi.

**4. Nới hằng số.** `imm_x` (dòng 98, 99): `ext = 00` nên sao bit 15 của `0x3B24` (bằng 0) ra 16 bit trên, được `0x00003B24`.

**5. Đọc thanh ghi.** `regfile` trả `rs_v` (thanh ghi 8) và `rt_v` (thanh ghi 13) ngay trong chu kỳ, không cần cạnh clock.

**6. Sang tầng sau.** Ở cạnh clock kế tiếp, nếu `id_ok` bằng 1 thì tất cả được chép vào băng chuyền ID/EX (dòng 279 đến 289): các công tắc, hai giá trị `rs_v`, `rt_v`, hằng số `imm_x`, số thanh ghi `rs`, `rt`, đích `idex_dst`.

**7. Ở lõi G1** làm cùng các bước nhưng không có băng chuyền: `control` nhìn thẳng `instr` (dòng 66 đến 70), thanh ghi đích tính ở dòng 81, và `regfile` được cấu hình **không bypass** (dòng 84).

### Bảng chu kỳ hoặc tính tay

:::suy-dan
**Đề bài.** Ba phép tính tay quanh chặng này.

1. Giải mã `0x02BA4821` (mã thật của một lệnh `addu`): op, rs, rt, rd, funct, và các công tắc chính.
2. Hằng số `0xFFFF` đi qua `addiu` (giữ dấu) và `ori` (thêm 0) cho hai giá trị 32 bit khác nhau. Là những số nào?
3. Lệnh `i` ghi thanh ghi `$2`. Lệnh `i+j` (không có chu kỳ chờ) đọc `$2`. Với `j = 1, 2, 3, 4`, lệnh `i+j` lấy giá trị từ đâu?
---
**Phép 1: giải mã `0x02BA4821`.** Viết nhị phân: `0000 0010 1011 1010 0100 1000 0010 0001`.

- Sáu bit đầu `000000`: họ R, phải xem funct.
- `rs = 10101 = 21`, `rt = 11010 = 26`, `rd = 01001 = 9`, `shamt = 00000`.
- `funct = 100001 = 0x21`, tra dòng 68 của `control.v`: `addu`.
- Công tắc: `reg_write = 1`, `dst = 01` (ghi vào `rd = 9`), `alu_src = 0` (toán hạng B là thanh ghi `rt`), `alu_ctl = 0` (cộng), `res_sel = 0` (lấy từ ALU), `uses_rs = 1`, `uses_rt = 1`.
- Khớp với dòng `02BA4821 1 1 0 0 0 0 0 0 0 0 0 0 0 0 1 1` trong `tb/vectors/control.txt`.

**Phép 2: nới `0xFFFF`.**

- `addiu` có `ext = 00` (giữ dấu): bit 15 bằng 1 nên 16 bit trên toàn 1, được `0xFFFFFFFF`, tức số **âm một**.
- `ori` có `ext = 01` (thêm 0): được `0x0000FFFF`, tức **65535**.
- Cùng một mã hằng số mà hai lệnh nhìn ra hai số khác nhau. Vì vậy tín hiệu `ext` là của **từng lệnh**, không phải của hằng số.

**Phép 3: lệnh sau đọc `$2` nằm cách `j` lệnh.** Lệnh `i` đi qua IF ở chu kỳ 1, ID chu kỳ 2, EX chu kỳ 3, MEM chu kỳ 4, WB chu kỳ 5. Lệnh `i+j` vào ID ở chu kỳ `2 + j` và vào EX ở chu kỳ `3 + j`.

| j | Lệnh `i` đang ở đâu khi lệnh `i+j` cần dữ liệu | Nguồn |
|---|---|---|
| 1 | `i+1` vào EX ở chu kỳ 4, lệnh `i` đang ở MEM (EX/MEM) | lấy tắt mã **10** |
| 2 | `i+2` vào EX ở chu kỳ 5, lệnh `i` đang ở WB (MEM/WB) | lấy tắt mã **01** |
| 3 | `i+3` đọc thanh ghi ở ID chu kỳ 5, đúng lúc lệnh `i` đang ghi | **bypass trong regfile**, `rd1` lấy thẳng `wd` |
| 4 | `i+4` đọc ở ID chu kỳ 6, lệnh `i` đã ghi xong ở cuối chu kỳ 5 | đọc thanh ghi **bình thường** |

Đây là ba cơ chế nối tiếp nhau, mỗi cái lo một khoảng cách. Bảng khớp với các ca T1 trong tài liệu chính sách pipeline: `and` (j = 1) mã 10, `or` (j = 2) mã 01, `addu` (j = 3) nhờ bypass.
:::

### Trong chip

:::trong-chip
Mỗi đoạn trích dưới đây có đường dẫn file và số dòng, phía sau giải thích từng dòng sinh ra phần cứng gì.

**Bộ điều khiển, vỏ ngoài (`src/control.v`).**

{{trich:src/control.v:12-33@module control #(}}

- **Dòng 12 đến 14** mở module, có tham số `G_BCD_COMB` (bản `bcd` tổ hợp hay tuần tự).
- **Dòng 15** `instr`: lệnh 32 bit, là **đầu vào duy nhất**.
- **Dòng 16** `reg_write`: lệnh có ghi vào thanh ghi không.
- **Dòng 17** `dst`: hai bit chọn thanh ghi đích: 00 không ghi, 01 `rd`, 10 `rt`, 11 thanh ghi 31.
- **Dòng 18, 19** `alu_src` (toán hạng B là hằng số hay thanh ghi) và `ext` (cách nới hằng số).
- **Dòng 20, 21** `alu_ctl` (4 bit, phép của ALU) và `res_sel` (3 bit, kết quả lấy từ ALU, nhân, HI, LO, bcd, CP0, hay PC+4).
- **Dòng 22 đến 24** ba cờ bộ nhớ: đọc, ghi, và "kết quả lấy từ bộ nhớ".
- **Dòng 25 đến 29** nhánh, nhảy, nhảy theo thanh ghi, lệnh nhiều chu kỳ, và thao tác CP0.
- **Dòng 30, 31** `uses_rs`, `uses_rt`: lệnh **thật sự đọc** rs, rt. Bộ phát hiện xung đột dùng hai cờ này để khỏi chờ oan.
- **Dòng 32** `valid`: 0 nghĩa là lệnh lạ.
- Tất cả đầu ra khai `reg`, nhưng nhờ `always @*` chúng là **mạch tổ hợp**.

**Bộ điều khiển, hằng và trường lệnh.**

{{trich:src/control.v:34-43@localparam D_NONE}}

- **Dòng 34** bốn giá trị tên cho `dst`.
- **Dòng 35** ba cách nới hằng: `E_SE` giữ dấu, `E_ZE` thêm 0, `E_LUI` đặt lên 16 bit cao.
- **Dòng 36, 37** tám phép của ALU: `A_ADD` đến `A_SRA` (mã 0 đến 7).
- **Dòng 38, 39** bảy nguồn kết quả `R_ALU` đến `R_PC4` (mã 0 đến 6).
- **Dòng 41 đến 43** ba dây cắt từ lệnh: `op` là 6 bit cao, `rs` là bit 25 đến 21, `funct` là 6 bit thấp. Chỉ là **đi dây**, không có cổng logic.

**Hai khuôn dùng lại.**

{{trich:src/control.v:45-58@ghi R-type ALU}}

- **Dòng 45 đến 51** `r_alu(ctl, u_rs)`: khuôn cho lệnh kiểu R tính toán. Bật `valid`, `reg_write`, `dst = rd`, đặt `alu_ctl`, `res_sel = ALU`, `uses_rt = 1`, còn `uses_rs` theo tham số.
- **Dòng 52 đến 58** `i_alu(ctl, e, u_rs)`: khuôn cho kiểu I tính toán. Bật `dst = rt`, `alu_src = 1`, chọn cách nới `e`.
- Hai khuôn tồn tại để không viết lặp mười mấy lần; chúng chỉ là cách viết gọn, phần cứng vẫn là một bảng phẳng.

**Giá trị mặc định rồi mới chọn.**

{{trich:src/control.v:60-66@always @* begin}}

- **Dòng 60** `always @*`: mạch tổ hợp, đầu ra đổi ngay khi `instr` đổi.
- **Dòng 63 đến 65** đặt **mọi** đầu ra về mặc định "không làm gì": không ghi, đích 00, nới dấu, cộng, lấy từ ALU, không đụng bộ nhớ, không nhảy.
- **Dòng 66** `case (op)`: rẽ theo sáu bit đầu.
- Hệ quả quan trọng: nhánh không khớp ở đâu thì tất cả vẫn là mặc định. Mã lạ ra **toàn số 0 và `valid = 0`** mà không cần viết thêm dòng nào.

**Họ R: xem funct.**

{{trich:src/control.v:67-81@6'h00: case (funct)}}

- **Dòng 67** `op = 0` là họ R, rẽ tiếp theo `funct`.
- **Dòng 68 đến 73** sáu lệnh ALU `addu, subu, and, or, xor, slt`: gọi `r_alu` với phép tương ứng và `uses_rs = 1`.
- **Dòng 74, 75** `sll` và `sra`: gọi `r_alu` với `uses_rs = 0`. Lệnh dịch lấy giá trị cần dịch từ `rt` và số bit từ trường `shamt`, **không đọc `rs`**.
- **Dòng 76** `jr`: chỉ bật `valid`, `jump_reg` và `uses_rs`.
- **Dòng 77** `div`: `multi = 01`, đọc cả `rs` và `rt`, **không** ghi thanh ghi (kết quả vào HI, LO).
- **Dòng 78, 79** `mfhi`, `mflo`: ghi vào `rd`, kết quả lấy từ HI hoặc LO (`res_sel`), không đọc rs, rt.
- **Dòng 80** `default: ;` funct lạ không bật gì.

**Họ I và J.**

{{trich:src/control.v:82-95@6'h09: i_alu}}

- **Dòng 82 đến 85** `addiu, slti` nới dấu; `andi, ori` nới bằng 0. Đó là lý do hai nhóm có `ext` khác nhau.
- **Dòng 86** `lui`: `i_alu(A_OR, E_LUI, 0)`: ALU làm `rs_v OR (imm << 16)`. Vì trường `rs` của `lui` bằng 0 nên `rs_v = 0`, kết quả là `imm << 16`.
- **Dòng 87** `lw`: lấy khuôn `i_alu(A_ADD, E_SE, 1)` (tính địa chỉ `rs + imm`), rồi bật thêm `mem_read` và `mem_to_reg`.
- **Dòng 88 đến 91** `sw`: **không** dùng khuôn vì không ghi thanh ghi. Bật `alu_src`, nới dấu, cộng, `mem_write`, đọc cả rs và rt (rt là dữ liệu cần cất).
- **Dòng 92, 93** `beq`, `bne`: chỉ bật `branch` 01 hoặc 10 và đọc cả rs, rt. Việc so sánh làm ở EX.
- **Dòng 94** `j`: chỉ bật `jump`.
- **Dòng 95** `jal`: bật `jump`, ghi vào thanh ghi 31, kết quả là `PC + 4` (`res_sel = 6`).

**SPECIAL2 và COP0.**

{{trich:src/control.v:96-114@6'h1C: case}}

- **Dòng 96 đến 102** họ SPECIAL2 (`op = 0x1C`), rẽ theo funct: `mul` (funct 0x02) lấy kết quả từ bộ nhân; `bcd` (funct 0x10) lấy từ khối bcd.
- **Dòng 100** `multi = (G_BCD_COMB != 0) ? 00 : 10`: bản tuần tự cần chờ nhiều chu kỳ (`multi = 10`), bản tổ hợp thì không (`multi = 00`).
- **Dòng 103 đến 111** họ COP0 (`op = 0x10`) phân tiếp bằng trường `rs` và các bit thấp: `mfc0` (rs = 0), `mtc0` (rs = 4), `eret` là đúng một mã `0x42000018`.
- **Dòng 104, 106** điều kiện `instr[10:0] == 0`: các bit thấp phải bằng 0, nếu không thì **không** nhận là `mfc0`/`mtc0`.
- **Dòng 107** `mtc0` chỉ đọc `rt` (`uses_rt = 1`), không đọc rs.
- **Dòng 112, 113** `default` và `endcase` đóng bảng.

**Tập thanh ghi, vỏ ngoài và bộ nhớ (`src/regfile.v`).**

{{trich:src/regfile.v:12-26@module regfile #(}}

- **Dòng 12 đến 14** tham số `G_BYPASS`: 1 cho G2, 0 cho G1.
- **Dòng 15, 16** `clk`, `rst`.
- **Dòng 17 đến 19** cổng ghi: `we` (cho phép), `wa` (số ngăn), `wd` (giá trị).
- **Dòng 20 đến 23** hai cổng đọc: số ngăn `ra1`, `ra2` vào, giá trị `rd1`, `rd2` ra.
- **Dòng 25** `reg [31:0] r [0:31]`: **32 ngăn kéo** mỗi ngăn 32 bit. Đây là 1 024 bit nhớ thật.
- **Dòng 26** biến đếm `i` cho vòng lặp reset, chỉ dùng khi mô phỏng và tổng hợp, không thành mạch riêng.

**Ghi sườn lên.**

{{trich:src/regfile.v:28-36@always @(posedge clk)}}

- **Dòng 28** `posedge clk`: ghi chỉ xảy ra ở **cạnh lên** của clock.
- **Dòng 29 đến 32** nếu `rst`: xóa cả 32 ngăn về 0.
- **Dòng 33, 34** nếu `we` và `wa != 0`: ghi `wd` vào ngăn `wa`. Điều kiện `wa != 0` chặn ghi vào `$zero`.

**Bypass và đọc.**

{{trich:src/regfile.v:38-46@// Bypass}}

- **Dòng 38 đến 40** chú thích: không bypass thì lệnh sau đọc phải giá trị **cũ**, vì ghi chỉ có hiệu lực ở cạnh clock kế tiếp.
- **Dòng 41, 42** `byp1`, `byp2`: bằng 1 khi cho phép bypass, đang ghi (`we`) và số ngăn ghi trùng số ngăn đọc.
- **Dòng 45, 46** đầu ra: ngăn 0 luôn ra 0; nếu không thì bypass thì ra thẳng `wd`; nếu không nữa thì ra `r[ra]`. Đây là bộ chọn hai tầng **tổ hợp**, không cần chờ clock.

**Tầng ID của G2: băng chuyền.**

{{trich:src/cpu_pipe.v:61-70@ID/EX}}

- **Dòng 61, 62** chú thích: băng chuyền ID/EX mang các công tắc và hai toán hạng đã đọc.
- **Dòng 63** tám cờ một bit: hợp lệ, ghi thanh ghi, từ bộ nhớ, đọc và ghi bộ nhớ, nguồn B, nhảy, nhảy theo thanh ghi.
- **Dòng 64 đến 66** `idex_actl` (4 bit), `idex_rsel` (3 bit), và ba mã hai bit (`idex_br`, `idex_multi`, `idex_cp0`).
- **Dòng 67** sáu giá trị 32 bit: `idex_pc`, `idex_pc4`, `idex_ins`, `idex_a`, `idex_b`, `idex_imm`.
- **Dòng 68** năm số thanh ghi 5 bit, gồm `idex_rs`, `idex_rt`, `idex_dst`. Hazard dùng ba cái này.
- **Dòng 69** `idex_j`: 26 bit đích nhảy.

**Tầng ID của G2: giải mã và đọc.**

{{trich:src/cpu_pipe.v:85-111@ID: giải mã + regfile}}

- **Dòng 86, 87** cắt trường `f_rs, f_rt, f_rd, f_sh` và `imm16` từ `ifid_ins`.
- **Dòng 89 đến 92** khai các dây công tắc.
- **Dòng 93 đến 97** gắn `control` với `ifid_ins`.
- **Dòng 98, 99** `imm_x`: bộ chọn ba đường: `ext = 01` thêm 0, `ext = 10` đặt lên 16 bit cao, còn lại nới dấu.
- **Dòng 102 đến 105** `d_dst`: nếu tầng ID rỗng thì 0; `dst_sel = 01` lấy `rd`; `10` lấy `rt`; `11` lấy 31; còn lại 0.
- **Dòng 107** các dây `rs_v`, `rt_v`, và `wb` (giá trị ghi về, đến từ tầng WB).
- **Dòng 108** `we_rf = cpu_ce && mw_v && mw_rw`: ghi thanh ghi khi CPU được bước, lệnh ở WB hợp lệ và có ghi.
- **Dòng 109, 110** gắn `regfile` với `G_BYPASS = 1`: cổng ghi dùng `mw_dst` và `wb` của **lệnh đang ở WB**, cổng đọc dùng `f_rs`, `f_rt` của **lệnh đang ở ID**. Hai lệnh khác nhau, nên cần bypass.

**Tầng ID của G2: đẩy sang EX.**

{{trich:src/cpu_pipe.v:278-290@ID/EX ← ID}}

- **Dòng 279** `idex_v <= id_ok`: lệnh có thật hay bong bóng.
- **Dòng 280 đến 286** từng cờ được **nhân với `id_ok`**: `idex_rw <= id_ok && reg_write`. Khi `id_ok = 0`, mọi cờ ghi bằng 0, tạo bong bóng. Các mã nhiều bit dùng `id_ok ? x : 0`.
- **Dòng 287** `idex_pc`, `idex_pc4`, `idex_ins` chép từ IF/ID.
- **Dòng 288** `idex_a <= rs_v`, `idex_b <= rt_v`, `idex_imm <= imm_x`, `idex_sh <= f_sh`: các giá trị đã đọc và nới.
- **Dòng 289** số thanh ghi `rs, rt, rd` và 26 bit đích nhảy.

**Giải mã của G1.**

{{trich:src/cpu_g1.v:61-86@giải mã}}

- **Dòng 62 đến 70** khai dây và gắn `control` với `instr` (thanh ghi đầu ra của bộ nhớ lệnh).
- **Dòng 73, 74** cắt trường.
- **Dòng 76, 77** `imm_x` giống G2.
- **Dòng 81** `wa`: thanh ghi đích chọn theo `dst`, **không** kiểm bong bóng vì G1 không có.
- **Dòng 82, 83** `rf_we = ph_a && reg_write && !stall`: ghi ở **pha A**, và không ghi khi lệnh nhiều chu kỳ chưa xong.
- **Dòng 84, 85** `regfile #(.G_BYPASS(0))`: **không bypass**. Lý do ghi ngay ở đầu `regfile.v` (dòng 5): cổng ghi là của chính lệnh đang đọc, bypass sẽ tạo vòng tổ hợp.
:::

### Bẫy và thầy hay hỏi

:::bay
**Bẫy 1: "Thanh ghi đích luôn là `rd`."** Sai. Chỉ lệnh kiểu R ghi vào `rd`. Lệnh kiểu I (`addiu`, `ori`, `lui`, `lw`, `mfc0`) ghi vào `rt`, vì trường `rd` bị hằng số chiếm. `jal` ghi vào thanh ghi 31. Tín hiệu `dst` hai bit tồn tại đúng để chọn giữa ba nơi này.
:::

:::bay
**Bẫy 2: "Mọi hằng số 16 bit đều nới dấu."** Sai. `andi` và `ori` nới bằng 0, `lui` đặt hằng lên nửa cao. Hằng `0xFFFF` qua `addiu` thành `0xFFFFFFFF` (âm một) nhưng qua `ori` thành `0x0000FFFF` (65535). Nếu `ori` nới dấu thì `ori $t0,$zero,0xFFFF` ra sai: bài thử có ca này và báo lỗi.
:::

:::bay
**Bẫy 3: "Điều kiện `wa != 0` là thứ duy nhất giữ `$zero` bằng 0."** Sai, và đây là chỗ nhiều người trả lời sai. Dòng 45 và 46 đã ép đọc ngăn 0 ra 0. Nếu bỏ `wa != 0` ở dòng 33 thì ngăn `r[0]` bị ghi thật, nhưng **không ai đọc được** giá trị đó. Bài thử `regfile_tb` vẫn PASS (thí nghiệm ở mục sau). Hai lớp phòng thủ chồng nhau, bỏ một lớp thì lớp kia che lỗi.
:::

:::bay
**Bẫy 4: "Gặp lệnh lạ thì CPU dừng."** Sai. Lệnh lạ cho toàn số 0 và `valid = 0`, CPU coi nó là lệnh rỗng và chạy tiếp. Cờ `valid` chỉ để mô phỏng in dòng cảnh báo (`cpu_g1.v:243`, `cpu_pipe.v:320`). Trên chip thật không có dấu hiệu gì.
:::

### Sửa tại chỗ và ứng dụng

:::sua-tai-cho
**Cài lỗi rồi xem bài thử nào bắt.** Hai lỗi, mỗi lần **chép file ra bản nháp rồi sửa bản nháp, không sửa file gốc**. Ở thư mục gốc project:

```bash
source tools/env.sh
mkdir -p work/mut
cp src/control.v work/mut/control.v
```

**Lỗi 1: `lw` quên bật `mem_to_reg`.** Trong `work/mut/control.v`, dòng 87, xóa phần ` mem_to_reg = 1;` để dòng thành `6'h23: begin i_alu(A_ADD, E_SE, 1); mem_read = 1; end`. Dịch và chạy với bản nháp:

```bash
iverilog -g2005 -Wno-timescale -o work/mut/c.vvp tb/control_tb.v work/mut/control.v
vvp work/mut/c.vvp | head -3
```

Kết quả đã chạy (12/11): dòng đầu là `loi ban tuan tu vs control.txt: instr=8d0d3b24 y0=3401002 y1=3401002 v=11`. Cách đọc: `instr=8d0d3b24` là đúng lệnh `lw` đã giải mã ở mục trên, `y0` là 28 bit công tắc mạch ra, và nó **khác** dòng `control.txt`. Hậu quả nếu lọt vào chip: `lw` ghi **địa chỉ** vào thanh ghi thay vì dữ liệu.

**Lỗi 2: `ori` nới dấu thay vì thêm 0.** Chép lại file gốc, rồi ở dòng 85 đổi `E_ZE` thành `E_SE` (dòng thành `6'h0D: i_alu(A_OR,  E_SE,  1);`):

```bash
cp src/control.v work/mut/control.v
# sửa dòng 85, rồi:
iverilog -g2005 -Wno-timescale -o work/mut/c.vvp tb/control_tb.v work/mut/control.v
vvp work/mut/c.vvp | head -3
```

Kết quả đã chạy: `loi ban tuan tu vs control.txt: instr=36e20b38 y0=3430002 ...`. Mã `36e20b38` là `ori` thật trong file vector. Lỗi này **chỉ lộ ra khi hằng số có bit 15 bằng 1**, tức là chương trình dùng `ori` với hằng lớn; với hằng nhỏ chương trình vẫn chạy đúng. Bài thử so từng công tắc với bảng nên bắt ngay.

**Thí nghiệm ở `regfile.v`: bỏ cổng đọc `$0`.** Chép `src/regfile.v` ra bản nháp, ở dòng 45 xóa phần `(ra1 == 5'd0) ? 32'd0 : ` để dòng thành `assign rd1 = (byp1 ? wd : r[ra1]);`:

```bash
cp src/regfile.v work/mut/regfile.v
iverilog -g2005 -Wno-timescale -o work/mut/r.vvp tb/regfile_tb.v work/mut/regfile.v
vvp work/mut/r.vvp | head -3
```

Kết quả đã chạy: dòng `loi bypass=1: we=1 wa=0 wd=ffffffff ra1=0 ra2=0 byp=ffffffff 00000000 ...` rồi `FAIL regfile_tb 2 loi / 2040 kiem tra`. Đọc ra: ghi `0xFFFFFFFF` vào ngăn 0 (`we=1 wa=0`) rồi đọc ngăn 0 thì bypass trả `ffffffff` thay vì 0.

**Thử thêm: "đột biến sống sót".** Ở dòng 33 của `regfile.v` xóa ` && wa != 5'd0`. Chạy lại bài thử: kết quả là **`PASS regfile_tb 2040`**, bài thử **không bắt được**. Giải thích ở Bẫy 3: cổng đọc ở dòng 45 đã che. Điều này không có nghĩa dòng 33 vô dụng (nó giữ cho `r[0]` sạch nếu sau này ai đó đọc ngăn 0 theo cách khác), nhưng nó cho thấy **bài thử không phân biệt được hai thiết kế** và cho thấy phải nói đúng "dòng 33 và dòng 45 là hai lớp phòng thủ".

Xong thì xóa thư mục `work/mut/` hoặc để đó, nó không nằm trong chip.
:::

:::dung-o-dau
**Kỹ năng này dùng ở đâu khác.**

- **Mọi bộ xử lý** (điện thoại, máy tính) có một bộ giải mã lệnh làm đúng việc này, chỉ có bảng lớn hơn rất nhiều. Cách nghĩ "bảng tra bằng mạch tổ hợp" dùng lại được.
- **Phân tích giao thức mạng**: một gói tin có phần đầu với các trường cố định, mỗi trường quyết định cách đọc phần sau. Đọc bit theo trường là cùng kỹ năng với cắt `op/rs/rt/imm`.
- **Máy trạng thái và ngôn ngữ mô tả phần cứng**: viết "đặt mặc định rồi chỉ ghi đè cái cần" (dòng 63 đến 65) là mẫu chuẩn để tránh chốt ngầm (latch) và để mạch không bao giờ có đầu ra chưa xác định.
- **Kiểm thử đột biến**: thí nghiệm bỏ `wa != 0` cho thấy bài thử có thể "xanh" mà mạch vẫn có lỗi che. Biết cài lỗi để đo chất lượng bài thử áp dụng cho mọi dự án.
:::

### Tự kiểm và quay lại bức tranh

:::tu-luan
Mã `0xAEF87269` là lệnh `sw`. Cắt các trường (op, rs, rt, imm) và nói bộ điều khiển bật những công tắc nào. Vì sao `sw` có `uses_rt = 1` còn `lw` có `uses_rt = 0`?
---
**Đáp án hoàn chỉnh.** Nhị phân `1010 1110 1111 1000 0111 0010 0110 1001`: `op = 101011 = 0x2B` (`sw`), `rs = 10111 = 23`, `rt = 11000 = 24`, `imm = 0x7269`.

Công tắc (dòng `AEF87269 0 0 1 0 0 0 0 1 0 0 0 0 0 0 1 1` của `control.txt`): `reg_write = 0` (không ghi thanh ghi), `dst = 00`, `alu_src = 1` (B là hằng số), `ext = 00` (nới dấu), `alu_ctl = 0` (cộng, để tính địa chỉ `rs + imm`), `mem_write = 1`, `uses_rs = 1`, `uses_rt = 1`.

`sw` đọc `rt` vì `rt` là **dữ liệu cần cất** vào bộ nhớ. `lw` thì `rt` là **thanh ghi đích**, không phải nguồn, nên `uses_rt = 0`. Điều này ảnh hưởng đến hazard: `lw $t0,..` rồi `addiu` không đọc `$t0` thì không chờ; `lw $t0,..` rồi `sw $t0,..` thì chờ một chu kỳ vì `sw` thật sự đọc `rt`.
:::

:::tu-luan
Vì sao `regfile` ở lõi G1 phải đặt `G_BYPASS = 0` còn ở G2 đặt `G_BYPASS = 1`?
---
**Đáp án hoàn chỉnh.** Ở G2, cổng ghi là của lệnh **cũ** đang ở tầng WB, cổng đọc là của lệnh **mới** đang ở tầng ID. Hai lệnh khác nhau nên bypass chỉ là chuyền giá trị `wd` sang cổng đọc, không có vòng. Ở G1 chỉ có **một** lệnh: cổng ghi (`wd = wb`) phụ thuộc kết quả ALU, ALU phụ thuộc giá trị đọc (`rs_v`), mà giá trị đọc nếu có bypass lại phụ thuộc `wd`. Đó là **vòng tổ hợp**: tín hiệu đi vòng không qua ô nhớ nào, mạch không ổn định. Nên G1 bắt buộc tắt bypass và ghi ở pha A, đọc ở pha B. Đây là chú thích dòng 4 và 5 của `regfile.v`.
:::

:::tu-luan
Giải mã `0x408D3800` (mã thật của một lệnh `mtc0`). Cắt trường, nói lệnh bật công tắc nào và vì sao có điều kiện `instr[10:0] == 11'd0` ở dòng 106 của `control.v`.
---
**Đáp án hoàn chỉnh.** `0x408D3800` là `0100 0000 1000 1101 0011 1000 0000 0000`: `op = 010000 = 0x10` (họ COP0), `rs = 00100 = 4` (chọn `mtc0`), `rt = 01101 = 13`, `rd = 00111 = 7`, 11 bit thấp bằng 0.

Công tắc (dòng `408D3800 0 0 0 0 0 0 0 0 0 0 0 0 0 1 0 1`): `reg_write = 0`, `cp0_op = 01`, `uses_rs = 0`, `uses_rt = 1` (đọc `rt` làm giá trị ghi vào CP0).

Điều kiện 11 bit thấp bằng 0 là **kiểm tra mã nghiêm ngặt**: MIPS chuẩn quy định các bit này bằng 0 với `mtc0`. Nếu không kiểm thì một mã COP0 lạ có `rs = 4` nhưng bit thấp khác 0 vẫn bị nhận nhầm thành `mtc0`. Có kiểm thì mã đó ra toàn số 0 và `valid = 0`. Bảng vector có 5 mã lạ để chứng minh.
:::

:::tu-luan
Lệnh `lui $t0, 0xA242` (mã `0x3C08A242`) cho kết quả gì, ALU làm phép gì, và bộ điều khiển dựa vào đâu mà `uses_rs = 0` vẫn đúng?
---
**Đáp án hoàn chỉnh.** Kết quả `0xA2420000`. Bộ điều khiển chọn `ext = 10` (LUI): `imm_x = {imm16, 16'd0} = 0xA2420000`, `alu_src = 1`, và `alu_ctl = OR`. ALU tính `rs_v OR imm_x`. Với `lui`, trường `rs` trong mã lệnh **bằng 0**, nên `rs_v = $0 = 0` và kết quả là `imm_x`. Cờ `uses_rs = 0` đúng vì lệnh không cần giá trị `rs` thật; nó dựa vào quy ước "trường `rs` của `lui` bằng 0" (chú thích dòng 86). Nếu ai đó viết `lui` với `rs` khác 0 theo kiểu hợp lệ về dạng thì kết quả sẽ bị OR thêm giá trị `rs`, nên bộ dịch asm của nhóm phải luôn đặt `rs = 0`.
:::

:::tu-luan
Đếm tổng số lệnh trong `control.v` theo từng họ và cho biết họ nào cần xem `funct`.
---
**Đáp án hoàn chỉnh.** Tổng **28** lệnh. Họ R (`op = 0`, xem `funct`): `addu, subu, and, or, xor, slt, sll, sra, jr, div, mfhi, mflo` là 12. Họ I: `addiu, slti, andi, ori, lui, lw, sw, beq, bne` là 9. Họ J: `j, jal` là 2. Họ SPECIAL2 (`op = 0x1C`, xem `funct`): `mul, bcd` là 2. Họ COP0 (`op = 0x10`, phân bằng `rs` và bit thấp): `mfc0, mtc0, eret` là 3. Cộng lại `12 + 9 + 2 + 2 + 3 = 28`. Họ R và SPECIAL2 cần xem `funct`. Họ COP0 phân tiếp bằng trường `rs` chứ không bằng `funct`.
:::

:::mcq id=KT-P3-01
? Ở WatchChip, lõi G1 gắn `regfile #(.G_BYPASS(0))` (`cpu_g1.v:84`) còn lõi G2 gắn `G_BYPASS(1)`. Lý do chính là gì?
- [ ] G1 chạy chậm hơn nên không cần bypass, còn G2 chạy nhanh cần thêm mạch để theo kịp
- [x] Ở G1 cổng ghi là của chính lệnh đang đọc, bypass sẽ tạo vòng tổ hợp
- [ ] G1 dùng bộ nhớ đồng bộ nên thanh ghi cũng phải đồng bộ và không đọc tổ hợp được
- [ ] G2 có nhiều thanh ghi hơn G1 nên cần cơ chế riêng để chọn đúng ngăn
> Giải thích: ở G1 cổng ghi nhận kết quả ALU của chính lệnh đang giải mã, nên nếu ghi đè ngược lại cổng đọc thì tạo vòng không qua ô nhớ nào. Ở G2 lệnh ghi là lệnh cũ ở tầng WB, lệnh đọc là lệnh mới ở ID, hai lệnh khác nhau nên không có vòng.
:::

:::mcq id=KT-P3-02
? Dòng 74 của `src/control.v`: `6'h00: r_alu(A_SLL, 0);` có tham số `u_rs = 0`. Điều đó nghĩa là gì?
- [ ] `sll` không ghi thanh ghi nào nên không cần đọc `rs`
- [ ] `sll` đọc `rs` làm số bit cần dịch nên hazard phải chờ khi `rs` trùng
- [x] `sll` không đọc `rs`: giá trị dịch lấy từ `rt`, số bit lấy từ `shamt`
- [ ] `sll` dùng `rs` làm thanh ghi đích nên `uses_rs` phải bằng 0 để khỏi ghi đè
> Giải thích: lệnh `sll rd, rt, shamt` dịch giá trị trong `rt` đi `shamt` bit rồi ghi vào `rd`. Trường `rs` của mã lệnh không được dùng. `uses_rs = 0` báo cho bộ hazard biết để khỏi chờ oan khi `rs` trùng thanh ghi `lw` vừa ghi.
:::

:::mcq id=KT-P3-03
? Với lệnh `lui` (dòng 86 của `control.v`), ALU làm phép OR giữa `rs_v` và `imm << 16`. Vì sao kết quả vẫn bằng đúng `imm << 16`?
- [x] Vì trường `rs` của `lui` bằng 0, nên `rs_v` là `$0` luôn bằng 0
- [ ] Vì ALU bỏ qua toán hạng A khi `alu_src = 1`, chỉ dùng toán hạng B
- [ ] Vì phép OR luôn trả toán hạng B khi A là một thanh ghi chưa được khởi tạo
- [ ] Vì `ext = 10` làm bộ điều khiển ép toán hạng A về 0 ở tầng giải mã
> Giải thích: `0 OR x = x`. Mã lệnh `lui` có trường `rs = 0`, tập thanh ghi trả 0 cho ngăn 0, nên `rs_v = 0`. Nếu trường `rs` khác 0 thì kết quả sẽ bị OR thêm giá trị đó, vì ALU không bỏ qua toán hạng A.
:::

:::mcq id=KT-P3-04
? Ở WatchChip lệnh `ori $t0,$t0,0xFFFF` cho toán hạng B (sau mở rộng) là giá trị nào?
- [ ] `0xFFFFFFFF`, vì mọi hằng số 16 bit đều được nới dấu trước khi vào ALU
- [ ] `0xFFFF0000`, vì hằng được đặt lên 16 bit cao giống `lui`
- [x] `0x0000FFFF`, vì `ori` dùng `ext = 01` nới bằng 0
- [ ] `0x0000FFFF` chỉ khi bit 15 bằng 0, nếu không thì nới dấu như `addiu`
> Giải thích: dòng 85 của `control.v` đặt `ori` với `E_ZE`. `imm_x` ở dòng 98 chọn `{16'd0, imm16}` khi `ext = 01`. Không phụ thuộc bit 15. `addiu` mới nới dấu (dòng 82), cho `0xFFFFFFFF` với cùng hằng.
:::

:::mcq id=KT-P3-05
? Mã `0x7C000000` (op = `0x1F`) không thuộc 28 lệnh. Bộ điều khiển trả gì và CPU làm gì?
- [ ] Toàn số 0, `valid = 0`, mạch dừng và đợi reset để khỏi chạy tiếp một lệnh sai
- [x] Toàn số 0, `valid = 0`, CPU coi như lệnh rỗng và chạy tiếp; mô phỏng in cảnh báo
- [ ] Giữ nguyên công tắc của lệnh trước đó cho tới khi gặp lệnh hợp lệ kế tiếp
- [ ] Bật `reg_write = 1` với `dst = 00` để ghi vào `$zero` mà không có tác dụng gì
> Giải thích: dòng 63 đến 65 đặt mặc định toàn 0, nhánh `default` ở dòng 112 không bật gì nên `valid` giữ 0. CPU chạy tiếp như lệnh rỗng; cảnh báo chỉ in ở mô phỏng (`cpu_g1.v:243`, `cpu_pipe.v:320`).
:::

:::mcq id=KT-P3-06
? Ở G2, thanh ghi nào được ghi khi `we_rf = cpu_ce && mw_v && mw_rw` (`cpu_pipe.v:108`) bằng 1 và vì sao lấy `mw_dst`?
- [ ] Thanh ghi đích của lệnh đang ở ID, vì quyết định ghi đã có từ lúc giải mã
- [ ] Thanh ghi đích của lệnh đang ở EX, vì ALU đã tính xong kết quả
- [x] Thanh ghi đích của lệnh đang ở WB, vì ghi chỉ xảy ra ở tầng cuối
- [ ] Thanh ghi `rt` của lệnh vừa nạp, vì `rt` luôn là đích của kiểu I
> Giải thích: `mw_` là băng chuyền MEM/WB. Lệnh nằm ở đó là lệnh đang ở tầng WB, nên ghi dùng `mw_dst` và `wb` (dòng 109). Đây chính là lý do cổng đọc ở ID (của lệnh khác) cần bypass.
:::

:::mcq id=KT-P3-07
? Trong WatchChip, nếu xóa điều kiện `wa != 5'd0` ở dòng 33 của `regfile.v`, chạy `regfile_tb` cho kết quả nào?
- [ ] `FAIL`, vì ngăn 0 bị ghi thành giá trị khác 0 và bị đọc ra
- [ ] `FAIL`, vì bypass trả giá trị ghi thay vì 0 cho ngăn 0
- [x] `PASS regfile_tb 2040`: đọc ngăn 0 đã bị ép 0 ở dòng 45, 46 nên lỗi bị che
- [ ] Biên dịch báo lỗi, vì dòng 33 là điều kiện bắt buộc của ngôn ngữ
> Giải thích: đã chạy thật ngày 12/11: bản sửa vẫn in `PASS regfile_tb 2040`. Ngăn `r[0]` có bị ghi nhưng cổng đọc `(ra1 == 5'd0) ? 32'd0 : ...` luôn trả 0. Đây là "đột biến sống sót": bài thử không phân biệt hai thiết kế.
:::

:::mcq id=KT-P3-08
? Dòng 102 của `cpu_pipe.v` đặt `d_dst = 5'd0` khi `!ifid_v`. Mục đích?
- [ ] Để lệnh bong bóng không tiêu thụ một ngăn thanh ghi thật làm đích ghi
- [ ] Để `$zero` luôn là thanh ghi đích mặc định của mọi lệnh ở ID
- [x] Để bong bóng không khai báo đích giả, tránh gây load-use và lấy tắt sai
- [ ] Để giảm số cổng logic ở bộ chọn `dst_sel` khi tầng ID rỗng
> Giải thích: `idex_dst` đi vào bộ phát hiện xung đột. Nếu bong bóng mang theo `dst` của lệnh cũ còn sót thì `hazard.v` thấy "lệnh ở EX ghi thanh ghi X" và có thể chờ hoặc lấy tắt oan. Đích bằng 0 bị mọi điều kiện `!= 0` ở `hazard.v` loại.
:::

### Thầy chỉ vào dòng này

:::thay-hoi
**`src/control.v:63-65`**: Vì sao đầu khối `always` đặt hết đầu ra về 0 trước? **Trả lời:** Để mỗi lệnh chỉ cần bật cái nó cần và mọi nhánh đều gán đủ đầu ra. Nhờ vậy không sinh chốt ngầm, và mã lạ tự động ra toàn 0 với `valid = 0`, tức lệnh rỗng.
:::

:::thay-hoi
**`src/control.v:74`**: Vì sao `sll` có `uses_rs = 0`? **Trả lời:** Vì `sll` lấy giá trị cần dịch từ `rt` và số bit dịch từ trường `shamt`, không đọc `rs`. Cờ này báo cho `hazard.v` để khỏi chờ oan khi `rs` trùng thanh ghi một lệnh `lw` vừa ghi.
:::

:::thay-hoi
**`src/control.v:86`**: `lui` giải mã thế nào để ra `imm << 16`? **Trả lời:** `ext = LUI` cho `imm_x = {imm16, 16'd0}`, `alu_src = 1`, `alu_ctl = OR`. ALU tính `rs_v OR imm_x`, mà trường `rs` của `lui` bằng 0 nên `rs_v = 0` và kết quả chính là `imm_x`.
:::

:::thay-hoi
**`src/control.v:87`**: `lw` khác `addiu` ở những công tắc nào? **Trả lời:** Cùng khuôn `i_alu(ADD, nới dấu, 1)` để tính địa chỉ `rs + imm` và ghi vào `rt`, nhưng `lw` bật thêm `mem_read` và `mem_to_reg`. `mem_to_reg` làm tầng WB lấy dữ liệu bộ nhớ thay vì kết quả ALU.
:::

:::thay-hoi
**`src/regfile.v:41`**: Bypass là gì, vì sao `we` nằm trong điều kiện? **Trả lời:** Khi lệnh cũ đang ghi đúng ngăn mà lệnh mới đọc cùng chu kỳ, bypass đưa thẳng `wd` ra cổng đọc, vì ghi chỉ có hiệu lực ở cạnh clock kế tiếp. Điều kiện `we` để chỉ bypass khi **thật sự có ghi**, không thì cổng đọc lấy nhầm `wd` rác.
:::

:::thay-hoi
**`src/cpu_g1.v:84`**: Vì sao G1 tắt bypass? **Trả lời:** Ở G1 cổng ghi là của chính lệnh đang đọc, nên bypass tạo vòng tổ hợp (ghi phụ thuộc ALU, ALU phụ thuộc đọc, đọc phụ thuộc ghi). G1 giải bằng cách ghi ở pha A, đọc ở pha B.
:::

## P4 · IF, PC, rẽ nhánh, hai pha và khối bcd

### Bản đồ

:::ban-do
Bài này dành cho người giữ chặng **lấy lệnh và quyết định lệnh kế tiếp** (tầng IF), cùng nhịp hai pha của lõi G1 và khối đổi nhị phân ra chữ số thập phân `bcd`. Nó gồm bốn mảnh:

| Mảnh | File và dòng | Làm gì |
|---|---|---|
| PC kế tiếp của G1 | `src/cpu_g1.v` dòng 148–170 | Chọn địa chỉ lệnh kế: đi tiếp, nhánh, nhảy, quay về, vào ngắt. |
| Hai pha và lấy lệnh của G1 | `src/cpu_g1.v` dòng 46–59, 190–227 | Mỗi chu kỳ CPU gồm hai nhịp: pha B (bộ nhớ dữ liệu) rồi pha A (cập nhật PC, nạp lệnh kế). |
| Lấy lệnh và nhảy của G2 | `src/cpu_pipe.v` dòng 56–60, 174–182, 291–300 | PC và băng chuyền IF/ID của đường ống, đích nhảy tính ở EX. |
| Khối `bcd` | `src/bcd_unit.v` (90 dòng) | Đổi số nhị phân thành tám chữ số thập phân để hiện lên màn hình, bằng thuật toán "dịch và cộng 3". |

**Cách đọc bảng:** `bcd_unit.v` đọc hết. Các đoạn của hai lõi CPU đọc đúng khoảng dòng đã nêu.

Bài thử của chặng này: `bash tools/run_unit.sh bcd`, kết quả mong đợi `PASS bcd_tb {{so:bcd-tb}}`. Phần PC của hai lõi được kiểm gián tiếp: `python tools/cosim_iss.py --rand 0` chạy chương trình trên mô hình lệnh và trên chip rồi so từng lệnh, kết quả chạy hôm 12/11 là `PASS cosim_iss 21` (không có ca ngẫu nhiên); log hồi quy đầy đủ ghi `PASS cosim_iss {{so:cosim-iss}}`.
:::

### Câu hỏi mở bài

Chương trình là một dãy lệnh nằm trong bộ nhớ. Ai nói cho chip biết lệnh kế tiếp nằm ở đâu? Khi gặp lệnh rẽ nhánh `beq`, địa chỉ nhảy tới được tính từ đâu? Và vì sao một lệnh `bcd` tốn tới **28 chu kỳ** trong khi lệnh cộng chỉ tốn một?

Câu trả lời ngắn, các mục sau chứng minh từng ý:

- Có một thanh ghi `pc` giữ địa chỉ lệnh đang chạy. Mỗi lệnh xong, một mạch chọn `next_pc` quyết định `pc` nhận gì: `pc + 4` (đi tiếp), một đích nhảy, hoặc địa chỉ ngắt `0x180`. Chọn **theo thứ tự ưu tiên** cố định.
- Địa chỉ nhánh tính **tương đối** từ `pc + 4`: lấy hằng số trong lệnh nhân 4 rồi cộng vào.
- `bcd` đổi 27 bit nhị phân thành chữ số thập phân **mỗi chu kỳ một bit**. Cộng một chu kỳ chốt đầu vào, tổng là 28.

### Trực giác

Hình dung `pc` là **ngón tay chỉ vào dòng đang đọc** trong một cuốn sách công thức nấu ăn. Thông thường ngón tay trượt xuống dòng kế tiếp (cộng 4, vì mỗi lệnh dài 4 byte). Nhưng sách có vài kiểu "chỉ dẫn nhảy":

- **Nhảy `j`, `jal`**: "xem trang X" (đích viết thẳng trong lệnh).
- **Rẽ nhánh `beq`, `bne`**: "nếu hai nguyên liệu bằng nhau thì nhảy lên hoặc xuống vài dòng". Số dòng lệnh đã ghi sẵn.
- **`jr`, `eret`**: "quay lại chỗ đã ghi trên giấy nhớ" (một thanh ghi hoặc `epc`).
- **Ngắt**: chuông reo, bỏ mọi thứ, nhảy tới trang khẩn cấp số `0x180`.

Còn bốn ý cần có.

**Địa chỉ lệnh luôn chia hết cho 4.** Mỗi lệnh dài 4 byte, nên hai bit thấp của `pc` luôn bằng 00. Vì vậy khi lấy lệnh từ bộ nhớ chỉ dùng các bit từ bit 2 trở lên (`pc[G_IMEM_AW+1:2]`).

**Hai pha.** Bộ nhớ trong FPGA (loại BRAM) đọc xong **chậm một nhịp**: đưa địa chỉ vào ở nhịp này, dữ liệu mới ra ở nhịp sau. Lõi G1 dàn việc cho vừa nhịp ấy: mỗi lệnh gồm **hai nhịp** cpu_ce, pha B rồi pha A. Ghi nhớ: **B (bộ nhớ) trước, A (cập nhật) sau**.

**Đứng chờ.** Lệnh nhiều chu kỳ (`div`, `bcd`) làm CPU **đứng**: `pc` giữ nguyên cho tới khi khối kia báo xong.

**BCD.** (Thuật toán đổi sang BCD có tên tiếng Anh là double dabble, nghĩa là dịch và cộng 3.) Một số như 1234 trong máy lưu theo nhị phân. Muốn hiện lên màn hình bảy đoạn cần từng chữ số 1, 2, 3, 4 riêng, mỗi chữ số trong 4 bit. Dạng đó gọi là BCD: số 1234 thành `0x00001234` (đọc từng nhóm 4 bit ra chữ số thập phân).

### Cơ chế theo đường tín hiệu

Theo dõi một lệnh `beq` ở G1, ở địa chỉ `0x40`, với hằng số `imm = 3`, hai thanh ghi so bằng nhau.

**1. Hai nhịp của lệnh.** Pha B (cạnh cpu_ce đầu): lệnh không đụng bộ nhớ nên không có gì xảy ra ngoài `phb <= 0`. Pha A (cạnh kế): mọi thứ cập nhật.

**2. Tính `pc4`.** `pc + 4 = 0x44` (dòng 149).

**3. So sánh.** `eq = (rs_v == rt_v)` bằng 1. `take = (branch == 01 && eq) || (branch == 10 && !eq)` bằng 1 vì lệnh là `beq` và hai giá trị bằng nhau (dòng 150, 151).

**4. Đích nhánh.** Dòng 160: `next_pc = pc4 + {imm_x[29:0], 2'b00}`. Hằng số `3` được nới thành `0x00000003`, lấy 30 bit thấp rồi ghép hai bit 0 phía dưới, tức dịch trái hai bit: `3 × 4 = 12 = 0xC`. Vậy `next_pc = 0x44 + 0xC = 0x50`. Quan trọng: địa chỉ cộng là `pc + 4`, **không phải** `pc`.

**5. Ưu tiên.** Không đang reset, không đứng chờ, không phải `eret`, `jr`, `j`, nên chuỗi `if` ở dòng 155 đến 161 rơi tới nhánh `take` (dòng 160).

**6. Ngắt.** `take_irq` (dòng 166) bằng 0 trong ví dụ, nên `pc_new = next_pc` (dòng 167).

**7. Cập nhật.** Ở pha A, `pc <= pc_new` (dòng 213), và cũng trong cùng cạnh đó thanh ghi `instr` nạp `imem[pc_new]` (dòng 192). Nhờ vậy khi pha B của lệnh kế tới, `instr` đã sẵn sàng: độ trễ một nhịp của bộ nhớ bị **giấu** vào chu kỳ hiện tại.

**8. Ở G2** việc chọn đích làm ở tầng EX (dòng 177 đến 182) và `pc` được nạp ở dòng 293. Hai lệnh đã nạp nhầm phía sau bị đánh dấu không hợp lệ (dòng 294 và `id_ok` ở dòng 205), tức **phạt hai chu kỳ**.

### Bảng chu kỳ hoặc tính tay

:::suy-dan
**Đề bài.** Ba phép tính tay quanh chặng này.

1. Đích của `beq` ở địa chỉ `0x40` với hằng số `imm = 3` và với `imm = 0xFFFE`.
2. Đích của `j` có 26 bit địa chỉ `0x0000010` ở địa chỉ `0x00000040`; và lệnh `j` giống hệt nếu nằm ở địa chỉ `0x10000040`.
3. Đổi số 13 sang BCD bằng thuật toán "dịch và cộng 3", từng bước (chỉ cần 4 bit nhị phân và 2 chữ số thập phân).
---
**Phép 1: đích của `beq`.** Công thức: `đích = (pc + 4) + imm × 4`, với `imm` có dấu.

- `imm = 3`: `0x44 + 12 = 0x50`.
- `imm = 0xFFFE`: là số âm `−2` (16 bit, bit cao bằng 1). Nới dấu thành `0xFFFFFFFE`, lấy 30 bit thấp rồi ghép hai bit 0 được `0xFFFFFFF8`, tức `−8`. Đích `= 0x44 − 8 = 0x3C`. Nhảy **lùi** về lệnh nằm ngay trước `beq` (`0x40 − 4 = 0x3C`), tức lùi hai lệnh so với `pc + 4`.
- `{imm_x[29:0], 2'b00}` chính là `imm_x` dịch trái hai bit (hai bit cao bị bỏ, không sao vì địa chỉ cộng theo modulo 2 mũ 32). Giữ nguyên được cả số âm.

**Phép 2: đích của `j`.** Công thức: `đích = {4 bit cao của pc + 4, 26 bit địa chỉ, 00}`.

- Ở `0x00000040`: `pc + 4 = 0x44`, 4 bit cao là 0. Đích `= {0x0, 0x0000010, 00} = 0x00000040`. Nhảy về chính nó (vòng lặp vô hạn).
- Ở `0x10000040`: `pc + 4 = 0x10000044`, 4 bit cao là `0x1`. Đích `= 0x10000040`. **Giữ 4 bit cao** của vùng bộ nhớ hiện tại. Nhờ vậy lệnh `j` chỉ nhảy trong cùng vùng 256 MB.

**Phép 3: đổi 13 sang BCD.** Số 13 là `1101` (4 bit). Chữ số BCD gồm 2 nhóm 4 bit, đặt tên `d`. Mỗi bước: nếu nhóm nào `≥ 5` thì cộng 3, rồi dịch trái một bit và kéo bit kế tiếp của số nhị phân vào.

| Bước | Bit kéo vào | `d` trước | Sau cộng 3 | Sau dịch trái và kéo bit |
|---|---|---|---|---|
| 1 | 1 | `0x00` | `0x00` | `0x01` |
| 2 | 1 | `0x01` | `0x01` | `0x03` |
| 3 | 0 | `0x03` | `0x03` | `0x06` |
| 4 | 1 | `0x06` | `0x09` (6 ≥ 5, cộng 3) | `0x13` |

- Kết quả `0x13`, đọc là chữ số `1` và `3`: đúng 13.
- Chỗ then chốt là bước 4: `6 ≥ 5` nên cộng 3 thành 9. Nếu không cộng, `6 × 2 + 1 = 13 = 0xD` không phải một chữ số thập phân (BCD chỉ có 0 đến 9). Cộng 3 trước khi nhân đôi làm phần dư "nhảy" sang nhóm bên cạnh: `9 × 2 + 1 = 19 = 0x13`.
:::

### Trong chip

:::trong-chip
Mỗi đoạn trích dưới đây có đường dẫn file và số dòng, phía sau giải thích từng dòng sinh ra phần cứng gì.

**Lõi G1: các thanh ghi trạng thái và hai pha.**

{{trich:src/cpu_g1.v:46-59@trạng thái}}

- **Dòng 47** `pc`: địa chỉ lệnh đang chạy, 32 bit.
- **Dòng 48** `instr`: thanh ghi đầu ra của bộ nhớ lệnh, chứa lệnh đang giải mã.
- **Dòng 49** `phb`: một bit nhớ "cạnh cpu_ce kế tiếp là pha B". Bằng 1 nghĩa là sắp tới pha B.
- **Dòng 50, 51** bộ nhớ lệnh `imem` và bộ nhớ dữ liệu `dmem` (4 KB).
- **Dòng 52, 53** `dmem_q` và `lsel`: dữ liệu `lw` đọc ở pha B và nguồn của nó.
- **Dòng 54** `started`: lệnh nhiều chu kỳ đã được "bấm start" chưa.
- **Dòng 55, 56** `status` và `epc`, hai thanh ghi của khối ngắt.
- **Dòng 58** `ph_a = cpu_ce && !phb`: đang ở pha A khi CPU được bước và `phb` bằng 0.
- **Dòng 59** `ph_b = cpu_ce && phb`: đang ở pha B khi `phb` bằng 1.
- Chỉ một thanh ghi một bit `phb` đổi qua lại, đó là toàn bộ "đồng hồ hai nhịp".

**Lõi G1: chọn lệnh kế tiếp.**

{{trich:src/cpu_g1.v:148-162@PC kế tiếp}}

- **Dòng 149** `pc4`: cộng `pc` với 4.
- **Dòng 150** `eq`: so hai giá trị đọc từ thanh ghi, ra 1 nếu bằng nhau.
- **Dòng 151** `take`: 1 khi `beq` (mã 01) mà bằng nhau, hoặc `bne` (mã 10) mà khác nhau.
- **Dòng 152** `next_pc` là `reg` nhưng nằm trong `always @*`, nên là bộ chọn **tổ hợp**.
- **Dòng 153** chú thích thứ tự ưu tiên: reset, đứng chờ, `eret`, `jr`, `j`/`jal`, nhánh, đi tiếp.
- **Dòng 155** `rst`: đích 0.
- **Dòng 156** `stall`: **giữ nguyên `pc`** để lệnh nhiều chu kỳ chạy tiếp ở chu kỳ sau.
- **Dòng 157** `eret` (`cp0_op = 10`): quay về `epc`.
- **Dòng 158** `jr`: lấy `rs_v`, ép hai bit thấp về 00 để địa chỉ chia hết cho 4.
- **Dòng 159** `j`, `jal`: ghép 4 bit cao của `pc4`, 26 bit trong lệnh, và 00.
- **Dòng 160** nhánh: `pc4 + {imm_x[29:0], 2'b00}`.
- **Dòng 161** còn lại: `pc4`.
- Chuỗi `if ... else if ...` sinh ra **bộ chọn có ưu tiên**: mỗi dòng đứng trên thắng mọi dòng đứng dưới.

**Lõi G1: ngắt và đầu ra.**

{{trich:src/cpu_g1.v:164-170@nhận ngắt ở cuối lệnh}}

- **Dòng 164, 165** chú thích: nhận ngắt ở cuối lệnh hiện tại; `mtc0` và `eret` đang ghi `status` cùng cạnh nên **chặn** ngắt.
- **Dòng 166** `take_irq`: có yêu cầu `irq`, đã cho phép (`status[0] = 1`), không đang trong ngắt (`status[1] = 0`), CPU không đứng chờ, và lệnh không phải `mtc0`/`eret` (`cp0_op = 00`).
- **Dòng 167** `pc_new`: nếu nhận ngắt thì `0x180`, ngược lại `next_pc`.
- **Dòng 169, 170** `pc_out` và `retire`: lệnh coi là **xong** ở pha A khi không đứng chờ.

**Lõi G1: lấy lệnh bằng một cổng đọc.**

{{trich:src/cpu_g1.v:190-192@một cổng đọc imem}}

- **Dòng 190** chú thích: chỉ một cổng đọc `imem` (kể cả lúc reset) để công cụ tổng hợp suy ra BRAM; hai cổng thì bị dựng bằng LUT.
- **Dòng 191, 192** ở cạnh clock, nếu reset hoặc pha A thì `instr <= imem[...]`. Reset đọc `imem[0]`, pha A đọc `imem[pc_new[G_IMEM_AW+1:2]]`: lệnh kế tiếp **được nạp ngay trong cạnh chốt `pc`**.

**Lõi G1: cập nhật ở hai pha.**

{{trich:src/cpu_g1.v:194-227@always @(posedge clk) begin}}

- **Dòng 195 đến 198** reset: `pc = 0`, `phb = 1`, `started = 0`, `status = 0`, `epc = 0`. Sau reset cạnh cpu_ce đầu tiên là **pha B của lệnh 0**.
- **Dòng 200 đến 208** pha B: `phb <= 0`; `sw` ghi `dmem` ở dòng 203 nếu địa chỉ ở vùng bộ nhớ dữ liệu; `lw` đọc `dmem_q` và ghi nhớ nguồn đọc vào `lsel`.
- **Dòng 209 đến 213** pha A: `phb <= 1`, cập nhật `started`, và `pc <= pc_new`.
- **Dòng 212** `started <= (multi != 00) && !mdone`: giúp lệnh nhiều chu kỳ chỉ nhận **một** xung start (bài của người giữ chặng thực thi).
- **Dòng 214 đến 224** chỉ khi không đứng chờ: `mtc0` ghi `status`/`epc` (dòng 215 đến 218), `eret` xóa bit `EXL` (dòng 219), nhận ngắt thì `epc <= next_pc` và `EXL <= 1` (dòng 220 đến 223).
- **Dòng 221** `epc <= next_pc` nhớ **lệnh kế tiếp**, vì lệnh vừa xong đã chạy trọn.

**Lõi G2: IF/ID.**

{{trich:src/cpu_pipe.v:56-60@IF/ID}}

- **Dòng 56, 57** chú thích: băng chuyền giữa tầng lấy lệnh và tầng giải mã; `_v` là cờ "có hiệu lực", 0 là bong bóng.
- **Dòng 58** `ifid_v`: cờ hợp lệ.
- **Dòng 59** `ifid_pc`, `ifid_ins`: địa chỉ và mã lệnh của lệnh đang ở tầng ID.

**Lõi G2: tính đích ở EX.**

{{trich:src/cpu_pipe.v:174-182@nhánh/nhảy quyết định ở EX}}

- **Dòng 174 đến 175** chú thích: nhánh và nhảy quyết định ở EX; `take = 1` nghĩa là phải đổi hướng, các lệnh nạp nhầm phía sau bị xóa.
- **Dòng 176** `eq`: so hai toán hạng **đã lấy tắt** (`opA`, `opB`), không phải giá trị đọc ở ID.
- **Dòng 177, 178** `take`: lệnh ở EX hợp lệ, EX không bận, và một trong: `beq` mà bằng, `bne` mà khác, `j`/`jal`, `jr`, hoặc `eret`.
- **Dòng 179 đến 182** `tgt`: bốn đường chọn theo ưu tiên: `eret` lấy `epc`; `jr` lấy `opA` ép chia hết cho 4; `j` ghép 4 bit cao của `idex_pc4`, 26 bit, 00; còn lại là nhánh `idex_pc4 + imm × 4`.

**Lõi G2: nạp PC.**

{{trich:src/cpu_pipe.v:291-300@IF/ID và PC}}

- **Dòng 291** chú thích: giữ khi load-use; nhảy thì nạp đích và xóa lệnh đã nạp.
- **Dòng 292** chỉ cập nhật khi **không** có load-use. Có load-use thì `pc` và IF/ID đều **giữ nguyên**.
- **Dòng 293** `pc`: nhận ngắt thì `0x180`, nhảy thì `tgt`, còn lại `pc + 4`.
- **Dòng 294** `ifid_v <= !take && !take_irq`: lệnh vừa nạp bị đánh dấu **không hợp lệ** nếu đang đổi hướng.
- **Dòng 295, 296** `ifid_pc` và `ifid_ins` nhận `pc` và lệnh tại `imem[pc]`.

**Khối bcd: vỏ ngoài.**

{{trich:src/bcd_unit.v:18-30@module bcd_unit #(}}

- **Dòng 18 đến 20** tham số `G_COMB`: 0 tuần tự (ít mạch), 1 tổ hợp (nhanh, tốn thêm khoảng 416 LUT).
- **Dòng 21 đến 24** cổng điều khiển: `clk`, `rst`, `ce`, `start`.
- **Dòng 25** `x`: số nhị phân cần đổi.
- **Dòng 26, 27** `busy` (đang chạy) và `done` (xong).
- **Dòng 28** `y`: tám chữ số BCD.
- **Dòng 30** `MAXV = 99 999 999`: số lớn nhất hiện được trên tám chữ số.

**Khối bcd: cộng 3 và đổi một lượt.**

{{trich:src/bcd_unit.v:32-50@// cộng 3}}

- **Dòng 33 đến 39** hàm `add3`: duyệt tám chữ số. Mỗi chữ số `≥ 5` thì cộng 3, ngược lại giữ nguyên. Đây là bước then chốt của thuật toán.
- **Dòng 41 đến 50** hàm `to_bcd`: 27 vòng lặp liên tiếp. Mỗi vòng: `d = {add3(d)} << 1 | b[k]`, từ bit cao nhất (bit 26) xuống bit 0. Công cụ tổng hợp trải thành 27 tầng mạch nối tiếp. Chỉ bản tổ hợp dùng.

**Khối bcd: chống tràn và hai bản.**

{{trich:src/bcd_unit.v:52-58@wire ovf}}

- **Dòng 52** `ovf = (x > MAXV)`: lớn hơn 99 999 999 thì không đổi được.
- **Dòng 54** `generate if (G_COMB != 0)`: chọn bản tổ hợp tại lúc dựng mạch.
- **Dòng 55** `busy = 0`: không bao giờ làm CPU đứng.
- **Dòng 56** `done = ce && start`: xong ngay trong chu kỳ start.
- **Dòng 57** `y`: tràn thì `FFFFFFFF`, ngược lại `to_bcd` của 27 bit thấp.

**Khối bcd: bản tuần tự, vỏ ngoài.**

{{trich:src/bcd_unit.v:59-71@end else begin : g_seq}}

- **Dòng 60 đến 63** bốn ô nhớ: `run` (đang chạy), `cnt` (đếm 0 đến 26), `d` (chữ số đang tích lũy), `b` (bit nhị phân còn lại).
- **Dòng 65** `d_n`: một bước: cộng 3, dịch trái một bit, kéo bit cao nhất của `b` vào.
- **Dòng 66** `last`: bước thứ **27** khi `cnt = 26`.
- **Dòng 68** `busy = run`.
- **Dòng 69** `done = ce && ((start && !run && ovf) || last)`: xong ở bước cuối hoặc xong ngay nếu tràn.
- **Dòng 70** `y = run ? d_n : FFFFFFFF`: ở bước cuối `d_n` chính là kết quả; ngoài chạy thì `FFFFFFFF` (dùng cho ca tràn).

**Khối bcd: máy trạng thái tuần tự.**

{{trich:src/bcd_unit.v:72-89@always @(posedge clk)}}

- **Dòng 73 đến 75** reset xóa hết; ngoài ra chỉ chạy khi `ce`.
- **Dòng 76 đến 80** nhận `start`: không tràn thì `run <= 1`, `cnt <= 0`, `d <= 0`, `b <= x[26:0]`: **chốt** đầu vào. Đây là **chu kỳ 1** trong 28.
- **Dòng 81 đến 86** mỗi chu kỳ đang chạy: `d <= d_n`, `b` dịch trái một bit, `cnt` cộng một. Bước thứ 27 (`cnt = 26`) thì `run <= 0`. Đây là **27 chu kỳ** còn lại.
- Tổng `1 + 27 = 28` chu kỳ cho lệnh `bcd` tuần tự.
:::

### Bẫy và thầy hay hỏi

:::bay
**Bẫy 1: "Đích nhánh bằng `pc` cộng hằng số."** Sai. Đích tính từ **`pc + 4`**, không phải `pc`. Ví dụ `beq` ở `0x40` với `imm = 3` nhảy tới `0x50`, không phải `0x4C`. Hằng số còn được **nhân 4** (dịch trái hai bit) vì lệnh dài 4 byte. Dòng 160: `pc4 + {imm_x[29:0], 2'b00}`.
:::

:::bay
**Bẫy 2: "G1 đọc lệnh kế tiếp ở đầu chu kỳ sau."** Sai. `instr <= imem[pc_new...]` chạy **cùng cạnh** với `pc <= pc_new` (dòng 192 và 213), nên lệnh kế tiếp đã sẵn sàng khi chu kỳ sau bắt đầu. Độ trễ một nhịp của bộ nhớ được giấu trong chu kỳ hiện tại. Đây chính là lý do chia chu kỳ làm hai pha.
:::

:::bay
**Bẫy 3: "Ngắt đến thì lệnh đang chạy bị bỏ dở."** Sai ở lõi G1: ngắt chỉ nhận ở **cuối lệnh** (pha A), lệnh vừa xong đã chạy trọn kể cả ghi thanh ghi và bộ nhớ. `epc <= next_pc` nhớ **lệnh kế tiếp** (dòng 221). Điều kiện `!stall` và `cp0_op == 00` (dòng 166) chặn nhận ngắt ngay giữa lệnh nhiều chu kỳ hay khi `mtc0` đang ghi `status`.
:::

:::bay
**Bẫy 4: "`bcd` chỉ cần cộng 3 vào cả số."** Sai. Cộng 3 chỉ áp cho **từng chữ số đang `≥ 5`**, và làm **trước mỗi lần dịch**. Cộng 3 vào chữ số nhỏ hơn 5 sẽ sinh chữ số sai. Ngưỡng 5 có lý do: `5 × 2 = 10` là con số đầu tiên cần nhảy sang chữ số bên cạnh.
:::

### Sửa tại chỗ và ứng dụng

:::sua-tai-cho
**Cài lỗi rồi xem bài thử nào bắt.** Hai lỗi. Mỗi lần **chép file ra bản nháp rồi sửa bản nháp, không sửa file gốc**. Ở thư mục gốc project:

```bash
source tools/env.sh
mkdir -p work/mut
cp src/bcd_unit.v work/mut/bcd_unit.v
```

**Lỗi 1: ngưỡng cộng 3 từ 5 lên 6.** Trong `work/mut/bcd_unit.v`, dòng 37, đổi `>= 4'd5` thành `>= 4'd6`. Dịch và chạy với bản nháp:

```bash
iverilog -g2005 -Wno-timescale -o work/mut/b.vvp tb/bcd_tb.v work/mut/bcd_unit.v
vvp work/mut/b.vvp | head -3
```

Kết quả đã chạy (12/11): dòng đầu là `loi tuan tu vs bcd.txt: x=0000000a y=0000000a yc=00000009 cyc=28 (can 00000010)`. Cách đọc: số 10 (`0x0A`) đúng ra phải ra `0x10` (hai chữ số 1 và 0), nhưng mạch ra `0x0A`: một "chữ số" bằng 10, không phải số thập phân. Ngưỡng 6 nghĩa là chữ số 5 không được cộng 3, nên khi nhân đôi `5 × 2 = 10` không nhảy sang chữ số kế.

**Lỗi 2: bước cuối đến sớm một chu kỳ.** Chép lại file gốc, rồi ở dòng 66 đổi `5'd26` thành `5'd25`:

```bash
cp src/bcd_unit.v work/mut/bcd_unit.v
# sửa dòng 66, rồi:
iverilog -g2005 -Wno-timescale -o work/mut/b.vvp tb/bcd_tb.v work/mut/bcd_unit.v
vvp work/mut/b.vvp | head -3
```

Kết quả đã chạy: `loi so chu ky tuan tu: x=00000000 y=00000000 yc=00000000 cyc=27 (can 00000000)` rồi `loi tuan tu vs bcd.txt: x=00000001 y=00000000 ...`. Đọc ra: lệnh chỉ chạy **27** chu kỳ thay vì 28, và vì chỉ làm 26 bước nên kết quả của số 1 bị lệch (`y=00000000`, cần `00000001`).

**Thử thêm: đổi ngưỡng tràn.** Ở dòng 52 đổi `x > MAXV` thành `x >= MAXV`. Kết quả đã chạy: `loi tuan tu vs bcd.txt: x=05f5e0ff y=ffffffff yc=86399999 cyc=1 (can 99999999)`. Đọc ra: số `99 999 999` (`0x05F5E0FF`) vốn **hợp lệ** nay bị coi là tràn và trả `FFFFFFFF` sau một chu kỳ. Đây là lỗi "lệch một" ở biên, loại lỗi chỉ lộ ra ở đúng một giá trị. Bài thử có ca biên nên bắt được.

Xong thì xóa thư mục `work/mut/` hoặc để đó, nó không nằm trong chip.
:::

:::dung-o-dau
**Kỹ năng này dùng ở đâu khác.**

- **Mọi bộ xử lý** có thanh ghi PC và một mạch chọn địa chỉ kế tiếp theo thứ tự ưu tiên giống hệt: ngắt, quay về, nhảy, nhánh, đi tiếp. Cách nghĩ "chuỗi `if` ưu tiên sinh ra bộ chọn" dùng lại mọi nơi.
- **Đổi nhị phân ra thập phân** xuất hiện ở mọi thiết bị có màn hình số: đồng hồ, máy tính cầm tay, đồng hồ đo. Thuật toán dịch và cộng 3 chỉ dùng phép dịch và cộng, không cần phép chia nên rất hợp với phần cứng.
- **Giấu độ trễ**: nạp lệnh kế tiếp ngay trong cạnh chốt `pc` là một ví dụ nhỏ của "làm việc chồng lên nhau để che độ trễ", cùng ý với đường ống, bộ nhớ đệm, tải trước dữ liệu.
- **Kiểm thử biên**: lỗi lệch một ở `99 999 999` cho thấy phải thử đúng các giá trị ở rìa của miền cho phép.
:::

### Tự kiểm và quay lại bức tranh

:::tu-luan
`beq` ở địa chỉ `0x100` có hằng số `imm = 0xFFFC` và hai thanh ghi so bằng nhau. Đích nhảy là gì? Có phải nhảy về chính nó không?
---
**Đáp án hoàn chỉnh.** `imm = 0xFFFC` là số âm `−4` (16 bit). Nới dấu `0xFFFFFFFC`, dịch trái hai bit (qua lấy 30 bit thấp rồi ghép 00) được `−16 = 0xFFFFFFF0`. Đích `= pc + 4 − 16 = 0x100 + 4 − 16 = 0xF4`. Vậy nhảy lùi bốn lệnh so với `pc + 4`, không phải về chính nó. Muốn nhảy về chính `beq` cần `imm = −1` (`0xFFFF`): `0x104 − 4 = 0x100`.
:::

:::tu-luan
Vì sao chu kỳ CPU của G1 chia làm hai pha, và vì sao thứ tự là B (bộ nhớ) trước, A (cập nhật) sau?
---
**Đáp án hoàn chỉnh.** Bộ nhớ trong FPGA (BRAM) đọc **trễ một nhịp**: đưa địa chỉ vào ở cạnh này, dữ liệu ra ở cạnh sau. Pha B dùng địa chỉ của `lw`/`sw` đã tính xong để chạm bộ nhớ dữ liệu, và dữ liệu `lw` đọc sẵn sàng khi sang pha A để ghi vào thanh ghi. Pha A chốt `pc` mới và **nạp luôn lệnh kế tiếp** vào `instr` (dòng 192), để pha B của lệnh sau có lệnh dùng ngay. Nếu đảo thứ tự (A trước) thì `lw` chưa có dữ liệu khi cần ghi vào thanh ghi. Nên B trước, A sau.
:::

:::tu-luan
Trong chuỗi `if` của `next_pc` (dòng 155 đến 161), vì sao `stall` đứng trên `eret`, `jr`, `j`? Nếu đảo `stall` xuống dưới thì chương trình có chạy sai không?
---
**Đáp án hoàn chỉnh.** `stall` bằng 1 khi lệnh đang giải mã là lệnh nhiều chu kỳ (`div` hoặc `bcd`) mà chưa xong; khi đó `pc` phải **giữ nguyên** (dòng 156). Đặt `stall` ở trên là cách viết **phòng thủ**: bảo đảm không có đường nào làm `pc` đổi trong lúc chờ.

Với tập lệnh hiện tại, đảo thứ tự **không làm sai** chương trình: `control.v` đặt `jump`, `jump_reg`, `branch`, `cp0_op` bằng 0 cho cả `div` (dòng 77) và `bcd` (dòng 99), nên khi `stall = 1` các nhánh `eret`, `jr`, `j`, nhánh đều không bật. Hai thứ tự cho cùng kết quả (nhận định này `inference` từ việc đọc `control.v`, chưa chạy thử). Thứ tự hiện tại vẫn đáng giữ vì nó an toàn nếu sau này thêm một lệnh vừa nhiều chu kỳ vừa nhảy.
:::

:::tu-luan
Đổi số 5 sang BCD bằng thuật toán dịch và cộng 3 với 3 bit nhị phân và 2 chữ số, từng bước. Chỉ ra bước nào có cộng 3.
---
**Đáp án hoàn chỉnh.** Số 5 là `101` (3 bit). Bắt đầu `d = 0x00`.

- Bước 1, kéo bit 1: `d` trước `0x00`, cộng 3 không (0 nhỏ hơn 5), dịch và kéo bit: `0x01`.
- Bước 2, kéo bit 0: `d` trước `0x01`, không cộng 3, dịch: `0x02`.
- Bước 3, kéo bit 1: `d` trước `0x02`, không cộng 3, dịch và kéo bit: `0x05`.
- Kết quả `0x05`: chữ số `0` và `5`. Đúng. **Không có bước nào cộng 3**, vì chữ số chưa bao giờ đạt 5 **trước** lần dịch (trước các lần dịch `d` lần lượt là 0, 1, 2).
- Số 6 (`110`) và số 7 (`111`) cũng không cần cộng 3 (trước các lần dịch `d` là 0, 1, 3). Số 13 (`1101`) mới có bước cộng 3, ở bước 4 khi `d = 6`.
:::

:::tu-luan
Vì sao lệnh `bcd` tuần tự mất đúng 28 chu kỳ và ca tràn chỉ mất 1 chu kỳ? Con số này ảnh hưởng gì đến đường ống G2?
---
**Đáp án hoàn chỉnh.** 28 = 1 chu kỳ chốt đầu vào (nhận `start`, dòng 76 đến 80) + 27 bước đổi (`cnt` từ 0 đến 26, dòng 81 đến 86). 27 bước vì `99 999 999 < 2^27 = 134 217 728`, tức đủ 27 bit nhị phân. Ca tràn (`x > 99 999 999`) không chạy: `done` lên ngay ở chu kỳ start với `y = FFFFFFFF` (dòng 69, 70), nên 1 chu kỳ. Ở G2, EX giữ lệnh `bcd` trong 28 chu kỳ và `stall_busy` bằng 1 trong 27 chu kỳ đầu, các tầng sau EX nhận bong bóng: tổng **+27 bong bóng** cho mỗi lệnh `bcd`. Bài thử `bcd_busy.s` có hai lệnh `bcd` nên ghi `bubbles 54`.
:::

:::mcq id=KT-P4-01
? Trong WatchChip, `beq` ở địa chỉ `0x40` có hằng số `imm = 3` và nhánh được lấy. Lõi G1 nhảy tới địa chỉ nào?
- [ ] `0x4C`, vì đích bằng `pc` cộng ba lệnh kế tiếp
- [x] `0x50`, vì đích là `pc + 4` cộng `imm` nhân 4
- [ ] `0x43`, vì đích là `pc` cộng thẳng hằng số `imm`
- [ ] `0x4C`, vì dòng 160 tính `pc + imm × 4` mà không cộng thêm 4
> Giải thích: dòng 160 của `cpu_g1.v` là `next_pc = pc4 + {imm_x[29:0], 2'b00}`. `pc4 = 0x44`, `imm × 4 = 12 = 0xC`. `0x44 + 0xC = 0x50`. Hai đáp án `0x4C` quên cộng 4 vào `pc`.
:::

:::mcq id=KT-P4-02
? Dòng 192 của `cpu_g1.v` nạp `instr <= imem[pc_new...]` ở cạnh pha A cùng lúc `pc <= pc_new`. Điều đó mang lại lợi ích gì cho lõi G1?
- [ ] Bộ nhớ lệnh được đọc hai lần trong một chu kỳ nên pha B của lệnh sau không phải chờ pha A
- [ ] Bộ nhớ lệnh có thể có hai cổng đọc nên đọc cùng lúc hai lệnh trong một chu kỳ
- [x] Lệnh kế tiếp có sẵn ngay khi chu kỳ sau bắt đầu, độ trễ bộ nhớ bị che
- [ ] CPU thực hiện hai lệnh trong một chu kỳ nên nhanh gấp đôi
> Giải thích: bộ nhớ trong FPGA đọc trễ một nhịp. Nạp lệnh kế ngay trong cạnh chốt `pc` làm dữ liệu sẵn sàng đúng lúc lệnh sau cần. Chỉ có một cổng đọc (dòng 190 nói rõ), và mỗi chu kỳ vẫn chỉ xong một lệnh.
:::

:::mcq id=KT-P4-03
? Ở WatchChip, lệnh `bcd` tuần tự mất bao nhiêu chu kỳ CPU khi số đầu vào là 1234, và khi số đầu vào là 100 000 000?
- [ ] 27 chu kỳ cho cả hai, vì thuật toán có 27 bước
- [ ] 28 chu kỳ cho cả hai, vì chốt đầu vào tốn một chu kỳ
- [x] 28 chu kỳ cho 1234; 1 chu kỳ cho 100 000 000 vì tràn
- [ ] 1 chu kỳ cho 1234 vì bản tuần tự cần một chu kỳ mỗi chữ số
> Giải thích: dòng 76 đến 86 của `bcd_unit.v`: một chu kỳ chốt cộng 27 bước, tổng 28. Số `100 000 000` lớn hơn `MAXV` nên `ovf` bằng 1, `done` lên ngay ở chu kỳ start (dòng 69) với `FFFFFFFF`. Bài thử kiểm cả hai ca: `cyc == (tràn ? 1 : 28)`.
:::

:::mcq id=KT-P4-04
? Số 6 (`0110`) đang nằm trong một chữ số BCD trước lần dịch. Thuật toán dịch và cộng 3 làm gì với nó và vì sao?
- [ ] Giữ nguyên, vì 6 vẫn nhỏ hơn 10 nên chữ số còn hợp lệ
- [ ] Trừ 3, vì cần giảm xuống dưới ngưỡng trước khi nhân đôi
- [x] Cộng 3 thành 9 để sau nhân đôi ra 18 và nhảy sang chữ số bên cạnh
- [ ] Cộng 3 sau khi dịch, vì nhân đôi 6 mới thành 12 và lúc đó mới cần sửa
> Giải thích: `add3` ở dòng 33 đến 39 cộng 3 vào chữ số `≥ 5` **trước** khi dịch. `6 + 3 = 9`, nhân đôi `18 = 0x12`: chữ số này giữ 2, một đơn vị nhảy sang chữ số cao hơn. Nếu không cộng, `6 × 2 = 12 = 0xC` không phải chữ số thập phân.
:::

:::mcq id=KT-P4-05
? Dòng 166 của `cpu_g1.v` có `take_irq = irq && status[0] && !status[1] && !stall && (cp0_op == 2'b00)`. Điều kiện `!stall` nhằm mục đích gì?
- [ ] Để chắc ngắt chỉ nhận ở pha B khi bộ nhớ đang bận
- [ ] Để `epc` lưu đúng địa chỉ của lệnh đang chờ thay vì lệnh kế tiếp
- [ ] Để ngắt có thể cắt ngang lệnh `div` ở giữa chừng cho kịp phản hồi
- [x] Để không nhận ngắt khi lệnh nhiều chu kỳ chưa xong, vì lệnh chưa chạy trọn
> Giải thích: G1 chỉ nhận ngắt ở cuối lệnh, khi lệnh vừa xong đã chạy trọn. Nếu lệnh `div` còn chạy (`stall = 1`) mà nhận ngắt thì `epc <= next_pc` sẽ nhớ sai chỗ và phép chia bị bỏ dở.
:::

:::mcq id=KT-P4-06
? Ở G2 (`cpu_pipe.v:293, 294`), khi nhánh nhảy thật thì `ifid_v <= !take && !take_irq` gán 0. Tác dụng là gì?
- [ ] Giữ nguyên lệnh đang ở tầng ID để dùng lại sau khi nhánh quyết định xong
- [ ] Xóa luôn lệnh đang ở tầng EX vì nó nạp nhầm
- [x] Đánh dấu lệnh vừa nạp là bong bóng, để nó không đi tiếp sang ID/EX
- [ ] Đưa `pc` về `pc − 4` để nạp lại lệnh vừa bỏ
> Giải thích: tới lúc `take` bằng 1 ở EX, hai lệnh phía sau đã nạp nhầm. Lệnh ở IF bị `ifid_v <= 0`, lệnh ở ID bị `id_ok = 0` (dòng 205). Cùng nhau chúng gây **phạt hai chu kỳ** (bảng T3 của tài liệu chính sách).
:::

:::mcq id=KT-P4-07
? Đích của lệnh `j` ở G1 là `{pc4[31:28], instr[25:0], 2'b00}` (dòng 159). Vì sao giữ lại 4 bit cao của `pc4`?
- [ ] Vì lệnh `j` có đủ 32 bit để chứa địa chỉ nên 4 bit cao chỉ để dự phòng
- [x] Vì 26 bit địa chỉ cộng 2 bit 00 chỉ đủ 28 bit; 4 bit cao còn thiếu lấy từ vùng hiện tại
- [ ] Vì 4 bit cao của `pc4` chứa cờ của lệnh nhảy
- [ ] Vì phần cứng không có mạch dịch trái hai bit nên phải ghép tay
> Giải thích: lệnh `j` có 6 bit mã lệnh và 26 bit địa chỉ. Địa chỉ lệnh chia hết cho 4, nên 26 bit đủ cho 28 bit địa chỉ. 4 bit còn lại lấy từ `pc + 4`. Hệ quả: `j` chỉ nhảy trong cùng vùng 256 MB.
:::

:::mcq id=KT-P4-08
? Trong WatchChip, nếu sửa `bcd_unit.v` ở dòng 66 thành `cnt == 5'd25`, `bcd_tb` báo gì?
- [ ] `PASS bcd_tb`, vì kết quả vẫn đúng với mọi số nhỏ
- [x] `loi so chu ky tuan tu` với `cyc=27 (can ...)`, vì lệnh xong sớm một chu kỳ
- [ ] Biên dịch báo lỗi, vì `cnt` rộng 5 bit không thể so với 25
- [ ] `loi to hop vs bcd.txt`, vì bản tổ hợp dùng chung hằng số này
> Giải thích: đã chạy thật ngày 12/11. Bản tuần tự mất 27 chu kỳ thay vì 28, bài thử so `cyc == 28` nên báo ngay `loi so chu ky tuan tu`. Bản tổ hợp không có `cnt`, không bị ảnh hưởng.
:::

### Thầy chỉ vào dòng này

:::thay-hoi
**`src/cpu_g1.v:160`**: Đích của `beq` tính thế nào? **Trả lời:** `pc4 + {imm_x[29:0], 2'b00}`: lấy `pc + 4`, cộng hằng số có dấu nhân 4. Nhân 4 vì lệnh dài 4 byte; cộng từ `pc + 4` vì khi `beq` ở EX hay ở pha A thì `pc` đã hướng tới lệnh kế.
:::

:::thay-hoi
**`src/cpu_g1.v:155-161`**: Thứ tự ưu tiên của `next_pc`? **Trả lời:** reset, rồi đứng chờ (`stall`), rồi `eret`, `jr`, `j`/`jal`, rồi nhánh, cuối cùng `pc + 4`. Chuỗi `if ... else if` là bộ chọn có ưu tiên: dòng trên thắng dòng dưới.
:::

:::thay-hoi
**`src/cpu_g1.v:192`**: Vì sao nạp `instr` ở cùng cạnh chốt `pc`? **Trả lời:** Bộ nhớ lệnh trong FPGA đọc trễ một nhịp. Nạp lệnh kế tiếp bằng địa chỉ `pc_new` ngay trong cạnh pha A khiến lệnh có sẵn khi pha B của lệnh sau bắt đầu.
:::

:::thay-hoi
**`src/cpu_g1.v:221`**: `epc` nhớ gì khi nhận ngắt? **Trả lời:** `next_pc`, tức lệnh kế tiếp. Ở G1 lệnh vừa xong đã chạy trọn, nên quay về chạy lệnh kế tiếp. `eret` sau đó đặt `pc <= epc`.
:::

:::thay-hoi
**`src/bcd_unit.v:37`**: Vì sao cộng 3 vào chữ số `≥ 5`? **Trả lời:** Vì ngay sau đó dịch trái một bit (nhân đôi). Chữ số `≥ 5` nhân đôi cho `≥ 10`, không còn vừa 4 bit BCD. Cộng 3 trước thì nhân đôi cho `≥ 16`, phần thừa tự tràn sang chữ số kế đúng như đếm thập phân.
:::

:::thay-hoi
**`src/bcd_unit.v:66`**: Vì sao `cnt == 26` mà lại là 28 chu kỳ? **Trả lời:** `cnt` đếm 0 đến 26 là 27 bước đổi, vì 27 bit nhị phân đủ chứa `99 999 999`. Thêm một chu kỳ chốt đầu vào khi nhận `start`, tổng 28.
:::

## P5 · CP0, ngắt và nhịp cpu_ce

### Bản đồ

:::ban-do
Bài này dành cho người giữ chặng **ngắt** và **nhịp bước của CPU**. Nó gồm năm mảnh:

| Mảnh | File và dòng | Làm gì |
|---|---|---|
| Bộ điều khiển ngắt | `src/irq_ctrl.v` (62 dòng) | Gom 8 nguồn sự kiện, nhớ cái nào đang chờ, cái nào được phép, báo CPU bằng một dây `irq`. |
| Thanh ghi hệ thống và nhịp | `src/soc_regs.v` (87 dòng) | Bộ đếm chu kỳ, hệ số hiệu chỉnh, hệ số chia `CPU_CLK_DIV`, và **sinh xung `cpu_ce`** cho CPU. |
| CP0 ở G1 | `src/cpu_g1.v` dòng 107–117 (đọc), 164–167 và 214–224 (ghi, vào ngắt) | Ba thanh ghi ngắt: Status, Cause, EPC. |
| CP0 và ngắt ở G2 | `src/cpu_pipe.v` dòng 119–122, 150–158, 201–205, 246–259 | Cùng việc ở đường ống, phức tạp hơn vì nhiều lệnh đang chạy cùng lúc. |
| Quy tắc ngắt chính xác | tài liệu `pipeline-policy.md` mục "Ngắt chính xác (G2, Q5)" | Bảng quy tắc nhận ngắt, EPC, lệnh nào hủy lệnh nào chạy trọn. |

**Cách đọc bảng:** `irq_ctrl.v` và `soc_regs.v` đọc hết. Các đoạn của hai lõi đọc đúng khoảng dòng đã nêu. Phần nhận ngắt trong từng lõi bạn đã gặp sơ lược ở bài PC; ở đây đọc kỹ từng điều kiện.

Bài thử của chặng này: `bash tools/run_unit.sh irq soc_bus`, kết quả mong đợi `PASS irq_tb {{so:irq-tb}}` và `PASS soc_bus_tb {{so:soc-bus-tb}}`. Ngắt trong lõi được kiểm gián tiếp bằng chương trình `fw/tests/cpu/irq.s` qua `python tools/cosim_iss.py --g2 --rand 0`.
:::

### Câu hỏi mở bài

Đồng hồ cần chạy khi đang vẽ màn hình, đang chia số, đang đọc nút bấm. Nếu CPU phải liên tục hỏi "đến giờ chưa?" thì tốn lệnh và dễ bỏ lỡ. Cách khác là để ngoại vi **gọi** CPU khi có việc: đó là ngắt. Ba câu hỏi:

- Sự kiện đến lúc CPU đang bận thì có bị mất không?
- CPU đang chạy dở một lệnh thì ngắt chen vào chỗ nào, và sau đó quay về đâu?
- Vì sao CPU "không có đồng hồ riêng" mà vẫn chạy chậm hay nhanh theo ý muốn?

Câu trả lời ngắn, các mục sau chứng minh từng ý:

- Mỗi sự kiện bật một bit **chờ** (`pending`) và bit đó **giữ** cho đến khi CPU xóa. Không mất dù CPU bận.
- Ngắt chỉ chen vào ở **ranh giới giữa hai lệnh**. Địa chỉ quay về ghi vào thanh ghi **EPC**. Lệnh `eret` đưa CPU về đó.
- CPU nhận một xung **cho phép bước** (`cpu_ce`). Giãn xung cho thưa thì CPU chậm lại, mà không đổi clock.

### Trực giác

Hình dung CPU là **người thợ đang làm việc ở bàn**. Có tám cái **chuông cửa** (tám nguồn ngắt). Mỗi chuông có một cái **công tắc cho phép** (`enable`): người thợ chọn chuông nào được phép làm phiền. Mỗi chuông có một **tờ giấy nhắc** (`pending`): ai bấm chuông thì giấy nhắc được dán lên và **dán mãi** đến khi người thợ tự gỡ.

- Khi có tờ giấy nhắc **và** công tắc cho phép của chuông ấy đang bật, đèn báo `irq` sáng.
- Người thợ, **xong việc đang làm**, mới nhìn đèn. Thấy sáng thì ghi vào **sổ tay** (EPC) mình đang dừng ở đâu, rồi đi đến **bàn khẩn cấp** (địa chỉ `0x180`).
- Ở bàn khẩn cấp, làm việc xong thì ghi một dấu vào tờ giấy nhắc để gỡ nó, rồi dùng lệnh `eret` để quay về chỗ đã ghi trong sổ tay.

Còn bốn ý cần có.

**CP0 là gì.** CP0 là nhóm thanh ghi đặc biệt **dành cho ngắt**, đọc bằng lệnh `mfc0`, ghi bằng `mtc0`. WatchChip dùng ba cái: `$12` (Status), `$13` (Cause), `$14` (EPC).

**Status** gồm hai bit. Bit 0 là **IE** (cho phép ngắt chung). Bit 1 là **EXL** (đang xử lý ngắt). CPU chỉ nhận ngắt khi `IE = 1` và `EXL = 0`. Khi nhận ngắt, phần cứng đặt `EXL = 1` để **chặn ngắt lồng nhau**. `eret` đặt `EXL = 0` lại.

**Cause** cho biết nguồn nào đang gây ngắt: nằm ở các bit 15 đến 8 (mỗi bit một nguồn).

**cpu_ce (clock enable).** Chip chỉ có **một** clock hệ thống 50 MHz. CPU không có clock riêng, nó chỉ được "cho phép bước" khi `cpu_ce = 1`. Muốn CPU chậm lại thì cho xung này **thưa ra**. Lõi G1 cần **hai** xung cho một chu kỳ CPU (hai pha). Lõi G2 cần **một**.

### Cơ chế theo đường tín hiệu

Theo dõi một ngắt `ALARM` (nguồn số 3) đi vào lõi G1.

**1. Sự kiện.** Khối báo thức phát một xung `ev[3] = 1` kéo dài đúng một chu kỳ hệ thống (`irq_ctrl.v` dòng 17).

**2. Nhớ.** Ở cạnh clock đó, `pending[3]` được đặt lên 1 (dòng 46: `pending <= (pending & ~clr) | ev`). Từ giờ bit này **giữ** dù xung `ev` đã tắt.

**3. Lọc.** `ip = pending & enable` (dòng 33). Nếu firmware đã bật `enable[3] = 1` thì `ip[3] = 1` và `irq = |ip = 1` (dòng 34). Nếu `enable[3] = 0` thì `irq` vẫn bằng 0 nhưng `pending[3]` vẫn nhớ: bật `enable` sau đó sẽ nổ ngay.

**4. Chụp thời điểm.** Ở cạnh lên của `irq` (`irq && !irq_q`, dòng 49), `stamp` chụp `cycle_count`. Đó là cách đo "ngắt đến lúc nào".

**5. CPU nhận ở cuối lệnh.** Trong lõi G1 (`cpu_g1.v:166`) `take_irq = irq && IE && !EXL && !stall && cp0_op == 00`. Đúng thì `pc_new = 0x180`. Ở pha A, `epc <= next_pc` (địa chỉ lệnh **kế tiếp**) và `EXL <= 1` (dòng 220 đến 223).

**6. Xử lý.** Chương trình ở `0x180` đọc `Cause` bằng `mfc0`, biết nguồn nào, làm việc, rồi **ghi 1 vào bit tương ứng của `IRQ_PENDING`** (địa chỉ `0xFFFFFF48`) để gỡ giấy nhắc.

**7. Quay về.** `eret` đặt `pc <= epc` và `EXL <= 0` (dòng 157 và 219 của `cpu_g1.v`). CPU chạy tiếp lệnh kế tiếp của chương trình chính.

**8. Ở G2** mọi bước giống nhưng CPU có nhiều lệnh dở dang. Ngắt nhận ở **ranh giới giữa ID/EX**: lệnh ở tầng EX/MEM và MEM/WB chạy trọn; lệnh ở ID/EX bị **hủy**; EPC trỏ vào **lệnh cũ nhất chưa xong**, để sau `eret` nó được chạy lại.

### Bảng chu kỳ hoặc tính tay

:::suy-dan
**Đề bài.** Ba phép tính tay quanh chặng này.

1. Ghi `CPU_CLK_DIV = D` vào G1 với `D = 4`, `D = 5`, `D = 1`, rồi `D = 1526`. Giá trị D thực sự được dùng, và với `D = 1526` thì CPU chạy bao nhiêu chu kỳ mỗi giây (clock hệ thống 50 MHz)?
2. Cùng chu kỳ hệ thống, firmware ghi `0x08` vào `IRQ_PENDING` (để gỡ nguồn 3) và đúng lúc đó nguồn 3 lại phát sự kiện. `pending` ra sao? Và nếu viết ngược ưu tiên?
3. G2 có ba lệnh đang chạy: lệnh A ở EX/MEM, lệnh B (địa chỉ `0x84`) ở ID/EX, lệnh C (địa chỉ `0x88`) ở IF/ID. Ngắt đến. EPC bằng bao nhiêu và lệnh nào bị hủy?
---
**Phép 1: chuẩn hóa D và tốc độ.** Luật ép ở `norm` (soc_regs.v dòng 46 đến 51): G1 nhỏ hơn 2 thì thành 2; lẻ thì bỏ bit thấp nhất (làm chẵn xuống); G2 bằng 0 thì thành 1.

| D ghi vào | D thực sự dùng ở G1 | Xung `cpu_ce` cách nhau | Một chu kỳ CPU của G1 |
|---|---|---|---|
| 4 | 4 | `D/2 = 2` chu kỳ hệ thống | 4 chu kỳ hệ thống |
| 5 | **4** (lẻ bỏ bit 0) | 2 | 4 |
| 1 | **2** (nhỏ hơn 2 thành 2) | 1 | 2 |
| 1526 | 1526 | 763 | 1526 |

- Chu kỳ CPU của G1 dùng **hai** xung cpu_ce nên dài đúng `D` chu kỳ hệ thống. Vì vậy G1 cần `D` chẵn.
- `D = 1526`: tần số CPU `= 50 000 000 / 1526 ≈ 32 765` chu kỳ mỗi giây, xấp xỉ 32,768 kHz của thạch anh đồng hồ. Đây là lý do thí nghiệm "CPU chậm bằng thạch anh đồng hồ" chọn 1526.

**Phép 2: xóa và sự kiện cùng chu kỳ.** Dòng 46: `pending <= (pending & ~clr) | ev`.

- `pending[3] = 1` trước đó, `clr[3] = 1` (ghi 1 vào bit 3), `ev[3] = 1`. Tính: `(1 & ~1) | 1 = 0 | 1 = 1`. `pending[3]` **vẫn bằng 1**. Sự kiện **thắng** lệnh xóa, ngắt mới không bị mất.
- Nếu viết ngược `(pending | ev) & ~clr` thì ra `1 & 0 = 0`: sự kiện **bị nuốt**. Chạy thật bản ngược ở mục Sửa tại chỗ: `irq_tb` báo `loi IRQ-3 su kien thang lenh xoa`.

**Phép 3: EPC ở G2.** Quy tắc: EPC là địa chỉ của **lệnh cũ nhất chưa retire**: nếu có lệnh ở ID/EX thì `idex_pc`, nếu không thì `ifid_pc`, nếu không nữa thì `pc` (dòng 122).

- Lệnh B ở ID/EX: `EPC = 0x84`.
- Lệnh A (ở EX/MEM) **chạy trọn**. Lệnh B bị **hủy** (không ghi gì). Lệnh C ở IF/ID cũng bị bỏ (`ifid_v <= 0`, dòng 294). `pc <= 0x180`.
- Sau `eret`, CPU nạp lại từ `0x84`: B chạy rồi C chạy. Không lệnh nào bị chạy hai lần, không lệnh nào bị bỏ sót.
:::

### Trong chip

:::trong-chip
Mỗi đoạn trích dưới đây có đường dẫn file và số dòng, phía sau giải thích từng dòng sinh ra phần cứng gì.

**Bộ điều khiển ngắt: vỏ ngoài.**

{{trich:src/irq_ctrl.v:14-35@module irq_ctrl (}}

- **Dòng 15, 16** `clk`, `rst`.
- **Dòng 17** `ev`: 8 sự kiện, mỗi bit là một xung dài một chu kỳ.
- **Dòng 18** `cycle_count`: bộ đếm chu kỳ toàn hệ thống, để chụp thời điểm.
- **Dòng 19 đến 23** cổng bus ngoại vi: địa chỉ, dữ liệu ghi, ghi, đọc, dữ liệu đọc.
- **Dòng 24** `irq`: mức báo CPU, bằng OR của các `pending & enable`.
- **Dòng 25** `ip`: tám bit nguồn đang gây ngắt, đưa sang CP0 làm Cause.
- **Dòng 27** địa chỉ ba thanh ghi: `A_EN = 0x44`, `A_PEND = 0x48`, `A_STAMP = 0x4C`, tức `0xFFFFFF44`, `0xFFFFFF48`, `0xFFFFFF4C`.
- **Dòng 29 đến 31** các ô nhớ: `enable` (8 bit), `pending` (8 bit), `stamp` (32 bit), `irq_q` (nhớ `irq` của chu kỳ trước).
- **Dòng 33, 34** `ip = pending & enable`; `irq = |ip`. Đây là mạch **tổ hợp**, không chờ clock.

**Gỡ chờ bằng cách ghi 1.**

{{trich:src/irq_ctrl.v:36-37@// Các bit CPU muốn xóa}}

- **Dòng 37** `clr`: nếu đang ghi vào địa chỉ `A_PEND` thì `clr = bus_wdata[7:0]`, ngược lại 0. Bit nào bằng 1 trong dữ liệu ghi thì bit đó **được xóa**. Ghi 0 không làm gì.

**Trạng thái của khối ngắt.**

{{trich:src/irq_ctrl.v:39-59@always @(posedge clk) begin}}

- **Dòng 40 đến 42** reset: tất cả về 0.
- **Dòng 44 đến 46** `pending <= (pending & ~clr) | ev`: xóa các bit CPU yêu cầu **rồi** bật các bit có sự kiện mới. Dấu `| ev` đứng sau nên **sự kiện thắng**.
- **Dòng 47** ghi vào `A_EN` thì nạp `enable`.
- **Dòng 48** `irq_q <= irq`: nhớ `irq` của chu kỳ này để chu kỳ sau so.
- **Dòng 49** `if (irq && !irq_q) stamp <= cycle_count`: chỉ chụp ở **cạnh lên** của `irq`.
- **Dòng 50 đến 57** đọc: `bus_rdata` được nạp theo địa chỉ (`enable`, `pending`, `stamp`; địa chỉ khác thì 0). `bus_rdata` là ô nhớ **có clock**: giá trị giữ đến lần đọc sau.

**Thanh ghi hệ thống và hệ số chia.**

{{trich:src/soc_regs.v:34-53@localparam A_CYCLE}}

- **Dòng 34 đến 37** bốn địa chỉ: `CYCLE_COUNT = 0x00` (chỉ đọc), `CAL = 0x18`, `CPU_CLK_DIV = 0x8C`, `DIV_FLAGS = 0x90` (chỉ đọc).
- **Dòng 39** `d`: hệ số chia **đã chuẩn hóa**.
- **Dòng 40** `c`: bộ đếm chu kỳ tới xung `cpu_ce` kế.
- **Dòng 41** `p`: số chu kỳ hệ thống giữa hai xung, **đang dùng**.
- **Dòng 42** `period`: G1 lấy `D/2` (dịch phải một bit), G2 lấy `D`.
- **Dòng 46 đến 51** hàm `norm`: G1: nhỏ hơn 2 thì 2, ngược lại bỏ bit 0. G2: 0 thì 1.
- **Dòng 53** `cpu_ce = !rst && (c >= p - 1)`: đếm đủ `p` chu kỳ thì phát một xung. Đây là **mạch tổ hợp** so sánh `c` với `p - 1`.

**Cập nhật thanh ghi hệ thống.**

{{trich:src/soc_regs.v:55-84@always @(posedge clk) begin}}

- **Dòng 56 đến 62** reset: `d = 2` (G1) hoặc 1 (G2), `c = 0`, `p = 1`. Sau reset `cpu_ce = 1` mỗi chu kỳ (vì `c >= 0`).
- **Dòng 64** `cycle_count` đếm mỗi chu kỳ.
- **Dòng 65** `c <= cpu_ce ? 0 : c + 1`: về 0 khi có xung, ngược lại đếm tiếp.
- **Dòng 66** `if (cpu_ce) p <= period`: `p` **chỉ nạp lại khi có xung**. Hệ quả: D mới chỉ có hiệu lực **từ chu kỳ CPU kế tiếp**, không cắt ngang một khoảng đang đếm.
- **Dòng 67 đến 73** ghi: `CAL` nạp thẳng; `CPU_CLK_DIV` nạp qua `norm`; ghi vào địa chỉ chỉ-đọc bị bỏ qua.
- **Dòng 74 đến 82** đọc: `bus_rdata` theo địa chỉ.

**CP0 ở lõi G1: đọc.**

{{trich:src/cpu_g1.v:107-117@CP0}}

- **Dòng 107, 108** chú thích: CP0 là thanh ghi điều khiển ngắt, đọc bằng `mfc0`.
- **Dòng 109** `cp0_rd`: kết quả `mfc0`.
- **Dòng 110 đến 116** `case (f_rd)`, trong đó `f_rd` là số thanh ghi CP0 cần đọc, lấy từ trường `rd` của lệnh.
- **Dòng 112** `$12`: `{30'd0, status}`, hai bit Status (EXL, IE) ở bit 1 và 0.
- **Dòng 113** `$13`: `{16'd0, irq_ip, 8'd0}`, tức tám bit nguồn ngắt đặt ở **bit 15 đến 8**.
- **Dòng 114** `$14`: `epc`.
- **Dòng 115** số khác: 0.

**CP0 ở lõi G2: ghi, vào ngắt.**

{{trich:src/cpu_pipe.v:246-259@EX: tác dụng CP0}}

- **Dòng 246, 247** chỉ ghi CP0 khi lệnh ở EX hợp lệ và EX không bận.
- **Dòng 248 đến 250** `mtc0`: `$12` nạp `status <= opB[1:0]`; `$14` nạp `epc <= {opB[31:2], 00}`. Giá trị dùng là `opB` (đã lấy tắt).
- **Dòng 252** `eret` xóa EXL (`status[1] <= 0`).
- **Dòng 254 đến 257** nhận ngắt: `epc <= irq_epc` và `EXL <= 1`. Khối này đứng **sau** khối `mtc0`, nên nếu cùng cạnh clock thì nhận ngắt thắng (nhưng điều kiện `take_irq` đã chặn ngắt ngay cạnh lệnh CP0).
- **Dòng 258** `started` cho lệnh nhiều chu kỳ.

**Điều kiện nhận ngắt ở G2.**

{{trich:src/cpu_pipe.v:119-122@take_irq;}}

- **Dòng 119** `take_irq`: dây nhận ngắt.
- **Dòng 120** `irq_tr`: nhớ "đã nhận ngắt ở chu kỳ trước", để ghi dòng `INTERRUPT` vào vết **sau** khi lệnh ở EX/MEM xong.
- **Dòng 121** `last_cp0`: lệnh retire gần nhất có phải CP0 không.
- **Dòng 122** `irq_epc = idex_v ? idex_pc : ifid_v ? ifid_pc : pc`: **lệnh cũ nhất chưa xong**.

{{trich:src/cpu_pipe.v:201-205@nhận ngắt}}

- **Dòng 201** chú thích: không nhận ngắt khi EX bận, khi load-use đang chờ, ngay sau hoặc ngay trước lệnh CP0.
- **Dòng 202 đến 204** `take_irq` là AND của: CPU được bước, có `irq`, `IE = 1`, `EXL = 0`, EX không bận (`!stall_busy`), không load-use (`!stall_lu`), lệnh ở ID/EX không phải CP0, không phải lệnh nhiều chu kỳ, và lệnh retire gần nhất không phải CP0.
- **Dòng 205** `id_ok` có `!take_irq`: lệnh ở ID bị hủy khi nhận ngắt.
:::

### Bẫy và thầy hay hỏi

:::bay
**Bẫy 1: "Sự kiện đến lúc CPU bận thì bị bỏ."** Sai. `pending` là ô nhớ **giữ** bit cho tới khi CPU xóa. Sự kiện đến khi CPU đang `div` hay đang chạy trong ngắt kia vẫn nằm đó và phát ngắt sau. Chính lệnh xóa cũng **thua** sự kiện cùng chu kỳ (dòng 46), để không mất ngắt.
:::

:::bay
**Bẫy 2: "Ghi 0 vào `IRQ_PENDING` để xóa."** Sai. Cơ chế là **ghi 1 để xóa** (`clr = bus_wdata`, dòng 37). Ghi 0 không làm gì. Thử đảo thành ghi 0 xóa, `irq_tb` bắt ngay (xem thí nghiệm).
:::

:::bay
**Bẫy 3: "`irq` bật là CPU nhảy tới `0x180` ngay."** Sai. Cần đủ: `IE = 1`, `EXL = 0`, và ở G1 là cuối lệnh (không đứng chờ, không phải `mtc0`/`eret`); ở G2 là còn nhiều điều kiện hơn (không load-use, không EX bận, không sát lệnh CP0). Sau khi nhận, `EXL = 1` chặn ngắt lồng cho tới `eret`.
:::

:::bay
**Bẫy 4: "CPU chậm lại vì chia clock."** Sai. Chip chỉ có **một** clock 50 MHz. Giảm tốc độ CPU bằng cách cho `cpu_ce` **thưa ra**: mỗi `p` chu kỳ hệ thống mới có một xung. Toàn bộ mạch dùng chung một clock, chỉ có "được phép bước" là thưa.
:::

:::bay
**Bẫy 5: "`STAMP` ghi lúc sự kiện xảy ra."** Sai. `stamp` chụp `cycle_count` ở **cạnh lên của `irq`** (`irq_ctrl.v` dòng 49), tức lúc `pending & enable` chuyển từ 0 sang 1. Nếu sự kiện đến khi nguồn chưa được cho phép rồi firmware bật `enable` sau, `stamp` ghi lúc bật `enable`, không phải lúc sự kiện. Bài thử `irq_tb` có ca "STAMP chi chot o canh len" để giữ đúng điều này.
:::

### Sửa tại chỗ và ứng dụng

:::sua-tai-cho
**Cài lỗi rồi xem bài thử nào bắt.** Hai lỗi. Mỗi lần **chép file ra bản nháp rồi sửa bản nháp, không sửa file gốc**. Ở thư mục gốc project:

```bash
source tools/env.sh
mkdir -p work/mut
cp src/irq_ctrl.v work/mut/irq_ctrl.v
```

**Lỗi 1: lệnh xóa thắng sự kiện.** Trong `work/mut/irq_ctrl.v`, dòng 46, đổi `(pending & ~clr) | ev` thành `(pending | ev) & ~clr`. Dịch và chạy với bản nháp:

```bash
iverilog -g2005 -Wno-timescale -o work/mut/i.vvp tb/irq_tb.v work/mut/irq_ctrl.v
vvp work/mut/i.vvp | head -3
```

Kết quả đã chạy (12/11): `loi IRQ-3 su kien thang lenh xoa: pending=00 enable=08 irq=0` rồi `loi IRQ-4 chuan bi 0x0C: pending=04 ...` và `FAIL irq_tb 2 loi / 12 kiem tra`. Cách đọc: ca IRQ-3 cố ý cho lệnh xóa và sự kiện trùng chu kỳ; đáng lẽ `pending` còn bit 3, mạch lỗi để `pending=00`, ngắt đã bị nuốt.

**Lỗi 2: `ip` dùng OR thay vì AND.** Chép lại file gốc, rồi ở dòng 33 đổi `pending & enable` thành `pending | enable`:

```bash
cp src/irq_ctrl.v work/mut/irq_ctrl.v
# sửa dòng 33, rồi:
iverilog -g2005 -Wno-timescale -o work/mut/i.vvp tb/irq_tb.v work/mut/irq_ctrl.v
vvp work/mut/i.vvp | head -3
```

Kết quả đã chạy: `loi IRQ-1 pending=1, irq=0: pending=08 enable=00 irq=1 rv=xxxxxxxx`. Đọc ra: nguồn chưa được cho phép (`enable=00`) mà `irq` đã bằng 1. Nguồn bị tắt vẫn đánh thức được CPU, đúng cái công tắc `enable` sinh ra để ngăn.

**Thử thêm: sai nhịp `cpu_ce`.** Chép `src/soc_regs.v` ra bản nháp, ở dòng 53 đổi `p - 16'd1` thành `period - 16'd1` (so thẳng với `period` tổ hợp thay vì `p` đã nạp ở cạnh xung). Bài thử là chương trình firmware nên dịch lại cả chip:

```bash
python tools/fw_build.py fw/tests/soc/bus.s work/soc_bus.hex
SRC=$(ls src/*.v | grep -v soc_regs.v); H=$(ls tb/*.v | grep -v '_tb\.v$')
iverilog -g2005 -Wno-timescale -o work/mut/s.vvp tb/soc_bus_tb.v work/mut/soc_regs.v $SRC $H
vvp -n work/mut/s.vvp +imem=work/soc_bus.hex | tail -4
```

Kết quả đã chạy: `loi D moi tu chu ky CPU ke` rồi `FAIL soc_bus_tb 1 loi / 20 kiem tra`. Đọc ra: nửa sau lệnh ghi `CPU_CLK_DIV` đã chạy theo D mới, trong khi quy tắc là D mới chỉ có hiệu lực từ chu kỳ CPU kế tiếp.

**Đột biến sống sót.** Ở dòng 66 đổi `if (cpu_ce) p <= period;` thành `p <= period;` (nạp `p` mỗi chu kỳ thay vì chỉ ở xung). Chạy lại như trên: kết quả đã chạy là **`PASS soc_bus_tb 20`**, tức bài thử **không bắt được**. Điều đó có nghĩa `soc_bus_tb` không phân biệt hai cách nạp `p` này. Đó là một khoảng trống trong bộ thử (nhận định `verified` ở mức "bài thử vẫn PASS", còn hành vi hai bản khác nhau ở chỗ nào là `inference`). Khi thầy hỏi "bài thử có đủ chưa" thì đây là câu trả lời trung thực.

Xong thì xóa thư mục `work/mut/` hoặc để đó, nó không nằm trong chip.
:::

:::dung-o-dau
**Kỹ năng này dùng ở đâu khác.**

- **Mọi hệ thống nhúng** (vi điều khiển, bộ định thời) dùng ngắt để ngoại vi gọi CPU. Cặp "bit chờ giữ lại và bit cho phép" là khuôn chuẩn của mọi bộ điều khiển ngắt.
- **Hệ điều hành** có thanh ghi "địa chỉ quay về" và "cờ đang xử lý ngắt" giống EPC và EXL. Hiểu EXL chặn ngắt lồng là hiểu vì sao trình xử lý ngắt phải chạy gọn.
- **Clock enable thay vì nhiều clock**: trong thiết kế FPGA, dùng nhiều clock gây rắc rối đồng bộ. Cho mạch chậm chạy bằng "xung cho phép" trên cùng một clock là cách làm chuẩn.
- **Đọc ghi thanh ghi trạng thái "ghi 1 để xóa"**: gặp trong rất nhiều bộ điều khiển phần cứng (UART, bộ định thời, DMA). Nhờ nó, CPU xóa đúng cờ mình đã xử lý mà không đè lên cờ mới đến.
:::

### Tự kiểm và quay lại bức tranh

:::tu-luan
Firmware ghi `CPU_CLK_DIV = 7` vào lõi G1. Giá trị `D` thực sự là bao nhiêu và `cpu_ce` cách nhau bao nhiêu chu kỳ hệ thống? Một chu kỳ CPU dài bao lâu?
---
**Đáp án hoàn chỉnh.** `norm` cho G1: `7 ≥ 2` nên không bị nâng, nhưng 7 lẻ nên bỏ bit thấp nhất: `D = 6` (dòng 48 của `soc_regs.v`). `period = D/2 = 3`, nên xung `cpu_ce` cách nhau 3 chu kỳ hệ thống (đếm `c = 0, 1, 2` rồi `c >= 2` thì phát xung). Một chu kỳ CPU của G1 gồm hai xung, tức `2 × 3 = 6` chu kỳ hệ thống, bằng `D`. Ở 50 MHz, đó là 120 ns.
:::

:::tu-luan
Vì sao `pending` là ô nhớ giữ bit, mà không để `irq` đi thẳng từ sự kiện `ev`?
---
**Đáp án hoàn chỉnh.** Sự kiện `ev` chỉ là xung dài **một chu kỳ**. CPU có thể đang chạy lệnh `div` kéo dài hơn 30 chu kỳ hoặc đang xử lý ngắt khác, nên sẽ không thấy xung. Nếu `irq` đi thẳng từ `ev` thì ngắt bị mất. `pending` ghi nhớ xung và giữ đến khi CPU chủ động xóa, nên không bao giờ bỏ lỡ. Quy tắc "sự kiện thắng lệnh xóa cùng chu kỳ" (dòng 46) vá nốt lỗ hổng còn lại.
:::

:::tu-luan
Một ngắt đến khi lệnh `div` (33 chu kỳ) đang chạy ở EX của G2. Ngắt có bị nhận ngay không? EPC trỏ vào đâu?
---
**Đáp án hoàn chỉnh.** Không nhận ngay. Điều kiện `take_irq` có `!stall_busy` (dòng 202) và `idex_multi == 00` (dòng 203): lệnh nhiều chu kỳ ở EX chặn ngắt. Ngắt chờ đến khi `div` xong. Sau đó ngắt nhận ở ranh giới kế tiếp, EPC là lệnh cũ nhất chưa retire, thường là lệnh ngay sau `div` (bảng trong tài liệu chính sách ghi "EPC = lệnh sau `div`"). `div` chạy trọn, không bị hủy.
:::

:::tu-luan
Giải thích dòng `mfc0 $t0, $13` nhận được giá trị nào khi chỉ nguồn số 3 (ALARM) đang gây ngắt.
---
**Đáp án hoàn chỉnh.** `Cause` được ghép `{16'd0, irq_ip, 8'd0}` (dòng 113 của `cpu_g1.v`). Với `irq_ip = 0000 1000` (bit 3), tám bit đó nằm ở bit 15 đến 8: giá trị là `0x00000800` (bit 3 của IP nằm ở bit 11 của thanh ghi). Firmware chỉ cần dịch phải 8 bit rồi kiểm tra từng bit để biết nguồn nào.
:::

:::tu-luan
Vì sao nhận ngắt đặt `EXL = 1`, và nếu không có EXL thì xảy ra chuyện gì?
---
**Đáp án hoàn chỉnh.** `EXL` nhớ "đang trong trình xử lý ngắt" và chặn nhận thêm ngắt (điều kiện `!status[1]`). Nếu không có, `irq` vẫn đang bằng 1 khi CPU vừa nhảy tới `0x180`, nên CPU lập tức nhận ngắt lần nữa **trước khi** kịp xóa nguồn, ghi đè `epc` bằng địa chỉ trong chính trình xử lý và mất đường về chương trình chính. `EXL = 1` bảo đảm `epc` còn nguyên cho tới `eret`, rồi `eret` đặt `EXL = 0`.
:::

:::mcq id=KT-P5-01
? Trong WatchChip, ngắt ALARM đến đúng lúc firmware ghi `0x08` vào `IRQ_PENDING` để xóa nguồn đó. Dòng 46 của `irq_ctrl.v` cho `pending[3]` bằng bao nhiêu và vì sao?
- [ ] 0, vì lệnh xóa của CPU luôn có quyền ưu tiên cao hơn sự kiện ngoại vi
- [ ] 0, vì `~clr` đảo bit 3 về 0 rồi phép OR với sự kiện không đổi được nữa
- [x] 1, vì phép `| ev` đứng sau nên sự kiện mới thắng lệnh xóa
- [ ] Không xác định, vì hai tác động trong cùng một chu kỳ gây xung đột mạch
> Giải thích: `pending <= (pending & ~clr) | ev` tính `(1 & ~1) | 1 = 1`. Dấu OR với `ev` làm sau cùng nên sự kiện thắng. Thiết kế cố ý như vậy để ngắt không bị mất. Bản đảo thứ tự cho `pending=00` và `irq_tb` bắt được.
:::

:::mcq id=KT-P5-02
? Firmware ghi `CPU_CLK_DIV = 5` vào lõi G1. Chuyện gì xảy ra theo `norm` (`soc_regs.v` dòng 46 đến 51)?
- [ ] D = 5 được giữ nguyên, và `cpu_ce` cách nhau 2,5 chu kỳ hệ thống nên nhịp lệch dần
- [ ] Ghi bị bỏ qua hoàn toàn vì 5 lẻ không hợp lệ với G1, nên D giữ nguyên giá trị cũ
- [x] D = 4: bit thấp nhất bị bỏ để D chẵn, `cpu_ce` cách nhau 2 chu kỳ
- [ ] D = 6: làm tròn lên để D chẵn, nên `cpu_ce` cách nhau 3 chu kỳ hệ thống
> Giải thích: dòng 48 là `{v[15:1], 1'b0}`, tức xóa bit thấp nhất, làm chẵn **xuống**: `5 → 4`. Chu kỳ CPU của G1 cần đúng hai xung nên D phải chẵn. `period = 4/2 = 2`.
:::

:::mcq id=KT-P5-03
? Điều kiện `!status[1]` trong `take_irq` ở WatchChip (cờ EXL) nhằm mục đích gì?
- [ ] Để tắt toàn bộ ngắt vĩnh viễn kể từ sau khi đã nhận ngắt lần đầu tiên sau reset
- [x] Chặn ngắt lồng nhau: đang xử lý ngắt thì không nhận thêm, giữ nguyên EPC
- [ ] Để biết lệnh hiện tại là `mtc0` hay `eret` mà tạm thời không nhận ngắt
- [ ] Để báo cho firmware biết nguồn ngắt nào vừa gây ra yêu cầu mà không cần đọc Cause
> Giải thích: khi nhận ngắt, phần cứng đặt `EXL = 1`. Nếu không chặn, `irq` còn bằng 1 và CPU nhận ngắt lần nữa, ghi đè `epc` và mất đường về. `eret` đặt `EXL = 0` để nhận ngắt trở lại. Việc né `mtc0`/`eret` do điều kiện `cp0_op == 00`, không phải EXL.
:::

:::mcq id=KT-P5-04
? `mfc0 $t0, $13` ở WatchChip trả giá trị nào khi chỉ nguồn số 3 đang gây ngắt (`irq_ip = 0x08`)?
- [ ] `0x00000008`, vì Cause đặt các bit nguồn ở tám bit thấp nhất của thanh ghi
- [ ] `0x08000000`, vì Cause đặt các bit nguồn ở tám bit cao nhất của thanh ghi
- [x] `0x00000800`, vì Cause là `{16'd0, irq_ip, 8'd0}`, nguồn ở bit 15 đến 8
- [ ] `0x00000003`, vì Cause trả số thứ tự của nguồn ngắt
> Giải thích: dòng 113 của `cpu_g1.v`. `irq_ip = 0000 1000` đứng ở bit 15 đến 8, tức `0x0800`. Cause trả **mặt nạ bit** (mỗi nguồn một bit), không phải số thứ tự.
:::

:::mcq id=KT-P5-05
? Ở G2, ngắt đến khi một lệnh `div` đang chiếm EX. Điều kiện nào trong `take_irq` (`cpu_pipe.v:202-204`) ngăn nhận ngắt ngay?
- [ ] `!stall_lu`, vì lệnh `div` được coi như một lệnh load đang chờ dữ liệu
- [x] `!stall_busy` và `idex_multi == 2'b00`, vì EX đang bận với lệnh nhiều chu kỳ
- [ ] `status[0]`, vì lệnh `div` tự tắt cờ cho phép ngắt ngay khi bắt đầu chạy
- [ ] `!status[1]`, vì lệnh `div` đặt cờ `EXL` lên 1 trong suốt thời gian chạy
> Giải thích: `stall_busy` bằng 1 trong lúc `div` chưa xong và `idex_multi` khác 0 với lệnh `div` hoặc `bcd`. Ngắt chờ, EPC là lệnh sau `div`. `div` không bị hủy. `stall_lu` chỉ liên quan đến `lw`.
:::

:::mcq id=KT-P5-06
? G2 nhận ngắt khi lệnh B (`0x84`) ở ID/EX và lệnh C (`0x88`) ở IF/ID. EPC bằng bao nhiêu (dòng 122)?
- [ ] `0x88`, vì lệnh C là lệnh được nạp gần nhất vào đường ống
- [x] `0x84`, vì `irq_epc` lấy `idex_pc` khi ID/EX có lệnh: lệnh cũ nhất chưa xong
- [ ] `0x80`, vì EPC là địa chỉ của lệnh vừa retire cuối cùng trước khi ngắt
- [ ] `0x8C`, vì EPC luôn trỏ vào lệnh kế tiếp của lệnh cuối cùng trong chuỗi
> Giải thích: `irq_epc = idex_v ? idex_pc : ifid_v ? ifid_pc : pc`. B ở ID/EX nên EPC là `0x84`. B bị hủy và chạy lại sau `eret`; lệnh đã ở EX/MEM trở đi chạy trọn nên không phải chạy lại.
:::

:::mcq id=KT-P5-07
? Trong WatchChip, đổi dòng 53 của `soc_regs.v` thành `c >= period - 16'd1` (so thẳng `period`), `soc_bus_tb` báo gì?
- [ ] `PASS soc_bus_tb 20`, vì `p` và `period` luôn bằng nhau
- [x] `FAIL soc_bus_tb` với `loi D moi tu chu ky CPU ke`
- [ ] Biên dịch báo lỗi vì `period` là dây tổ hợp không được so sánh
- [ ] CPU chạy nhanh gấp đôi vì `period` nhỏ hơn `p`
> Giải thích: đã chạy thật ngày 12/11, in `FAIL soc_bus_tb 1 loi / 20 kiem tra`. `p` chỉ nạp lại ở xung `cpu_ce`, nên D mới có hiệu lực từ chu kỳ CPU kế. So thẳng `period` làm nửa sau của lệnh ghi D đã theo D mới.
:::

:::mcq id=KT-P5-08
? Khi nhận ngắt ở lõi G1, `epc <= next_pc` (`cpu_g1.v:221`). Vì sao EPC là địa chỉ lệnh kế tiếp mà không phải lệnh vừa chạy?
- [ ] Vì lệnh vừa chạy bị hủy và phải chạy lại sau `eret`
- [ ] Vì `eret` luôn cộng thêm 4 vào EPC trước khi nhảy
- [ ] Vì lệnh kế tiếp là lệnh quan trọng cần ưu tiên chạy lại sau ngắt
- [x] Vì ngắt chỉ nhận ở cuối lệnh, lệnh vừa chạy đã xong trọn vẹn
> Giải thích: G1 nhận ngắt ở pha A khi lệnh vừa hoàn thành (kể cả ghi thanh ghi và bộ nhớ). Quay về đúng chỗ là chạy lệnh kế tiếp. `next_pc` đã tính cả nhánh/nhảy, nên nếu lệnh vừa xong là `beq` nhảy thật thì EPC là đích nhánh.
:::

### Thầy chỉ vào dòng này

:::thay-hoi
**`src/irq_ctrl.v:46`**: Vì sao `| ev` đứng sau `& ~clr`? **Trả lời:** Để khi CPU xóa một bit và sự kiện mới của bit đó đến cùng chu kỳ thì bit vẫn bằng 1. Sự kiện thắng lệnh xóa nên không mất ngắt. Đảo thứ tự thì `irq_tb` báo `loi IRQ-3`.
:::

:::thay-hoi
**`src/irq_ctrl.v:33`**: `ip` tính thế nào? **Trả lời:** `pending & enable`: chỉ nguồn vừa đang chờ vừa được cho phép mới gây ngắt. `irq` là OR của tám bit đó. Nguồn chưa được cho phép vẫn được nhớ ở `pending`, bật `enable` sau là nổ.
:::

:::thay-hoi
**`src/soc_regs.v:66`**: Vì sao `p` chỉ nạp khi `cpu_ce`? **Trả lời:** Để D mới chỉ có hiệu lực từ chu kỳ CPU kế tiếp, không cắt ngang khoảng đang đếm. Đặc biệt ở G1, lệnh ghi `CPU_CLK_DIV` có hai pha, nửa sau vẫn phải chạy theo D cũ. Lưu ý: bản nạp `p` mỗi chu kỳ vẫn qua bài thử hiện có (đã chạy), nên chỗ này bài thử chưa kiểm chặt.
:::

:::thay-hoi
**`src/cpu_g1.v:113`**: `mfc0 $13` trả gì? **Trả lời:** `{16'd0, irq_ip, 8'd0}`: tám bit nguồn ngắt ở bit 15 đến 8, 16 bit cao và 8 bit thấp bằng 0. Đó là mặt nạ bit của các nguồn đang chờ và được phép.
:::

:::thay-hoi
**`src/cpu_pipe.v:122`**: EPC của G2 lấy từ đâu? **Trả lời:** Từ lệnh **cũ nhất chưa retire**: `idex_pc` nếu ID/EX có lệnh, không thì `ifid_pc`, không thì `pc`. Lệnh ở ID/EX bị hủy nên phải chạy lại sau `eret`; lệnh ở EX/MEM trở đi chạy trọn.
:::

:::thay-hoi
**`src/cpu_pipe.v:202-204`**: Những điều kiện nào chặn ngắt ở G2? **Trả lời:** Không có `irq`, `IE = 0`, `EXL = 1`, EX đang bận nhiều chu kỳ, load-use đang chờ, lệnh ở ID/EX là CP0 hoặc nhiều chu kỳ, hoặc lệnh retire gần nhất là CP0. Mỗi điều kiện có lý do: không hủy dở một lệnh nhiều chu kỳ và không nhận ngắt khi CP0 vừa đổi `Status`.
:::

## C0 · Một lệnh đi qua năm người

### Bản đồ

:::ban-do
Bài này dành cho **cả nhóm**. Năm bài P chia chip thành năm lát. Thầy hỏi xoáy sẽ không hỏi theo lát: thầy chỉ vào **một tín hiệu đi từ lát này sang lát kia**. Bài C0 theo dõi đúng hai lệnh nối nhau (`lw` rồi `beq`) qua cả năm lát, để mỗi người biết lát bên cạnh đưa gì cho mình.

| Lát | Người giữ | Lệnh `lw` đi qua đây thế nào | Lệnh `beq` đi qua đây thế nào |
|---|---|---|---|
| ID, control, regfile | TV3 | giải mã: `mem_read`, `mem_to_reg`, nới dấu hằng số, đọc `$zero` | giải mã: `branch = 01`, đọc cả hai thanh ghi nguồn |
| EX, số học | TV1 | ALU cộng thanh ghi với hằng số ra **địa chỉ** | so sánh `opA == opB` |
| Hazard, forwarding, MEM, WB | TV2 | đọc DMEM ở MEM, ghi `$t0` ở WB; gây ra một bong bóng | nhận `$t0` bằng forwarding 01 sau bong bóng |
| IF, PC, nhánh | TV4 | nạp lệnh, giữ lệnh khi đứng chờ | tính đích, đổi PC, xóa hai lệnh nạp nhầm |
| CP0, ngắt, `cpu_ce` | TV5 | `cpu_ce` cho phép mọi băng chuyền bước | ngắt chỉ được nhận ở ranh giới an toàn |

Chương trình dùng xuyên suốt bài (6 lệnh, ở địa chỉ 0x00 đến 0x14):

```
0x00  sw    $zero, 0x800($zero)    # M[0x800] = 0, để lw có số 0 mà đọc
0x04  lw    $t0, 0x800($zero)      # $t0 = 0
0x08  beq   $t0, $zero, L          # $t0 = 0 nên nhảy thật, hằng số imm = 2
0x0C  addiu $t1, $zero, 1          # nạp nhầm, phải bị xóa
0x10  addiu $t2, $zero, 2          # nạp nhầm, phải bị xóa
0x14  L: addiu $t3, $zero, 3       # lệnh đích
```

Đã chạy thật trên lõi G2 (12/11): bộ kiểm đòi `# bubbles 3` và cả sáu giá trị cuối đều khớp ISS (`OK c0 4 dong trace`). Chu kỳ rời trạm WB của ba lệnh cuối là **5, 7, 10** (lệnh `sw` rời ở chu kỳ 4). Cả bài xoay quanh ba con số 5, 7, 10 đó.

Bài thử của bài này: `bash tools/run_unit.sh hazard control regfile`, mong đợi `PASS hazard_tb {{so:hazard-tb}}`, `PASS control_tb {{so:control-tb}}`, `PASS regfile_tb {{so:regfile-tb}}`. Chương trình mẫu cùng dạng nằm ở `fw/tests/hazard/branch.s` (dòng `lw` rồi `beq` có chú thích "stall 1, nhảy: 2"), kiểm bằng `python tools/cosim_iss.py --g2 --rand 0`.
:::

### Câu hỏi mở bài

Một lệnh trong chip không thuộc về một người. Nó là một **gói** đi từ tầng này sang tầng kia, mỗi tầng do một người giữ. Ba câu hỏi để cả nhóm trả lời được sau bài này:

- Khi `beq` cần số `$t0` mà `lw` chưa lấy xong, **ai** bắt chờ, **ai** đưa số cho, và đưa ở **tầng nào**?
- Khi `beq` nhảy thật, hai lệnh nạp nhầm bị xóa **ở đâu**, và vì sao chúng không kịp ghi gì?
- Thầy hỏi một tín hiệu, bạn trả lời được nó **đến từ lát nào, đi sang lát nào** trong 5 giây không?

Trả lời ngắn, các mục sau chứng minh:

- Tầng ID (TV2 cùng TV3) thấy `lw` ở EX mà `beq` ở ID cần đúng thanh ghi đó, nên **giữ `beq` lại một chu kỳ** (`stall_lu`). Sau đó số `$t0` đến EX qua đường **forwarding 01** (lấy từ trạm WB).
- Hai lệnh nạp nhầm bị chặn ở hai chỗ: một ở **ID** (`id_ok` có `!take`), một ở **IF** (`ifid_v <= !take`). Cả hai chưa vào EX nên không ghi gì.
- Ghi nhớ bốn tín hiệu qua lại giữa các lát: `idex_dst`, `fwd_a`, `take`, `cpu_ce`.

### Trực giác

Hình dung **dây chuyền năm trạm** trong nhà máy làm bánh. Mỗi trạm là một người.

- Trạm 1 (**IF**, TV4): lấy phiếu việc kế tiếp từ chồng phiếu.
- Trạm 2 (**ID**, TV3): đọc phiếu, lấy nguyên liệu từ tủ (`regfile`), ghi chú "việc này cần gì".
- Trạm 3 (**EX**, TV1): làm phép tính, hoặc so sánh hai nguyên liệu.
- Trạm 4 (**MEM**, TV2): vào kho lấy hoặc cất đồ.
- Trạm 5 (**WB**, TV2): cất thành phẩm vào tủ.

Và còn **người quản đốc** (cũng TV2, `hazard.v`) đứng cạnh dây chuyền, nhìn xem phiếu nào cần nguyên liệu mà trạm trước chưa làm xong. Một **chiếc còi nhịp** (`cpu_ce`, TV5) quyết định mọi trạm chuyển một bước cùng lúc.

Chuyện của hai phiếu:

- Phiếu **`lw`** nói: "lấy một túi ở kho, đặt tên `$t0`". Túi chỉ lấy được ở trạm 4, và đến trạm 5 mới cất vào tủ.
- Phiếu **`beq`** ngay sau nói: "nếu túi `$t0` rỗng thì nhảy sang phiếu L". `beq` cần `$t0` ở trạm 3, nhưng lúc đó túi còn ở trạm 4. Quản đốc ra hiệu: **`beq` đứng chờ một nhịp**. Nhịp sau, túi nằm ở trạm 5; quản đốc cho phép **chuyền tay** túi thẳng vào trạm 3 (đó là forwarding), không đợi nó vào tủ.
- Khi `beq` so xong và thấy phải nhảy, hai phiếu đã được lấy ra từ chồng nhầm. Trạm 2 và trạm 1 **vứt** hai phiếu đó. Chúng chưa tới trạm 3 nên chưa làm gì hỏng.

Còn bốn ý cần có.

**Một chu kỳ trong bài này là một nhịp `cpu_ce`.** Ở lõi G2 với `CPU_CLK_DIV = 1`, mỗi chu kỳ hệ thống đều có `cpu_ce = 1`, nên một chu kỳ trong bảng cũng là một chu kỳ hệ thống. Nếu D lớn hơn thì mọi cột bảng dãn ra D lần, thứ tự không đổi.

**Bong bóng** là một ô trống đi qua dây chuyền: lệnh hợp lệ (`idex_v = 0`) mà không ghi gì. Bài đếm bong bóng bằng khoảng cách giữa các chu kỳ rời WB: rời ở chu kỳ 5 rồi 7 nghĩa là chen một bong bóng ở giữa.

**Hai nguồn trễ khác nhau.** Chờ load-use (1 chu kỳ) là do **dữ liệu**. Xóa lệnh nạp nhầm (2 chu kỳ) là do **hướng đi**. Hai việc do hai lát khác nhau giữ, thầy hay hỏi lẫn lộn.

**G1 và G2 cùng chạy chương trình này nhưng khác hẳn bên trong.** G1 xử lý từng lệnh trọn vẹn rồi mới sang lệnh kế (hai pha A và B), nên không có hazard, không cần forwarding, và chương trình này không có bong bóng nào. Bài tập trung vào G2 vì thầy hay hỏi chỗ có lệnh chen nhau.

### Cơ chế theo đường tín hiệu

Theo dõi từng tầng, từng người, theo thứ tự `lw` rồi `beq`. Đánh số chu kỳ từ lúc `lw` vào tầng IF (chu kỳ 1).

**1. Chu kỳ 1, IF (TV4).** `ifid_ins <= imem[pc]` nạp `lw` ở địa chỉ 0x04. PC tăng lên 0x08 (`pc + 4`).

**2. Chu kỳ 2, `lw` ở ID, `beq` ở IF.** TV3: `control` thấy `op = 0x23` và bật `alu_src`, `mem_read`, `mem_to_reg`, `reg_write` (control.v dòng 87). Hằng số `0x800` được nới dấu (`imm_x`). `regfile` đọc `$zero` ra 0. `d_dst = f_rt` tức `$t0` (thanh ghi 8). `beq` được nạp.

**3. Chu kỳ 3, `lw` ở EX (TV1), `beq` ở ID (TV3).** TV1: ALU cộng `opA = 0` với `alu_b = idex_imm = 0x800` ra địa chỉ 0x800. TV3 giải mã `beq`: `branch = 01`, `uses_rs = uses_rt = 1`. TV2 (`hazard.v`) thấy `idex_mem_read = 1`, `idex_dst = 8`, và `ifid_rs = 8`, nên `stall_lu = 1`. Hệ quả: `id_ok = 0`, ID/EX nhận **một bong bóng**, IF/ID và PC **giữ nguyên** (cpu_pipe.v dòng 292).

**4. Chu kỳ 4, `lw` ở MEM (TV2), `beq` vẫn ở ID.** `stall_lu` về 0 vì lệnh ở EX bây giờ là bong bóng. TV2: MEM đọc `dmem[0x800 >> 2]` vào `mw_mdata`. `beq` đi tiếp sang ID/EX ở cuối chu kỳ này. Lệnh 0x08 (nạp nhầm số 1) được nạp vào IF/ID.

**5. Chu kỳ 5, `lw` ở WB, `beq` ở EX.** TV2: `wb = mw_m2r ? wb_ld : mw_res` ra giá trị 0. `fwd_a = 01` vì `memwb_dst == idex_rs == 8`. `opA = wb = 0` (dòng 131). TV1: `eq = (opA == opB)` bằng 1 vì `opB` là `$zero`. `take = 1`. `lw` **rời WB ở chu kỳ 5** (đúng con số 5 trong trace). `$t0` được ghi vào regfile ở cạnh clock cuối chu kỳ.

**6. Cuối chu kỳ 5, TV4 đổi hướng.** `pc <= tgt = idex_pc4 + {imm[29:0], 00} = 0x0C + 8 = 0x14`. `ifid_v <= !take = 0`: lệnh 0x0C vừa nạp **bị bỏ**. Còn lệnh 0x08 đang ở ID bị chặn bởi `id_ok = ... && !take = 0`: ID/EX nhận bong bóng.

**7. Chu kỳ 6.** IF/ID rỗng, ID/EX là bong bóng, `beq` ở MEM. TV4 nạp lệnh 0x14 vào IF/ID ở cuối chu kỳ.

**8. Chu kỳ 7.** Lệnh 0x14 ở ID, `beq` ở WB: **`beq` rời WB ở chu kỳ 7**. Từ `lw` (chu kỳ 5) đến `beq` (chu kỳ 7) cách **2**, nghĩa là có **1** bong bóng (load-use).

**9. Chu kỳ 8 đến 10.** Lệnh 0x14 qua EX, MEM, WB và **rời WB ở chu kỳ 10**. Từ `beq` (7) đến lệnh đích (10) cách **3**, nghĩa là có **2** bong bóng (xóa nạp nhầm). Tổng `1 + 2 = 3`, đúng dòng `# bubbles 3`.

**10. Nhịp cpu_ce (TV5) bao trùm tất cả.** Mỗi bước trên xảy ra ở cạnh clock có `cpu_ce = 1` (`else if (cpu_ce)` ở cpu_pipe.v dòng 240). Nếu ngắt đến ở bất kỳ bước nào, `take_irq` chỉ thành 1 khi không rơi vào bước 3 (đang `stall_lu`), không rơi vào lệnh CP0, và EX không bận.

### Bảng chu kỳ hoặc tính tay

:::suy-dan
**Đề bài.** Điền bảng vị trí của năm lệnh (`lw`, `beq`, 0x0C, 0x10, 0x14) qua mười chu kỳ, rồi trả lời.

1. Ở chu kỳ nào `beq` bị giữ, và `beq` ở tầng nào trong hai chu kỳ đó?
2. Ở chu kỳ nào có `fwd_a = 01`? Nếu chèn thêm một lệnh độc lập giữa `lw` và `beq` thì `fwd_a` bằng bao nhiêu và có bong bóng load-use không?
3. Hai lệnh nạp nhầm (0x08 trong bảng bên dưới tính là lệnh sau `beq`, địa chỉ 0x0C và 0x10 trong chương trình) bị xóa ở tầng nào, ở chu kỳ nào?
4. Đổi `beq` thành `bne` với cùng dữ liệu (`$t0 = 0`). Tổng bong bóng là bao nhiêu?
---
**Lưu ý đánh số.** Ba lệnh sau `sw` là `lw` (0x04), `beq` (0x08), lệnh nạp nhầm A (0x0C), lệnh nạp nhầm B (0x10), lệnh đích L (0x14). Bảng dưới gọi A và B cho gọn. Chu kỳ 1 là lúc `lw` vào IF.

| Chu kỳ | IF | ID | EX | MEM | WB |
|---|---|---|---|---|---|
| 1 | lw | | | | |
| 2 | beq | lw | | | |
| 3 | A | beq (giữ) | lw | | |
| 4 | A | beq | bong bóng | lw | |
| 5 | B | A (bị chặn) | beq (nhảy) | bong bóng | lw |
| 6 | L | rỗng | bong bóng | beq | bong bóng |
| 7 | | L | bong bóng | bong bóng | beq |
| 8 | | | L | bong bóng | bong bóng |
| 9 | | | | L | bong bóng |
| 10 | | | | | L |

Cách đọc bảng: một bong bóng đi từ EX (chu kỳ 4) xuống MEM (5), WB (6): nó là bong bóng của load-use. Hai bong bóng của nhánh đi từ EX (6 và 7) xuống WB (8 đến 9). Hàng "IF" ở chu kỳ 3: IF/ID và PC **giữ nguyên** (A vẫn là lệnh kế sẽ nạp). Bảng này đã đối chiếu với trace thật (rời WB ở 5, 7, 10).

**Câu 1.** `beq` bị giữ ở **chu kỳ 3 và 4**, cả hai chu kỳ đều ở tầng ID. Ở chu kỳ 3, `stall_lu = 1`. Ở chu kỳ 4, `lw` đã sang MEM nên `idex_mem_read = 0` và `stall_lu = 0`, `beq` tiến sang EX ở chu kỳ 5.

**Câu 2.** `fwd_a = 01` ở **chu kỳ 5** (`lw` ở WB, `beq` ở EX, `memwb_dst = 8 = idex_rs`). Nếu chèn một lệnh độc lập (ví dụ `addiu $t4, $zero, 9`) giữa `lw` và `beq`: `beq` ở ID khi `lw` đã ở MEM nên **không còn load-use**, không chờ; đến EX thì `lw` ở WB nên vẫn `fwd_a = 01`. Tổng bong bóng load-use giảm từ 1 xuống 0. (Cùng quy tắc với `fw/tests/hazard/load_use.s`: cách 1 lệnh thì 0 chờ.)

**Câu 3.** Lệnh A (0x0C) bị chặn **ở ID ở chu kỳ 5** nhờ `id_ok = ifid_v && !take && ...` (ID/EX nhận bong bóng). Lệnh B (0x10) vừa nạp ở cuối chu kỳ 5 bị bỏ vì `ifid_v <= !take = 0`, nên ở chu kỳ 6 IF/ID rỗng. Cả hai **chưa bao giờ vào EX**.

**Câu 4.** `bne` với `$t0 = 0`: `idex_br == 2'b10 && !eq` bằng 0, `take = 0`. Chỉ còn 1 bong bóng của load-use: tổng `1`. (Cùng quy tắc với `fw/tests/hazard/branch.s`: nhánh không nhảy mất 0.) Đây là con số chưa chạy riêng cho `bne` trong bài này, ghi `inference` từ code `take` cộng với dòng "beq không nhảy: 0" của `branch.s`.
:::

### Trong chip

:::trong-chip
Các đoạn dưới đây là đường đi của hai lệnh, theo thứ tự tầng. Mỗi đoạn có thêm ghi chú "ai sang ai".

**TV3 giải mã `lw` và `beq`.**

{{trich:src/control.v:87-92@6'h23:}}

- **Dòng 87** `lw`: `i_alu(A_ADD, E_SE, 1)` bật `alu_src = 1` (B của ALU là hằng số), nới dấu hằng số, ghi vào `rt`, đọc `rs`. Thêm `mem_read = 1`, `mem_to_reg = 1`.
- **Dòng 88 đến 91** `sw`: không ghi thanh ghi, có `mem_write`, đọc cả `rs` và `rt` (cần `rt` làm dữ liệu cất).
- **Dòng 92** `beq`: **chỉ** `branch = 2'b01` và đọc cả `rs`, `rt`. Không `alu_src`, không `reg_write`. Việc so sánh để ở EX (TV1 và TV4 chia nhau).

**TV3 nới dấu và đọc thanh ghi.**

{{trich:src/cpu_pipe.v:98-99@wire [31:0] imm_x}}

- **Dòng 98, 99** `imm_x`: `ext = 01` thì mở rộng bằng 0, `ext = 10` thì đặt vào nửa cao (`lui`), còn lại (`E_SE`) nới dấu: chép bit 15 của `imm16` vào 16 bit cao. `lw` dùng E_SE nên `0x0800` ra `0x00000800`.

{{trich:src/cpu_pipe.v:107-110@wire [31:0] rs_v}}

- **Dòng 108** `we_rf`: ghi thanh ghi chỉ khi có `cpu_ce`, lệnh ở MEM/WB hợp lệ và có `reg_write`: lát TV2 (WB) quyết định, TV3 (regfile) thực thi.
- **Dòng 109, 110** `regfile` với `G_BYPASS(1)`: cổng ghi lấy từ trạm WB (`mw_dst`, `wb`), hai cổng đọc theo `f_rs`, `f_rt` của lệnh ở ID.

**TV3 và TV2: bypass trong chính regfile.**

{{trich:src/regfile.v:41-45@wire byp1}}

- **Dòng 41, 42** `byp1`, `byp2`: bật khi đang ghi (`we`) đúng thanh ghi mà lệnh ở ID đang đọc. Lúc đó đưa luôn `wd` ra, không đợi ghi xong. Đây là đường lấy tắt **thứ ba**, dành cho lệnh ở ID khi nguồn đang ở WB (cách nhau hai lệnh).
- **Dòng 45** `rd1`: thanh ghi 0 luôn ra 0; không thì ưu tiên bypass.

**TV2 quản đốc: đứng chờ.**

{{trich:src/hazard.v:39-40@assign stall_lu}}

- **Dòng 39** `stall_lu`: lệnh ở EX là load (`idex_mem_read`), đích khác 0, lệnh ở ID hợp lệ...
- **Dòng 40** ...và lệnh ở ID **thật sự đọc** rs hoặc rt (`uses_rs`, `uses_rt` do TV3 phát) trùng với đích đó. `beq` đọc cả hai nên bị giữ; `addiu` không đọc `rt` nên không bị giữ oan.

**TV2 quản đốc: chuyền tay.**

{{trich:src/hazard.v:44-47@Toán hạng A}}

- **Dòng 46** `fwd_a = 10`: lệnh ở EX/MEM ghi đúng `rs` của lệnh ở EX. **Mới hơn** nên ưu tiên.
- **Dòng 47** `fwd_a = 01`: lệnh ở MEM/WB ghi đúng `rs`. Trong bài này `lw` ở WB, nên đường 01 được chọn.
- **Dòng 48** không trùng: 00, dùng giá trị đã đọc ở ID.

**TV1 chọn toán hạng và tính.**

{{trich:src/cpu_pipe.v:131-136@wire [31:0] opA}}

- **Dòng 131, 132** `opA`, `opB`: chọn một trong ba nguồn theo `fwd`: `exm_res` (10), `wb` (01), hoặc giá trị đã đọc ở ID (00).
- **Dòng 133** `alu_b = idex_asrc ? idex_imm : opB`: `lw` chọn hằng số, `beq` chọn `opB`.
- **Dòng 136** ALU cộng cho `lw` (ra địa chỉ); với `beq` kết quả ALU **không dùng**: cổng `alu_zero` nằm trong `unused_ok` (dòng 302).

**TV1 và TV4: so sánh và đổi hướng.**

{{trich:src/cpu_pipe.v:176-182@wire eq}}

- **Dòng 176** `eq = (opA == opB)`: so sánh **riêng**, không qua ALU.
- **Dòng 177, 178** `take`: lệnh ở EX hợp lệ, EX không bận, và (là `beq` mà bằng, hoặc `bne` mà khác, hoặc nhảy, hoặc `eret`).
- **Dòng 182** đích của nhánh: `idex_pc4 + {idex_imm[29:0], 2'b00}`. Với `beq` ở 0x08 và `imm = 2`: `0x0C + 8 = 0x14`.

**TV4 và TV3: xóa lệnh nạp nhầm.**

{{trich:src/cpu_pipe.v:200-205@quyết định tầng ID}}

- **Dòng 205** `id_ok`: lệnh ở ID chỉ đi tiếp nếu hợp lệ **và** không `take` **và** không `stall_lu` **và** không `take_irq`. Một trong ba lý do bất kỳ biến lệnh ở ID thành bong bóng.

{{trich:src/cpu_pipe.v:291-296@IF/ID và PC}}

- **Dòng 292** `if (!stall_lu)`: khi đứng chờ, PC và IF/ID **không đổi**.
- **Dòng 293** `pc`: ưu tiên `take_irq` (0x180), rồi `take` (đích nhánh), rồi `pc + 4`.
- **Dòng 294** `ifid_v <= !take && !take_irq`: lệnh vừa nạp bị coi là rỗng nếu vừa đổi hướng.

**TV2: MEM rồi WB.**

{{trich:src/cpu_pipe.v:262-265@mw_lmmio <=}}

- **Dòng 262** `mw_lmmio`: nhớ lệnh load này đọc ngoại vi (MMIO) hay bộ nhớ dữ liệu.
- **Dòng 265** `mw_mdata`: đọc `dmem[exm_res[11:2]]` nếu địa chỉ nằm trong DMEM, ngoài ra đọc 0.

{{trich:src/cpu_pipe.v:194-195@wire [31:0] wb_ld}}

- **Dòng 194** `wb_ld`: dữ liệu `lw` đến từ ngoại vi (`bus_rdata`, do TV5 giữ) hay từ DMEM.
- **Dòng 195** `wb`: lệnh load lấy `wb_ld`, lệnh khác lấy kết quả tính `mw_res`. Cùng giá trị này **vừa** ghi vào regfile **vừa** chuyền tay vào EX qua `fwd = 01`.

**TV5: ngắt chỉ chen khi an toàn.**

{{trich:src/cpu_pipe.v:202-204@assign take_irq}}

- Điều kiện có `!stall_lu` và `!stall_busy`: ngắt **không** nhận giữa lúc `beq` đang bị giữ ở ID (chu kỳ 3 của bảng), và không nhận khi `div`/`bcd` đang chiếm EX.
:::

### Bẫy và thầy hay hỏi

:::bay
**Bẫy 1: "`lw` rồi `beq` phải chờ hai chu kỳ."** Sai. Chờ **một** chu kỳ load-use. Hai chu kỳ là bong bóng **sau khi nhảy thật** (xóa hai lệnh nạp nhầm), do lát khác giữ. Nếu nhánh quyết định ở ID thì mới phải chờ hai, vì `$t0` chỉ có sau MEM. Quyết định ở EX tận dụng forwarding nên chỉ chờ một.
:::

:::bay
**Bẫy 2: "Hai lệnh nạp nhầm chạy rồi mới bị hủy."** Sai. Chúng bị chặn ở **ID và IF**, trước khi vào EX, nên không ghi thanh ghi, không ghi bộ nhớ. Thử bỏ chặn (đột biến `ifid_v <= !take_irq`) thì lệnh nạp nhầm chạy thật và co-sim ISS bắt được.
:::

:::bay
**Bẫy 3: "Forwarding 10 lấy dữ liệu của `lw`."** Sai. Đường 10 đưa `exm_res` là **địa chỉ** mà `lw` vừa tính (kết quả ALU). Dữ liệu của `lw` chỉ tồn tại sau MEM, nên dùng được từ đường 01 hoặc bypass của regfile. Đó là lý do `lw` rồi dùng ngay thì **bắt buộc** chờ một chu kỳ.
:::

:::bay
**Bẫy 4: "Mỗi người chỉ cần biết lát của mình."** Sai. Thầy hỏi tín hiệu đi qua biên giới. Ví dụ `uses_rt` do TV3 phát nhưng TV2 dùng trong `stall_lu`; `take` do TV1 tính nhưng TV4 dùng để đổi PC. Bạn phải nói được tín hiệu **đến từ ai, đi sang ai**.
:::

**Mười lăm câu chéo.** Mỗi lát hỏi ba câu cho lát bên cạnh. Mỗi câu ghi người hỏi, người đáp, dòng code, và lời đáp 2 đến 3 câu. Cả nhóm đọc hết, không chỉ đọc câu của mình.

:::thay-hoi
**Hỏi chéo 1 (TV1 hỏi TV3): `src/control.v:87`.** Vì sao ALU của `lw` nhận hằng số mà không nhận `rt`? Ai quyết? **Trả lời:** TV3: `i_alu(A_ADD, E_SE, 1)` bật `alu_src = 1`, nên `alu_b = idex_imm` (cpu_pipe.v dòng 133). `rt` là **đích** của `lw` chứ không phải nguồn, nên `uses_rt` không bật và không bị `stall_lu` chờ oan.
:::

:::thay-hoi
**Hỏi chéo 2 (TV1 hỏi TV2): `src/hazard.v:47`.** Khi `lw` chưa xong, `beq` ở EX lấy số `$t0` từ đâu? **Trả lời:** TV2: sau một chu kỳ chờ, `lw` ở WB, `memwb_dst == idex_rs` nên `fwd_a = 01` và `opA = wb`. Không lấy được ở đường 10 vì lúc `lw` ở EX/MEM trong `exm_res` mới chỉ có địa chỉ.
:::

:::thay-hoi
**Hỏi chéo 3 (TV1 hỏi TV4): `src/cpu_pipe.v:302`.** `alu_zero` của ALU em làm gì với `beq`? **Trả lời:** TV4: không dùng. `beq` so `eq = (opA == opB)` riêng ở dòng 176 và đưa vào `take`. `alu_zero` nằm trong `unused_ok` nên không có trong tổ hợp nhánh.
:::

:::thay-hoi
**Hỏi chéo 4 (TV2 hỏi TV3): `src/hazard.v:40`.** Vì sao `stall_lu` cần `uses_rs` và `uses_rt` do control phát? **Trả lời:** TV3: để chỉ chờ khi lệnh ở ID **thật sự đọc** thanh ghi đó. `beq` đọc cả hai nên chờ; `addiu` chỉ đọc `rs` nên lấy `rt` trùng đích của `lw` cũng không chờ (đúng ca trong `fw/tests/hazard/load_use.s`).
:::

:::thay-hoi
**Hỏi chéo 5 (TV2 hỏi TV1): `src/cpu_pipe.v:265`.** Địa chỉ `lw` em tính ra đi vào DMEM thế nào? **Trả lời:** TV1: kết quả ALU nằm ở `exm_res`; MEM dùng `exm_res[11:2]` làm chỉ số từ trong `dmem` nếu `exm_res[31:12] == 0` (`in_dmem`). Hai bit thấp bị bỏ vì `lw` căn theo từ.
:::

:::thay-hoi
**Hỏi chéo 6 (TV2 hỏi TV4): `src/cpu_pipe.v:302`.** Cổng `flush` của `hazard.v` có xóa lệnh nạp nhầm không? **Trả lời:** TV4: không. `flush = taken` chỉ là một dây, bị đưa vào `unused_ok` (dòng 302). Việc xóa thật nằm ở `id_ok` (dòng 205, `!take`) và `ifid_v <= !take` (dòng 294). Đây là chi tiết dễ nhầm khi đọc `hazard.v`.
:::

:::thay-hoi
**Hỏi chéo 7 (TV3 hỏi TV2): `src/regfile.v:41`.** Lệnh ở ID đọc đúng thanh ghi mà lệnh ở WB đang ghi thì lấy gì? **Trả lời:** TV2 và TV3: `byp1`/`byp2` đưa luôn `wd` ra (`G_BYPASS = 1` ở G2). Đây là đường thứ ba, ngoài forwarding 10 và 01 ở EX. Ở G1 phải tắt (`G_BYPASS = 0`) vì cổng ghi là của chính lệnh đang đọc, sẽ tạo vòng tổ hợp.
:::

:::thay-hoi
**Hỏi chéo 8 (TV3 hỏi TV4): `src/cpu_pipe.v:102`.** Vì sao `d_dst` bằng 0 khi `!ifid_v`? **Trả lời:** TV4: IF/ID rỗng nghĩa là bong bóng (vừa bị `take` bỏ). Nếu không ép `d_dst = 0` thì bong bóng có thể mang số thanh ghi đích cũ và làm `hazard` hoặc `regfile` hiểu nhầm là có lệnh ghi. `id_ok` cũng đòi `ifid_v`.
:::

:::thay-hoi
**Hỏi chéo 9 (TV3 hỏi TV5): `src/control.v:106`.** `mfc0`, `mtc0`, `eret` do control sinh gì để CP0 dùng? **Trả lời:** TV5: `cp0_op` (01 = `mtc0`, 10 = `eret`, 00 là còn lại, `mfc0` dùng `res_sel = R_CP0`). Lát TV5 dùng `cp0_op` để ghi `status`/`epc` ở EX (cpu_pipe.v dòng 248 đến 252) và để không nhận ngắt sát lệnh CP0.
:::

:::thay-hoi
**Hỏi chéo 10 (TV4 hỏi TV1): `src/cpu_pipe.v:182`.** Đích nhánh dùng `idex_imm` thế nào? **Trả lời:** TV1 và TV3: `idex_imm` là hằng số đã nới dấu ở ID (`E_SE`). Đích `= idex_pc4 + {idex_imm[29:0], 2'b00}`, tức `(pc + 4) + imm × 4`. Với `beq` ở 0x08 và `imm = 2` ra `0x14`.
:::

:::thay-hoi
**Hỏi chéo 11 (TV4 hỏi TV2): `src/cpu_pipe.v:292`.** Khi `stall_lu = 1`, em phải giữ những gì? **Trả lời:** TV2 và TV4: giữ `pc` và `IF/ID` (khối `if (!stall_lu)`), và ID/EX nhận bong bóng (`id_ok = 0`). Các tầng sau (EX, MEM, WB) vẫn bước bình thường để `lw` tiếp tục tiến, nếu không `lw` đứng mãi và không bao giờ hết chờ.
:::

:::thay-hoi
**Hỏi chéo 12 (TV4 hỏi TV5): `src/cpu_pipe.v:293`.** Nhánh nhảy thật cùng chu kỳ với ngắt thì `pc` đi đâu? **Trả lời:** TV5: `take_irq` đứng trước `take` trong phép chọn, nên `pc <= 0x180`. EPC là `idex_pc` (lệnh `beq` đang ở EX bị hủy), sau `eret` nó chạy lại. Suy luận từ code, chưa chạy riêng (`inference`).
:::

:::thay-hoi
**Hỏi chéo 13 (TV5 hỏi TV4): `src/cpu_g1.v:221`.** Ở G1, ngắt đến khi `beq` vừa nhảy thật thì `epc` bằng gì? **Trả lời:** TV4: `epc <= next_pc`, mà `next_pc` đã tính cả nhánh (`take` ở dòng 151, chọn ở dòng 154 đến 160). Nên `epc` là **đích nhánh**, không phải lệnh sau `beq`. Khớp bảng "nhánh nhảy thật: EPC = đích nhánh" của chính sách pipeline.
:::

:::thay-hoi
**Hỏi chéo 14 (TV5 hỏi TV2): `src/cpu_pipe.v:202`.** Ngắt đến lúc load-use đang chờ thì sao? **Trả lời:** TV2: không nhận, vì `take_irq` có `!stall_lu`. Ngắt chờ hết chu kỳ giữ rồi mới nhận; chương trình `fw/tests/cpu/irq_lu.s` kiểm đúng việc này (ngắt nhận đúng một lần, không mất hay lặp lệnh).
:::

:::thay-hoi
**Hỏi chéo 15 (TV5 hỏi TV3): `src/cpu_pipe.v:154`.** `mfc0 $13` đọc `Cause` đi qua tầng nào, vì sao không nhận ngắt sát lệnh CP0? **Trả lời:** TV3: `control` chọn `res_sel = R_CP0` và `cp0_rd` được tính ở EX theo `idex_rd` (dòng 150 đến 158). Không nhận ngắt sát lệnh CP0 vì lệnh đó đang đổi `status`/`epc`: nhận ngắt lúc đó dễ làm EPC hoặc cờ IE/EXL sai (điều kiện `idex_cp0 == 00` và `!last_cp0`, dòng 202 đến 204).
:::

### Sửa tại chỗ và ứng dụng

:::sua-tai-cho
**Cài lỗi ở biên giới giữa các lát, xem bài thử nào bắt.** Mỗi lần **chép file ra bản nháp rồi sửa bản nháp, không sửa file gốc**. Ở thư mục gốc project:

```bash
source tools/env.sh
mkdir -p work/mut/c0src
cp src/*.v work/mut/c0src/
```

**Lỗi 1: quản đốc không bao giờ bắt chờ (TV2).** Trong `work/mut/c0src/hazard.v`, dòng 39, đổi `assign stall_lu = idex_mem_read && ...` thành `assign stall_lu = 1'b0 && idex_mem_read && ...`. Dịch và chạy:

```bash
H=$(ls tb/*.v | grep -v '_tb\.v$'); SRC=$(ls work/mut/c0src/*.v)
iverilog -g2005 -Wno-timescale -o work/mut/c0h.vvp tb/hazard_tb.v $SRC $H
vvp -n work/mut/c0h.vvp | head -3
```

Kết quả đã chạy (12/11): `loi vec 2: lu 0/1 flush 1/1 fwdA 00/00 fwdB 00/00` rồi `FAIL hazard_tb 8705 loi / 200007 vector`. Cách đọc: `lu 0/1` là "mạch cho 0, mong đợi 1". Đúng cái tín hiệu chờ load-use biến mất. Chạy lại bản gốc cho `PASS hazard_tb {{so:hazard-tb}}`.

**Lỗi 2: không xóa lệnh nạp nhầm ở IF (TV4).** Chép lại `src/cpu_pipe.v` gốc rồi sửa dòng 294 thành `ifid_v  <= !take_irq;` (bỏ `!take`). Bài thử là co-sim nên chạy qua biến môi trường `COSIM_SRC` trỏ vào thư mục bản nháp:

```bash
cp src/*.v work/mut/c0src/
# sửa dòng 294 của work/mut/c0src/cpu_pipe.v, rồi:
COSIM_SRC=work/mut/c0src python tools/cosim_iss.py --g2 --rand 0 | grep -v '^OK' | head -6
```

Kết quả đã chạy (12/11, mất khoảng 4 phút vì chạy cả bộ): 14 trong 21 chương trình báo `SAI`, dòng cuối `FAIL cosim_iss 14 sai / 21 chuong trinh`. Chương trình đầu tiên bị bắt:

```
SAI  all27     99 dong trace,    0 ngat
     loi lech o dong 63, cot: pc, instr, rd, value
     loi   RTL: 132,000000f8,15800001,0,00000000,-,00000000,00000000
     loi   ISS: 62,000000fc,258c0001,12,00000001,-,00000000,00000000
```

Cách đọc: dòng 63 của trace, mô hình ISS chạy lệnh ở `0x0FC`, nhưng RTL lại cho một lệnh ở `0x0F8` rời WB. Đó là một lệnh nạp nhầm đã lọt qua và retire (suy luận `inference` từ chỗ lệch, chưa dò từng chu kỳ). Với `bcd` và `cp0` cũng báo lệch tương tự. Điểm đáng nhớ: bài thử đơn vị `hazard_tb` **không** bắt lỗi này, vì `hazard.v` không chứa việc xóa; chỉ co-sim chạy cả chip mới thấy.

**Thử thêm: so sánh với `hazard_tb` bản gốc.** Trước khi cài lỗi, chạy `bash tools/run_unit.sh hazard control regfile` để có ba dòng `PASS` làm mốc. Sau khi xong, để nguyên thư mục `work/mut/` (không nằm trong chip) hoặc xóa tay.
:::

:::dung-o-dau
**Kỹ năng này dùng ở đâu khác.**

- **Mọi bộ xử lý đường ống** (kể cả máy tính thật) có ba nguồn trễ giống hệt: chờ dữ liệu từ bộ nhớ (load-use), xóa lệnh sai hướng (branch flush), và tài nguyên bận (như `div` ở đây). Biết đếm chu kỳ của một cặp lệnh là biết đọc bảng CPI của bất cứ CPU nào.
- **Trình biên dịch** xếp lại lệnh để chèn một lệnh độc lập vào giữa `lw` và lệnh dùng nó, đúng như câu 2 của phần tính tay: bong bóng load-use thành 0.
- **Làm việc nhóm trên phần cứng**: tín hiệu đi qua biên giới giữa các module luôn là chỗ lỗi sinh ra nhiều nhất. Cách đọc "ai phát, ai dùng" áp dụng cho mọi dự án có nhiều người.
- **Thầy hỏi xoáy**: câu hỏi hay gặp ở bảo vệ đồ án nào cũng là câu chéo, không phải câu thuộc lòng.
:::

### Tự kiểm và quay lại bức tranh

:::tu-luan
Đổi `beq` thành `bne` trong chương trình mẫu (cùng dữ liệu, `$t0 = 0`). Tổng bong bóng là bao nhiêu và vì sao?
---
**Đáp án hoàn chỉnh.** Tổng **1**. `lw` rồi `bne` vẫn bị load-use giữ một chu kỳ, vì `stall_lu` không quan tâm lệnh kế là `beq` hay `bne`, chỉ quan tâm nó đọc đúng thanh ghi `lw` ghi. Nhưng `bne` với `$t0 = $zero` thì `eq = 1`, nên `idex_br == 2'b10 && !eq` bằng 0, `take = 0`, không đổi hướng, không xóa lệnh nào: **0** bong bóng nhánh. Tổng `1 + 0 = 1`. Đối chiếu: `fw/tests/hazard/branch.s` ghi "beq không nhảy: 0" cho cùng cơ chế (nhận định `inference` cho riêng `bne` của bài này).
:::

:::tu-luan
Vì sao đường forwarding 01 (lấy từ WB) dùng được cho `lw`, còn đường 10 (lấy từ EX/MEM) thì không?
---
**Đáp án hoàn chỉnh.** Dữ liệu của `lw` chỉ có sau tầng MEM. Khi `lw` còn ở EX/MEM (đường 10), thứ có trong `exm_res` mới là **địa chỉ** vừa tính, dữ liệu chưa đọc ra. Khi `lw` đã sang MEM/WB (đường 01), `wb = mw_m2r ? wb_ld : mw_res` đã là dữ liệu đúng. Vì vậy `beq` sát ngay sau `lw` phải chờ một chu kỳ cho `lw` sang WB, rồi mới lấy tắt được. Đó chính xác là điều `stall_lu` đảm nhiệm.
:::

:::tu-luan
Nếu `lw` đọc địa chỉ nằm ở vùng MMIO (ví dụ `0xFFFFFF48`, thanh ghi `IRQ_PENDING`) thay vì DMEM, đường dữ liệu khác đi ở chỗ nào?
---
**Đáp án hoàn chỉnh.** Ở MEM, `in_mmio = (exm_res[31:8] == 24'hFFFFFF)` bật `bus_re` và `mw_lmmio <= exm_mrd && in_mmio` nhớ rằng đây là đọc ngoại vi (dòng 187 đến 191, 262). `mw_mdata` ra 0 vì địa chỉ không nằm trong DMEM. Ở WB, `wb_ld = mw_lmmio ? bus_rdata : mw_mdata` chọn `bus_rdata` do ngoại vi (ví dụ `irq_ctrl`, lát TV5) trả về. `bus_rdata` là ô nhớ có clock nên đã sẵn sàng đúng lúc lệnh đến WB. Từ WB trở đi, đường ghi regfile và forwarding 01 y hệt `lw` thường.
:::

:::tu-luan
Một ngắt đến đúng chu kỳ 3 của bảng (`beq` đang bị giữ ở ID vì `stall_lu`). Có nhận ngay không? Và nếu ngắt đến ở chu kỳ 5 (khi `beq` ở EX và `take = 1`) thì sao?
---
**Đáp án hoàn chỉnh.** Chu kỳ 3: **không nhận**, vì `take_irq` có điều kiện `!stall_lu` (cpu_pipe.v dòng 202). Ngắt chờ sang chu kỳ 4. Chu kỳ 5: điều kiện không bị chặn bởi `stall_lu`, nên có thể nhận. Khi đó `pc` ưu tiên `take_irq` (0x180) hơn `take` (dòng 293), `EPC = irq_epc = idex_pc` (chính `beq`, vì ID/EX đang có lệnh), và `exm_v <= idex_v && !take_irq` hủy `beq` ở EX. Sau `eret`, `beq` chạy lại từ đầu và nhảy. Đây là suy luận từ code (`inference`), chưa chạy riêng ca này; bảng chính sách ghi ca "nhánh nhảy thật" với kết luận EPC = đích nhánh khi ngắt rơi ở chu kỳ sau đó.
:::

:::mcq id=KT-C0-01
? Trên lõi G2 của WatchChip, chương trình `lw $t0` rồi `beq $t0,$zero` (nhảy thật) cho trace rời WB ở các chu kỳ 5, 7 và 10 của ba lệnh `lw`, `beq`, lệnh đích. Các con số đó có nghĩa gì?
- [ ] Một bong bóng load-use cộng một bong bóng nhánh nên tổng chỉ là 2 chu kỳ chờ
- [ ] `lw` mất 2 chu kỳ, `beq` mất 3 chu kỳ để xong, mỗi lệnh có bong bóng của riêng nó
- [x] 1 bong bóng load-use (5 đến 7) và 2 bong bóng xóa nhánh (7 đến 10), tổng 3
- [ ] Đường ống rỗng hoàn toàn trong lúc `beq` nhảy nên 3 chu kỳ đều là chờ nhánh
> Giải thích: khoảng cách giữa hai lần rời WB trừ 1 bằng số bong bóng ở giữa. `5 → 7` cách 2 nên có 1 bong bóng, `7 → 10` cách 3 nên có 2. Tổng 3 khớp dòng `# bubbles 3` mà bộ kiểm đòi. Số bong bóng không thuộc "một lệnh" nào cả.
:::

:::mcq id=KT-C0-02
? Trong bài `lw` rồi `beq` ở WatchChip, nhờ đường nào mà `beq` nhận được `$t0` sau một chu kỳ chờ mà không phải đợi `$t0` vào regfile?
- [ ] Đường forwarding 10, lấy từ `exm_res` của lệnh `lw` đang ở EX/MEM
- [ ] Bypass trong regfile, vì `lw` ghi đúng chu kỳ `beq` đọc ở tầng ID
- [x] Đường forwarding 01, lấy `wb` khi `lw` đang ở MEM/WB và `beq` ở EX
- [ ] ALU tự tính lại `$t0` từ địa chỉ vì `beq` không cần dữ liệu thật của `lw`
> Giải thích: ở chu kỳ 5, `lw` ở WB còn `beq` ở EX, `memwb_dst == idex_rs` nên `fwd_a = 01` và `opA = wb`. Đường 10 chỉ có địa chỉ (chưa có dữ liệu). Bypass của regfile phục vụ lệnh ở ID, mà lúc đó `beq` đã rời ID.
:::

:::mcq id=KT-C0-03
? Hai lệnh nạp nhầm sau `beq` nhảy thật ở WatchChip bị chặn ở đâu, và hệ quả là gì?
- [ ] Cả hai bị chặn ở EX, sau khi đã tính xong, bằng cách hủy kết quả ở MEM
- [ ] Cả hai chạy hết các tầng nhưng `reg_write` bị tắt nên không ghi gì được
- [x] Một lệnh ở ID (`id_ok` có `!take`), một lệnh ở IF (`ifid_v <= !take`), chưa vào EX
- [ ] Cả hai bị chặn ở IF vì bộ nhớ lệnh ngừng đọc khi phát hiện nhánh
> Giải thích: `take` chỉ tính được ở EX (chu kỳ 5), lúc đó lệnh 0x0C đang ở ID bị `id_ok = 0` chặn, còn lệnh 0x10 vừa nạp bị `ifid_v <= !take` coi là rỗng. Chúng chưa tới EX nên không ghi gì. Bộ nhớ lệnh vẫn đọc bình thường (`imem[pc]`).
:::

:::mcq id=KT-C0-04
? Ở WatchChip, lệnh `beq` quyết định nhảy hay không bằng tín hiệu nào, và cổng `zero` của ALU có tham gia không?
- [ ] `alu_zero`, vì ALU trừ hai thanh ghi rồi báo kết quả bằng 0
- [x] `eq = (opA == opB)` so sánh riêng; `alu_zero` không dùng cho nhánh
- [ ] `stall_lu`, vì nhánh phải đợi dữ liệu nên hazard quyết định luôn hướng
- [ ] `branch` từ control, vì nó tự mang kết quả so sánh sang IF
> Giải thích: cpu_pipe.v dòng 176 so sánh trực tiếp hai toán hạng đã chuyền tay (`opA`, `opB`). `alu_zero` bị đưa vào `unused_ok` (dòng 302), nghĩa là chip cố ý không dùng. `branch` chỉ nói "đây là beq hay bne", còn `take` mới là kết quả.
:::

:::mcq id=KT-C0-05
? Trong khung G2 của WatchChip, ngắt đến đúng lúc `beq` đang bị `stall_lu` giữ ở ID. Điều gì xảy ra?
- [ ] Ngắt được nhận ngay và EPC trỏ vào `lw` đang ở MEM
- [ ] Ngắt bị bỏ qua hẳn vì lúc đang giữ lệnh thì `pending` bị khóa
- [x] Ngắt chờ: `take_irq` có `!stall_lu`, nhận sau khi hết giữ
- [ ] Ngắt được nhận nhưng `beq` bị hủy và `lw` phải chạy lại từ đầu
> Giải thích: `pending` vẫn giữ bit ngắt (lát TV5), còn điều kiện `!stall_lu` trong `take_irq` (cpu_pipe.v dòng 202) chặn nhận ngay. Sang chu kỳ sau `stall_lu = 0` thì ngắt được nhận. Test `fw/tests/cpu/irq_lu.s` kiểm đúng tình huống này.
:::

## U1 · Đồng hồ trong 15 phút

### Bản đồ

:::ban-do
Bài này dành cho **cả nhóm**, đọc sau bài C0. Năm bài P dạy phần CPU. Bài U1 dạy phần **đồng hồ**: một mili giây đi từ thạch anh đến chữ số trên màn hình. Mỗi người nói được một khối trong 3 phút, năm khối nối thành 15 phút.

| Khối | Người nói | Làm gì trong đường đi của một mili giây | File |
|---|---|---|---|
| 1. Nhịp mili giây | TV5 | đếm 50 000 chu kỳ clock thành một tick, có hiệu chỉnh `CAL` | `src/timebase.v`, `src/timers.v` |
| 2. Bản đồ chip | TV3 | nối CPU với mọi ngoại vi qua một bus, đọc về bằng phép OR | `src/soc_top.v`, `docs/mmio-map.md` |
| 3. Đổi số ra chữ số | TV1 | firmware đổi mili giây trong ngày thành 8 ký tự | `fw/fmt.s`, `report/3.4-dse.md` |
| 4. Hiện lên LED | TV4 | quét 8 chữ số dùng chung chân đoạn, chống bóng ma | `src/seg7_scan.v`, `src/display_ctrl.v` |
| 5. Vì sao tin chip đúng | TV2 | so chip với mô hình ISS từng lệnh, cài lỗi xem bài thử bắt | `tools/cosim_iss.py`, `tools/cmp_trace.py` |

**Cách dùng bài:** mỗi khối có hai phần: *nói gì trong 3 phút* và *thầy hay hỏi gì*. Người giữ khối học kỹ khối mình, bốn người còn lại đọc lướt để nghe hiểu.

Số liệu trong bài đều đọc từ sổ số đã đo: `{{so:hazard-tb}}` ca của `hazard_tb`, `{{so:timebase-tb}}` ca của `timebase_tb`, `{{so:cosim-iss}}` chương trình của `cosim_iss`. Bài thử của bài này: `bash tools/run_unit.sh timebase seg7 display_ctrl`.
:::

### Câu hỏi mở bài

Đồ án nói một câu: tự thiết kế chip cho đồng hồ, rồi đo xem muốn đồng hồ chuẩn đến 1 phần nghìn giây thì việc nào nên làm bằng phần cứng, việc nào bằng phần mềm. Ba câu hỏi để nói được trong 15 phút:

- Con số "1 mili giây" sinh ra ở đâu, và nếu thạch anh nhanh hay chậm vài chục phần triệu thì sửa thế nào?
- Từ số mili giây (một số rất lớn) đến tám chữ số trên LED, ai làm việc gì, mất bao nhiêu chu kỳ?
- Vì sao nhóm tin con chip đúng, trong khi chỉ chạy mô phỏng?

Trả lời ngắn, các mục sau chứng minh:

- `timebase` đếm 50 000 chu kỳ clock 50 MHz thì phát một tick. Lệch thạch anh được bù bằng cách **cho một số mili giây dài thêm hoặc ngắn bớt một chu kỳ** (hệ số `CAL`).
- Firmware đổi số bằng `div`, bằng lệnh `bcd`, hoặc để phần cứng đếm sẵn dạng BCD. Ba cách tốn 224, 162 và khoảng 25 chu kỳ. Ở xung thường cả ba đều dưới 1 % tải CPU.
- Chip được kiểm bằng **hai đường độc lập**: chạy chương trình trên chip rồi so từng lệnh với mô hình ISS; và cài lỗi cố ý để xem bài thử có bắt được không.

### Trực giác

Hình dung một **đồng hồ cát khổng lồ** (thạch anh) chảy ra 50 triệu hạt cát mỗi giây. Cứ đếm đủ 50 000 hạt là có một **mili giây**. Đó là việc của người giữ khối 1.

Nhưng cát không chảy đều tuyệt đối: có đồng hồ cát chảy hơi nhanh một chút. Nếu cứ đếm đúng 50 000 hạt thì mỗi ngày lệch vài giây. Cách sửa của nhóm: mỗi mili giây đều **ghi nhớ phần lẻ** (ví dụ nhanh 0,3 hạt), cộng dồn; mỗi khi phần lẻ đủ 1 hạt thì cho mili giây đó dài thêm một hạt. Giống trả tiền lẻ: dư 0,3 xu thì cộng dồn, đủ 1 xu mới trả thêm.

Sau đó **mili giây đi vào chip**. Mạch chủ (khối 2) giống một bàn điều khiển có nhiều ngăn kéo: CPU hỏi một địa chỉ, mỗi ngoại vi tự xem địa chỉ có phải của mình không; không phải thì trả 0; nên muốn đọc chỉ việc **OR** tất cả câu trả lời.

Chương trình chạy trên chip (khối 3) nhận số mili giây, ví dụ 45 296 789, rồi **tách thành chữ số** `12.34.56` để hiện.

Cuối cùng khối 4: 8 chữ số LED dùng chung 7 chân đoạn, nên mỗi lúc chỉ bật được một chữ số. Bật lần lượt rất nhanh, mắt thấy tất cả cùng sáng.

Khối 5 trả lời câu "sao biết đúng": thêm một người giám khảo là **mô hình ISS** (một chương trình Python hiểu đúng 28 lệnh), chạy cùng chương trình với chip, so từng lệnh.

Còn bốn ý cần có.

**Ppm** là phần triệu: 50 ppm nghĩa là sai 50 trên một triệu. Một ngày có 86 400 giây, nên 50 ppm trôi `50 × 10⁻⁶ × 86 400 = 4,32` giây mỗi ngày.

**Mili giây trong ngày** chạy từ 0 đến 86 399 999. Số 45 296 789 là 12 giờ 34 phút 56,789 giây.

**BCD** là cách ghi mỗi chữ số thập phân bằng 4 bit: 12 là `0001 0010`. Màn hình cần đúng dạng đó, còn số nhị phân thường thì không.

**Chu kỳ CPU và `cpu_ce`.** CPU không có clock riêng, nó chỉ bước khi xung cho phép `cpu_ce` bằng 1 (bài P5). Với `CPU_CLK_DIV = 1` lõi G2 bước mỗi chu kỳ hệ thống; với `CPU_CLK_DIV = 1526` nó bước khoảng 32 765 lần mỗi giây, gần bằng thạch anh đồng hồ thật 32 768 Hz. Cột "chu kỳ CPU" trong bảng đo ở khối 3 tính theo các bước này.

**Mọi thứ chỉ mô phỏng.** Chip chưa chạy trên board thật. Khi thầy hỏi "chạy thật chưa" câu trả lời trung thực là chưa; những gì nói được là kết quả mô phỏng và kiểm từng lệnh.

### Cơ chế theo đường tín hiệu

Theo một mili giây từ đầu đến cuối. Mỗi khối là một đoạn 3 phút.

**Khối 1: nhịp mili giây (TV5, `timebase.v`).** Nói trong 3 phút:

- Clock 50 MHz, mỗi chu kỳ 20 ns. Đếm `cnt` từ 0; đến chu kỳ cuối của mili giây (`cnt = len - 1`) thì `tick = 1` đúng một chu kỳ, rồi `cnt` về 0 (dòng 40, 50 đến 52).
- Độ dài mili giây là `len = G_N + (s >>> 16)` với `s = frac + CAL` (dòng 34 đến 37). `frac` là phần lẻ 16 bit, đơn vị 1/65 536 chu kỳ. `CAL` có dấu: dương thì mili giây dài hơn, đồng hồ **chậm lại**.
- 1 ppm bằng `50 000 × 10⁻⁶ = 0,05` chu kỳ mỗi mili giây, nên bằng `0,05 × 65 536 = 3 276,8` đơn vị `CAL`.
- `CAL` được chốt ở chu kỳ đầu của mili giây (`s_q`): đổi `CAL` giữa chừng chỉ có tác dụng từ mili giây sau.
- Dấu `>>>` (dịch số học) là bắt buộc: `CAL` âm cần phần nguyên âm. Dịch logic `>>` sẽ sai.

**Thầy hay hỏi (khối 1):** "vì sao dùng phần lẻ thay vì cứ đổi 50 000 thành 50 001?" Trả lời: đổi một lần chỉ bù được những sai số **nguyên** chu kỳ mỗi mili giây (20 ppm mỗi chu kỳ). Sai số vài ppm cần bù **phân số** chu kỳ, nên phải cộng dồn phần lẻ.

**Khối 2: bản đồ chip (TV3, `soc_top.v`).** Nói trong 3 phút:

- CPU đọc/ghi ngoại vi bằng `lw`/`sw` ở địa chỉ `0xFFFFFFxx`; địa chỉ `0x00000xxx` là bộ nhớ dữ liệu; còn lại đọc ra 0 và ghi bỏ (`docs/mmio-map.md` mục 2).
- Mọi ngoại vi cùng nhận `bus_addr`, `bus_we`, `bus_re`. Khối nào không phải của mình trả 0. Vì vậy `bus_rdata` là OR của 10 đường đọc (dòng 54).
- Tín hiệu `tick_ms` từ `timebase` chạy ra `rtc` (đếm giờ), `buttons`, `beeper`, `display_ctrl`. Sự kiện (hết giờ, báo thức, nút bấm, UART nhận) đi vào `irq_ctrl` thành tín hiệu ngắt gửi CPU.
- Chọn lõi: biên dịch bình thường là G1; thêm `-DG2` thì dùng pipeline. Hai lõi cùng cổng cùng tên.

**Thầy hay hỏi (khối 2):** "đọc một địa chỉ không ai nhận thì ra gì?" Trả lời: ra 0, vì không khối nào bật dữ liệu và OR của toàn số 0 là 0. Ghi vào đó thì bị bỏ.

**Khối 3: đổi số ra chữ số (TV1, `fw/fmt.s`).** Nói trong 3 phút:

- Số mili giây trong ngày (0 đến 86 399 999) phải thành 8 ký tự `HH.MM.SS` để ghi vào 8 ô Display RAM.
- Ba cách: `fmt_div` (6 lệnh `div`, chia dần: mili giây → giây → giờ phút giây → từng chữ số), `fmt_bcd` (3 lệnh `div`, 2 lệnh `mul`, 1 lệnh `bcd`), `fmt_hw` (đọc thẳng thanh ghi `RTC_BCD` phần cứng đã đếm sẵn dạng BCD).
- Đo bằng cách đọc `CYCLE_COUNT` (địa chỉ `0xFFFFFF00`, tức `-256`) trước và sau khi gọi hàm, trừ chi phí gọi hàm rỗng (`fmt.s` dòng 21 đến 25).
- Kết quả đo ở lõi G2, `CPU_CLK_DIV = 1`: `div` thuần **{{so:fmt-div}}** chu kỳ, `bcd` tuần tự **{{so:fmt-bcd}}**, `bcd` tổ hợp **{{so:fmt-bcdc}}**, phần cứng **{{so:fmt-hw}}** (bảng DSE ghi 24 cho lõi G1, 25 cho G2).
- Ở xung thường cả ba đều dưới 1 % tải CPU nếu cập nhật 1 000 lần mỗi giây; khác biệt lộ ra khi hạ xung xuống 32 768 Hz như đồng hồ thật.

**Thầy hay hỏi (khối 3):** "vì sao `div` mất 224 chu kỳ mà G1 và G2 giống nhau?" Trả lời: `div` mất 33 chu kỳ mỗi lần, 6 lần đã chiếm gần hết, mà chu kỳ đo ở đây tính theo chu kỳ CPU. G2 nhanh gấp đôi chỉ vì xung gấp đôi, không vì ít chu kỳ hơn.

**Khối 4: hiện lên LED (TV4, `seg7_scan.v`).** Nói trong 3 phút:

- 8 chữ số dùng **chung** 7 chân đoạn, nên mỗi lúc chỉ một chữ số sáng. Quét lần lượt, mỗi chữ số một **khe** dài `G_SLOT` chu kỳ (50 000 chu kỳ = 1 ms), nên cả vòng 8 ms: mỗi chữ số sáng lại **125 lần mỗi giây**, mắt thấy sáng đều.
- Mỗi khe chia ba đoạn theo bộ đếm `c`: `c < G_BLANK` tắt hết; rồi anode bật một lúc dài theo độ sáng (PWM); phần còn lại tắt (dòng 91).
- **Bóng ma:** transistor anode tắt chậm. Nếu vừa chuyển chữ số mà chân đoạn đổi hình ngay thì anode cũ còn sáng mờ sẽ hiện hình **mới**. Cách chữa: trong khoảng tắt (`c < G_BLANK`) vẫn xuất hình chữ số **trước** (`js`, dòng 83), tới khi hết khoảng tắt mới đổi.
- `display_ctrl` là bảng 8 ô mà firmware ghi chữ lên; LED và VGA chỉ đọc bảng này. Các thanh ghi của nó chỉ-ghi nên đọc ra 0.

**Thầy hay hỏi (khối 4):** "nháy 2 Hz làm thế nào?" Trả lời: `bcnt` đếm mili giây từ 0 đến 499; từ 250 trở đi là nửa tắt (`blink_ph`); ô nào có bit trong `blink_mask` thì tắt trong nửa đó (dòng 89, 90). Ghi `BLINK_MASK` thì `bcnt` về 0 để nháy bắt đầu từ pha sáng.

**Khối 5: vì sao tin chip đúng (TV2, `cosim_iss.py`).** Nói trong 3 phút:

- Chip chạy một chương trình, ghi **vết** (trace): mỗi lệnh rời trạm WB in một dòng gồm `pc`, lệnh, thanh ghi ghi, giá trị, truy cập bộ nhớ.
- Mô hình **ISS** (`tools/iss.py`) chạy cùng chương trình. `cmp_trace.py` so từng dòng, **dừng ở dòng đầu tiên lệch** và in hai dòng lệch cùng tên cột lệch.
- Kết quả: `PASS cosim_iss` **{{so:cosim-iss}}** chương trình khớp.
- Hạn chế phải nói thật: ISS và chip **cùng một nhóm viết**, hiểu sai cùng chỗ thì cả hai cùng sai. Vì vậy có đường kiểm thứ hai: `cosim_mars` so với MARS (một bộ mô phỏng MIPS của bên ngoài), **{{so:cosim-mars}}** chương trình.
- Thêm một đường nữa: **cài lỗi cố ý** (đột biến) vào chip rồi xem bài thử có đỏ không. Một bài thử không bắt được lỗi nào thì chưa chứng minh được gì.

**Thầy hay hỏi (khối 5):** "co-sim chứng minh được gì, chưa chứng minh được gì?" Trả lời: chứng minh chip **khớp mô hình** trên những chương trình đã chạy; chưa chứng minh chip khớp phần cứng thật (chưa chạy board), chưa chứng minh mô hình đúng (cần đường MARS), và chưa chứng minh mọi chương trình (chỉ những cái đã chạy).

### Bảng chu kỳ hoặc tính tay

:::suy-dan
**Đề bài.** Bốn phép tính tay xuyên suốt đường đi của một mili giây.

1. Với `CAL = 163 840` (ứng với +50 ppm), tính độ dài hai mili giây đầu (bắt đầu `frac = 0`) và nói quy luật lặp.
2. Nếu không bù, đồng hồ lệch bao nhiêu giây mỗi ngày với sai số 50 ppm?
3. Đổi 45 296 789 ms ra `HH.MM.SS` bằng phép chia nguyên liên tiếp (đúng cách `fmt_div` làm).
4. Tải CPU của `fmt_div` (224 chu kỳ) khi cập nhật 1 000 lần mỗi giây, ở 50 MHz và ở `CPU_CLK_DIV = 1526`.
---
**Phép 1: hai mili giây đầu.** Công thức: `s = frac + CAL`, `len = 50 000 + (s >>> 16)`, `frac' = s[15:0]`.

| Mili giây | `frac` vào | `s = frac + CAL` | `s >>> 16` | `len` | `frac` ra |
|---|---|---|---|---|---|
| 0 | 0 | 163 840 | 2 | **50 002** | 32 768 |
| 1 | 32 768 | 196 608 | 3 | **50 003** | 0 |
| 2 | 0 | 163 840 | 2 | 50 002 | 32 768 |

Quy luật: dài 50 002 và 50 003 xen kẽ, trung bình `2,5` chu kỳ thêm mỗi mili giây, đúng `+50 ppm` (`2,5 / 50 000 = 5 × 10⁻⁵`). Kiểm: `163 840 / 65 536 = 2,5`.

**Phép 2: trôi mỗi ngày.** `50 × 10⁻⁶ × 86 400 = 4,32` giây mỗi ngày. Đó là mức sai nếu bỏ qua hiệu chỉnh; là lý do đồ án có thí nghiệm hiệu chỉnh `CAL`. Dấu: mili giây dài hơn thì đồng hồ chậm lại, nên `CAL` dương bù cho thạch anh nhanh.

**Phép 3: 45 296 789 ms.** Chia từng bước:

- `45 296 789 ÷ 1000 = 45 296` dư 789 (phần mili giây).
- `45 296 ÷ 60 = 754` dư **56** (giây).
- `754 ÷ 60 = 12` dư **34** (phút); giờ là **12**.
- Vậy `12:34:56.789`. Kiểm: `12 × 3600 + 34 × 60 + 56 = 45 296`.

Mỗi số hai chữ số lại chia 10 lấy thương và dư (`34 → 3, 4`). Tổng 6 lệnh `div`: 3 lần cho giờ phút giây, 3 lần cho chữ số (đúng "6 `div`" trong tiêu đề của `fmt_div`).

**Phép 4: tải CPU.** `224 × 1000 = 224 000` chu kỳ CPU mỗi giây.

- Ở 50 MHz (G2): `224 000 / 50 000 000 = 0,448 %` (bảng ghi 0,45 %).
- Ở `CPU_CLK_DIV = 1526`: tần số CPU `= 50 000 000 / 1526 ≈ 32 765` chu kỳ mỗi giây, nên `224 000 / 32 765 ≈ 6,84`, tức **684 %**: không kịp. Chu kỳ CPU không đủ để làm 1 000 lần mỗi giây.
- Màn `HH.MM.SS` chỉ cần 1 lần mỗi giây, nên chỉ `224 / 32 765 ≈ 0,68 %`: kịp. Đó là lý do câu trả lời "cách nào hơn" phụ thuộc màn hiển thị nào.
:::

### Trong chip

:::trong-chip
Mỗi đoạn trích dưới đây ứng với một khối, có kèm cách đọc.

**Khối 1: hiệu chỉnh phân số.**

{{trich:src/timebase.v:34-40@wire signed [33:0] s_now}}

- **Dòng 34** `s_now`: phần lẻ `frac` (16 bit, nối thêm 18 bit 0 phía trên) cộng `cal` có dấu (nới dấu 2 bit). Ra số có dấu 34 bit.
- **Dòng 35** `s_cur`: ở chu kỳ đầu của mili giây (`cnt == 0`) dùng `s_now`, các chu kỳ sau dùng bản đã chốt `s_q` để đổi `CAL` giữa chừng không làm mili giây bị tính hai kiểu.
- **Dòng 36** chú thích: `>>>` giữ dấu, dịch logic sẽ sai.
- **Dòng 37** `len`: `G_N + (s_cur >>> 16)`. Phần nguyên của `s / 65 536` là số chu kỳ thêm hoặc bớt.
- **Dòng 40** `tick`: bật đúng một chu kỳ khi `cnt` bằng `len - 1`, và chỉ khi `en = 1`.

**Khối 2: OR của mọi khối.**

{{trich:src/soc_top.v:53-54@wire [31:0] rd_soc}}

- **Dòng 53** mười đường đọc, mỗi khối một đường (`rd_soc`, `rd_irq`, `rd_rtc`, `rd_sw`, `rd_tmr`, `rd_al`, `rd_btn`, `rd_disp`, `rd_uart`, `rd_bcd`).
- **Dòng 54** `bus_rdata`: OR của cả mười. Chạy đúng vì mỗi khối **trả 0** khi địa chỉ không phải của mình (quy ước ở `mmio-map.md` mục 2).

**Khối 3: đọc `CYCLE_COUNT` để đo.**

{{trich:fw/fmt.s:21-25@lw    $s0, -256($zero)}}

- **Dòng 21** `lw $s0, -256($zero)`: địa chỉ `-256 = 0xFFFFFF00` là `CYCLE_COUNT` (chỉ đọc). Đọc trước khi gọi hàm.
- **Dòng 22** `jal fmt_nop`: gọi hàm rỗng để đo **chi phí nền** (gọi và trả về), sẽ trừ đi.
- **Dòng 23, 24** đọc lại, trừ: ra số chu kỳ của lần gọi.

**Khối 4: khe quét và chống bóng ma.**

{{trich:src/seg7_scan.v:83-91@wire [JW-1:0] js}}

- **Dòng 83** `js`: trong khoảng tắt (`c < G_BLANK`) lấy chữ số **trước** `j - 1` (vòng về 7 khi `j = 0`); ngoài khoảng tắt lấy `j`.
- **Dòng 84, 87** lấy ô 8 bit của chữ số đó, đổi mã ký tự thành 7 đoạn bằng `char_rom`.
- **Dòng 89** `blink_ph`: `bcnt >= 250` là nửa tắt của chu kỳ nháy 500 ms.
- **Dòng 91** `lit`: anode `j` bật khi `c` nằm trong `[G_BLANK, G_BLANK + bright × G_STEP)` và không đang nháy tắt. Độ sáng càng cao thì bật càng lâu.

**Khối 5: so lệnh với số chu kỳ.**

{{trich:tools/cosim_iss.py:96-107@if G2["on"]:}}

- **Dòng 96** chỉ với lõi G2: kiểm **số chu kỳ** (bong bóng) ngoài việc kiểm giá trị.
- **Dòng 97 đến 99** chương trình trong thư mục `hazard` bắt buộc có dòng `# bubbles N`, thiếu thì báo lỗi.
- **Dòng 101 đến 107** đếm khe hở giữa các lần retire (`gaps`) và so với `N` ghi sẵn; lệch thì báo `bong bong: RTL ..., spec ...`.
:::

### Bẫy và thầy hay hỏi

:::bay
**Bẫy 1: "`CAL` dương làm đồng hồ nhanh lên."** Sai, ngược lại. `CAL` dương làm mili giây **dài hơn**, nên đồng hồ chậm lại. Muốn bù thạch anh chạy nhanh thì đặt `CAL` dương. Câu trong code: "CAL > 0 → ms dài hơn → đồng hồ chậm lại" (`timebase.v` dòng 9).
:::

:::bay
**Bẫy 2: "Mili giây nào cũng dài đúng 50 000 chu kỳ."** Sai khi `CAL` khác 0. Các mili giây dài 50 002 và 50 003 xen kẽ (ví dụ `+50 ppm`). Chỉ **trung bình** mới là 50 000,05 trở lên theo `CAL`.
:::

:::bay
**Bẫy 3: "Đồng hồ nhìn thấy sáng đều nghĩa là tám chữ số sáng cùng lúc."** Sai. Mỗi lúc chỉ một chữ số sáng; mắt thấy đều vì mỗi chữ số được bật lại 125 lần mỗi giây (lưu ảnh võng mạc). Hệ quả: nếu firmware ghi 8 ô bằng 8 lệnh `sw` liên tiếp đúng lúc quét thì có thể thấy "xé hình".
:::

:::bay
**Bẫy 4: "Co-sim PASS nghĩa là chip đúng."** Sai. Chỉ nghĩa là chip **khớp ISS** trên các chương trình đã chạy. ISS và chip cùng nhóm viết. Phải kèm đường MARS và đột biến mới đáng tin hơn.
:::

### Sửa tại chỗ và ứng dụng

:::sua-tai-cho
**Cài lỗi rồi xem bài thử nào bắt.** Hai lỗi, mỗi lần **chép file ra bản nháp rồi sửa bản nháp, không sửa file gốc**. Ở thư mục gốc project:

```bash
source tools/env.sh
mkdir -p work/mut/u1 work/mut/u1s
```

**Lỗi 1: tick lệch một chu kỳ (TV5).** Chép `src/timebase.v` vào `work/mut/u1/`, ở dòng 40 đổi `== len - 1);` thành `== len);` (tick bật ở chu kỳ sau cuối, nên mỗi mili giây dài thêm một chu kỳ). Dịch và chạy bài thử với bản nháp:

```bash
cp src/timebase.v work/mut/u1/timebase.v
# sửa dòng 40 của work/mut/u1/timebase.v, rồi:
H=$(ls tb/*.v | grep -v '_tb\.v$')
iverilog -g2005 -Wno-timescale -o work/mut/u1/tb.vvp tb/timebase_tb.v work/mut/u1/timebase.v $H
vvp -n work/mut/u1/tb.vvp > work/mut/u1/tb.out; head -3 work/mut/u1/tb.out; tail -2 work/mut/u1/tb.out
```

Kết quả đã chạy (12/11, mất khoảng 46 giây): ba dòng đầu đều là `loi TB-1: G_N=50 cal=0`, dòng cuối `FAIL timebase_tb 597 loi / 693 kiem tra`. Cách đọc: ca TB-1 đòi tick ở chu kỳ 50, 100, 150... khi `CAL = 0`; bản lỗi tick ở 51, 102... nên 597 trong 693 lần kiểm đỏ. Bản gốc cho `PASS timebase_tb 693`.

**Một lỗi khác, bài thử không kết thúc.** Đổi `>>>` thành `>>` ở dòng 37 (dịch logic thay vì dịch số học). Chạy như trên: **sau hơn 10 phút bài thử vẫn chưa in gì**, phải dừng tay. Lý do (`inference`): `CAL` âm ở dạng 34 bit không dấu dịch ra số khoảng 2¹⁸, mỗi mili giây thành khoảng 262 000 chu kỳ nên các ca đếm 1 000 mili giây chạy gần như vô hạn. Đây **không** phải một dòng `FAIL` gọn; ghi lại để biết: lỗi dấu ở `>>` làm bài thử treo chứ không báo lỗi.

**Lỗi 2: bỏ chống bóng ma (TV4).** Chép `src/seg7_scan.v` vào `work/mut/u1s/`, ở dòng 83 đổi cả biểu thức thành `wire [JW-1:0] js = j;` (luôn lấy chữ số hiện tại). Bài thử cần các module còn lại từ `src/`:

```bash
cp src/seg7_scan.v work/mut/u1s/seg7_scan.v
# sửa dòng 83, rồi:
H=$(ls tb/*.v | grep -v '_tb\.v$'); SRC=$(ls src/*.v | grep -v seg7_scan.v)
iverilog -g2005 -Wno-timescale -o work/mut/u1s/tb.vvp tb/seg7_tb.v work/mut/u1s/seg7_scan.v $SRC $H
vvp -n work/mut/u1s/tb.vvp | head -3; vvp -n work/mut/u1s/tb.vvp | tail -2
```

Kết quả đã chạy (12/11): các dòng đầu `loi doan: cyc=0 slot=0 c=0 an=00000000 (can 00000000) seg=4f bright=15 ticks=0` rồi cuối cùng `FAIL seg7_tb 844 loi / 25362 kiem tra`. Cách đọc: `seg=4f` là hình mà mạch xuất ra (chữ số hiện tại) còn bài thử mong đợi hình chữ số **trước** trong khoảng tắt, nên chỉ ra ngay chu kỳ `c = 0`. Bài thử D-2 (thứ tự anode và khoảng tắt) bắt đúng lỗi này.

**Lỗi 3 (đã chạy ở bài C0): bỏ xóa lệnh nạp nhầm.** Co-sim `COSIM_SRC=work/mut/c0src python tools/cosim_iss.py --g2 --rand 0` báo `FAIL cosim_iss 14 sai / 21 chuong trinh`. Đây là ví dụ cho khối 5: lỗi ở lõi G2 mà bài thử đơn vị `hazard_tb` không thấy, chỉ co-sim thấy.
:::

:::dung-o-dau
**Kỹ năng này dùng ở đâu khác.**

- **Mọi thiết bị đo thời gian** (đồng hồ treo tường, đồng hồ bấm giờ, máy tính) có cùng bài toán: một nguồn dao động không chuẩn tuyệt đối và cần **hiệu chỉnh phần lẻ**. Cộng dồn phần dư để bù sai số nhỏ hơn một chu kỳ là kỹ thuật chung (chia tần phân số).
- **Quét LED** có mặt ở bàn phím, màn hình ma trận, bảng điện tử: dùng chung đường dẫn, bật lần lượt, nhờ lưu ảnh võng mạc.
- **Bus địa chỉ với OR đường đọc** là cách đơn giản nhất để nối nhiều ngoại vi vào một CPU; vi điều khiển thật dùng ý tưởng gần như vậy.
- **Đo chi phí bằng bộ đếm chu kỳ** là cách chuẩn so hai cách làm cùng việc (phần mềm hay phần cứng), nên cả việc đọc bảng 224, 162, 25 chu kỳ lẫn việc tự đo đều dùng được cho mọi dự án nhúng.
- **Kiểm chip bằng mô hình tham chiếu cộng cài lỗi** là quy trình kiểm chứng phần cứng phổ biến: nếu bài thử không đỏ khi cài lỗi thì bài thử chưa đủ.
:::

### Tự kiểm và quay lại bức tranh

:::tu-luan
Giải thích bằng lời, không công thức, vì sao `CAL` dương làm đồng hồ chậm lại và một mili giây mất trung bình bao nhiêu chu kỳ khi `CAL = 163 840`.
---
**Đáp án hoàn chỉnh.** `CAL` được cộng vào phần lẻ mỗi mili giây; khi phần lẻ tràn một chu kỳ thì mili giây đó **dài thêm** một chu kỳ clock. Đồng hồ đếm số mili giây, mỗi mili giây dài hơn nghĩa là cùng một khoảng thời gian thật chứa **ít** mili giây hơn, nên đồng hồ chạy chậm. `163 840 / 65 536 = 2,5` chu kỳ thêm mỗi mili giây, nên mili giây trung bình dài `50 002,5` chu kỳ (xen kẽ 50 002 và 50 003). Tương đương +50 ppm. Dùng để bù thạch anh chạy nhanh 50 ppm.
:::

:::tu-luan
`fmt_div` mất 224 chu kỳ, `fmt_hw` mất 25. Nêu một lý do để vẫn dùng `fmt_div` và một lý do để chọn `fmt_hw`.
---
**Đáp án hoàn chỉnh.** Lý do dùng `fmt_div`: **không tốn phần cứng** (0 LUT thêm), chạy ở xung thường chỉ 0,45 % tải. Lý do chọn `fmt_hw`: ở xung thấp (`CPU_CLK_DIV = 1526`, 32 765 chu kỳ mỗi giây) `fmt_div` cần 684 % khi cập nhật 1 000 lần mỗi giây, không kịp, còn `fmt_hw` chỉ khoảng 76 % (`25 000 / 32 765`); đổi lại thêm khoảng 150 LUT (số Yosys, `inference`). Màn `HH.MM.SS` chỉ cần 1 lần mỗi giây nên `fmt_div` vẫn kịp; bộ đếm BCD phần cứng chỉ đáng khi cần màn giây.mili giây ở xung thấp.
:::

:::tu-luan
Vì sao `bus_rdata` chỉ cần OR các khối lại, mà không cần bộ chọn (MUX) theo địa chỉ?
---
**Đáp án hoàn chỉnh.** Quy ước của bus: mọi khối nhận chung địa chỉ và **tự trả 0 khi địa chỉ không phải của mình** (`mmio-map.md` mục 2). Với mỗi lần đọc, đúng một khối trả dữ liệu thật, chín khối còn lại trả 0. OR của dữ liệu thật với toàn 0 chính là dữ liệu thật. Nhờ vậy không cần mạch chọn riêng. Hệ quả: một khối quên trả 0 sẽ làm hỏng mọi lần đọc ở khối khác. Đó là yêu cầu mà mọi khối phải giữ (thanh ghi `bus_rdata` của khối là ô nhớ có clock, ra 0 mặc định).
:::

:::tu-luan
Hai cách kiểm chip: co-sim với ISS và cài lỗi cố ý. Mỗi cách chứng minh được gì và chưa chứng minh được gì?
---
**Đáp án hoàn chỉnh.** Co-sim với ISS: chứng minh chip **khớp mô hình** trên mọi chương trình đã chạy, từng lệnh một; chưa chứng minh mô hình đúng (ISS cùng nhóm viết), chưa chứng minh chương trình chưa chạy, chưa chứng minh chạy board thật. Cài lỗi cố ý: chứng minh một **bài thử cụ thể có bắt được** loại lỗi đó (ví dụ `hazard_tb` bắt lỗi bỏ `stall_lu`; `seg7_tb` bắt lỗi bỏ chống bóng ma); chưa chứng minh bài thử bắt được lỗi mà nhóm **chưa nghĩ ra để cài**. Hai cách bổ sung nhau, không cách nào thay được cách kia.
:::

:::mcq id=KT-U1-01
? Trong WatchChip, `timebase` có `CAL = 163 840` và `frac` bắt đầu bằng 0. Hai mili giây đầu dài bao nhiêu chu kỳ clock?
- [ ] 50 002 rồi 50 002, vì mỗi mili giây thêm đúng 2 chu kỳ
- [ ] 50 003 rồi 50 002, vì phần lẻ được dùng trước phần nguyên
- [ ] 50 005 rồi 50 000, vì phần lẻ tích lũy tới khi đủ rồi xả một lần
- [x] 50 002 rồi 50 003, xen kẽ, trung bình thêm 2,5 chu kỳ mỗi mili giây
> Giải thích: `s0 = 0 + 163 840`, `s0 >>> 16 = 2`, `frac = 32 768`. `s1 = 32 768 + 163 840 = 196 608`, `s1 >>> 16 = 3`, `frac = 0`. Lặp lại. Trung bình `2,5 / 50 000 = 50 ppm`.
:::

:::mcq id=KT-U1-02
? Ở lõi G2 của WatchChip, `fmt_div` đo 224 chu kỳ. Với `CPU_CLK_DIV = 1526` (CPU chạy khoảng 32 765 chu kỳ mỗi giây) và cập nhật 1 000 lần mỗi giây, tải CPU khoảng bao nhiêu?
- [ ] Khoảng 0,45 %, vì số chu kỳ mỗi lần không đổi nên tải cũng không đổi
- [ ] Khoảng 68 %, vì chia 224 cho 32 765 rồi nhân với 100
- [x] Khoảng 684 %: `224 × 1000 / 32 765`, nghĩa là không kịp
- [ ] Khoảng 6,8 %, vì CPU chậm đi 1526 lần nên số lần cập nhật giảm tương ứng
> Giải thích: `224 000 / 32 765 ≈ 6,84`, tức 684 %. Số chu kỳ mỗi lần không đổi nhưng số chu kỳ CPU mỗi giây giảm 1526 lần so với 50 MHz. Với màn `HH.MM.SS` chỉ cần 1 lần mỗi giây thì `224 / 32 765 ≈ 0,68 %`, kịp.
:::

:::mcq id=KT-U1-03
? Vì sao `bus_rdata` trong `soc_top.v` của WatchChip tính bằng OR của mười đường đọc mà vẫn đúng?
- [ ] Vì CPU chọn trước khối nào được phép trả lời bằng tín hiệu riêng
- [x] Vì mỗi khối tự trả 0 khi địa chỉ không phải của mình, nên chỉ khối đúng góp dữ liệu
- [ ] Vì phép OR chọn giá trị lớn nhất, và khối đúng luôn trả giá trị lớn nhất
- [ ] Vì bộ giải mã địa chỉ tắt các khối còn lại bằng cách ngắt clock của chúng
> Giải thích: quy ước của bus (`mmio-map.md` mục 2): khối nào không nhận ra địa chỉ thì trả 0. Chỉ một khối góp dữ liệu thật, chín khối còn lại góp 0, OR cho ra đúng dữ liệu. Không có tín hiệu chọn riêng và không có ngắt clock.
:::

:::mcq id=KT-U1-04
? Trong `seg7_scan.v` của WatchChip, dòng `wire [JW-1:0] js = (c < G_BLANK) ? ... : j;` để làm gì?
- [ ] Làm cho chữ số sáng hơn trong khoảng tắt bằng cách bật thêm anode
- [ ] Đảo thứ tự quét để chữ số bên trái được quét trước chữ số bên phải
- [x] Chống bóng ma: trong khoảng tắt vẫn xuất hình chữ số trước, hết khoảng tắt mới đổi sang chữ số mới
- [ ] Chọn độ sáng PWM, vì `js` quyết định anode bật bao lâu
> Giải thích: anode tắt chậm. Nếu chân đoạn đổi hình ngay lúc chuyển chữ số, anode cũ còn sáng mờ sẽ hiện hình mới. Giữ hình cũ đến hết `G_BLANK` rồi mới đổi. Cài lỗi bỏ dòng này (`js = j`), `seg7_tb` báo `FAIL ... 844 loi`.
:::

:::mcq id=KT-U1-05
? Co-sim của WatchChip báo `PASS cosim_iss` trên mọi chương trình. Điều nào sau đây được chứng minh?
- [ ] Chip đã đúng với phần cứng thật và có thể nạp lên board
- [ ] Mô hình ISS đúng tuyệt đối vì nó khớp với chip trên mọi chương trình
- [x] Chip khớp mô hình ISS từng lệnh trên các chương trình đã chạy, chỉ vậy
- [ ] Mọi chương trình có thể có đều chạy đúng trên chip, kể cả chương trình chưa thử
> Giải thích: co-sim so trace RTL với ISS trên những chương trình đã chạy. ISS và chip cùng nhóm viết nên có thể cùng sai; đó là lý do thêm đường MARS và đột biến. Chưa chạy board thật nên không khẳng định được về phần cứng thật.
:::
