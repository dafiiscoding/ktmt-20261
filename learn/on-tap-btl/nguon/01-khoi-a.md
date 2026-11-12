# Khối A · Kiến trúc lõi và ngoại vi cơ bản

Khối A trang bị kiến thức nền tảng về phần cứng của WatchChip: cách các phép tính số học được hiện thực trong ALU, cách CPU đơn chu kỳ G1 phối hợp với bộ nhớ BRAM qua cơ chế 2 pha, hệ thống công cụ kiểm thử tự động, và các khối ngoại vi đếm thời gian, hiển thị LED 7 đoạn, màn hình VGA cùng giao tiếp UART.

Năm bài học trong Khối A gồm:
- {{bai:A1}}: Khối số học ALU, bộ nhân chia `muldiv` và bộ chuyển đổi số thập phân `bcd`.
- {{bai:A2}}: Bộ não đơn chu kỳ G1 và đường đi của lệnh đọc bộ nhớ `lw`.
- {{bai:A3}}: Bộ công cụ kiểm thử: trình biên dịch `asm.py`, bộ mô phỏng ISS, đồng mô phỏng co-sim và kỹ thuật kiểm thử đột biến.
- {{bai:A4}}: Bộ đếm thời gian gốc `timebase`, cơ chế hiệu chỉnh xung nhịp `CAL` và đồng hồ thời gian thực RTC.
- {{bai:A5}}: Mạch quét đèn LED 7 đoạn, mạch xuất hình VGA, còi báo và giao tiếp nối tiếp UART.

### Hỏi lại bức tranh

:::nhac ids=KT-H-01,KT-H-02,KT-H-05
:::

## A2 · G1 và đường đi lw

### Bản đồ

:::ban-do
Trong toàn bộ cấu trúc của con chip WatchChip, CPU G1 đóng vai trò là phiên bản bộ vi xử lý đơn chu kỳ (single-cycle). Khác với bản pipeline G2 gồm 5 tầng chạy song song, G1 hoàn thành trọn vẹn từng lệnh một trước khi bước sang lệnh tiếp theo.

Vị trí của bài học này trên sơ đồ kết nối phần cứng:
- **Lõi CPU G1:** chip chỉ có một đồng hồ 50 MHz. CPU không có đồng hồ riêng, nó chỉ bước khi nhận tín hiệu cho phép `cpu_ce` (sinh từ bộ chia `CPU_CLK_DIV`, gọi tắt là D). Một chu kỳ CPU của G1 cần hai lần `cpu_ce`: một lần cho pha A, một lần cho pha B, luân phiên nhau. Ở cấu hình mặc định D = 2, `cpu_ce` bật ở mọi nhịp của đồng hồ 50 MHz, nên một chu kỳ CPU dài 2 nhịp hệ thống, tức 40 ns, hiệu dụng 25 MHz. Đặt D lớn hơn thì `cpu_ce` thưa ra (cách nhau D/2 nhịp) và CPU chạy chậm lại.
- **Bộ nhớ chương trình (IMEM, instruction memory):** nơi cất danh sách lệnh của firmware, mỗi lệnh là một số nhị phân 32 bit. Nó được xây bằng BRAM, khối nhớ có sẵn trong chip FPGA. IMEM chốt địa chỉ lệnh ở pha A.
- **Tập thanh ghi (regfile):** 32 ô nhớ nhỏ tên `$0` đến `$31`, CPU dùng như giấy nháp. Đọc ra ngay (không chờ nhịp), ghi vào ở pha A.
- **Khối điều khiển (control):** đọc mã lệnh rồi bật tắt 16 công tắc (tín hiệu điều khiển) cho các khối khác, theo bảng chân lý của từng lệnh.
- **Khối tính toán (ALU, arithmetic logic unit):** khối làm toán cộng, trừ, so sánh. Ở lệnh này nó tính địa chỉ bộ nhớ bằng cách lấy giá trị thanh ghi gốc cộng với số tức thời (số viết ngay trong lệnh) đã mở rộng dấu.
- **Bus ngoại vi MMIO (Memory-Mapped I/O):** các ngoại vi như đồng hồ, màn hình được gắn vào những địa chỉ đặc biệt, nên CPU đọc ghi chúng bằng chính lệnh `lw`, `sw` như đọc ghi bộ nhớ. Bus gồm các dây `bus_addr`, `bus_wdata`, `bus_we`, `bus_re`, `bus_rdata`.
- **Ngoại vi RTC (real-time clock, đồng hồ thời gian thực):** nơi cất thanh ghi `MS_OF_DAY` ở địa chỉ ngoại vi `0xFFFFFF04`.
:::

### Câu hỏi mở bài

Làm thế nào một bộ xử lý đơn chu kỳ có thể vừa đọc mã lệnh từ bộ nhớ chương trình, vừa đọc dữ liệu từ bộ nhớ dữ liệu hoặc ngoại vi trong cùng một lệnh, khi mà bộ nhớ trong chip FPGA (BRAM, khối nhớ có sẵn trong chip) luôn bắt buộc phải chờ một cạnh xung nhịp (khoảnh khắc đồng hồ của chip nhích một nhịp) mới xuất được dữ liệu ra ngoài?

Đây là bài toán hóc búa nhất của kiến trúc đơn chu kỳ trên FPGA:
- Trong lý thuyết sách giáo khoa cổ điển, bộ nhớ thường được giả định là lý tưởng: đưa địa chỉ vào là dữ liệu xuất hiện ngay lập tức (gọi là đọc bất đồng bộ: giống tra bảng, không phải chờ nhịp đồng hồ).
- Nhưng trên FPGA hiện đại, các khối bộ nhớ phần cứng BRAM (Block RAM) bắt buộc phải đọc đồng bộ: địa chỉ đưa vào ở cạnh lên này thì dữ liệu chỉ có thể sẵn sàng ở cạnh lên tiếp theo.
- Lệnh `lw` (load word - nạp một từ 32 bit từ bộ nhớ vào thanh ghi) đòi hỏi tới hai lần truy cập bộ nhớ: lần một để đọc mã lệnh từ IMEM, lần hai để đọc dữ liệu từ DMEM hoặc ngoại vi.
- Nếu đợi hai cạnh xung nhịp liên tiếp của cùng một clock để đọc hai bộ nhớ, CPU không thể hoàn tất lệnh trong một nhịp đơn lẻ theo cách hiểu thông thường.

Để giải quyết mâu thuẫn này mà không tạo thêm miền clock phức tạp, WatchChip chia mỗi chu kỳ CPU thành hai pha rõ rệt: pha A và pha B.

### Trực giác

Hãy hình dung một văn phòng có hai tủ hồ sơ: Tủ Lệnh (các tờ lệnh việc cần làm) và Tủ Dữ Liệu (hồ sơ cần tra). Mỗi tủ chạy bằng chuông: lúc chuông reo, nhân viên đưa vào tủ một tờ ghi số hồ sơ cần lấy; ngay sau tiếng chuông đó, hồ sơ nằm sẵn ở cửa tủ. Tủ không thể trả hồ sơ nếu chưa nghe chuông để nhận số. Mỗi ngày làm việc (một chu kỳ CPU) có đúng hai tiếng chuông: chuông A đầu ngày và chuông B giữa ngày.

Cách làm chậm: sáng nay mới biết hôm nay làm lệnh số mấy, rồi mới đưa số cho Tủ Lệnh.
- Đến chuông B (giữa ngày) tờ lệnh mới ra cửa tủ.
- Đọc lệnh "lấy hồ sơ số 5" xong, nhân viên chỉ kịp đưa số cho Tủ Dữ Liệu ở chuông A hôm sau. Một việc kéo dài sang hai ngày.

Cách của WatchChip:
- **Chuông A (đầu ngày):** số của tờ lệnh hôm nay đã được tính xong từ hôm trước (`next_pc`) và đưa vào Tủ Lệnh đúng chuông này. Ngay sau chuông, tờ lệnh nằm sẵn trên bàn.
- **Buổi sáng:** đọc lệnh, tính xem hồ sơ nằm ở số mấy (ALU).
- **Chuông B (giữa ngày):** đưa số hồ sơ cho Tủ Dữ Liệu (hoặc gọi bộ phận ngoại vi). Ngay sau chuông, hồ sơ ra cửa tủ.
- **Buổi chiều:** mang hồ sơ về bàn.
- **Chuông A của ngày hôm sau:** cất hồ sơ vào ngăn kéo cá nhân (thanh ghi `$t0`), đồng thời đưa số tờ lệnh của ngày kế tiếp cho Tủ Lệnh. Lệnh `lw` xong trọn trong một ngày, ngày sau lại bắt đầu với tờ lệnh nằm sẵn.

### Cơ chế theo đường tín hiệu

Xét trường hợp cụ thể khi CPU chạy lệnh:
```mips
lw $t0, -252($zero)
```

Lệnh này có ý nghĩa: đọc một từ dữ liệu 32 bit từ địa chỉ được tạo bởi giá trị thanh ghi `$zero` cộng với hằng số `-252`, sau đó ghi giá trị đọc được vào thanh ghi `$t0`.

Hằng số `-252` biểu diễn dạng thập lục phân 16 bit bù hai là `0xFF04`.
Khi đi qua bộ giải mã và bộ mở rộng dấu (sign extension), hằng số này biến thành số 32 bit: `0xFFFFFF04`.
Thanh ghi `$zero` luôn bằng 0. Do đó địa chỉ bộ nhớ được tính là:
`0 + 0xFFFFFF04 = 0xFFFFFF04`.

Vì 24 bit cao của địa chỉ toàn là số 1 (`0xFFFFFF`), CPU nhận diện đây không phải là bộ nhớ RAM thông thường (DMEM), mà là địa chỉ thuộc không gian ngoại vi MMIO (Memory-Mapped I/O). Cụ thể, offset `0x04` tương ứng với thanh ghi `MS_OF_DAY` (số mili giây đã trôi qua trong ngày) của khối đồng hồ thời gian thực RTC.

Đường đi của tín hiệu qua con chip diễn ra theo đúng 5 bước:

1. **Pha A (cạnh đầu chu kỳ):**
   - `pc` nhận địa chỉ của lệnh này.
   - Cũng ở chính cạnh này, IMEM chốt `next_pc` (địa chỉ đã được tính xong ở chu kỳ trước), nên ngay sau cạnh, đầu ra `instr` đã là mã nhị phân của lệnh `lw $t0, -252($zero)`.
   - Chu kỳ CPU bắt đầu với mã lệnh hoàn chỉnh mà không cần chờ thêm.

2. **Giữa pha A và pha B (lan truyền tổ hợp):**
   - Mã lệnh từ IMEM đi vào khối giải mã `control.v`.
   - Khối `control.v` tra bảng chân lý và bật các tín hiệu điều khiển: cờ cho phép ghi thanh ghi `reg_write = 1`, đích ghi là thanh ghi `rt` (`dst = 2'b10`, tức `$t0`), nguồn toán hạng B của ALU là tức thời `alu_src = 1`, cờ đọc bộ nhớ `mem_read = 1`, cờ chọn dữ liệu ghi ngược từ bộ nhớ `mem_to_reg = 1`.
   - Tập thanh ghi `regfile.v` đọc giá trị từ cổng thanh ghi số 0 (`$zero`), trả về giá trị 0.
   - Bộ mở rộng dấu kéo dài `0xFF04` thành `0xFFFFFF04`.
   - Khối `alu.v` thực hiện phép cộng `0 + 0xFFFFFF04 = 0xFFFFFF04`. Kết quả này đưa thẳng tới đầu vào địa chỉ bộ nhớ `maddr`.

3. **Pha B (cạnh xung nhịp giữa chu kỳ):**
   - Mạch nhận diện địa chỉ thấy `maddr[31:8] == 24'hFFFFFF` nên bật cờ `in_mmio = 1`.
   - Đúng tại cạnh pha B, tín hiệu đọc bus ngoại vi `bus_re` được bật lên:
     `assign bus_re = ph_b && mem_read && in_mmio;`
   - Ngoại vi RTC nhận địa chỉ `bus_addr = 0x04`, đọc giá trị mili giây hiện tại từ thanh ghi `MS_OF_DAY` và đưa lên đường dây `bus_rdata`.
   - Đồng thời, ngoại vi RTC kích hoạt cơ chế chụp ngày: giá trị số ngày hiện tại được đóng băng ngay lập tức vào thanh ghi bóng `DAY_SHADOW`. Điều này đảm bảo nếu phần mềm đọc giờ lúc 23:59:59.999 rồi mới đọc ngày, ngày không bao giờ bị nhảy lệch sang hôm sau giữa hai lần đọc.

4. **Giữa pha B và pha A kế tiếp (lan truyền dữ liệu đọc về):**
   - Dữ liệu `bus_rdata` từ ngoại vi chạy qua bộ dồn kênh MUX về cổng dữ liệu ghi của tập thanh ghi `regfile`.
   - Bộ MUX chọn nguồn dữ liệu từ bus (`lsel == 2'b10`) đưa vào đường truyền `load_v`, rồi qua MUX chính gán vào đường dây `wb` (write-back).
   - Bộ cộng PC tính toán địa chỉ lệnh tiếp theo: `next_pc = pc + 4`.

5. **Pha A của chu kỳ kế tiếp (chốt kết quả hoàn tất lệnh):**
   - Tín hiệu cho phép ghi thanh ghi `rf_we` kích hoạt ở pha A (`rf_we = ph_a && reg_write && !stall`).
   - Giá trị thời gian đọc được từ `MS_OF_DAY` được ghi chính thức vào thanh ghi đích `$t0`.
   - Đồng thời, IMEM chốt địa chỉ `next_pc` để sẵn sàng đưa lệnh tiếp theo ra cổng dữ liệu. Lệnh `lw` hoàn tất trọn vẹn 1 chu kỳ CPU.

**So sánh trường hợp đọc từ RAM dữ liệu (DMEM):**
Nếu lệnh là đọc một biến từ ngăn xếp trong bộ nhớ nội bộ, ví dụ `lw $t0, 4($sp)` với địa chỉ nằm trong vùng `0x00000xxx`:
- Mạch giải mã địa chỉ nhận diện 20 bit cao bằng 0 nên bật `in_dmem = 1` và tắt `in_mmio = 0`.
- Tín hiệu `bus_re` không bật vì lệnh không giao tiếp với ngoại vi.
- Tại pha B, khối BRAM của `dmem` chốt địa chỉ và đưa dữ liệu ra cổng `dmem_q`.
- Bộ chọn `lsel` chốt giá trị `2'b01`. Dữ liệu nạp `load_v` sẽ lấy từ `dmem_q` thay vì `bus_rdata`. Cơ chế 2 pha vẫn giữ nguyên trọn vẹn.

### Bảng chu kỳ hoặc tính tay

Bảng chu kỳ phân tích diễn biến tín hiệu trong một chu kỳ CPU của kiến trúc G1:

| Thời điểm | Trạng thái clock | Công việc của CPU G1 | Trạng thái tín hiệu |
|---|---|---|---|
| Cạnh pha A | Cạnh lên clock hệ thống (chẵn) | Cập nhật `pc`, nạp trước mã lệnh từ IMEM theo `next_pc`, ghi kết quả lệnh trước | `ph_a = 1`, `ph_b = 0`, `instr` sẵn sàng |
| Giữa A → B | Mức logic ổn định (20 ns đầu) | Giải mã lệnh `control`, đọc thanh ghi `$zero`, ALU tính địa chỉ `0xFFFFFF04` | `reg_write = 1`, `alu_src = 1`, `alu_y = 0xFFFFFF04` |
| Cạnh pha B | Cạnh lên clock hệ thống (lẻ) | DMEM/MMIO chốt địa chỉ, RTC đọc `MS_OF_DAY`, kích hoạt chụp ngày vào `DAY_SHADOW` | `ph_a = 0`, `ph_b = 1`, `bus_re = 1`, `bus_addr = 0x04` |
| Giữa B → A | Mức logic ổn định (20 ns sau) | Dữ liệu `bus_rdata` truyền qua MUX về đầu vào `wd` của regfile, tính `next_pc = pc + 4` | `load_v = bus_rdata`, `wb = load_v`, `next_pc = pc + 4` |
| Cạnh pha A sau | Cạnh lên clock hệ thống kế tiếp | Ghi giá trị vào `$t0`, chuyển sang lệnh kế tiếp | `rf_we = 1`, `r[wa] <= wd`, `pc <= next_pc` |

Tính toán thời gian và tần số làm việc:
- Clock hệ thống: `clk = 50 MHz` (chu kỳ clock hệ thống là 20 ns).
- Tham số chia xung CPU: `D = 2`.
- Tần số CPU G1: `50 MHz / 2 = 25 MHz`.
- Chu kỳ CPU G1: `40 ns`. Trong đó:
  - Thời gian pha A (nửa đầu chu kỳ): trọn vẹn 20 ns cho giải mã và tính toán ALU.
  - Thời gian pha B (nửa sau chu kỳ): trọn vẹn 20 ns cho truy xuất bus ngoại vi và dồn kênh dữ liệu.

Cách đọc bảng chân lý điều khiển (`docs/control-table.md`):
Bảng chân lý của CPU gồm 28 dòng tương ứng với 28 lệnh MIPS mà chip hỗ trợ. Mỗi dòng quy định trạng thái của 16 tín hiệu điều khiển nhị phân.
Để tra cứu một lệnh, ta thực hiện:
- Nhìn vào cột `op` (opcode) và `funct`: với `lw`, mã opcode là `0x23` (nhị phân `100011`).
- Cột `reg_write = 1`: cho biết lệnh này có ghi kết quả vào tập thanh ghi.
- Cột `dst = rt`: đích ghi là trường `rt` (bit 20:16), tức `$t0`.
- Cột `alu_src = 1`: toán hạng thứ hai của ALU lấy từ hằng số mở rộng dấu tức thời, không lấy từ thanh ghi `rt`.
- Cột `ext = SE`: hằng số 16 bit được mở rộng có dấu (sign extension).
- Cột `alu_ctl = ADD`: ALU thực hiện phép cộng giữa thanh ghi gốc `rs` và số tức thời.
- Cột `mem_read = 1`: kích hoạt đọc bộ nhớ dữ liệu hoặc ngoại vi.
- Cột `mem_to_reg = 1`: dữ liệu ghi vào thanh ghi lấy từ đường truyền bộ nhớ chứ không lấy từ đầu ra ALU.
- Các cột `branch`, `jump`, `multi`, `cp0_op` đều bằng 0 vì đây không phải lệnh nhảy hay lệnh ngắt.

:::suy-dan
Đề bài: Cho lệnh `lw $s1, -248($zero)`. Hãy tính toán địa chỉ 32 bit mà CPU truy xuất, xác định tên thanh ghi ngoại vi tương ứng và giải thích ý nghĩa của việc đọc thanh ghi này ngay sau khi đọc `MS_OF_DAY`.
---
**Lời giải từng bước:**
1. Hằng số tức thời là `-248`. Đổi sang số bù hai 16 bit:
   `65536 - 248 = 65288 = 0xFF08`.
2. Mở rộng dấu lên 32 bit: bit cao nhất là 1, do đó 16 bit cao được điền toàn số 1:
   `imm_x = 0xFFFFFF08`.
3. ALU tính địa chỉ: `$zero + 0xFFFFFF08 = 0xFFFFFF08`.
4. Tra cứu bản đồ địa chỉ MMIO trong tài liệu `docs/mmio-map.md`:
   - Địa chỉ `0xFFFFFF08` (offset `-248`) chính là thanh ghi `DAY_SHADOW`.
5. Ý nghĩa kết hợp: Khi lệnh trước đó đọc `MS_OF_DAY` (`0xFFFFFF04`), phần cứng RTC đã chụp ngày hiện tại vào `DAY_SHADOW`. Lệnh kế tiếp đọc `DAY_SHADOW` sẽ nhận được chính xác số ngày gắn liền với mốc mili giây vừa đọc, ngăn chặn hoàn toàn lỗi lệch ngày khi đồng hồ chuyển giao giữa ngày cũ và ngày mới lúc nửa đêm.
:::

### Trong chip

:::trong-chip
Đoạn mã Verilog trong tệp `src/cpu_g1.v` thể hiện chính xác cơ chế giải mã địa chỉ MMIO và điều khiển đọc bus ngoại vi tại pha B:

{{trich:src/cpu_g1.v:122-130@wire [31:0] maddr}}

Giải thích chi tiết từng dòng mã nguồn:
- **Dòng 122 (`wire [31:0] maddr = alu_y;`):** Địa chỉ truy cập bộ nhớ `maddr` được nối trực tiếp từ đầu ra tính toán của bộ làm toán ALU.
- **Dòng 123 (`wire in_dmem = (maddr[31:12] == 20'd0);`):** Nếu 20 bit cao của địa chỉ bằng 0, vùng nhớ thuộc phạm vi RAM dữ liệu nội bộ 4 KB (từ `0x00000000` đến `0x00000FFF`).
- **Dòng 124 (`wire in_mmio = (maddr[31:8] == 24'hFFFFFF);`):** Nếu 24 bit cao toàn là số 1 (tức `0xFFFFFFxx`), địa chỉ thuộc không gian ngoại vi MMIO.
- **Dòng 125 (`assign bus_addr = {maddr[7:2], 2'b00};`):** Trích xuất 6 bit địa chỉ từ bit 7 đến bit 2 (luôn căn lề 4 byte) để gửi tới các khối ngoại vi trên bus.
- **Dòng 126 (`assign bus_wdata = rt_v;`):** Dữ liệu cần ghi ra ngoại vi (nếu là lệnh `sw`) lấy từ giá trị thanh ghi `rt`.
- **Dòng 127 (`assign bus_we = ph_b && mem_write && in_mmio;`):** Tín hiệu ghi bus ngoại vi chỉ bật khi đang ở pha B, lệnh yêu cầu ghi bộ nhớ và địa chỉ thuộc vùng MMIO.
- **Dòng 128 (`assign bus_re = ph_b && mem_read && in_mmio;`):** Tín hiệu đọc bus ngoại vi chỉ kích hoạt ở pha B, lệnh yêu cầu đọc bộ nhớ (`mem_read`) và địa chỉ thuộc vùng MMIO.
- **Dòng 130 (`wire [31:0] load_v = ...`):** Dữ liệu nạp về `load_v` được chọn thông qua cờ `lsel`: nếu đọc từ DMEM thì lấy `dmem_q`, nếu đọc từ ngoại vi MMIO thì lấy `bus_rdata`.

Cùng lúc đó, trong tệp `src/control.v`, dòng 87 định nghĩa tín hiệu điều khiển cho mã opcode `0x23` của lệnh `lw`:
{{doc:src/control.v:87}}
Lệnh gọi hàm `i_alu(A_ADD, E_SE, 1)` để cấu hình ALU làm phép cộng với số mở rộng dấu tức thời, đồng thời bật cờ `mem_read = 1` và `mem_to_reg = 1`.

Trong tệp `src/regfile.v`, cổng đọc và ghi thanh ghi được tổ chức độc lập:
{{trich:src/regfile.v:41-46@wire byp1}}
Đối với CPU G1, tham số `G_BYPASS` bắt buộc phải đặt bằng 0. Bởi vì trong CPU đơn chu kỳ, việc ghi thanh ghi chỉ diễn ra ở pha A cuối lệnh, nếu bật bypass sẽ vô tình tạo ra vòng lặp tổ hợp nguy hiểm từ đầu ra ALU quay ngược lại đầu vào của chính lệnh đó.
:::

### Bẫy và thầy hay hỏi

:::bay
**Bẫy 1: Ngộ nhận bộ nhớ BRAM trên FPGA có thể đọc dữ liệu bất đồng bộ như mạch tổ hợp thông thường.**
Trong nhiều tài liệu lý thuyết nhập môn kiến trúc máy tính, sinh viên thường quen với mô hình RAM lý tưởng: đặt địa chỉ vào là vài nano giây sau dữ liệu xuất hiện ngay ở đầu ra mà không cần xung nhịp. Tuy nhiên, trên FPGA thật, Block RAM luôn là phần cứng chuyên dụng đọc đồng bộ. Dữ liệu chỉ xuất hiện sau một cạnh tích cực của clock. Nếu thiết kế cần RAM đọc ngay không chờ nhịp, công cụ tổng hợp không dùng được BRAM mà phải dựng RAM từ các ô logic nhỏ lẻ (LUT), tốn diện tích hơn. Chính `src/cpu_g1.v` ghi chú điều này ở chỗ đọc IMEM: chỉ dùng một cổng đọc để công cụ suy ra được BRAM, hai cổng thì bị dựng bằng LUT.
:::

:::bay
**Bẫy 2: Ngộ nhận chốt địa chỉ IMEM bằng `pc` (địa chỉ lệnh vừa xong) thay vì `next_pc` (địa chỉ lệnh sắp chạy).**
Nhiều bạn nghĩ cứ lấy `pc` hiện tại nạp vào IMEM là xong. Nhưng BRAM chỉ nhìn địa chỉ có sẵn TRƯỚC cạnh nhịp, và dữ liệu ra ngay sau cạnh đó. Tại cạnh pha A, thanh ghi `pc` vẫn còn giữ địa chỉ của lệnh VỪA chạy xong, còn lệnh sắp chạy mới nằm ở `next_pc` (đã tính xong trong chu kỳ trước). Chốt bằng `pc` thì IMEM đưa ra lại lệnh cũ: mỗi lệnh chạy trễ một nhịp so với `pc`, nhánh nhảy sai đích. Còn nếu chờ `pc` cập nhật xong rồi mới chốt thì lệnh chỉ ra ở giữa chu kỳ, không còn thời gian để đọc bộ nhớ dữ liệu. Vì vậy G1 chốt bằng `next_pc` (trong mã là `pc_new`, bằng `next_pc` trừ lúc có ngắt) ngay tại cạnh pha A.
:::

:::bay
**Bẫy 3: Ngộ nhận số âm `-252` trong câu lệnh assembly là lỗi truy cập bộ nhớ hoặc tràn số.**
Khi nhìn thấy `-252($zero)`, người chưa có kiến thức nền dễ nghĩ rằng bộ nhớ làm sao có địa chỉ âm, hoặc chương trình đang bị lỗi chỉ số mảng. Thực tế, trong kiến trúc máy tính 32 bit, các số âm biểu diễn dạng bù hai được ánh xạ tự nhiên lên nửa trên của không gian địa chỉ. Hằng số `-252` tương đương với `0xFFFFFF04`. Nhóm thiết kế đã tận dụng đặc điểm này để đặt toàn bộ thanh ghi điều khiển ngoại vi MMIO ở vùng địa chỉ cao nhất (`0xFFFFFF00` trở lên), giúp phần mềm truy cập nhanh chóng bằng cách dùng thanh ghi `$zero` làm mốc.
:::

:::bay
**Bẫy 4: Thầy hỏi: Nếu đọc `DAY_SHADOW` trước rồi mới đọc `MS_OF_DAY` thì có được không?**
Câu trả lời dứt khoát là **KHÔNG**. Cơ chế phần cứng trong khối RTC quy định rằng chỉ khi có tín hiệu đọc thanh ghi `MS_OF_DAY` (`bus_re` với địa chỉ `0x04`), mạch chốt mới kích hoạt sao chép giá trị ngày hiện tại vào `DAY_SHADOW`. Nếu phần mềm đọc `DAY_SHADOW` trước, giá trị nhận được sẽ là ngày cũ của lần đọc trước đó, hoàn toàn mất tác dụng chống trượt ngày khi qua nửa đêm. Quy trình bắt buộc luôn là: đọc `MS_OF_DAY` trước để chụp ngày, sau đó đọc `DAY_SHADOW`.
:::

:::bay
**Bẫy 5: Thầy hỏi: Nếu lệnh kế tiếp dùng ngay thanh ghi `$t0` thì CPU G1 có bị dừng (stall) như kiến trúc pipeline không?**
Câu trả lời là **KHÔNG**. Trong CPU G1 đơn chu kỳ, việc ghi vào `$t0` hoàn tất ngay tại cạnh pha A kết thúc lệnh `lw`. Lệnh kế tiếp bắt đầu từ pha A đó, khi đọc cổng `ra1` hay `ra2` của tập thanh ghi `regfile` thì đã nhìn thấy ngay giá trị mới vừa được ghi. Vì thế G1 hoàn toàn không gặp xung đột dữ liệu load-use và `lw` không bao giờ làm G1 phải dừng chờ (G1 chỉ dừng khi chạy lệnh nhiều chu kỳ như `div`, `bcd`). Đây là điểm khác biệt cốt lõi với kiến trúc G2 pipeline 5 tầng, nơi lệnh `lw` tới tầng MEM mới có dữ liệu nhưng lệnh sau ở tầng EX đã cần dùng, buộc phần cứng hazard phải dừng CPU 1 chu kỳ.
:::

### Sửa tại chỗ và ứng dụng

:::sua-tai-cho
**Tình huống cài lỗi kiểm tra độ hiểu sâu của sinh viên:**
Giả sử trong tệp `src/cpu_g1.v`, tại dòng 192, ta cố tình sửa mã nguồn để IMEM chốt địa chỉ bằng `pc` thay vì `next_pc`:
- Mã gốc (viết gọn): `if (rst || ph_a) instr <= imem[rst ? 10'd0 : pc_new[11:2]];`
- Mã sửa lỗi: `if (rst || ph_a) instr <= imem[rst ? 10'd0 : pc[11:2]];`

**Test nào sẽ bắt được lỗi này?**
Hai testbench `regfile_tb` và `control_tb` KHÔNG bắt được lỗi này: chúng chỉ thử tập thanh ghi và bảng điều khiển, không có CPU nên vẫn báo PASS (đã chạy thật với lỗi cài sẵn). Lỗi chỉ lộ ra ở các test chạy cả CPU:
```bash
bash tools/run_unit.sh system
python tools/cosim_iss.py
```
Với lỗi này, `system_tb` báo FAIL, còn `cosim_iss` (so từng lệnh của chip với bộ mô phỏng chuẩn ISS) báo sai ở mọi chương trình thử. Lý do: CPU chạy lệch một lệnh so với `pc`, nên kết quả tính toán không còn khớp mô hình tham chiếu.
:::

:::dung-o-dau
**Kiến thức này dùng ở đâu ngoài đồ án môn học?**
Kỹ thuật chia mỗi chu kỳ thành hai pha trên cùng một clock, kèm tín hiệu cho phép (clock enable), thường gặp khi thiết kế trên FPGA:
- **Tránh nhiều đồng hồ khác nhau:** chip chỉ có một clock, các khối chạy chậm hơn nhờ tín hiệu cho phép. Nhờ vậy không phải truyền tín hiệu giữa hai đồng hồ khác nhau (gọi là chuyển miền xung nhịp, vốn dễ gây lỗi khó tìm).
- **Mọi bộ nhớ có thanh ghi đầu ra:** bất kỳ thiết kế nào dùng bộ nhớ đồng bộ (như BRAM) đều gặp đúng bài toán này: địa chỉ phải sẵn sàng trước cạnh nhịp thì dữ liệu mới ra kịp.
:::

### Tự kiểm và quay lại bức tranh

:::tu-luan
Vẽ đường đi của tín hiệu (datapath) trong CPU G1 khi thực thi lệnh `lw $t0, -252($zero)` và chỉ rõ vai trò của từng khối phần cứng.
---
**Đáp án hoàn chỉnh:**
1. **Khối IMEM:** Chốt sẵn mã lệnh `lw $t0, -252($zero)` từ pha A trước đó và phát mã lệnh ra đầu dây `instr`.
2. **Khối control:** Tách các trường bit, tra cứu bảng chân lý và kích hoạt các tín hiệu: `reg_write = 1`, `dst = rt` (`$t0`), `alu_src = 1` (chọn số tức thời), `mem_read = 1`, `mem_to_reg = 1`.
3. **Khối regfile:** Đọc giá trị cổng 1 với số thanh ghi là 0 (`$zero`), trả về giá trị `0x00000000`.
4. **Khối mở rộng dấu:** Nhận hằng số 16 bit `0xFF04` (-252), mở rộng thành `0xFFFFFF04`.
5. **Khối ALU:** Thực hiện phép cộng `0x00000000 + 0xFFFFFF04 = 0xFFFFFF04` và đưa ra đầu ra `alu_y`.
6. **Mạch giải mã bus MMIO:** Nhận diện 24 bit cao là `0xFFFFFF`, kích hoạt `in_mmio = 1`. Tại pha B, cờ `bus_re` bật lên đưa địa chỉ `0x04` tới ngoại vi RTC.
7. **Ngoại vi RTC:** Trả dữ liệu `MS_OF_DAY` lên `bus_rdata` và tự động chụp ngày vào `DAY_SHADOW`.
8. **Khối dồn kênh MUX:** Chuyển dữ liệu `bus_rdata` vào đường dây `wb`.
9. **Ghi thanh ghi (tại pha A kế tiếp):** Giá trị được chốt chính thức vào thanh ghi `$t0` trong tập thanh ghi `regfile`.
:::

:::tu-luan
Vì sao trong CPU đơn chu kỳ G1, tham số `G_BYPASS` của tập thanh ghi `regfile` bắt buộc phải đặt bằng 0, trong khi ở CPU pipeline G2 lại bắt buộc đặt bằng 1?
---
**Đáp án hoàn chỉnh:**
- **Trong CPU G1 (đơn chu kỳ):** Lệnh thực thi toàn bộ trong một chu kỳ CPU. Việc ghi vào thanh ghi diễn ra ở pha A cuối lệnh. Nếu bật tính năng bypass nội bộ (`G_BYPASS = 1`), dữ liệu ghi `wd` ở đầu ra ALU sẽ được nối tắt ngay lập tức sang đầu ra đọc `rd1`/`rd2` trong cùng một chu kỳ. Điều này vô tình tạo ra một vòng lặp kín tổ hợp (combinational loop): đầu ra ALU nuôi ngược lại đầu vào ALU, làm tín hiệu dao động mất kiểm soát và mạch không thể hoạt động ổn định. Vì vậy G1 bắt buộc phải đặt `G_BYPASS = 0`.
- **Trong CPU G2 (pipeline 5 tầng):** Lệnh trước đang ở tầng ghi ngược (WB) trong khi lệnh sau đang ở tầng giải mã (ID). Cả hai lệnh diễn ra ở cùng một nhịp clock. Nếu không có bypass, lệnh ở tầng ID sẽ đọc phải giá trị cũ trong thanh ghi thay vì giá trị mới đang được ghi ở tầng WB. Do đó G2 bắt buộc phải đặt `G_BYPASS = 1` để thực hiện kỹ thuật ghi nửa đầu chu kỳ, đọc nửa sau chu kỳ.
:::

:::tu-luan
Giải thích tại sao một chu kỳ CPU G1 tương đương với 2 chu kỳ xung nhịp hệ thống (hạ tần số từ 50 MHz xuống 25 MHz) và lợi ích của việc dùng tín hiệu clock enable thay vì tạo một xung nhịp clock mới.
---
**Đáp án hoàn chỉnh:**
- **Lý do hạ tần số:** Do cấu trúc 2 pha, một chu kỳ CPU G1 cần đúng 2 lần `cpu_ce`. Ở mặc định D = 2, `cpu_ce` bật ở mọi nhịp hệ thống, nên đó là 2 nhịp liên tiếp (nhịp này làm pha A, nhịp kế làm pha B). Với tần số hệ thống 50 MHz (chu kỳ 20 ns), tần số làm việc của CPU G1 là `50 / 2 = 25 MHz` (chu kỳ 40 ns).
- **Lợi ích của clock enable (`cpu_ce`):** Toàn bộ chip WatchChip chỉ dùng duy nhất một nguồn clock đồng bộ 50 MHz. CPU G1 hoạt động chậm hơn thông qua tín hiệu điều khiển cho phép `cpu_ce`. Nhờ đó:
  1. Loại bỏ hoàn toàn vấn đề chuyển miền xung nhịp (Clock Domain Crossing), tránh các lỗi vi sai thời gian và hiện tượng không ổn định trạng thái.
  2. Dễ dàng chỉnh tốc độ chip (ví dụ giả lập chip đồng hồ 32,768 kHz bằng `D = 1526`, tức CPU chạy chậm hơn nhiều) chỉ bằng cách thay đổi tần suất phát xung `cpu_ce` mà không cần cấu hình lại bộ tạo dao động phần cứng PLL.
:::

:::mcq id=KT-A2-01
? Vì sao trong kiến trúc G1 của WatchChip, lệnh lấy dữ liệu từ bộ nhớ `lw` cần hai pha (pha A và pha B) trên cùng một nguồn clock?
- [ ] Vì bộ nhớ BRAM của FPGA chỉ đọc được dữ liệu ở sườn xuống của xung nhịp chứ không đọc được ở sườn lên
- [x] Vì BRAM đọc đồng bộ cần một cạnh clock để trả dữ liệu, nên cần pha B cho bộ nhớ và pha A cập nhật thanh ghi
- [ ] Vì CPU cần một pha để tính giá trị địa chỉ và một pha riêng biệt để giải mã lệnh từ mã nhị phân sang công tắc
- [ ] Vì tín hiệu bus ngoại vi MMIO bắt buộc phải truyền qua hai tầng thanh ghi đồng bộ trước khi đến ngoại vi
> Giải thích: Trong FPGA, bộ nhớ BRAM hoạt động đồng bộ và cần một cạnh clock để chốt địa chỉ rồi trả dữ liệu. Bằng cách chia một chu kỳ CPU thành pha B (đọc hoặc ghi bộ nhớ) và pha A (cập nhật thanh ghi và nạp lệnh kế tiếp), G1 hoàn thành toàn bộ lệnh lw trong 1 chu kỳ mà không bị xung đột thời gian. Các ngộ nhận về sườn xuống hay tầng đệm đều không đúng với thiết kế mạch 2 pha trên cùng 1 clock.
:::

:::mcq id=KT-A2-02
? Trong lệnh `lw $t0, -252($zero)`, giá trị hằng số offset `-252` có ý nghĩa gì đối với không gian địa chỉ của WatchChip?
- [x] Khi mở rộng dấu 32 bit, giá trị trở thành `0xFFFFFF04`, trỏ thẳng vào thanh ghi ngoại vi `MS_OF_DAY`
- [ ] Số âm thể hiện CPU đang truy cập vào vùng ngăn xếp bộ nhớ dữ liệu DMEM nằm ở cuối dải nhớ 4 KB của hệ thống
- [ ] Đây là mã lỗi đặc biệt của lệnh nhằm báo cho ngoại vi biết phải kích hoạt chụp ngày tự động trên con chip
- [ ] Giá trị bù hai này cho biết CPU muốn đọc ngược lại 252 ô nhớ tính từ đỉnh của bảng chân lý điều khiển
> Giải thích: Trong MIPS, số tức thời 16 bit `-252` được mở rộng dấu (sign extension) thành `0xFFFFFF04`. Do 24 bit cao là `0xFFFFFF`, mạch giải mã nhận diện đây là vùng địa chỉ MMIO của ngoại vi, cụ thể là thanh ghi mili giây trong ngày `MS_OF_DAY`. Không có việc đọc ngược hay truy cập ngăn xếp ở đây.
:::

:::mcq id=KT-A2-03
? Tín hiệu đọc bus `bus_re` trong mạch `src/cpu_g1.v` được kích hoạt dựa trên những điều kiện nào?
- [ ] Khi CPU đang ở pha A và lệnh hiện tại là lệnh đọc bộ nhớ thông thường trong vùng DMEM
- [x] Khi đang ở pha B, lệnh có bật cờ `mem_read`, và địa chỉ truy cập nằm trong vùng MMIO
- [ ] Khi ngoại vi gửi cờ yêu cầu ngắt lên bộ điều khiển và thanh ghi Status cho phép ngắt
- [ ] Khi tín hiệu clock enable `cpu_ce` đạt mức cao đồng thời lệnh ALU tính xong kết quả cộng
> Giải thích: Theo dòng code {{doc:src/cpu_g1.v:128}}, `bus_re` được gán bằng biểu thức `ph_b && mem_read && in_mmio`. Nghĩa là bus đọc ngoại vi chỉ bật đúng ở pha B, khi lệnh là lw (`mem_read = 1`) và địa chỉ thuộc vùng MMIO (`0xFFFFFFxx`). Các trường hợp đọc RAM nội bộ hay cờ ngắt không kích hoạt `bus_re`.
:::

:::mcq id=KT-A2-04
? Tại sao trong CPU G1, thanh ghi lệnh IMEM phải chốt địa chỉ bằng `next_pc` ở pha A thay vì dùng giá trị `pc` hiện tại?
- [ ] Vì dùng `pc` sẽ khiến mạch ALU không kịp tính toán kết quả phép cộng trong nửa chu kỳ còn lại
- [ ] Vì bộ đếm chương trình `pc` chỉ được cập nhật sau khi lệnh đã hoàn tất ghi vào thanh ghi đích
- [x] Vì lúc cạnh pha A, `pc` còn là địa chỉ lệnh vừa xong; chốt bằng `pc` thì ra lại lệnh cũ, mọi lệnh chạy trễ một nhịp
- [ ] Vì kiến trúc MIPS yêu cầu bắt buộc phải có một khe trễ nhánh phía sau mọi lệnh truy xuất bộ nhớ
> Giải thích: BRAM chỉ nhìn địa chỉ có trước cạnh nhịp và trả dữ liệu ngay sau cạnh đó. Ở cạnh pha A, `pc` chưa kịp cập nhật nên vẫn là địa chỉ của lệnh vừa xong; chốt bằng `pc` thì IMEM đưa ra lại lệnh cũ. Địa chỉ đúng là `next_pc`, đã tính xong ở chu kỳ trước. Hai lựa chọn còn lại nói về ALU và khe trễ nhánh, không liên quan đến thời điểm chốt địa chỉ.
:::

:::mcq id=KT-A2-05
? Thao tác đọc thanh ghi `MS_OF_DAY` tại địa chỉ `0xFFFFFF04` mang lại tác dụng phụ gì đối với phần cứng RTC của WatchChip?
- [x] Phần cứng tự động chụp giá trị ngày hiện tại vào thanh ghi đệm `DAY_SHADOW` để tránh lệch ngày
- [ ] Bộ đếm mili giây tự động xóa về 0 để đồng bộ lại chu kỳ đếm mới với nhịp xung 25 MHz của CPU G1
- [ ] Mạch ngắt lập tức phát tín hiệu báo cho CPU biết một giây mới vừa trôi qua trong hệ thống đồng hồ
- [ ] Giá trị hiệu chỉnh `CAL` được tự động nạp vào bộ cộng phân số của timebase để điều chỉnh độ lệch
> Giải thích: Khi đọc `MS_OF_DAY` (mili giây trong ngày), nếu đúng lúc đồng hồ nhảy qua nửa đêm (23:59:59.999 sang 00:00:00.000) mà đọc ngày sau đó thì ngày và giờ sẽ lệch nhau một ngày. Do đó, phần cứng RTC được thiết kế để ngay khi có lệnh đọc `MS_OF_DAY`, giá trị ngày lập tức được chụp đóng băng vào `DAY_SHADOW`. Đọc không làm reset bộ đếm hay phát ngắt.
:::


## A3 · asm, ISS, co-sim, MARS và kiểm thử đột biến

### Bản đồ

:::ban-do
Trong toàn bộ hệ sinh thái của WatchChip, bài học này bao quát toàn bộ tầng công cụ kiểm chứng (verification toolchain) bao quanh con chip, đóng vai trò như hệ thống trọng tài độc lập bảo đảm từng cổng logic và từng dòng mã máy hoạt động chính xác tuyệt đối.

Vị trí của các công cụ kiểm thử trên bản đồ phát triển:
- **Trình biên dịch hợp ngữ (`tools/asm.py`):** chuyển đổi các file mã nguồn hợp ngữ MIPS (`fw/*.s`, đặc biệt là `main.s`) thành mã máy nhị phân 32 bit, nạp vào bộ nhớ chương trình BRAM dưới dạng file `.hex`.
- **Bộ mô phỏng tập lệnh ISS (`tools/iss.py`):** một phần mềm viết bằng Python mô phỏng toàn bộ hoạt động của CPU MIPS 28 lệnh và các thanh ghi ngoại vi ở mức hành vi trừu tượng, không phụ thuộc vào dây dẫn hay xung nhịp clock phần cứng.
- **Bộ đối chiếu vết lệnh (`tools/cmp_trace.py`):** công cụ tự động đọc hai file nhật ký thực thi (trace log) sinh ra từ hai nguồn khác nhau, so sánh từng dòng và từng cột để phát hiện ngay lập tức bất kỳ sự sai lệch nào ở từng lệnh đơn lẻ.
- **Hệ thống đồng mô phỏng co-sim (`tools/cosim_iss.py`):** quy trình chạy song song mô phỏng phần cứng Verilog RTL và mô phỏng phần mềm ISS, tự động trích xuất nhật ký thực thi từng lệnh và đối chiếu qua `cmp_trace`. Đã chạy hồi quy toàn diện trên 25 ca kiểm thử (`{{so:cosim-iss}}` ca kiểm thử).
- **Trọng tài độc lập MARS (`tools/cosim_mars.py`):** trình giả lập MIPS chuẩn công nghiệp của Đại học Bang Missouri, dùng làm mô hình tham chiếu độc lập bên ngoài để đối chiếu trạng thái thanh ghi và bộ nhớ trên 19 ca kiểm thử (`{{so:cosim-mars}}` ca kiểm thử), ngăn chặn hoàn toàn bẫy cùng sai.
- **Kỹ thuật kiểm thử đột biến (mutation testing):** phương pháp cố tình gieo các lỗi sai nhỏ vào mã nguồn phần cứng và công cụ để thẩm định độ nhạy và mức độ bao phủ thực chất của toàn bộ hệ thống bài kiểm tra.
:::

### Câu hỏi mở bài

Làm sao chúng ta có thể tin chắc rằng con chip phần cứng chạy đúng thiết kế, khi mà chính chúng ta vừa là người thiết kế mạch, vừa là người viết bài kiểm tra và tự đưa ra đáp án mong đợi?

Đây là câu hỏi cốt tử trong kỹ thuật thiết kế vi mạch điện tử:
- Trong quá trình làm việc, một kỹ sư hoàn toàn có thể hiểu sai một chi tiết trong tập lệnh kiến trúc (ví dụ: hiểu nhầm lệnh dịch phải số học `sra` là chèn số 0 thay vì giữ nguyên bit dấu âm).
- Nếu kỹ sư đó tự viết bộ vi xử lý bằng Verilog, rồi tự viết testbench để kiểm tra, người đó sẽ viết testbench cũng kiểm tra theo cách hiểu sai đó. Kết quả là mạch chạy sai nhưng testbench vẫn báo xanh hoàn hảo. Đó chính là bẫy cùng sai (common-mode failure).
- Hơn nữa, một con chip thực tế có thể chạy hàng trăm ngàn lệnh liên tiếp. Việc mở dạng sóng xung nhịp để dò bằng mắt từng tín hiệu điện áp là điều bất khả thi và rất dễ bỏ lọt những lỗi sai ngầm chỉ xuất hiện sau nhiều chu kỳ tính toán phức tạp.

Để giải quyết bài toán niềm tin này, WatchChip thiết lập một quy trình kiểm chứng đa tầng khép kín: dùng trình dịch hai lượt để chuẩn hóa mã lệnh, dùng đồng mô phỏng co-sim để máy tự động so sánh từng lệnh với mô hình phần mềm ISS, dùng trình giả lập chuẩn mực MARS làm trọng tài độc lập, và thử thách chính bộ test bằng kỹ thuật kiểm thử đột biến.

### Trực giác

Hãy hình dung quá trình này qua những câu chuyện đời thường:

- **Trình biên dịch hai lượt (`asm.py`):** Giống như một hướng dẫn viên du lịch viết sách hướng dẫn cho đoàn khách đi bộ qua một khu phố cổ ngoằn ngoèo. Nếu tác giả vừa đi vừa viết ngay trong một lượt duy nhất, khi đến ngã ba đầu phố gặp chỉ dẫn "nếu trời mưa hãy rẽ vào Quán Bún Bò", tác giả sẽ không thể ghi vào sách rằng quán nằm cách đây bao nhiêu mét, vì Quán Bún Bò nằm ở tận cuối phố mà tác giả chưa từng đi qua! Do đó, tác giả bắt buộc phải đi hai lượt:
  - **Lượt một (khảo sát và lập sổ địa chỉ):** Đi bộ từ đầu phố đến cuối phố, ghi chép lại sổ tay tọa độ của từng địa điểm quan trọng: "Ngã ba ở mét thứ 4, Chợ ở mét thứ 20, Quán Bún Bò ở mét thứ 80".
  - **Lượt hai (viết sách hướng dẫn chính thức):** Đi lại lần nữa để soạn thảo các câu lệnh. Khi đứng ở ngã ba (mét thứ 4) và cần chỉ đường tới Quán Bún Bò (mét thứ 80), tác giả mở sổ tra cứu và tính ngay ra khoảng cách là `80 - 4 = 76` mét (tương ứng với độ lệch bước nhảy). Từ đó ghi con số chính xác vào sách.

- **Đồng mô phỏng co-sim và nhật ký thực thi (trace log):** Giống như cho hai thí sinh cùng giải một đề thi tính toán dài 10 000 bước.
  - Thí sinh A là một người thợ cơ khí lành nghề, lắp ráp từng bánh răng kim loại và thanh truyền động bằng đồng (mô phỏng phần cứng Verilog RTL chạy theo từng nhịp clock).
  - Thí sinh B là một chuyên gia toán học tính nhẩm bằng giấy nháp và bút chì (bộ mô phỏng tập lệnh ISS viết bằng Python).
  - Sau mỗi bước giải, cả hai cùng ghi lại vào một cuốn sổ nhật ký (trace log): vừa làm phép tính gì, kết quả ghi vào ô nhớ nào.
  - Một giám khảo điện tử nghiêm khắc (`cmp_trace.py`) cầm hai cuốn sổ áp sát vào nhau, rà soát từng dòng một. Nếu ở bước thứ 4 521, người thợ cơ khí ghi kết quả là `0x0000002A` mà chuyên gia tính nhẩm lại ghi `0x0000002B`, tiếng còi báo động lập tức vang lên, chỉ đích danh dòng thứ 4 521 bị lệch!

- **Trọng tài MARS và cách thoát bẫy cùng sai:** Nếu cả thí sinh A và thí sinh B đều do cùng một gia sư dạy dỗ (hoặc do cùng một người / công cụ AI viết ra), cả hai có thể cùng nhớ nhầm một công thức lượng giác và cùng cho ra đáp án sai giống hệt nhau. Để loại bỏ hoàn toàn khả năng này, ta mang cuốn sổ đến nhờ một vị giáo sư đầu ngành uy tín ở trường đại học quốc tế (phần mềm MARS 4.5 của Đại học Bang Missouri) chấm độc lập. Khi kết quả của con chip khớp trọn vẹn với giáo sư MARS, ta có thể tự tin tuyệt đối rằng kiến trúc đã chuẩn xác.

- **Kiểm thử đột biến (mutation testing):** Làm sao biết chuông báo cháy của tòa nhà có hoạt động thực sự hay không? Nếu chỉ đứng nhìn chuông im lặng rồi kết luận "tòa nhà hoàn toàn an toàn", đó là sự chủ quan nguy hiểm. Cách kiểm tra chuẩn mực là cố tình đốt một mẩu giấy có khói đưa sát vào đầu cảm biến (cố ý cài lỗi vào hệ thống, gọi là tạo đột biến). Nếu chuông lập tức reo vang, hệ thống báo cháy được chứng nhận đạt chuẩn. Ngược lại, nếu khói bay mù mịt mà chuông vẫn im re, bộ kiểm tra đã thất bại.

### Cơ chế theo đường tín hiệu

Quy trình kiểm chứng toàn diện từ file mã nguồn hợp ngữ đến khi nghiệm thu phần cứng trên WatchChip trải qua 6 công đoạn kỹ thuật chặt chẽ:

1. **Giai đoạn 1 - Dịch hợp ngữ hai lượt qua `tools/asm.py`:**
   - Trình dịch hợp ngữ của WatchChip hỗ trợ đầy đủ 28 lệnh MIPS phần cứng kèm 5 lệnh giả tiện ích (`nop`, `move`, `li`, `la`, `b`).
   - **Lượt 1 (Pass 1):** Đọc từng dòng văn bản, cắt bỏ các phần chú thích sau dấu thăng `#`. Sử dụng biểu thức chính quy `LABEL_RE` để bóc tách các nhãn định danh (`tên_nhãn:`). Quản lý con trỏ địa chỉ bộ nhớ riêng biệt cho phân đoạn mã lệnh (`.text`, bắt đầu từ địa chỉ 0) và phân đoạn dữ liệu (`.data`). Ghi nhận tên nhãn và địa chỉ tương ứng vào từ điển bảng biểu tượng (symbol table): `labels[name] = addr`. Tính toán kích thước ô nhớ mà mỗi lệnh chiếm dụng (mỗi lệnh chuẩn chiếm 4 byte, riêng lệnh giả `la` nở thành 8 byte gồm 2 lệnh `lui` và `ori`).
   - **Lượt 2 (Pass 2):** Quét lại danh sách các lệnh đã thu thập. Với mỗi lệnh, tra cứu bảng biểu tượng để tính toán các tham số:
     - Với lệnh nhảy không điều kiện `j`, `jal`: lấy 26 bit địa chỉ tuyệt đối bằng phép dịch phải 2 bit (`target_addr >> 2`).
     - With lệnh rẽ nhánh có điều kiện `beq`, `bne`: tính độ lệch địa chỉ tương đối theo quy ước của MIPS: `offset = (target_addr - (pc + 4)) // 4`. Kiểm tra giá trị offset có nằm vừa trong dải số nguyên 16 bit có dấu (-32 768 đến +32 767) hay không.
     - Ghép các trường mã nhị phân theo khuôn dạng lệnh R, I, J và phát sinh file mã máy `.hex` (mỗi dòng 8 chữ số thập lục phân nạp vào BRAM) cùng file liệt kê `.lst` để đối chiếu dòng lệnh gốc.

2. **Giai đoạn 2 - Mô phỏng phần cứng và xuất nhật ký thực thi (trace RTL):**
   - Trình mô phỏng mã nguồn mở Icarus Verilog (`iverilog`) biên dịch mã nguồn RTL cùng testbench hệ thống (như `tb/cpu_g1_tb.v` hoặc `tb/cpu_pipe_tb.v`).
   - Trong quá trình mô phỏng, mỗi khi một lệnh CPU được thực thi hoàn tất (ở CPU G1 là tại cạnh lên pha A kế tiếp; ở CPU G2 là khi lệnh đi qua trạm ghi kết quả MEM/WB), mạch testbench sẽ ghi một dòng trạng thái vào file nhật ký `.csv`.
   - Cấu trúc một dòng trace gồm đúng 8 cột chuẩn hóa theo tài liệu đặc tả kiến trúc:
     `cycle, pc, instr, rd, value, mop, maddr, mdata`
     - `cycle`: số chu kỳ xung nhịp hệ thống kể từ khi khởi động chip.
     - `pc`: địa chỉ byte của lệnh vừa thực thi (dạng hex 8 chữ số, ví dụ `00000004`).
     - `instr`: mã máy 32 bit của lệnh vừa chạy.
     - `rd`: số thứ tự của thanh ghi đích trong tập thanh ghi được ghi ngược kết quả (từ 0 đến 31, nếu lệnh không ghi thanh ghi thì mang giá trị 0).
     - `value`: giá trị số học 32 bit thực tế được ghi vào thanh ghi đích `rd`.
     - `mop`: loại thao tác bộ nhớ (`r` là đọc dữ liệu, `w` là ghi dữ liệu, `-` là không truy cập bộ nhớ).
     - `maddr`: địa chỉ byte bộ nhớ hoặc ngoại vi MMIO mà lệnh truy xuất.
     - `mdata`: dữ liệu 32 bit được đọc từ bộ nhớ hoặc ghi xuống bộ nhớ.

3. **Giai đoạn 3 - Bộ mô phỏng tập lệnh ISS và cơ chế phát lại ngoại vi (Replay MMIO):**
   - File `tools/iss.py` chứa lớp `ISS` cài đặt toàn bộ kiến trúc tập lệnh MIPS bằng Python. ISS duy trì mảng 32 thanh ghi đa năng, hai thanh ghi đặc thù `HI`, `LO`, các thanh ghi điều khiển đồng xử lý CP0 (`Status`, `Cause`, `EPC`) và mảng bộ nhớ dữ liệu DMEM.
   - Khi CPU chỉ chạy các phép tính nội bộ (cộng, trừ, nhân, chia, dịch bit, rẽ nhánh), ISS tự động tính toán độc lập từng bước.
   - Khi CPU tương tác với thế giới ngoại vi (đọc thanh ghi thời gian thực `MS_OF_DAY`, đọc ký tự từ bàn phím nối tiếp UART, hoặc tiếp nhận tín hiệu ngắt bất định từ bên ngoài): bộ mô phỏng phần mềm không thể tự đoán trước được thời điểm người dùng nhấn nút hay đồng hồ vật lý trôi đi bao nhiêu nhịp.
   - Để giải quyết vấn đề này, ISS vận hành ở chế độ Replay MMIO: ISS đọc tuần tự file trace của phần cứng RTL; mỗi khi gặp lệnh đọc ngoại vi (`lw` ở vùng địa chỉ MMIO `0xFFFFFFxx`) hoặc lệnh đọc cờ ngắt (`mfc0` từ thanh ghi Cause), ISS sẽ lấy đúng giá trị mà phần cứng thực tế đã đọc được từ file trace để nạp vào thanh ghi mô phỏng của mình, sau đó tiếp tục tự tính toán các lệnh xử lý tiếp theo. Nhờ đó, tính đúng đắn logic của thuật toán phần mềm được kiểm tra trọn vẹn mà không bị đứt quãng bởi sự ngẫu nhiên của ngoại vi.

4. **Giai đoạn 4 - So sánh vết tự động bằng công cụ `cmp_trace.py`:**
   - Công cụ `tools/cmp_trace.py` nhận đầu vào là hai file trace: file của mô phỏng phần cứng RTL và file của bộ mô phỏng phần mềm ISS.
   - Trước khi so sánh, hàm `_norm` tự động lược bỏ cột đầu tiên (`cycle`) vì thời gian xung nhịp vật lý giữa CPU G1 (2 nhịp mỗi lệnh), CPU G2 (chạy ống dẫn 5 tầng có các chu kỳ dừng chờ stall) và ISS (chạy tuần tự không có khái niệm chu kỳ clock) là hoàn toàn khác nhau.
   - `cmp_trace` so sánh đối chiếu từng dòng trên 7 cột còn lại: `pc`, `instr`, `rd`, `value`, `mop`, `maddr`, `mdata`.
   - Nếu phát hiện bất kỳ sự khác biệt nào ở bất kỳ cột nào, chương trình lập tức dừng lại, in số thứ tự dòng bị lỗi, tên các cột bị sai khác, giá trị của cả hai bên để kỹ sư truy vết nguyên nhân, và trả về mã thoát lỗi 1. Nếu toàn bộ hàng chục ngàn dòng khớp nhau từng bit, chương trình in thông báo thành công `PASS cmp_trace <số dòng>` với mã thoát 0.

5. **Giai đoạn 5 - Trọng tài độc lập công nghiệp MARS:**
   - Script `tools/cosim_mars.py` biên dịch chương trình kiểm thử bằng trình giả lập MARS 4.5 (`Mars4_5.jar`) với cờ `CompactTextAtZero`.
   - Cho chạy song song chương trình trên mô phỏng Icarus Verilog của CPU G1 và trên máy ảo MARS.
   - Khi chương trình kết thúc, script thu thập toàn bộ trạng thái cuối cùng gồm 32 thanh ghi đa năng (`$0` đến `$31`), toàn bộ vùng nhớ RAM từ địa chỉ `0x800` đến `0xFF8`, và tổng số lượng lệnh đã thực thi.
   - Tiến hành so sánh từng ô nhớ và từng thanh ghi giữa Verilog RTL và MARS. Nhờ MARS là phần mềm chuẩn mực đã được hàng trăm trường đại học trên thế giới kiểm chứng qua nhiều thập kỷ, sự trùng khớp này bảo đảm thiết kế của nhóm hoàn toàn tuân thủ chuẩn kiến trúc MIPS quốc tế.

6. **Giai đoạn 6 - Đối chiếu Waveform và Trace log:**
   - Trong quá trình phát triển, việc kết hợp giữa file vết lệnh (trace log) và biểu đồ dạng sóng xung nhịp (waveform xem bằng công cụ GTKWave) mang lại cái nhìn toàn diện:
     - Trace log cung cấp bức tranh toàn cảnh ở mức kiến trúc phần mềm: giúp trả lời ngay câu hỏi "lệnh nào tính ra kết quả sai ở bước nào?".
     - Waveform hiển thị chi tiết mức vật lý phần cứng theo từng nano giây: giúp trả lời câu hỏi "tại sao tín hiệu điện áp bị trễ, tại sao cờ điều khiển bật sai nhịp?".
     - Khi mở file waveform `.vcd` trên GTKWave, chỉ trỏ chuột vào một chu kỳ xung nhịp cụ thể, ta có thể đọc được ngay:
       - Với CPU G1: một lệnh nằm trọn vẹn trong hai nhịp clock 50 MHz (pha A chốt địa chỉ lệnh và ghi thanh ghi, pha B kích hoạt đọc ghi bộ nhớ).
       - Với CPU G2: tại cùng một chu kỳ nhịp, 5 lệnh liên tiếp nhau đang đồng thời nằm ở 5 trạm khác nhau (lệnh mới nhất ở trạm lấy lệnh IF, lệnh kế trước ở trạm giải mã ID, lệnh tiếp theo ở trạm tính toán EX, lệnh kế đó ở trạm bộ nhớ MEM, và lệnh cũ nhất ở trạm ghi kết quả WB). Dòng trace log tương ứng của lệnh sẽ xuất hiện đúng ở thời điểm lệnh bước qua trạm WB.

### Bảng chu kỳ hoặc tính tay

:::suy-dan
Xem xét một đoạn chương trình hợp ngữ ngắn gồm 5 lệnh để minh họa quá trình tính tay của trình dịch hai lượt `asm.py`, cách tính độ lệch bước nhảy và dạng nhật ký vết lệnh trace log tương ứng:

```assembly
0x000:       addiu $t0, $zero, 10      # Khởi tạo $t0 = 10
0x004: LOOP: beq   $t0, $zero, DONE    # Nếu $t0 == 0 thì thoát vòng lặp
0x008:       addiu $t0, $t0, -1        # Giảm biến đếm $t0 đi 1
0x00C:       j     LOOP                # Nhảy quay lại đầu vòng lặp
0x010: DONE: nop                       # Lệnh rỗng kết thúc chương trình
```

Tính toán từng bước qua hai lượt của trình biên dịch `asm.py`:
---
**Bảng 1: Lượt 1 (Pass 1) - Quét nhãn và xây dựng Bảng biểu tượng (Symbol Table)**

| Dòng | Lệnh nguồn | Phân tích cú pháp | Địa chỉ PC | Nhãn ghi nhận | Cập nhật bảng ký hiệu |
|---|---|---|---|---|---|
| 1 | `addiu $t0, $zero, 10` | Lệnh thường, chiếm 1 từ (4 byte) | `0x000` | Không có | `addr = 0x004` |
| 2 | `LOOP: beq $t0, $zero, DONE` | Phát hiện nhãn `LOOP:`, lệnh chiếm 4 byte | `0x004` | `LOOP` | `labels["LOOP"] = 0x004`, `addr = 0x008` |
| 3 | `addiu $t0, $t0, -1` | Lệnh thường, chiếm 1 từ (4 byte) | `0x008` | Không có | `addr = 0x00C` |
| 4 | `j LOOP` | Lệnh thường, chiếm 1 từ (4 byte) | `0x00C` | Không có | `addr = 0x010` |
| 5 | `DONE: nop` | Phát hiện nhãn `DONE:`, lệnh chiếm 4 byte | `0x010` | `DONE` | `labels["DONE"] = 0x010`, `addr = 0x014` |

Kết thúc lượt 1, trình dịch sở hữu bảng ký hiệu hoàn chỉnh: `labels = {"LOOP": 0x004, "DONE": 0x010}`.

**Bảng 2: Lượt 2 (Pass 2) - Tra cứu nhãn, tính offset và sinh mã máy nhị phân 32 bit**

1. **Tại địa chỉ `0x000` (`addiu $t0, $zero, 10`):**
   - Khuôn dạng lệnh I: `opcode (6 bit) | rs (5 bit) | rt (5 bit) | imm (16 bit)`.
   - Opcode `addiu` là `0x09` (`001001_b`), `rs = $zero` (`0`), `rt = $t0` (`8`), `imm = 10` (`0x000A`).
   - Ghép bit: `(0x09 << 26) | (0 << 21) | (8 << 16) | 10` = `0x2408000A`.

2. **Tại địa chỉ `0x004` (`beq $t0, $zero, DONE`):**
   - Đây là lệnh rẽ nhánh có điều kiện tham chiếu tới nhãn `DONE` nằm ở phía trước.
   - Tra bảng ký hiệu: `target_addr = labels["DONE"] = 0x010` (tương ứng 16 trong hệ thập phân).
   - Địa chỉ lệnh hiện tại là `PC = 0x004` (4 thập phân). Địa chỉ của lệnh kế tiếp là `PC + 4 = 0x008` (8 thập phân).
   - Công thức tính trường offset 16 bit của MIPS:
     $$\text{offset} = \frac{\text{target\_addr} - (\text{PC} + 4)}{4} = \frac{16 - 8}{4} = \frac{8}{4} = +2$$
   - Ý nghĩa con số `+2`: từ lệnh kế tiếp (`0x008`), bộ vi xử lý bước thêm 2 lệnh nữa là đến đúng nhãn `DONE` (`0x010`).
   - Opcode `beq` là `0x04` (`000100_b`), `rs = $t0` (`8`), `rt = $zero` (`0`), `imm = 2` (`0x0002`).
   - Ghép bit: `(0x04 << 26) | (8 << 21) | (0 << 16) | 2` = `0x11000002`.

3. **Tại địa chỉ `0x008` (`addiu $t0, $t0, -1`):**
   - Giá trị số âm `-1` biểu diễn bù hai 16 bit là `0xFFFF`.
   - `rs = $t0` (`8`), `rt = $t0` (`8`), ghép bit ra mã máy: `0x2508FFFF`.

4. **Tại địa chỉ `0x00C` (`j LOOP`):**
   - Đây là lệnh nhảy không điều kiện tuyệt đối dạng J.
   - Tra bảng ký hiệu: `target_addr = labels["LOOP"] = 0x004`.
   - Trường địa chỉ 26 bit: `target_addr >> 2 = 0x004 >> 2 = 1`.
   - Opcode của lệnh `j` là `0x02` (`000010_b`).
   - Ghép bit: `(0x02 << 26) | 1` = `0x08000001`.

5. **Tại địa chỉ `0x010` (`nop`):**
   - Lệnh giả `nop` tương đương với mã máy toàn bit 0: `0x00000000`.

**Bảng 3: Dạng nhật ký vết lệnh (Trace Log) 8 cột khi thực thi vòng lặp đầu tiên**

| cycle | pc | instr | rd | value | mop | maddr | mdata | Ý nghĩa hành vi kiến trúc |
|---|---|---|---|---|---|---|---|---|
| 2 | `00000000` | `2408000a` | 8 | `0000000a` | - | `00000000` | `00000000` | Nạp giá trị 10 vào thanh ghi `$t0` (`$8`) |
| 4 | `00000004` | `11000002` | 0 | `00000000` | - | `00000000` | `00000000` | `beq`: $t0 khác 0 nên không nhảy, không ghi thanh ghi |
| 6 | `00000008` | `2508ffff` | 8 | `00000009` | - | `00000000` | `00000000` | Giảm `$t0` từ 10 xuống 9, ghi vào `$8` |
| 8 | `0000000c` | `08000001` | 0 | `00000000` | - | `00000000` | `00000000` | `j LOOP`: nhảy về `0x004`, chu kỳ sau PC = `0x004` |

Khi chạy qua công cụ `cmp_trace`, cột `cycle` bị bỏ qua, và toàn bộ 7 cột còn lại giữa mô phỏng phần cứng và ISS được so khớp tuyệt đối từng ký tự.
:::

### Trong chip

:::trong-chip
Quy tắc cốt lõi của việc đối chiếu vết lệnh tự động được thể hiện trọn vẹn trong hàm `compare` của tệp công cụ `tools/cmp_trace.py`:

{{trich:tools/cmp_trace.py::compare}}

Đọc và phân tích từng dòng mã nguồn kỹ thuật:
- **Dòng 23 (`def compare(a, b, na="A", nb="B"):`):** Hàm tiếp nhận hai danh sách dòng `a` (vết từ phần cứng RTL) và `b` (vết từ mô phỏng ISS), kèm tên nhãn đại diện để xuất báo cáo.
- **Dòng 25 (`for k in range(min(len(a), len(b))):`):** Duyệt đồng thời từng cặp dòng theo chỉ số từ 0 đến hết độ dài của file ngắn hơn.
- **Dòng 26 (`x, y = _norm(a[k]), _norm(b[k])`):** Chuẩn hóa hai dòng dữ liệu thông qua hàm `_norm`. Hàm này thực hiện nhiệm vụ thiết yếu: cắt bỏ cột `cycle` (cột đầu tiên) và chuyển toàn bộ chuỗi ký tự hex về chữ thường để tránh sai khác định dạng in ấn.
- **Dòng 27–30 (`if x != y:`):** Nếu phát hiện nội dung hai dòng chuẩn hóa không trùng khớp, vòng lặp dừng ngay lập tức. Cột bị sai khác được nhận diện chính xác qua biểu thức dò 7 trường (`pc`, `instr`, `rd`, `value`, `mop`, `maddr`, `mdata`), sau đó thông báo lỗi chi tiết chỉ rõ số thứ tự dòng sai và giá trị cụ thể của từng bên.
- **Dòng 31–35 (`if len(a) != len(b):`):** Kiểm tra độ dài tổng thể của hai file trace. Nếu một bên chạy thừa lệnh so với bên kia (ví dụ phần cứng bị treo vòng lặp vô tận hoặc dừng sớm do lỗi logic), hàm sẽ báo lỗi thừa dòng và in ra dòng lệnh đầu tiên bị dư thừa.
- **Dòng 36 (`return True, []`):** Chỉ khi toàn bộ các dòng khớp nhau 100% trên cả 7 cột và hai file có độ dài bằng nhau, hàm mới xác nhận kết quả kiểm thử đạt chuẩn (PASS).
:::

### Bẫy và thầy hay hỏi

:::bay
**Ngộ nhận rằng bộ mô phỏng tập lệnh ISS chỉ đơn giản là viết lại mã phần cứng Verilog sang ngôn ngữ Python.**
*Thực tế bản chất:* ISS (Instruction Set Simulator) và Verilog RTL hoạt động ở hai mức độ trừu tượng hoàn toàn khác nhau.
- Verilog RTL mô tả cấu trúc vật lý thực tế: có dây dẫn, cổng logic, xung nhịp clock, các sườn kích hoạt flip-flop, hiện tượng tranh chấp bus và trễ lan truyền tín hiệu.
- Ngược lại, ISS là một máy trạng thái trừu tượng thuần túy phần mềm: nó nhận vào một mã máy 32 bit, giải mã và cập nhật trực tiếp mảng thanh ghi hoặc mảng bộ nhớ theo ngữ nghĩa toán học của lệnh trong đúng một hàm gọi.
- ISS chạy nhanh hơn mô phỏng phần cứng hàng chục đến hàng trăm lần, cho phép chạy thử nghiệm nhanh toàn bộ hệ điều hành hay phần mềm lớn. Nhưng ISS hoàn toàn "mù" trước các lỗi xung đột phần cứng như xung đột thời gian thiết lập (setup timing), lỗi xung đột bộ nhớ hai cổng hay hiện tượng nghẽn đường ống (pipeline hazards). Đó là lý do bắt buộc phải kết hợp cả hai qua cơ chế đồng mô phỏng co-sim.
:::

:::bay
**Bẫy cùng sai (Common-Mode Failure) khi một kỹ sư tự viết phần cứng và tự viết bộ kiểm tra.**
*Thực tế bản chất:* Đây là cạm bẫy tâm lý và kỹ thuật nguy hiểm nhất trong thiết kế vi mạch vi xử lý.
- Nếu người lập trình có một ngộ nhận sai lầm về tập lệnh MIPS (ví dụ: ngộ nhận rằng phép chia `div` cho số 0 phải phát sinh biệt lệ ngắt phần cứng, trong khi chuẩn MIPS thực tế quy định phép chia 0 không gây ngắt mà để lại kết quả không xác định trong thanh ghi `HI`/`LO`), người đó sẽ vừa sửa code Verilog để phát ngắt, vừa viết testbench để chờ bắt ngắt đó.
- Cả hai phần đều sai so với chuẩn quốc tế nhưng khi chạy kiểm tra thì luôn luôn báo xanh (PASS 100%).
- Cách hóa giải duy nhất của WatchChip là đưa trình giả lập MARS 4.5 của bên thứ ba vào làm trọng tài độc lập trong `tools/cosim_mars.py`. Vì MARS được phát triển hoàn toàn độc lập bởi các giáo sư đại học và đã qua kiểm nghiệm thực tế hàng triệu lần, bất kỳ sự sai lệch nào của phần cứng so với chuẩn MIPS đều bị MARS vạch trần ngay lập tức.
:::

:::bay
**Vì sao trình biên dịch hợp ngữ bắt buộc phải có hai lượt duyệt mà không thể hoàn tất trong một lượt duy nhất?**
*Thực tế bản chất:* Nguyên nhân cốt lõi nằm ở hiện tượng tham chiếu về phía trước (forward reference).
- Trong các chương trình thực tế, các lệnh rẽ nhánh có điều kiện như `beq $t0, $zero, EXIT` thường xuyên nhảy tới một nhãn `EXIT:` nằm ở phía sau (cách đó hàng chục hoặc hàng trăm dòng lệnh).
- Khi trình dịch đang đứng ở dòng lệnh `beq`, nếu chỉ dịch một lượt, nó hoàn toàn chưa đọc tới nhãn `EXIT:`, do đó không thể biết nhãn đó sẽ nằm ở địa chỉ byte số mấy trong bộ nhớ để tính toán trường `offset`.
- Nếu cố tình dịch một lượt, người ta phải dùng kỹ thuật vá ngược địa chỉ (backpatching): ghi tạm mã máy rỗng rồi lưu danh sách cần sửa, sau khi gặp nhãn mới quay lại ghi đè vào file. Kỹ thuật này phức tạp, dễ gây lỗi và không phù hợp với việc phát sinh file bộ nhớ tĩnh `.hex` cho FPGA. Lượt 1 để thu thập toàn bộ nhãn vào bảng biểu tượng và Lượt 2 để mã hóa là giải pháp kinh điển, an toàn và sáng sủa nhất.
:::

:::bay
**Tại sao khi thực hiện đồng mô phỏng co-sim, công cụ `cmp_trace.py` bắt buộc phải loại bỏ cột chu kỳ xung nhịp (`cycle`) trước khi so sánh?**
*Thực tế bản chất:* Chu kỳ xung nhịp là đại lượng đo lường vật lý phụ thuộc chặt chẽ vào cấu trúc vi kiến trúc của từng loại bộ xử lý, không phải là thuộc tính ngữ nghĩa của phần mềm.
- Với CPU G1 đơn chu kỳ: mỗi lệnh mất đúng 2 nhịp clock hệ thống 50 MHz (pha A và pha B).
- Với CPU G2 đường ống (pipeline): một lệnh bình thường mất 1 chu kỳ để trôi qua mỗi tầng, nhưng khi gặp xung đột dữ liệu load-use sẽ bị dừng 1 chu kỳ bong bóng (stall bubble), khi gặp nhánh rẽ sẽ bị phạt 2 chu kỳ, và khi gặp phép chia `div` sẽ phải dừng chờ 33 chu kỳ.
- Với bộ mô phỏng phần mềm ISS: chương trình chạy trên máy tính theo các câu lệnh Python tuần tự, hoàn toàn không có khái niệm chu kỳ xung nhịp phần cứng.
- Nếu giữ lại cột `cycle`, file trace giữa G1, G2 và ISS sẽ lệch nhau ngay từ những lệnh đầu tiên dù kết quả tính toán trên các thanh ghi hoàn toàn trùng khớp. Do đó, quy tắc so sánh trace chuẩn công nghiệp chỉ tập trung vào trạng thái kiến trúc (architectural state): PC, mã lệnh, thanh ghi bị thay đổi và thao tác bộ nhớ.
:::

### Sửa tại chỗ và ứng dụng

:::sua-tai-cho
**Tình huống cài lỗi thực tế:**
Giả sử trong quá trình chỉnh sửa công cụ biên dịch `tools/asm.py`, một thành viên vô tình sửa nhầm bảng mã lệnh số học tại dòng 24: đổi mã hàm `funct` của lệnh trừ không dấu `subu` từ giá trị đúng `0x23` thành giá trị `0x21` (trùng với mã hàm của lệnh cộng không dấu `addu`).

**Hậu quả trên hệ thống:**
Mọi dòng lệnh `subu` trong các file mã nguồn hợp ngữ (kể cả trong mã nguồn firmware `fw/main.s`) khi được dịch ra file `.hex` đều bị biến thành lệnh cộng `addu`. Khi nạp vào phần cứng, thay vì thực hiện phép trừ biến đếm, con chip sẽ thực hiện phép cộng, làm sai lệch toàn bộ logic thuật toán.

**Bài kiểm tra nào sẽ bắt được lỗi này?**
1. **Bắt ở tầng công cụ biên dịch:** Lệnh kiểm thử tự động `pytest tools/` sẽ lập tức báo đỏ (FAIL) ở bài kiểm tra `test_all28` nằm trong file `tools/test_asm.py`. Bài test này đối chiếu từng từ mã máy sinh ra cho 28 lệnh MIPS với một danh sách mã máy chuẩn đã được tính tay độc lập từ trước. Lệnh `subu $t0, $t1, $t2` sẽ bị phát hiện có mã máy sai lệch ngay tại chỗ.
2. **Bắt ở tầng đồng mô phỏng co-sim:** Nếu file `.hex` lỗi này được mang đi chạy đồng mô phỏng bằng lệnh `python tools/cosim_iss.py sum100`, công cụ `cmp_trace.py` sẽ lập tức báo lỗi dừng lại ở lệnh trừ đầu tiên:
   ```
   FAIL cmp_trace lech o dong 5, cot: value
     RTL: 5,00000010,01294021,8,00000003,-,00000000,00000000
     ISS: 5,00000010,01294023,8,00000001,-,00000000,00000000
   ```
   Giá trị ghi vào thanh ghi `$8` của phần cứng (thực hiện cộng ra 3) hoàn toàn lệch với giá trị mong đợi của ISS (thực hiện trừ ra 1).
3. **Bằng chứng kiểm thử đột biến (Mutation Testing):** Trong chiến dịch kiểm thử độ phủ thực tế ghi nhận tại nhật ký `work/mut_asm_20261003.log`, 10 trên 10 đột biến cố ý gieo vào `tools/asm.py` đều bị hệ thống bài test bắt gọn 100%. Tương tự, 20 trên 20 đột biến gieo vào ISS và RTL trong `work/mut_iss_20261003.log` đều bị bắt sạch, chứng minh độ nhạy bén hoàn hảo của chuỗi công cụ kiểm chứng.
:::

:::dung-o-dau
**Kiến thức này được ứng dụng ở đâu ngoài dự án?**
- **Quy trình chuẩn trong các tập đoàn bán dẫn hàng đầu:** Kỹ thuật đồng mô phỏng (co-sim) và đối chiếu vết thực thi từng lệnh (instruction trace comparison) là phương pháp nền tảng bắt buộc tại các tập đoàn vi xử lý lớn nhất thế giới như ARM, Intel, AMD, NVIDIA và Qualcomm. Khi phát triển một lõi vi xử lý mới (ví dụ lõi ARM Cortex hoặc lõi đồ họa GPU), trước khi chi hàng triệu USD để sản xuất tấm wafer silicon thật, các kỹ sư luôn chạy đồng mô phỏng hàng tỷ chu kỳ giữa mô hình phần cứng RTL và mô hình phần mềm vàng (Golden Reference Model thường viết bằng C++ hoặc SystemC) để bảo đảm không có bất kỳ một lỗi vi kiến trúc nào lọt lưới.
- **Kiểm thử đột biến (Mutation Testing) trong ngành hàng không và y tế:** Trong kỹ thuật phần mềm dành cho các hệ thống nhúng đòi hỏi độ an toàn cực hạn (như hệ thống điều khiển bay máy bay dân dụng theo chuẩn DO-254/DO-178C, hoặc thiết bị cấy ghép y tế), việc chỉ đo độ phủ dòng lệnh thông thường (line coverage) bị coi là không đủ tiêu chuẩn. Người ta bắt buộc phải sử dụng kỹ thuật kiểm thử đột biến: tự động tạo ra hàng ngàn phiên bản lỗi giả định để thẩm định xem bộ bài kiểm tra có thực sự phát hiện được các lỗi tinh vi hay không.
:::

### Tự kiểm và quay lại bức tranh

:::tu-luan
Trình bày nguyên lý hoạt động của trình biên dịch hợp ngữ hai lượt (`tools/asm.py`) và giải thích chi tiết tại sao một trình biên dịch không thể tính toán độ lệch của lệnh rẽ nhánh `beq` chỉ bằng một lượt duyệt duy nhất.
---
**Đáp án hoàn chỉnh:**
- **Nguyên lý của trình biên dịch hai lượt:**
  - *Lượt 1 (Pass 1):* Trình biên dịch đọc tuần tự từng dòng mã nguồn, loại bỏ các ký tự chú thích, bóc tách tên các nhãn (labels) và lưu cặp giá trị `(tên_nhãn, địa chỉ_PC)` vào từ điển bảng biểu tượng (symbol table). Mỗi khi gặp một lệnh hợp lệ, con trỏ địa chỉ `addr` được tăng tương ứng với độ dài của lệnh (lệnh đơn tăng 4 byte, lệnh giả tăng 8 byte).
  - *Lượt 2 (Pass 2):* Trình biên dịch đọc lại danh sách lệnh từ đầu. Lúc này bảng biểu tượng đã chứa đầy đủ địa chỉ của mọi nhãn trong toàn bộ chương trình. Trình dịch tra cứu bảng biểu tượng để tính toán các trường địa chỉ tuyệt đối (lệnh `j`, `jal`) hoặc địa chỉ tương đối (lệnh `beq`, `bne`), chuyển đổi các toán hạng thanh ghi và hằng số thành các trường bit nhị phân, ghép thành mã máy 32 bit hoàn chỉnh và xuất ra file `.hex`.
- **Vì sao không thể dịch một lượt:**
  - Trong lập trình hợp ngữ, hiện tượng tham chiếu về phía trước (forward reference) diễn ra rất phổ biến: một lệnh rẽ nhánh `beq $t0, $zero, LABEL_END` nhảy tới một nhãn nằm ở phía sau vị trí hiện tại.
  - Tại thời điểm đọc dòng lệnh `beq`, nếu chỉ duyệt một lượt, trình biên dịch hoàn toàn chưa đọc tới dòng chứa `LABEL_END`, do đó không thể biết được nhãn này nằm ở địa chỉ bộ nhớ bao nhiêu để áp dụng công thức tính khoảng cách `offset = (target - (pc + 4)) // 4`.
  - Nếu chỉ dịch một lượt mà không dùng bảng biểu tượng ở lượt 1, trình dịch sẽ bị thiếu dữ liệu toán hạng và không thể phát sinh mã máy 32 bit chính xác cho lệnh rẽ nhánh.
:::

:::tu-luan
Phân tích cơ chế Replay MMIO trong bộ mô phỏng tập lệnh ISS (`tools/iss.py`) và nêu rõ lý do tại sao kỹ thuật này cho phép đối chiếu chính xác giữa phần mềm và phần cứng ngay cả khi hệ thống tiếp nhận các tín hiệu ngoại vi ngẫu nhiên từ bên ngoài.
---
**Đáp án hoàn chỉnh:**
- **Cơ chế Replay MMIO:**
  - Bộ mô phỏng tập lệnh ISS là phần mềm chạy độc lập trên máy tính, thực thi 28 lệnh MIPS thuần túy bằng các hàm Python.
  - Khi chương trình thực hiện các lệnh truy xuất không gian bộ nhớ ngoại vi MMIO (như đọc thời gian thực từ thanh ghi `MS_OF_DAY`, đọc dữ liệu nhận được từ cổng nối tiếp UART) hoặc đọc cờ ngắt (`mfc0` từ thanh ghi Cause): đây là các dữ liệu phụ thuộc vào thế giới vật lý bên ngoài và thời điểm xung nhịp thực tế của phần cứng RTL. Bộ mô phỏng ISS chạy trên máy tính không thể tự suy diễn hay đồng bộ hóa thời gian thực với phần cứng.
  - Ở chế độ Replay MMIO, ISS tiếp nhận file nhật ký vết lệnh (trace log) đã được xuất ra từ quá trình mô phỏng RTL trước đó. Khi gặp một lệnh đọc ngoại vi hoặc cờ ngắt, ISS không tự tính toán mà đọc trực tiếp giá trị dữ liệu mà phần cứng RTL đã thu nhận được trong dòng trace tương ứng, nạp giá trị đó vào thanh ghi đích của ISS.
- **Ý nghĩa kỹ thuật:**
  - Kỹ thuật Replay giúp cô lập hoàn toàn yếu tố bất định và ngẫu nhiên của các tín hiệu ngoại vi.
  - Bộ mô phỏng ISS có được đúng dữ liệu đầu vào mà phần cứng đã trải nghiệm, từ đó tiếp tục tự tính toán độc lập toàn bộ các thuật toán xử lý dữ liệu tiếp theo.
  - Nhờ vậy, công cụ `cmp_trace.py` có thể so sánh đối chiếu chuẩn xác từng phép tính logic, từng nhánh rẽ và từng thao tác ghi bộ nhớ giữa phần mềm và phần cứng mà không bao giờ bị lệch do sai khác thời điểm ngoại vi.
:::

:::tu-luan
Kỹ thuật kiểm thử đột biến (Mutation Testing) được nhóm áp dụng như thế nào trong dự án WatchChip, và việc bắt được 100% các đột biến chứng minh điều gì về chất lượng của hệ thống bài kiểm tra?
---
**Đáp án hoàn chỉnh:**
- **Cách áp dụng kiểm thử đột biến trên WatchChip:**
  - Nhóm không chỉ chạy các bài kiểm thử thông thường trên mã nguồn gốc mà chủ động tạo ra các bản sao mã nguồn có chứa lỗi cố ý (gọi là các đột biến - mutants).
  - Các đột biến được thiết kế đa dạng và tinh vi: đảo ngược điều kiện so sánh, sửa mã hàm ALU, thay đổi điều kiện kích hoạt cờ đọc ghi bus, bỏ qua trạng thái khóa chống rung nút bấm, trễ nhịp lấy mẫu bit UART...
  - Cho toàn bộ hệ thống bài test chạy trên các phiên bản đột biến này. Nếu có ít nhất một bài kiểm tra báo lỗi (FAIL), đột biến đó được coi là "bị bắt" (killed). Nếu tất cả bài test vẫn báo xanh (PASS), đột biến đó bị coi là "lọt lưới" (survived), đồng nghĩa với việc bộ kiểm tra đang có lỗ hổng bao phủ.
- **Ý nghĩa của việc bắt 100% đột biến:**
  - Kết quả thực tế ghi nhận trong các nhật ký lưu trữ: 10/10 đột biến trên `asm.py`, 20/20 đột biến trên ISS và RTL, 6/6 đột biến trên `cmp_trace.py`, 15/15 đột biến trên khối UART và 9/9 đột biến trên khối VGA đều bị hệ thống bài test bắt giữ tuyệt đối.
  - Con số này chứng minh hệ thống bài kiểm tra của WatchChip có độ nhạy bén thực chất và độ bao phủ lỗi cực cao: không có bất kỳ bài test nào được viết ra chỉ để "lấy lệ" hay kiểm tra hình thức, mà mỗi kiểm tra đều thực sự bảo vệ một ràng buộc kiến trúc sống còn của con chip.
:::

:::mcq id=KT-A3-01
? Tại sao trình dịch hợp ngữ `tools/asm.py` của WatchChip bắt buộc phải thực hiện theo quy trình hai lượt thay vì dịch toàn bộ chương trình trong một lượt duy nhất?
- [ ] Vì bộ nhớ BRAM của FPGA chỉ cho phép nạp dữ liệu vào các ô nhớ sau khi đã trải qua hai cạnh xung nhịp liên tiếp
- [x] Vì lượt một cần thu thập địa chỉ của mọi nhãn vào bảng biểu tượng để lượt hai tính toán độ lệch cho các lệnh rẽ nhánh
- [ ] Vì cú pháp tập lệnh MIPS yêu cầu phân đoạn mã lệnh `.text` và phân đoạn dữ liệu `.data` phải được lưu ở hai file vật lý tách biệt
- [ ] Vì lượt một dùng để kiểm tra lỗi cú pháp chuỗi ký tự còn lượt hai dùng để nén mã máy nhị phân giảm dung lượng lưu trữ
> Giải thích: Trong các chương trình hợp ngữ, lệnh rẽ nhánh thường xuyên nhảy tới các nhãn nằm ở phía sau (tham chiếu về phía trước). Nếu chỉ dịch một lượt, trình dịch chưa đọc tới nhãn nên không thể biết địa chỉ để tính trường offset. Do đó, lượt một phải quét toàn bộ file để lập bảng biểu tượng ghi nhận địa chỉ của mọi nhãn, sau đó lượt hai mới có đủ dữ liệu để tính toán offset và sinh mã máy chính xác. Các lựa chọn về BRAM, tách file hay nén dung lượng đều là ngộ nhận không đúng bản chất.
:::

:::mcq id=KT-A3-02
? Trong hệ thống kiểm chứng của WatchChip, bẫy cùng sai (common-mode failure) được giải quyết triệt để bằng giải pháp kỹ thuật nào sau đây?
- [ ] Tăng tần số xung nhịp mô phỏng của bộ xử lý G1 từ 25 MHz lên 50 MHz để phát hiện sớm các lỗi chạy đua thời gian
- [ ] Viết thêm nhiều chương trình kiểm thử ngẫu nhiên bằng script Python để tăng số lượng dòng nhật ký thực thi trace log
- [x] Đưa trình giả lập MARS độc lập của bên thứ ba vào đối chiếu kết quả thanh ghi và bộ nhớ với mô phỏng phần cứng
- [ ] Tự động hóa việc kiểm tra dạng sóng xung nhịp waveform bằng phần mềm GTKWave thay cho việc đọc nhật ký thực thi
> Giải thích: Bẫy cùng sai xảy ra khi chính người thiết kế phần cứng tự viết bài test và tự quy định đáp án theo cùng một cách hiểu sai về kiến trúc. Việc tăng tần số xung nhịp hay sinh thêm bài test ngẫu nhiên bằng cùng một bộ sinh test vẫn không thoát khỏi cách hiểu sai đó. Cách giải quyết triệt để là sử dụng trình giả lập MIPS chuẩn mực MARS 4.5 của bên thứ ba làm mô hình tham chiếu độc lập để đối chiếu trạng thái cuối cùng của thanh ghi và bộ nhớ.
:::

:::mcq id=KT-A3-03
? Khi công cụ `tools/cmp_trace.py` thực hiện so sánh hai file nhật ký thực thi giữa mô phỏng phần cứng RTL và mô phỏng ISS, thao tác chuẩn hóa nào sau đây bắt buộc phải thực hiện đầu tiên?
- [x] Lược bỏ cột chu kỳ xung nhịp `cycle` vì thời gian chu kỳ phụ thuộc vào vi kiến trúc phần cứng chứ không thuộc ngữ nghĩa lệnh
- [ ] Đổi toàn bộ các giá trị thanh ghi đích `rd` từ chỉ số số học sang tên gọi quy ước bằng chữ như `$t0`, `$s0`
- [ ] Xóa bỏ toàn bộ các dòng lệnh không có thao tác truy cập đọc hoặc ghi bộ nhớ dữ liệu để thu gọn kích thước file
- [ ] Thêm các chu kỳ chờ nhân tạo vào file trace của ISS để số lượng dòng khớp hoàn toàn với số chu kỳ clock của RTL
> Giải thích: Cột `cycle` thể hiện số chu kỳ xung nhịp vật lý phần cứng. CPU G1 tốn 2 nhịp clock cho một lệnh, CPU G2 có các chu kỳ dừng chờ do hazard, trong khi mô hình phần mềm ISS chạy tuần tự không có chu kỳ clock. Do đó hàm `_norm` trong `cmp_trace.py` bắt buộc phải loại bỏ cột `cycle` và chỉ so sánh 7 cột thể hiện trạng thái kiến trúc thực tế của chương trình (`pc`, `instr`, `rd`, `value`, `mop`, `maddr`, `mdata`).
:::

:::mcq id=KT-A3-04
? Trong công thức tính trường số tức thời 16 bit của lệnh rẽ nhánh `beq` trong MIPS, giá trị `offset = (target - (pc + 4)) // 4` có ý nghĩa kỹ thuật trực tiếp là gì?
- [ ] Là số byte bộ nhớ tuyệt đối tính từ đầu phân đoạn mã lệnh `.text` mà bộ vi xử lý cần nhảy tới khi thỏa mãn điều kiện
- [ ] Là chỉ số hàng trong bảng chân lý điều khiển của khối control tương ứng với lệnh rẽ nhánh đang được thực thi
- [x] Là số lượng từ lệnh 32 bit mà con trỏ chương trình cần bước thêm tính từ vị trí của lệnh nằm ngay sau lệnh rẽ nhánh
- [ ] Là khoảng cách thời gian tính theo nano giây mà bộ cộng ALU cần hoàn thành việc so sánh hai thanh ghi đầu vào
> Giải thích: Trong kiến trúc MIPS, trường offset của lệnh rẽ nhánh không lưu địa chỉ byte tuyệt đối mà lưu khoảng cách tương đối tính theo số lượng từ lệnh (word, mỗi từ 4 byte). Vì con trỏ chương trình đã tự động trỏ tới `pc + 4` ngay sau khi nạp lệnh, khoảng cách bước nhảy được tính từ vị trí `pc + 4` đến địa chỉ đích `target`, chia cho 4 để ra số lượng từ lệnh cần dịch chuyển.
:::

:::mcq id=KT-A3-05
? Mục đích thực chất và quan trọng nhất của việc thực hiện kiểm thử đột biến (mutation testing) trên toàn bộ hệ thống WatchChip là gì?
- [ ] Đo lường tốc độ tính toán tối đa của bộ xử lý khi các cổng logic phần cứng phải hoạt động trong điều kiện nhiệt độ cao
- [ ] Tự động phát hiện các đoạn mã nguồn dư thừa trong firmware để trình biên dịch tiến hành tối ưu hóa dung lượng BRAM
- [ ] Giúp mạch phần cứng có khả năng tự sửa chữa và khôi phục trạng thái hoạt động bình thường khi gặp sự cố bức xạ điện từ
- [x] Thẩm định năng lực phát hiện lỗi của bộ bài kiểm thử bằng cách cố tình cài lỗi xem các bài test có báo đỏ hay không
> Giải thích: Kiểm thử đột biến không phải là kỹ thuật tối ưu mã hay sửa lỗi phần cứng tự động, mà là phương pháp kiểm thử chính bộ kiểm thử (test the tests). Bằng cách cố tình gieo các sai sót nhỏ vào mã nguồn, nếu hệ thống bài test phát hiện và báo lỗi (bắt được đột biến), ta chứng minh được bộ test có độ bao phủ thực chất và nhạy bén. Ngược lại nếu gieo lỗi mà bài test vẫn báo xanh, bộ test đó có lỗ hổng.
:::
