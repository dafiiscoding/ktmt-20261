# Phần 0 · Học nhanh

## H0 · Bắt đầu từ số 0

Trang này viết cho người chưa học gì về phần cứng hay lập trình. Từ chuyên môn nào cũng được giải thích ngay chỗ nó xuất hiện. Quên nghĩa thì xem **Từ điển** ở H1.

**Đồ án này nói một câu:** nhóm tự thiết kế con chip cho một chiếc đồng hồ điện tử, rồi đo xem muốn đồng hồ chuẩn tới 1 phần nghìn giây thì việc nào giao cho chương trình được, việc nào phải làm bằng mạch điện.

Con chip tên là WatchChip, gồm ba phần:

- **Bộ não (CPU):** phần chạy các lệnh, hiểu 28 loại lệnh theo chuẩn có tên MIPS. Nhóm làm hai phiên bản, gọi là G1 và G2.
- **Các mạch phụ trách việc riêng (ngoại vi):** đếm thời gian, nhận nút bấm, sáng số trên đèn LED, xuất hình ra màn VGA, kêu còi, nhận dữ liệu từ máy tính qua UART (giải thích ở thẻ 10).
- **Chương trình chạy trên chip (firmware):** quyết định đồng hồ đang ở chế độ nào trong năm chế độ và hiện gì lên màn.

Con chip này **chỉ chạy trong mô phỏng, chưa chạy trên phần cứng thật**. Phần dưới giải thích câu đó, nhưng trước hết cần vài kiến thức nền.

### Kiến thức nền: máy tính làm việc thế nào

**Bit và số nhị phân.** Bên trong chip chỉ có dây điện, mỗi dây có điện hoặc không có điện, ghi là 1 hoặc 0. Một giá trị 0 hoặc 1 như vậy gọi là **bit**. Muốn ghi số lớn thì ghép nhiều bit, gọi là số nhị phân: 101 là 5, 111 là 7. CPU của nhóm là loại **32 bit**, nghĩa là nó tính trên các số dài 32 bit, tối đa khoảng 4,3 tỉ giá trị khác nhau.

**Bộ nhớ và địa chỉ.** Bộ nhớ giống một dãy nhà rất dài, mỗi nhà cất một con số. Số nhà gọi là **địa chỉ**. Muốn lấy dữ liệu thì đưa địa chỉ, bộ nhớ trả về con số trong nhà đó.

**Lệnh và chương trình.** Lệnh là một việc rất nhỏ mà CPU làm được, như cộng hai số hoặc lấy một số từ bộ nhớ. Chương trình là danh sách lệnh, cũng cất trong bộ nhớ. CPU chỉ lặp lại đúng một vòng: lấy lệnh, làm lệnh, sang lệnh kế tiếp.

**Clock (đồng hồ nhịp).** Mọi thứ trong chip chạy theo một tín hiệu đập đều như tiếng nhạc trưởng gõ nhịp. Mỗi nhịp, các ô nhớ cùng cập nhật giá trị mới. Lưu ý: clock này là nhịp làm việc của chip, không phải giờ mà đồng hồ hiện cho người xem.

**Đơn vị thời gian và tốc độ:**

| Đơn vị | Bằng | Hình dung |
|---|---|---|
| ms (mili giây) | 1/1 000 giây | Đồ án nhắm tới độ chuẩn này |
| µs (micro giây) | 1/1 000 ms | 1 ms = 1 000 µs |
| ns (nano giây) | 1/1 000 µs | 1 nhịp ở 50 MHz dài 20 ns |
| MHz | 1 triệu nhịp mỗi giây | 50 MHz là 50 triệu nhịp mỗi giây |

### Chip và Verilog

Con chip là một mạch điện cực nhỏ, gồm các **cổng logic** (mạch quyết định đầu ra là 0 hay 1 theo đầu vào) và các **ô nhớ** (mạch giữ lại một bit), nối với nhau bằng dây.

Không ai vẽ tay từng cổng. Người thiết kế viết bản mô tả bằng **Verilog**, một ngôn ngữ trông giống code nhưng mô tả mạch điện: dây nào nối vào đâu, tới nhịp clock thì ô nhớ nào đổi. Khác với code thường chạy từng dòng một, mọi phần trong Verilog hoạt động song song, như các máy trong nhà xưởng cùng chạy một lúc.

### Chạy trong mô phỏng nghĩa là gì

Có bản mô tả rồi, một chương trình trên máy tính đọc nó và **tính** xem ở từng nhịp, mỗi dây đang là 0 hay 1. Project này dùng chương trình Icarus Verilog (hai lệnh `iverilog` và `vvp`).

Không có mạch điện nào chạy cả. Giống như thử một ngôi nhà bằng phần mềm tính kết cấu trước khi xây: kết quả cho biết bản vẽ có đúng không, nhưng chưa có ngôi nhà.

Vì không có phần cứng, mọi thứ bên ngoài chip đều được đóng giả bằng **testbench**, tức file viết riêng để thử chip: nó tạo tín hiệu đầu vào rồi kiểm đầu ra có đúng không.

| Ngoài đời | Trong mô phỏng |
|---|---|
| Thạch anh (linh kiện tạo nhịp) phát clock | Testbench tự tạo clock 50 MHz ({{doc:docs/mmio-map.md:7}}) |
| Ngón tay bấm nút | Testbench đặt dây `btn` thành 1 ({{doc:docs/kich-ban-demo.md:126}}) |
| Đèn LED, màn VGA | Công cụ `tools/screen.py` đọc tín hiệu ở các dây ra của chip rồi vẽ lại hình |
| Máy tính gửi giờ qua cáp | Testbench gửi từng bit vào dây nhận dữ liệu |

Mô phỏng chậm hơn chip thật rất nhiều, nên phần lớn bài thử **nén thời gian**. Chip thật cần 50 000 nhịp cho 1 ms ({{doc:src/soc_top.v:23}}). Bài thử đặt thông số `G_N = 50`, tức chỉ 50 nhịp cho 1 ms ({{doc:tb/system_tb.v:27}}). Logic không đổi, chỉ nhanh hơn khoảng 1000 lần. Như tua nhanh một đoạn phim: diễn biến vẫn y nguyên. Riêng thí nghiệm đo độ chính xác E1′ dùng đủ 50 000 nhịp thật ({{doc:docs/goi-viec.md:279}}).

### FPGA là gì, board là gì

**FPGA** là một con chip "trống", bên trong có rất nhiều ô logic nhỏ và dây nối có thể đổi. Nạp một file cấu hình vào thì nó trở thành đúng mạch đã mô tả; nạp file khác thì thành mạch khác. Giống bộ đồ chơi lắp ghép: tháo ra lắp lại thành hình khác được. Nhờ vậy sinh viên có mạch thật mà không phải đặt nhà máy sản xuất chip, việc tốn rất nhiều tiền.

**Board** là tấm mạch gắn sẵn FPGA cùng những thứ để nó chạy được: thạch anh, nút bấm, đèn LED số, cổng màn hình VGA, cổng USB. Basys 3 và DE10-Lite là hai loại board nhóm từng cân nhắc.

Từ Verilog tới chiếc đồng hồ thật có năm bước:

| Bước | Làm gì | Công cụ | Trạng thái |
|---|---|---|---|
| 1. Viết | Mô tả mạch bằng Verilog | Trình soạn thảo | Đã xong |
| 2. Mô phỏng | Máy tính tính thử từng nhịp xem có đúng không | Icarus Verilog | Đã xong |
| 3. Tổng hợp | Dịch Verilog thành các ô của FPGA, biết mạch tốn bao nhiêu ô | Yosys | Mới đếm ước lượng |
| 4. Đặt dây, đo tốc độ | Xếp các ô lên chip thật, đo Fmax, xuất file nạp | Vivado hoặc Quartus | Chưa làm |
| 5. Nạp lên board | Cắm board, bấm nút thật, nhìn đèn thật | Board + file ràng buộc chân | Chưa làm |

**Fmax** là tốc độ clock cao nhất mà mạch còn kịp chạy đúng. Tín hiệu đi qua dây và cổng logic cũng mất thời gian, như người chạy tiếp sức. Clock nhanh quá thì kết quả chưa tới nơi đã bị ghi lại, thành sai. Mô phỏng của nhóm không tính thời gian đi dây này, nên chưa trả lời được câu "chip có chạy nổi 50 MHz không".

**File ràng buộc chân** cho biết mỗi tín hiệu của chip nối vào chân nào trên board, ví dụ dây `btn` nối vào nút nào.

### Vì sao chưa làm board

- **Quyết định:** Long chốt ngày 01/10 là chỉ mô phỏng, không board ({{doc:docs/de-bai.md:10}}, {{doc:docs/goi-viec.md:18}}).
- **Tình trạng ghi trong báo cáo:** nhóm không có board, máy không cài Vivado hay Quartus, nên bỏ phần Fmax ({{doc:report/3.6-bang-dat.md:50}}). File ràng buộc chân cũng chưa viết ({{doc:report/3.6-bang-dat.md:51}}).
- **Làm gì thay thế:** dựng màn hình ảo từ tín hiệu của chip, và giả lập thạch anh chạy lệch trong thí nghiệm E1′.

Tài liệu của project chỉ ghi như trên, không ghi lý do sâu hơn như tiền hay thời gian.

:::bay
Dòng "chỉ mô phỏng" trong {{doc:docs/de-bai.md:10}} do Long tự điền, chưa có câu trả lời nguyên văn của thầy. Vì vậy chưa thể nói "thầy đồng ý không cần board". Nên hỏi lại thầy trước khi bảo vệ.

Tiền lệ: báo cáo cuối kỳ của Nhóm 3 (kỳ 2025.1, nhóm được cho là điểm cao, điểm chưa kiểm) cũng chỉ mô phỏng trên ModelSim. Họ ghi rõ là "chưa thực hiện tổng hợp và nạp lên các kít phần cứng thực tế (như FPGA)" vì giới hạn thời gian và thiết bị. Đề của nhóm khác ở chỗ làm cả con chip đồng hồ, nên vẫn cần hỏi thầy để chắc.
:::

### Mô phỏng chứng minh được gì

| Đã chứng minh | Chưa chứng minh |
|---|---|
| Logic đúng ở từng nhịp, so với các đáp án độc lập | Chip có chạy nổi 50 MHz không, vì chưa có Fmax |
| Firmware chạy đúng trên chip, đủ năm chế độ | Nút thật rung ra sao, vì nút chỉ là testbench đặt dây thành 1 |
| Con số hiệu chỉnh `CAL` tính đúng với độ lệch giả định | Thạch anh thật đổi theo nhiệt độ; mô hình chỉ cho lệch cố định |
| Mạch quét LED chặn được bóng ma trong mô hình | Linh kiện thật tắt chậm bao lâu; số 1 µs và 3 µs là giả định |

### Muốn lên board thì cần thêm gì

Các việc sau là suy luận từ tài liệu (`inference`, tức chưa ai làm thử):

1. **Chọn board.** Chip đang dùng 8 chữ số LED và VGA. Ghi chú của nhóm nói Basys 3 có 4 chữ số, DE10-Lite có 6 (theo trí nhớ, `unverified`, tức chưa kiểm), nên phải đổi số chữ số hoặc chọn board khác.
2. **Cài Vivado hoặc Quartus.** Bước này không cần board mà đã đo được Fmax ({{doc:docs/goi-viec.md:18}}).
3. **Viết file ràng buộc chân.**
4. **Dùng thông số thật.** Bản chip mặc định đã là số thật, `G_N = 50000` ({{doc:src/soc_top.v:23}}). Chỉ testbench mới đặt số nhỏ.
5. **Kiểm mức tích cực.** Có board coi 1 là "nút đang bấm", có board coi 0 mới là bấm. Đèn cũng vậy. Khác nhau thì phải đổi thông số tương ứng.

## H1 · Làm những gì

Sơ đồ tổng thể của chip:

```text
   nút ──► buttons ─┐                       ┌──► seg7_scan ──► LED 7 đoạn
                    │   ┌──────────────┐    │
 UART RX ─► uart ───┼──►│  bus + MMIO  │◄──►├──► vga_digits ──► VGA
                    │   │  (soc_regs)  │    │
 timebase ─► timers ┘   └──────┬───────┘    └──► beeper ──► còi
 (CAL)   (rtc, sw, tmr, alarm) │  ▲ irq_ctrl (8 nguồn ngắt)
                        ┌──────▼──┴────┐
                        │  CPU G1 / G2 │◄── IMEM (firmware) + DMEM
                        └──────────────┘
```

**Cách đọc:** mũi tên là đường đi của dữ liệu. Bên trái là thứ đi vào chip: nút bấm, dữ liệu từ máy tính (UART), bộ đếm thời gian. Bên phải là thứ đi ra: đèn LED, màn VGA, còi. Ở giữa là **bus**, đường chung nối CPU với mọi khối, như trục đường chính nối các phòng ban. Dưới cùng là CPU cùng hai bộ nhớ.

| Lớp | Là gì | Làm gì |
|---|---|---|
| CPU | Bộ não, chạy từng lệnh | Có hai bản. G1 làm trọn một lệnh rồi mới sang lệnh sau. G2 chia lệnh thành 5 trạm như dây chuyền. |
| Ngoại vi | Các mạch chạy song song, không cần CPU trông | `timebase` tạo nhịp 1 ms. `timers` giữ giờ, bấm giờ, hẹn giờ, báo thức. `buttons` lọc nhiễu nút bấm. `seg7_scan` bật đèn số. `vga_digits` vẽ số ra màn hình. `beeper` kêu còi. `uart` gửi nhận dữ liệu với máy tính. `irq_ctrl` gom các yêu cầu ngắt gửi cho CPU. |
| Firmware | Chương trình `fw/main.s`, viết bằng hợp ngữ (cách viết sát với lệnh của CPU) | Đọc nút, đổi giữa năm chế độ: TIME (xem giờ), STOPWATCH (bấm giờ), TIMER (hẹn giờ), ALARM (báo thức), SET (chỉnh giờ), rồi ghi số ra màn hình. |
| Công cụ kiểm tra | Các chương trình phụ để bắt lỗi | `asm.py` dịch hợp ngữ thành mã số mà CPU đọc được. `iss.py` là một CPU giả viết bằng Python, dùng làm đáp án. `cmp_trace.py` so từng lệnh giữa chip và đáp án. |

**Muốn xem đồng hồ chạy:** bấm đôi vào file `work/demo_tuong_tac.html`, nó mở bằng trình duyệt, không cần mạng. Đây là phát lại kết quả mô phỏng, không phải chip thật.

### Từ điển

**Nền tảng**

| Từ | Nghĩa dễ hiểu |
|---|---|
| Bit | Một giá trị 0 hoặc 1. |
| CPU | Bộ não của chip, phần chạy các lệnh. |
| MIPS | Tên một bộ quy ước về lệnh của CPU, thường dùng để dạy. Nhóm làm theo quy ước này, 28 lệnh. |
| Lệnh | Một việc nhỏ CPU làm được. `addu` là cộng hai số, `lw` là đọc một số từ bộ nhớ, `sw` là ghi một số vào bộ nhớ. |
| Thanh ghi | 32 ô nhớ rất nhanh ngay trong CPU, như nháp để tính. Tên dạng `$t0`. Riêng `$zero` luôn bằng 0. |
| Địa chỉ | Số nhà của một ô trong bộ nhớ. |
| PC | Ô nhớ giữ địa chỉ của lệnh đang chạy. `next_pc` là địa chỉ của lệnh kế tiếp. |
| IMEM, DMEM | Bộ nhớ chứa lệnh và bộ nhớ chứa dữ liệu. |
| BRAM | Loại bộ nhớ có sẵn trong FPGA. Đưa địa chỉ ở nhịp này, phải tới cạnh clock tiếp theo mới có dữ liệu. |
| Firmware | Chương trình chạy trên chip của thiết bị. |
| Hợp ngữ | Cách viết chương trình sát với lệnh của CPU, như `lw $t0, 0($s0)`. |
| 0x | Đằng trước một số nghĩa là số đó viết theo hệ 16, một cách viết gọn số nhị phân: mỗi ký tự thay cho 4 bit. Ví dụ `0x180`. |

**Thời gian**

| Từ | Nghĩa dễ hiểu |
|---|---|
| Clock, nhịp | Tín hiệu đập đều, mọi ô nhớ đổi giá trị theo nhịp này. |
| Cạnh clock | Thời điểm clock đổi từ 0 sang 1 hoặc từ 1 sang 0. Mỗi nhịp có hai cạnh. |
| Chốt | Ghi một giá trị vào ô nhớ tại cạnh clock. Sau đó ô nhớ giữ giá trị này. |
| Chu kỳ CPU | Thời gian CPU làm một bước. G1 cần 2 nhịp clock cho 1 chu kỳ CPU nên chạy 25 MHz. |
| CPI | Trung bình mỗi lệnh tốn bao nhiêu chu kỳ CPU. Cùng tốc độ clock thì càng thấp càng tốt. |
| Thạch anh | Linh kiện rung đều, dùng để tạo clock. Luôn lệch một chút so với giờ chuẩn. |
| ppm | Phần triệu. Lệch 20 ppm tức là cứ 1 triệu ms lại sai 20 ms, khoảng 1,7 giây mỗi ngày. |
| `CAL` | Con số hiệu chỉnh, làm 1 ms dài thêm hoặc ngắn đi một chút để bù thạch anh lệch. |

**Cách chip làm việc với bên ngoài**

| Từ | Nghĩa dễ hiểu |
|---|---|
| Ngoại vi | Mạch ngoài CPU phụ trách một việc, như còi hay đếm giờ. |
| Bus | Đường chung nối CPU với mọi khối. |
| MMIO | Gán địa chỉ cho ngoại vi, để CPU đọc giờ, ghi màn hình bằng đúng lệnh đọc ghi bộ nhớ. |
| Polling | CPU tự hỏi đi hỏi lại "có ai bấm nút chưa?". Như cứ chốc lại chạy ra xem có khách không. |
| Ngắt | Thiết bị chủ động báo cho CPU. Như chuông cửa: CPU làm xong việc đang dở rồi ra mở cửa. |
| Handler | Đoạn chương trình CPU chạy khi có ngắt. |
| Capture | Mạch tự ghi lại thời điểm ngay nhịp xảy ra sự kiện, không chờ CPU. Như camera có in sẵn giờ. |

**Kiểm tra và đo đạc**

| Từ | Nghĩa dễ hiểu |
|---|---|
| Testbench | File dùng riêng để thử chip: tạo đầu vào rồi kiểm đầu ra. |
| RTL | Bản mô tả mạch bằng Verilog, tức chính con chip của nhóm. |
| ISS | CPU giả viết bằng Python, dùng làm đáp án để so. |
| Co-sim | Chạy cùng một chương trình trên chip và trên đáp án, rồi so từng lệnh. |
| MARS | Phần mềm chạy lệnh MIPS do người ngoài viết, dùng làm đáp án thứ hai. |
| Đột biến, cài lỗi | Cố ý làm hỏng code để xem bài thử có bắt được không. |
| Hồi quy | Chạy lại toàn bộ bài thử để chắc rằng chưa làm hỏng gì. |
| LUT, FF | Hai loại ô trong FPGA. LUT làm một phép logic nhỏ, FF nhớ 1 bit. |
| PASS, FAIL | Đạt, không đạt. |

## H2 · Ý nghĩa gì

Câu hỏi xuyên suốt: **muốn đồng hồ chuẩn tới 1 ms thì phần nào phải là phần cứng?**

"Phần mềm" ở đây là firmware chạy trên CPU. "Phần cứng" là mạch làm thẳng công việc, không cần CPU.

Thí nghiệm E3 đo việc này bằng nút bấm giờ: từ lúc nút được bấm tới lúc thời điểm đó được ghi lại mất bao lâu. Hình dung bạn cần ghi lại chính xác lúc khách tới cửa, có ba cách:

| Cách | Trong chip | Hình dung |
|---|---|---|
| **Polling** | CPU tự hỏi trong một vòng lặp. Nút bấm đúng lúc CPU vừa hỏi xong thì phải chờ hết vòng. | Cứ chốc lại chạy ra xem cửa. Khách tới ngay sau lần xem thì phải đợi tới lần sau. |
| **Ngắt** | Nút báo cho CPU. Nhanh hơn, nhưng CPU phải làm xong lệnh đang chạy. Nếu đang chạy phép chia `div` dài 33 chu kỳ thì phải chờ. | Có chuông cửa, nhưng đang bận việc dở thì làm xong mới ra. |
| **Capture phần cứng** | Mạch ghi ngay nhịp bấm, không cần CPU. | Camera tự in giờ ngay khi có người tới. |

Trong bảng dưới, **D** cho biết CPU chậm cỡ nào: cứ D nhịp clock thì CPU làm được một bước. D càng lớn thì CPU càng chậm. D = 1526 tương đương khoảng 32,8 nghìn lệnh mỗi giây. **Trễ** là thời gian từ lúc bấm tới lúc ghi được. **Sai số** là con số giờ ghi được lệch so với lúc bấm thật, tính trung bình.

| D | Cách | Trễ nhỏ nhất / trung bình / lớn nhất (µs) | Sai số trung bình (ms) |
|---|---|---|---|
| 2 | polling | 0,18 / 0,99 / 1,80 | 0,001 |
| 2 | ngắt | 0,08 / 0,64 / 1,38 | 0,001 |
| 100 | polling | 7,0 / 47,4 / 88,9 | 0,047 |
| 100 | ngắt | 2,0 / 31,1 / 68,0 | 0,031 |
| 1526 | polling | 108 / 740 / **1 358** | **0,740** |
| 1526 | ngắt | 31 / 466 / **1 037** | **0,466** |
| mọi D | capture | **0** (đúng nhịp bấm, {{so:e3-capture}} lần) | **0** |

Bảng chép từ {{doc:report/2.5-e3-thi-nghiem.md:31}}. Nhớ rằng 1 ms bằng 1000 µs.

**Cách đọc:** nhìn hàng D = 1526, cột trễ lớn nhất. Cả polling (1 358 µs) và ngắt (1 037 µs) đều có lúc trễ quá 1 ms, trong khi capture luôn bằng 0. Giờ nhìn hàng D = 2: polling chỉ trễ khoảng 1 µs, không đáng kể. Vậy phần mềm chỉ thua khi CPU chậm.

**Vì sao ngắt vẫn trễ:** ở D = 1526, một lệnh mất 1 526 nhịp. Nút bấm đúng lúc phép chia `div` vừa bắt đầu thì phải chờ, chậm nhất là 34 lệnh ({{doc:report/2.5-e3-thi-nghiem.md:35}}).

:::bay
Kết luận đúng: **khi CPU chạy chậm** thì phần mềm không giữ nổi 1 ms, còn capture phần cứng luôn đúng. Không được nói "polling luôn sai 0,74 ms". Đây là thí nghiệm riêng, có `div` chiếm 33/41 thời gian vòng lặp, không phải số đo của firmware thật `fw/main.s`. Firmware thật chỉ dùng ngắt cho UART.
:::

## H3 · Tóm tắt kiến thức

Mười một thẻ, mỗi thẻ một mảng. Phần "Thầy hay hỏi" có sẵn câu trả lời; nên che lại và tự trả lời trước. Dòng "Chỗ trong chip" là file và số dòng code cho ai muốn mở ra xem, không mở vẫn hiểu được.

:::the
**1. CPU và bản G1**

- **Là gì:** CPU là phần chạy lệnh. G1 là bản đơn giản: làm trọn một lệnh rồi mới sang lệnh sau. Hầu hết lệnh gói trong 1 chu kỳ CPU, trừ các lệnh dài như `div`, `bcd`.
- **Vấn đề:** bộ nhớ trong FPGA (BRAM) giống quầy nhận đồ: đưa số phiếu ở lần gõ nhịp này, tới lần gõ nhịp sau mới có đồ. Trong khi một lệnh đọc bộ nhớ `lw` cần cả hai lần lấy đồ: lấy chính lệnh đó từ bộ nhớ lệnh, rồi lấy dữ liệu từ bộ nhớ dữ liệu.
- **Cách giải:** chia 1 chu kỳ CPU thành hai khoảng, tương ứng hai cạnh của clock 50 MHz, gọi là **pha A** và **pha B**. Pha A lấy lệnh, pha B đọc dữ liệu. Vì tốn 2 nhịp cho một bước, G1 chạy 25 MHz, dù chip chỉ có một clock 50 MHz.
- **Chỗ trong chip:** {{doc:src/cpu_g1.v:8}}, {{doc:src/cpu_g1.v:157}}.
- **Thầy hay hỏi:** vì sao bộ nhớ lệnh IMEM nhận `next_pc` (địa chỉ lệnh kế tiếp) chứ không phải `PC` (địa chỉ lệnh hiện tại)? Vì nó cần được đưa địa chỉ từ trước. Đưa địa chỉ lệnh kế tiếp ở pha A thì lúc chu kỳ mới bắt đầu, lệnh đã sẵn. Đưa `PC` thì lệnh ra trễ mất nửa chu kỳ.
:::

:::the
**2. ALU và lệnh so sánh `slt`**

- **Là gì:** ALU là khối tính toán của CPU, như cái máy tính bỏ túi: cộng, trừ, so sánh, dịch bit.
- **Vì sao cần:** mọi lệnh tính toán đều qua đây. Đọc ghi bộ nhớ cũng dùng nó để cộng ra địa chỉ.
- **`slt` làm gì:** trả 1 nếu số đầu nhỏ hơn số sau, không thì trả 0.
- **Tràn là gì:** số 32 bit có giới hạn, khoảng từ −2,1 tỉ tới +2,1 tỉ. Giống đồng hồ công-tơ-mét xe máy: 99 999 cộng thêm 1 quay về 00 000. Tính vượt giới hạn thì kết quả bị sai dấu. Đó là **tràn**.
- **Bit dấu:** bit đầu tiên của số cho biết âm hay dương, 1 là âm, 0 là dương.
- **Chỗ trong chip:** {{doc:src/alu.v:26}}.
- **Thầy hay hỏi:** muốn so sánh thì lấy hiệu rồi xem dấu là xong, vì sao `slt` không làm chỉ thế? Vì hiệu có thể tràn nên dấu sai. Nên mạch xem trước: hai số khác dấu thì số âm là số nhỏ hơn, khỏi cần trừ. Hai số cùng dấu thì phép trừ không bao giờ tràn, lúc đó mới dùng dấu của hiệu.
:::

:::the
**3. Phép chia `div` và đổi số `bcd`**

- **`div`:** chia theo đúng kiểu chia cột dọc đã học, nhưng trên số nhị phân. Mỗi bước hạ một bit xuống, thử trừ số chia; trừ được thì ghi 1 vào thương, không thì ghi 0. Làm 32 bước vì số có 32 bit.
- **`bcd`:** máy tính giữ số ở dạng nhị phân, nhưng đèn LED cần từng chữ số 0 đến 9. Khối này đổi nhị phân thành từng chữ số thập phân.
- **Cách đổi (double dabble):** đẩy từng bit của số vào các ô chữ số. Mỗi lần đẩy là nhân đôi giá trị trong ô. Trước mỗi lần đẩy, ô nào từ 5 trở lên thì cộng thêm 3.
- **Vì sao cần làm nhiều bước:** chia từng bước thì mạch nhỏ hơn hẳn mạch chia xong trong một lần, đổi lại tốn thời gian.
- **Chỗ trong chip:** {{doc:src/muldiv.v:7}}, {{doc:src/bcd_unit.v:37}}, {{doc:src/bcd_unit.v:47}}.
- **Thầy hay hỏi:** `div` mất bao lâu? 33 chu kỳ CPU: 1 chu kỳ khởi động và 32 bước. `−7 / 2` ra gì? Thương −3, dư −1, vì −3 × 2 + (−1) = −7. Vì sao cộng 3? Ô chữ số chỉ tự nhớ sang ô kế khi vượt 15, còn số thập phân phải nhớ khi vượt 9. Cộng 3 rồi nhân đôi là thêm đúng 6, bù vừa đủ khoảng cách từ 10 tới 16.
:::

:::the
**4. Dây chuyền năm trạm (pipeline, bản G2)**

- **Là gì:** G2 chia mỗi lệnh thành 5 trạm, như dây chuyền rửa xe. Mỗi chu kỳ, mỗi trạm làm cho một lệnh khác nhau, nên cùng lúc có 5 lệnh đang được xử lý.
- **Năm trạm:** IF lấy lệnh từ bộ nhớ. ID đọc hiểu lệnh và lấy số từ thanh ghi. EX tính toán. MEM đọc ghi bộ nhớ. WB ghi kết quả vào thanh ghi.
- **Vì sao cần:** clock chỉ phải chờ trạm chậm nhất thay vì chờ cả lệnh, nên G2 chạy được 50 MHz.
- **Tên hay gặp:** giữa hai trạm có thanh ghi trung chuyển để giữ dữ liệu, gọi theo hai trạm đó, ví dụ ID/EX, EX/MEM, MEM/WB.
- **Chỗ trong chip:** {{doc:src/cpu_pipe.v:14}}.
- **Thầy hay hỏi:** gặp lệnh rẽ nhánh (lệnh "nếu đúng thì nhảy tới chỗ khác") thì dây chuyền làm gì, có delay slot không? CPU luôn đoán "không nhảy" và lấy tiếp lệnh ngay sau; đoán sai thì xóa. Không có delay slot, tức là không có quy định bắt buộc chạy lệnh nằm ngay sau nhánh. Vì sao quyết định nhảy ở EX, không đưa lên ID cho phạt ít hơn? Đưa lên ID thì phạt 1 thay vì 2 khi nhảy thật. Đổi lại, lệnh nhánh đứng ngay sau `lw` phải chờ 2 chu kỳ thay vì 1 ({{doc:docs/pipeline-policy.md:190}}, bảng T4). Báo cáo Nhóm 3 chọn ID; hai cách đều hợp lý, khác nhau ở chỗ đánh đổi.
:::

:::the
**5. Xung đột trên dây chuyền (hazard)**

- **Là gì:** các lệnh chồng lên nhau trên dây chuyền, nên lệnh sau có thể cần thứ mà lệnh trước chưa làm xong. Đó là hazard, gồm ba loại:
  - **Cấu trúc:** hai lệnh cùng cần một phần cứng, ví dụ cùng lúc lấy lệnh và đọc dữ liệu từ một bộ nhớ. Chip tránh bằng cách tách bộ nhớ lệnh (IMEM) và bộ nhớ dữ liệu (DMEM), kiểu **Harvard**. Chỗ ghi và đọc thanh ghi trong cùng chu kỳ cũng được xử lý bằng đi tắt qua regfile.
  - **Dữ liệu:** lệnh sau cần kết quả của lệnh trước.
  - **Điều khiển:** lệnh rẽ nhánh làm chưa biết lệnh kế tiếp là lệnh nào.

  Bốn trường hợp dưới đây thuộc loại dữ liệu và điều khiển, riêng `busy` là trường hợp đơn vị tính còn đang bận.
- **Forwarding (chuyền tắt):** lệnh sau cần kết quả mà lệnh trước chưa ghi vào thanh ghi. Giống như đồng nghiệp đưa thẳng kết quả sang tay bạn, không đợi ghi vào sổ. Mạch chuyền thẳng kết quả về trạm EX, không phải chờ. Có hai nguồn thì lấy nguồn mới hơn: EX/MEM trước MEM/WB.
- **Load-use (đọc rồi dùng ngay):** lệnh sau dùng ngay số mà `lw` vừa đọc. Tới cuối trạm MEM số đó mới có, chuyền tắt cũng không kịp, nên lệnh sau đứng chờ 1 chu kỳ.
- **Nhánh nhảy thật:** tới trạm EX mới biết phải nhảy, lúc đó dây chuyền đã lỡ lấy 2 lệnh sai, phải xóa, nên **mất 2 chu kỳ**. Gọi là phạt 2.
- **Phép tính dài (`busy`):** `div`, `bcd` cần nhiều chu kỳ, trong lúc đó tín hiệu `busy` (đang bận) giữ các trạm phía trước đứng yên; MEM và WB vẫn chạy tiếp.
- **Chỗ trong chip:** {{doc:src/hazard.v:39}}, {{doc:src/hazard.v:41}}, {{doc:src/hazard.v:46}}.
- **Thầy hay hỏi:** nhiều trường hợp trùng nhau thì sao? Ưu tiên **busy > flush > load-use**; flush là xóa lệnh sai khi nhánh nhảy. Hazard gồm mấy loại? Ba: cấu trúc, dữ liệu, điều khiển. Loại cấu trúc ở bộ nhớ không xảy ra vì IMEM và DMEM tách riêng. Đang bận thì chưa quyết định gì cả, rồi mới tới xóa lệnh sai, cuối cùng mới tới đứng chờ.
:::

:::the
**6. Ngắt và CP0**

- **Là gì:** ngắt là khi thiết bị báo cho CPU có việc, như đang đọc sách thì chuông cửa reo. CPU phải đánh dấu trang đang đọc, ra mở cửa, rồi quay lại đúng trang đó.
- **Trong chip:** "cái kẹp đánh dấu trang" là thanh ghi `EPC`, lưu địa chỉ để quay về. "Việc mở cửa" là đoạn chương trình **handler**, luôn nằm ở địa chỉ `0x180`. Lệnh `eret` đưa CPU quay về. Thanh ghi `Status` bật hoặc tắt việc nhận ngắt. `EPC` và `Status` nằm trong CP0, bộ thanh ghi quản lý riêng.
- **G1 khác G2:**
  - G1 chỉ có một lệnh, nên nhận ngắt ở cuối lệnh, không phải hủy gì. `EPC` = `next_pc`, tức lệnh kế tiếp.
  - G2 có nhiều lệnh đang dở trên dây chuyền, nên nhận ở ranh giới ID/EX. Lệnh đã đi xa (ở EX/MEM và MEM/WB) được làm nốt. Lệnh mới vào (ở ID và ID/EX) bị hủy và chạy lại sau `eret`. `EPC` = lệnh cũ nhất chưa xong.
- **Chỗ trong chip:** {{doc:src/cpu_g1.v:11}}, {{doc:src/cpu_pipe.v:122}}, {{doc:src/cpu_pipe.v:202}}.
- **Thầy hay hỏi:** ngắt đến lúc `div` đang chạy thì sao? Chờ hết `busy` rồi mới nhận. Firmware có dùng ngắt cho nút bấm không? Không, `main.s` chỉ dùng ngắt cho việc nhận dữ liệu UART.
:::

:::the
**7. MMIO: nói chuyện với ngoại vi như đọc bộ nhớ**

- **Là gì:** mỗi thanh ghi của ngoại vi được gán một địa chỉ, như gán số nhà. CPU đọc giờ bằng đúng lệnh `lw` dùng để đọc bộ nhớ.
- **Vì sao cần:** không phải thêm lệnh riêng cho từng thiết bị.
- **Ví dụ:** lệnh `lw` tính địa chỉ bằng cách lấy thanh ghi cộng một con số gọi là offset. Vùng ngoại vi nằm ở cuối dãy địa chỉ, nên chỉ cần lấy `$zero` (luôn bằng 0) cộng một offset âm. Số âm trong máy tính ứng với các địa chỉ cuối dãy.
- **Chỗ trong chip:** {{doc:docs/mmio-map.md:58}}.
- **Thầy hay hỏi:** số −252 trong code là gì? Là thanh ghi `MS_OF_DAY` (`FF04`), chứa số mili giây đã trôi qua trong ngày. Đọc nó thì mạch đồng thời chụp lại ngày, để giờ và ngày luôn khớp nhau kể cả khi đọc đúng lúc qua nửa đêm.
:::

:::the
**8. `timebase` và `CAL`: bù cho thạch anh lệch**

- **Là gì:** `timebase` đếm clock 50 MHz để tạo nhịp 1 ms. Bình thường 1 ms là 50 000 nhịp.
- **Vấn đề:** thạch anh luôn lệch một chút. Nếu nó chạy nhanh hơn 50 ppm, mỗi ms phải đếm thêm 2,5 nhịp, mà không thể đếm nửa nhịp.
- **Cách giải:** giống trả mỗi ngày 2,5 nghìn mà chỉ có tờ 1 nghìn: ngày trả 2, ngày trả 3, cộng dồn phần lẻ. Mạch có một ô cộng dồn gọi là **phần lẻ**. Mỗi ms cộng `CAL` vào đó; đủ tròn bao nhiêu nhịp thì ms đó dài thêm bấy nhiêu nhịp. Ví dụ trên, các ms sẽ dài 50 002 và 50 003 nhịp xen kẽ.
- **Đơn vị:** 1 nhịp được chia thành 65 536 phần (số lớn nhất mà 16 bit biểu diễn được, cộng 1). `CAL` đếm theo phần này.
- **Chỗ trong chip:** {{doc:src/timebase.v:34}}, {{doc:src/timebase.v:37}}.
- **Thầy hay hỏi:** vì sao 1 ppm = 3 276,8? Suy dẫn từng bước ở H5. `CAL` âm thì dịch kiểu nào? Dịch bit sang phải là phép chia đôi nhanh. Dịch số học giữ nguyên bit dấu nên số âm vẫn âm; dịch logic đẩy số 0 vào đầu, biến số âm thành số dương rất lớn.
:::

:::the
**9. Nút bấm, bấm giờ, hẹn giờ, báo thức**

- **Là gì:** `buttons` lọc nhiễu nút và ghi giờ lúc bấm. `timers` gồm giờ, bấm giờ, hẹn giờ và 4 báo thức.
- **Vì sao cần:** nút nối thẳng vào khối bấm giờ. Nên **lap** (bấm để ghi một mốc thời gian, như vận động viên qua một vòng chạy) được ghi ngay đúng nhịp bấm, không qua CPU. Đây chính là capture trong thí nghiệm E3. Khối bấm giờ còn có bộ chia nhịp riêng, được đặt lại ngay lúc reset, để lần bấm giờ mới đếm đúng từ đầu.
- **Chống rung:** nút cơ khí khi bấm thì tiếp điểm đóng mở nhiều lần rất nhanh, như quả bóng nảy vài lần trước khi nằm yên. Nếu không xử lý, một lần bấm bị tính thành nhiều lần. Mạch nhận ngay lần đầu, rồi bỏ qua mọi thay đổi trong 10 ms.
- **Chỗ trong chip:** {{doc:src/timers.v:161}}, {{doc:src/timers.v:214}}, {{doc:src/buttons.v:5}}.
- **Thầy hay hỏi:** hẹn giờ về 0 thì sao? Không dừng, đếm tiếp sang số âm. Số âm cho biết đã quá giờ bao nhiêu mili giây.
:::

:::the
**10. Hiển thị và UART**

- **LED 7 đoạn:** mỗi chữ số ghép từ 7 thanh đèn, như số trên đồng hồ điện tử. Có 8 chữ số dùng chung 7 dây điều khiển thanh đèn, gọi là **chân đoạn**. Mỗi chữ số có thêm một công tắc riêng gọi là **anode**. Mỗi lúc chỉ bật được 1 chữ số.
- **Quét:** bật lần lượt 8 chữ số, mỗi chữ số 1 ms. Mỗi chữ số sáng lại 125 lần mỗi giây, nhanh tới mức mắt thấy cả 8 cùng sáng.
- **Bóng ma:** khi chuyển chữ số, công tắc anode cũ tắt chậm, nên chữ số cũ hiện mờ hình của chữ số mới. Sửa bằng một khoảng tắt ngắn `G_BLANK`: giữ chân đoạn cũ trong lúc tắt, hết khoảng tắt mới đổi chân đoạn và bật chữ số mới.
- **VGA:** màn hình được vẽ từng điểm, từ trái qua phải, từ trên xuống dưới. Chip không có bộ nhớ chứa sẵn cả bức hình (frame buffer), mà tính màu của mỗi điểm ngay lúc tới lượt điểm đó.
- **UART:** cách gửi dữ liệu từng bit qua một sợi dây. Tốc độ 115 200 baud, tức 115 200 bit mỗi giây. Kiểu 8N1 nghĩa là mỗi gói có 8 bit dữ liệu, không có bit kiểm tra, 1 bit kết thúc (stop). Lúc rảnh, dây giữ mức 1. Thấy dây tụt xuống 0, mạch chờ nửa bit, vẫn là 0 thì mới coi là bắt đầu thật. Bit stop phải là 1, không thì báo lỗi gói.
- **Chỗ trong chip:** {{doc:src/seg7_scan.v:27}}, {{doc:src/seg7_scan.v:28}}, {{doc:src/vga_digits.v:10}}, {{doc:src/uart.v:9}}.
- **Thầy hay hỏi:** vì sao lấy mẫu ở giữa bit? Vì giữa bit là chỗ xa hai mép chuyển mức nhất, nên hai bên có lệch nhịp một chút vẫn đọc đúng.
:::

:::the
**11. Vì sao tin chip chạy đúng**

- **Vấn đề:** nhóm tự viết chip và tự viết bài thử. Nếu hiểu sai từ đầu thì cả hai cùng sai mà bài thử vẫn đạt. Vì vậy cần đáp án từ nơi khác.
- **Ba nguồn đáp án độc lập:** các bộ số do script sinh ra, CPU giả ISS, và phần mềm MARS của người ngoài.
- **Chạy trên chip:** `system_tb` có {{so:system-tb}} điểm kiểm với firmware thật, gồm cả bản polling. So từng lệnh với ISS {{so:cosim-iss}} mục, với MARS {{so:cosim-mars}} mục.
- **Cài lỗi:** cố ý làm hỏng code thì bài thử phải phát hiện được. Không phát hiện nghĩa là bài thử yếu.
- **Chỗ trong chip:** {{doc:evidence/20261027_regress_rbuf.log:102}}.
- **Thầy hay hỏi:** CPU giả ISS sai thì co-sim có phát hiện không? Không chắc, vì chip và ISS có thể cùng hiểu sai một lệnh, nên mới có thêm MARS. Giới hạn: tất cả vẫn chỉ là mô phỏng.
:::

## H4 · Một lệnh đi qua chip

Mục này theo một lệnh thật, để thấy các phần ở trên ghép với nhau thế nào.

Lệnh mẫu: `lw $t0, -252($zero)`. Đọc thành lời: lấy `$zero` (bằng 0) cộng −252 ra một địa chỉ, đọc giá trị ở đó, cất vào thanh ghi `$t0`. Ý nghĩa thực tế: **xem bây giờ là mấy giờ.**

Trong máy tính, −252 dài 32 bit được viết là `0xFFFFFF04`. Đây là địa chỉ của `MS_OF_DAY`, thanh ghi chứa số mili giây trong ngày. Mạch nhận ra địa chỉ này thuộc vùng ngoại vi nên đọc qua bus, không đọc bộ nhớ dữ liệu. Khi bị đọc, thanh ghi đồng thời chụp lại ngày.

**Ở G1,** một chu kỳ CPU gồm hai pha, A và B:

| Thời điểm | Việc xảy ra |
|---|---|
| Pha A | Bộ nhớ lệnh đã đưa lệnh ra, vì nó nhận địa chỉ `next_pc` từ trước. |
| Giữa A và B | CPU đọc hiểu lệnh, đọc `$zero`, ALU cộng −252 ra địa chỉ. |
| Pha B | Tín hiệu `bus_re` (đọc bus) bật lên ({{doc:src/cpu_g1.v:128}}). Ngoại vi nhận địa chỉ, trả về `MS_OF_DAY`, và chụp ngày. |
| Giữa B và A | Dữ liệu `bus_rdata` (số đọc được từ bus) đi qua bộ chọn tới cổng ghi của thanh ghi ({{doc:src/cpu_g1.v:130}}). Bộ chọn (MUX) giống công tắc chọn một trong nhiều đường. |
| Pha A kế tiếp | `$t0` được ghi kết quả. |

**Ở G2,** cùng lệnh đó đi qua 5 trạm, mỗi trạm 1 chu kỳ:

1. IF lấy lệnh.
2. ID đọc hiểu lệnh và đọc `$zero`.
3. EX tính ra địa chỉ.
4. MEM đọc qua bus.
5. WB ghi vào `$t0`.

Nếu lệnh ngay sau dùng `$t0`, nó phải đứng chờ 1 chu kỳ vì tới cuối trạm MEM dữ liệu mới có.

## H5 · Tính tay ba phép

Hai bảng đầu là **bảng chu kỳ**: mỗi hàng là một lệnh, mỗi cột là một chu kỳ (c1 là chu kỳ 1), ô ghi lệnh đó đang ở trạm nào. Đọc theo cột để biết tại một lúc, các lệnh đang ở đâu.

### Load-use: `lw` rồi dùng ngay

Lệnh `lw` đọc một số vào `$t0`, lệnh `addu` ngay sau đó cần dùng `$t0`.

| Lệnh | c1 | c2 | c3 | c4 | c5 | c6 | c7 |
|---|---|---|---|---|---|---|---|
| `lw $t0,0($s0)` | IF | ID | EX | MEM | WB | | |
| `addu $t1,$t0,$t2` | | IF | ID (phát hiện) | ID* | EX (nhận chuyền tắt) | MEM | WB |
| (bubble) | | | | EX — | MEM — | WB — | |
| lệnh kế | | | IF | IF* | ID | EX | MEM |

- `*` là đứng yên ở trạm cũ.
- **Bubble** là chỗ trống được chèn vào dây chuyền, không làm gì, như một khoang trống trên băng chuyền.
- Ở c3, mạch phát hiện `addu` cần số mà `lw` chưa đọc xong, nên giữ `addu` lại một chu kỳ. Tới c5, số đã có và được chuyền tắt từ MEM/WB về EX.
- Kết quả: `addu` chậm đúng 1 chu kỳ.

### Nhánh nhảy thật

Lệnh `beq` nghĩa là "nếu hai số bằng nhau thì nhảy tới nhãn `L`". `i+1`, `i+2` là hai lệnh nằm ngay sau `beq`.

| Lệnh | c1 | c2 | c3 | c4 | c5 | c6 |
|---|---|---|---|---|---|---|
| `beq $s0,$s2,L` | IF | ID | EX (nhảy) | MEM | WB | |
| `i+1` | | IF | ID | bị xóa | | |
| `i+2` | | | IF | bị xóa | | |
| `L:` | | | | IF | ID | EX |

Tới c3 mới biết phải nhảy, lúc đó đã lấy nhầm hai lệnh `i+1` và `i+2`. Xóa hai lệnh này nên mất 2 chu kỳ.

### `CAL` với thạch anh nhanh +20 ppm

**Bối cảnh:** máy tính gửi giờ chuẩn cho chip hai lần, cách nhau một khoảng I. Chip so với giờ của nó thì thấy lệch một lượng D. Từ đó firmware tính ra `CAL` cần chỉnh.

**Công thức:** D = I × p / 1 000 000, với p là độ lệch tính bằng ppm. Sau đó ΔCAL = ((D × 65 536) / (I / 1000)) × 50, trong đó ΔCAL là lượng cần chỉnh và phép chia chỉ lấy phần nguyên ({{doc:fw/main.s:739}}).

**Thay số:**

1. I = 60 phút = 3 600 000 ms, p = 20, nên D = 72 ms. Sau 1 giờ, chip lệch 72 ms.
2. 72 × 65 536 / 3600 = 1310,72, lấy phần nguyên được 1310.
3. 1310 × 50 = **65 500**.
4. Giá trị lý tưởng là 20 × 3 276,8 = 65 536. Thiếu 36 vì phép chia đã bỏ phần lẻ.

**Kiểm bằng cách chạy thử:** đo trên chip mô phỏng, 1 000 ms có 50 000 999 nhịp, còn lý tưởng là 50 001 000. Thiếu 1 nhịp trên 50 triệu, tức chỉ còn lệch {{so:e1-con-20}}.

**Vì sao 1 ppm = 3 276,8:**

1. 1 ms có 50 000 nhịp.
2. 1 ppm là một phần triệu, nên 1 ppm của 50 000 nhịp là 0,05 nhịp.
3. `CAL` tính theo đơn vị 1/65 536 nhịp, nên 0,05 × 65 536 = 3 276,8.

**Trường hợp +250 ppm:** D = 900 ms, lớn hơn giới hạn I / 5000 = 720 ms, nên firmware **từ chối** và giữ `CAL` cũ. Giới hạn này tương đương 200 ppm. Thạch anh hiếm khi lệch nhiều vậy, nên lệch quá thì coi như câu giờ gửi tới bị sai, không tin.

:::bay
Kết quả trên là mô phỏng tách riêng firmware với `timebase`. Review trên cloud báo `CAL` có thể học lệch −16,7…−20 ppm khi máy tính gửi giờ mỗi phút, chưa kiểm trên bản local. Xem H7.
:::

## H6 · Năm con số

| Con số | Cách hiểu |
|---|---|
| CPI G1 = {{so:cpi-g1}}; G2 = {{so:cpi-g2}} | CPI là số chu kỳ trung bình cho một lệnh. Thời gian chạy = số lệnh × CPI / tần số. CPI của G2 cao chủ yếu vì nhánh ({{so:g2-nhanh}} chu kỳ) và `busy` ({{so:g2-busy}}), load-use chỉ {{so:g2-loaduse}}. Nhưng G2 chạy 50 MHz so với 25 MHz nên vẫn nhanh hơn. Với ba chương trình thử: `sum100` {{so:tang-sum100}}, `fact10` {{so:tang-fact10}}, `bcd` {{so:tang-bcd}}. Báo cáo Nhóm 3 ghi CPI 1,34 (lý thuyết 1,0, chênh do phạt nhánh), thấp hơn của nhóm mình. Không so thẳng được: họ chỉ có 14 lệnh, không có `div`, `bcd`, ngắt, và đo một chương trình tính tổng 1 đến 10. CPI của G2 nhóm mình cao chủ yếu do nhánh và `busy`. |
| 0 / 0,47 / 0,74 ms | Sai số trung bình của capture, ngắt, polling trong thí nghiệm E3, ở D = 1526 (CPU chậm nhất). |
| {{so:system-tb}} kiểm | Số điểm kiểm của `system_tb`, bài thử chạy firmware thật trên chip, gồm cả bản polling. Toàn bộ hồi quy có 41 dòng PASS, kết thúc `EXIT 0` (nghĩa là không có lỗi). |
| 28 lệnh | Số loại lệnh MIPS mà CPU của nhóm hiểu. |
| 1 ppm = 3 276,8 | Số đơn vị `CAL` ứng với 1 ppm. Suy dẫn ở H5. |

## H7 · Giới hạn phải nói thật

Bảo vệ đồ án thì phải nói rõ những điều sau, đừng để thầy phát hiện trước.

- Chip chỉ chạy mô phỏng, chưa có board, chưa có file nạp (xem H0). Báo cáo Nhóm 3 kỳ trước cũng chỉ mô phỏng và nói rõ điều đó. `G_N = 50` chỉ để nén thời gian trong bài thử, không phải tốc độ của chip.
- Số LUT, FF (số ô mạch tốn) là ước lượng từ Yosys, không phải Vivado (`inference`, tức suy luận). Chưa có số Fmax.
- G2 đã chạy qua toàn bộ hồi quy, nhưng bản demo hiện là G1.
- Phần lớn code do Claude viết theo yêu cầu của Long. Cách khai với thầy chưa chốt.
- Chưa có đề và barem BTL gốc. C1–C8 là tiêu chí do nhóm tự đặt, không thể khẳng định bộ ôn bao phủ đúng barem thầy.
- E1′: kết quả ≤ 0,1 ppm là mô phỏng tách riêng firmware với `timebase`. Review cloud báo `CAL` có thể học lệch −16,7…−20 ppm khi máy tính gửi giờ mỗi phút. Trên bản local chưa kiểm lại (`unverified`, tức chưa kiểm).

## H8 · Từ đây mỗi người làm gì

Nhóm không phải viết code mới. Việc của mỗi người là hiểu phần được giao tới mức giải thích được, chỉ được dòng code liên quan và tự sửa một lỗi nhỏ. TV1–TV5 là thành viên 1 đến 5; chưa có tên người ghép với từng phần.

### Cách chạy bài tự kiểm

Bài tự kiểm là chương trình chạy thử phần của mình và báo đạt hay không. Trên Windows, làm như sau:

1. Mở thư mục project `ktmt-2026-1-casio`. Bấm chuột phải vào chỗ trống, chọn **Open Git Bash here** (Windows 11 có thể phải chọn **Show more options** trước). Git Bash là cửa sổ để gõ lệnh; máy chưa có thì cài Git for Windows.
2. **Chỉ làm lần đầu, cần mạng:** gõ `bash tools/setup_env.sh` rồi Enter. Lệnh này cài công cụ vào ngay trong thư mục project.
3. **Mỗi lần mở cửa sổ mới:** gõ `source tools/env.sh` rồi Enter. Lệnh này không in gì cả, đó là bình thường.
4. Gõ lệnh trong cột "Tự kiểm" của bảng dưới, rồi đọc kết quả.

**Đọc kết quả thế nào:** ví dụ `bash tools/run_unit.sh alu` in ra `PASS alu_tb 4200`. `PASS` là đạt, `alu_tb` là tên bài thử, 4200 là số trường hợp đã thử. Dòng `$finish called` ngay sau là thông báo bình thường. Nếu thấy `FAIL` thì đọc dòng đó xem sai ở đâu.

**Báo `command not found`** thường là quên bước 3 hoặc chưa làm bước 2.

### Phần của từng người

| Người | Phần việc | File chính | Tự kiểm | Câu hỏi hay gặp |
|---|---|---|---|---|
| TV1 | Tính toán, nhân chia, đổi số | `alu.v` `muldiv.v` `bcd_unit.v` | `bash tools/run_unit.sh alu muldiv bcd` | Vì sao `slt` không chỉ nhìn dấu của hiệu? `div` mất bao lâu? |
| TV2 | Công cụ, xung đột dây chuyền, firmware | `asm.py` `iss.py` `hazard.v` `main.s` | `pytest tools/` · `python tools/cosim_iss.py --rand 0` · `bash tools/run_unit.sh hazard` | Vì sao `lw` rồi dùng ngay phải chờ? ISS sai thì co-sim có phát hiện không? |
| TV3 | CPU và ghép chip | `regfile.v` `control.v` `cpu_g1.v` `cpu_pipe.v` `irq_ctrl.v` `soc_top.v` | `bash tools/run_unit.sh regfile control irq system` · `python tools/cosim_iss.py --rand 0` | `lw` đi từ địa chỉ tới thanh ghi đích thế nào? Ngắt đến lúc `div` chạy thì sao? |
| TV4 | Hiển thị, còi, UART | `seg7_scan.v` `display_ctrl.v` `beeper.v` `uart.v` `vga_digits.v` | `bash tools/run_unit.sh seg7 display_ctrl beeper uart vga_digits exp_e4` | Bóng ma là gì? UART lấy mẫu giữa bit để làm gì? |
| TV5 | Đếm ms, nút, đồng bộ giờ | `timebase.v` `timers.v` `buttons.v` `rtc_bcd.v` | `bash tools/run_unit.sh timebase rtc stopwatch cdtimer alarm buttons exp_cal` | Vì sao 1 ppm = 3 276,8? `CAL` âm dịch kiểu nào? Capture khác polling ở đâu? |
| Long | Biên tập báo cáo + 1 phần tự chọn | `report/latex/` | | |

File đuôi `.v` là Verilog, nằm trong `src/`. File đuôi `.py` và `main.s` nằm trong `tools/` và `fw/`.

### Mốc gần nhất: Cổng 1 ngày 14/11

Cổng là mốc tự kiểm tra của nhóm. Cổng 1 kiểm G1 và phần của mỗi người. Yêu cầu:

- **Vấn đáp:** đúng ít nhất 8/10 câu về phần của mình, và 3/5 **câu chéo** (câu chung ai cũng phải trả lời được), chỉ được đúng dòng code.
- **Sửa tại chỗ:** tự sửa được một lỗi nhỏ trong 30 phút.
- **Chạy lại bài tự kiểm** sau khi sửa.

## H9 · Tự kiểm tra

Chọn đáp án rồi tự giải thích vì sao. Câu sai được lưu lại để ôn tiếp.

:::mcq id=KT-H-01
? WatchChip hiện đã chạy ở đâu?
- [x] Chỉ trong mô phỏng trên máy tính
- [ ] Trên FPGA, nhưng chưa đo Fmax
- [ ] Trên board mượn của phòng thí nghiệm
- [ ] Trên FPGA, còn phần VGA thì mô phỏng
> Giải thích: nhóm không có board, chưa có file nạp. Công cụ Yosys chỉ đếm ước lượng số ô mạch, không có nghĩa là chip đã chạy trên FPGA.
:::

:::mcq id=KT-H-02
? Câu hỏi trung tâm của đề tài là gì?
- [x] Muốn chuẩn tới 1 ms thì phần nào phải là phần cứng?
- [ ] Bản G2 nhanh hơn bản G1 bao nhiêu lần trên cùng firmware?
- [ ] Firmware cần bao nhiêu lệnh để chạy đủ năm chế độ hiển thị?
- [ ] Bộ chia `timebase` tốn bao nhiêu ô mạch nếu đặt ở 50 MHz?
> Giải thích: G2, CPI và số ô mạch đều là phần phụ. Trục chính là so polling, ngắt, capture xem phần mềm giữ được 1 ms tới đâu.
:::

:::mcq id=KT-H-03
? Năm chế độ xem giờ, bấm giờ, hẹn giờ, báo thức, chỉnh giờ được quyết định ở đâu?
- [x] Trong firmware `fw/main.s`
- [ ] Trong mạch quét đèn `seg7_scan.v`
- [ ] Trong bộ gom ngắt `irq_ctrl.v`
- [ ] Trong khối đếm `timers.v`
> Giải thích: firmware là chương trình quyết định đang ở chế độ nào và hiện gì. `timers.v` chỉ đếm, `seg7_scan.v` chỉ bật đèn theo số đã được ghi sẵn.
:::

:::mcq id=KT-H-04
? Co-sim so chip với CPU giả ISS. Nếu ISS sai thì co-sim có chắc phát hiện được không?
- [x] Không chắc; hai bên có thể cùng sai nên cần thêm MARS
- [ ] Có; so từng lệnh thì mọi chỗ sai của ISS đều lộ ra
- [ ] Có; chip viết bằng Verilog nên không thể sai giống ISS
- [ ] Không; co-sim chỉ đếm số lệnh, không so giá trị bên trong
> Giải thích: so từng lệnh chỉ thấy chỗ hai bên khác nhau. Hai bên cùng hiểu sai một lệnh thì vẫn khớp, nên cần một nguồn độc lập là MARS.
:::

:::mcq id=KT-H-05
? `G_N = 50` trong bài thử nghĩa là gì?
- [x] Nén 1 ms còn 50 nhịp để mô phỏng nhanh, logic không đổi
- [ ] Chip chạy ở 50 MHz, đây là cách ghi tắt của tần số clock
- [ ] Chip thật mỗi mili giây có 50 nhịp nên đếm rất nhanh
- [ ] CPU được phép chạy tối đa 50 lệnh trong mỗi mili giây
> Giải thích: chip thật cần 50 000 nhịp cho 1 ms. Số 50 chỉ để bài thử chạy nhanh hơn khoảng 1000 lần, trùng với 50 MHz là tình cờ.
:::

:::mcq id=KT-H-06
? Vì sao lệnh đọc `lw` rồi dùng ngay phải đứng chờ 1 chu kỳ ở G2?
- [x] Dữ liệu tới cuối MEM mới có, không kịp về đầu EX của lệnh sau
- [ ] Lệnh `lw` luôn bị coi là lệnh nhánh nên lệnh kế tiếp bị xóa
- [ ] G2 không có đường chuyền tắt từ MEM/WB về trạm EX
- [ ] G2 có delay slot nên lệnh ngay sau `lw` luôn bị giữ lại
> Giải thích: G2 có đường chuyền tắt từ MEM/WB, nhưng phải đứng 1 chu kỳ thì dữ liệu mới tới được đó. G2 không có delay slot.
:::

:::mcq id=KT-H-07
? Lệnh rẽ nhánh ở G2 nhảy thật thì mất bao nhiêu chu kỳ, vì sao?
- [x] 2 chu kỳ; quyết định ở EX, đã lỡ lấy hai lệnh
- [ ] 1 chu kỳ; quyết định ở ID, đã lỡ lấy một lệnh
- [ ] 0 chu kỳ; lệnh sau nhánh nằm trong delay slot
- [ ] 3 chu kỳ; quyết định ở MEM, đã lỡ lấy ba lệnh
> Giải thích: một số CPU quyết định ở trạm ID nên chỉ mất 1, nhưng G2 quyết định ở EX. Lúc đó hai trạm IF và ID đang giữ hai lệnh lấy nhầm.
:::

:::mcq id=KT-H-08
? Các trường hợp xung đột trùng nhau thì ưu tiên theo thứ tự nào? (flush là xóa lệnh sai)
- [x] `busy` > flush > load-use
- [ ] load-use > flush > `busy`
- [ ] flush > load-use > `busy`
- [ ] flush > `busy` > load-use
> Giải thích: khi `div` còn chạy, lệnh ở trạm EX chưa xong nên chưa được phép quyết định nhảy. Vì vậy `busy` đứng trước flush.
:::

:::mcq id=KT-H-09
? Ngắt đến khi phép chia `div` đang chạy thì CPU làm gì?
- [x] Chờ `div` tính xong rồi mới nhận
- [ ] Hủy `div`, nhận ngắt, rồi chia lại từ đầu
- [ ] Nhận ngắt ngay, `div` chạy tiếp ở nền
- [ ] Bỏ qua ngắt đó vì CPU đang bận
> Giải thích: ngắt không bị mất mà chờ tới khi hết `busy`. Đây là lý do ngắt trong thí nghiệm E3 có lúc trễ tới 34 lệnh.
:::

:::mcq id=KT-H-10
? Khi G2 nhận ngắt, nhóm lệnh nào được làm nốt?
- [x] EX/MEM và MEM/WB làm nốt; ID và ID/EX bị hủy, chạy lại sau `eret`
- [ ] ID và ID/EX làm nốt; EX/MEM và MEM/WB bị hủy, chạy lại sau `eret`
- [ ] Tất cả lệnh làm nốt rồi mới nhảy tới handler, không hủy lệnh nào
- [ ] Tất cả lệnh bị hủy rồi chạy lại từ lệnh cũ nhất sau khi `eret` về
> Giải thích: lệnh đã đi qua EX có thể đã làm thay đổi dữ liệu nên phải làm nốt. Lệnh mới vào chưa đổi gì nên hủy được, và `EPC` nhớ lệnh cũ nhất chưa xong.
:::

:::mcq id=KT-H-11
? `slt` so a = −2³¹ (số âm nhỏ nhất) với b = 1. Kết quả nào đúng? (1 nghĩa là a nhỏ hơn b)
- [x] 1; khác dấu nên số âm nhỏ hơn
- [ ] 0; phép trừ tràn nên hiệu ra dương
- [ ] 1; luôn lấy bit dấu của hiệu
- [ ] 0; −2³¹ không có số đối nên báo lỗi
> Giải thích: a − b bị tràn nên dấu của hiệu là dương, tin vào đó sẽ ra sai. Mạch so dấu trước: khác dấu thì số âm là số nhỏ hơn.
:::

:::mcq id=KT-H-12
? Cùng 1 000 lệnh, G1 có CPI 1,428 ở 25 MHz, G2 có CPI 2,027 ở 50 MHz. Bản nào nhanh hơn?
- [x] G2: khoảng 40,54 µs so với G1 57,12 µs
- [ ] G1: khoảng 28,56 µs so với G2 40,54 µs
- [ ] G1: CPI thấp hơn nên luôn nhanh hơn G2
- [ ] Bằng nhau vì cùng chạy đúng 1 000 lệnh
> Giải thích: thời gian = số lệnh × CPI / tần số. Số 28,56 µs là tính nhầm G1 ở 50 MHz; G1 chỉ chạy 25 MHz vì có 2 pha.
:::

:::mcq id=KT-H-13
? Thạch anh lệch +10 ppm thì giá trị `CAL` lý tưởng là bao nhiêu?
- [x] 32 768
- [ ] 3 276,8
- [ ] 65 536
- [ ] 16 384
> Giải thích: 1 ppm ứng với 3 276,8 đơn vị, nhân 10 được 32 768. Số 3 276,8 chỉ là của 1 ppm, còn 65 536 là của 20 ppm.
:::

:::mcq id=KT-H-14
? Bảng thí nghiệm E3 cho phép kết luận điều gì?
- [x] Khi CPU chậm, phần mềm không giữ nổi 1 ms; capture luôn đúng
- [ ] Polling luôn sai 0,74 ms ở mọi tốc độ CPU; capture luôn đúng
- [ ] Firmware `main.s` đo được các số này; ngắt tốt hơn capture
- [ ] Ở mọi D, ngắt đều trễ dưới 1 ms nên không cần capture nữa
> Giải thích: 0,74 ms chỉ đúng ở D = 1526; ở D = 2 polling chỉ trễ khoảng 1 µs. Ở D = 1526 ngắt có lúc trễ 1,037 ms, và đây là thí nghiệm riêng, không phải `main.s`.
:::

:::mcq id=KT-H-15
? Đèn LED quét 125 lần mỗi giây. Số 125 đến từ đâu?
- [x] 8 chữ số, mỗi chữ số 1 ms: 1000 / 8
- [ ] Clock 50 MHz chia thẳng cho 125
- [ ] 125 lần là ngưỡng mắt người cần
- [ ] Mỗi chữ số bật 125 lần mỗi ms
> Giải thích: quét hết 8 chữ số mất 8 ms, nên mỗi giây có 125 vòng. Con số này đến từ độ dài mỗi lượt bật, không phải từ một ngưỡng của mắt.
:::
