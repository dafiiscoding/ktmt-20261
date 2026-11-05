// soc_top.v — ghép CPU G1 + bus MMIO + các khối đã có: soc_regs, irq_ctrl, timebase, rtc, stopwatch, cdtimer,
// alarm, buttons, display_ctrl (LED + VGA), beeper, uart, rtc_bcd (tùy chọn)
// Gói C6 · chủ: TV3 · spec: mmio-map.md §1–§5
// Code do Claude viết theo yêu cầu Long (02/10, E3/E4 03/10, UART + rtc_bcd + VGA 26/10/2026); chủ gói đọc hiểu để vấn đáp.
//
// VGA không có thanh ghi (đọc Display RAM của display_ctrl). beeper chỉ ghi → không góp vào bus_rdata.
// Bộ giải mã bus: mọi khối nhận chung bus_addr/bus_we/bus_re (CPU đã lọc vùng 0xFFFF_FFxx) và tự trả 0 khi
// địa chỉ không phải của mình (mmio-map §2) → bus_rdata = OR các khối.
//
// ĐỌC NHANH: file này là "bảng mạch chủ": không tự tính gì, chỉ nối dây giữa CPU và mọi ngoại vi.
// Cách CPU nói chuyện với ngoại vi: CPU đọc/ghi một địa chỉ đặc biệt (vùng cuối 4 GB, địa chỉ "âm") bằng lệnh lw/sw
// như đọc/ghi bộ nhớ. Địa chỉ đó đi lên "bus" chung nối mọi khối. Mỗi khối tự xem địa chỉ có phải của mình không:
// phải thì xử lý, không phải thì trả về 0. Nhờ vậy đọc về chỉ cần OR tất cả kết quả lại (dòng bus_rdata ở dưới).
// Các khối nối với nhau:
//   timebase (nhịp 1 ms) → rtc (giờ), buttons, beeper, display; stopwatch/cdtimer có bộ chia riêng.
//   Sự kiện (hết giờ, báo thức, nhấn nút, nhận UART...) đi vào irq_ctrl, thành tín hiệu ngắt gửi CPU.
// Chọn CPU: biên dịch bình thường là G1 (cpu_g1); thêm -DG2 thì dùng pipeline (cpu_pipe). Hai CPU cùng cổng, cùng tên.
module soc_top #(
    parameter IMEM_FILE  = "",
    parameter DMEM_FILE  = "",
    parameter G_IMEM_AW  = 11,         // 2048 lệnh: main.s + sync vượt 1024 (26/10, isa-spec §7)
    parameter G_BCD_COMB = 0,
    parameter G_N        = 50000,       // chu kỳ / ms (mô phỏng: 50)
    parameter G_SLOT     = 50000,       // chu kỳ / khe quét LED
    parameter G_BLANK    = 100,
    parameter G_BTN_ACTIVE_LOW = 0,
    parameter G_BIT      = 434,         // chu kỳ / bit UART (mô phỏng: 8)
    parameter G_BCD_RTC  = 0,           // 1 = có RTC_BCD (E7, DSE: đo fmt_hw); 0 = đọc 0, không tốn ô
    parameter G_CPU_DIV_RST = 0,        // CPU_CLK_DIV sau reset; 0 = mặc định lõi (G1 2, G2 1). Nạp FPGA G1 @50 MHz: 4 (TIM-02)
    parameter TRACE_FILE = ""
) (
    input  wire       clk,
    input  wire       rst_in,           // chân reset (mức cao) → đồng bộ 2 FF
    input  wire [3:0] btn,              // MODE, A, B, C (không đồng bộ)
    output wire [7:0] an,
    output wire [6:0] seg,
    output wire       dp,
    output wire       beep,             // buzzer thụ động
    input  wire       uart_rx,          // nghỉ = 1 (không đồng bộ; uart tự đồng bộ 2 FF)
    output wire       uart_tx,
    output wire       vga_hs,           // 640×480@60, sync tích cực thấp (display-spec §7)
    output wire       vga_vs,
    output wire [11:0] vga_rgb          // R[11:8] G[7:4] B[3:0]
);
    // ------------------------------------------------------------ reset đồng bộ (mmio-map §1)
    // giá trị bật nguồn 2'b11 = power-on reset ≥ 2 chu kỳ kể cả khi chân rst_in không được kích (FPGA nạp INIT
    // của FF; thiếu nó thì p = 0 → cpu_ce 1 xung / 65 536 chu kỳ, BEEP_FREQ = 0, UART TX kẹt 0 — audit RST-03)
    reg [1:0] rst_sync = 2'b11;         // chân reset giữ ≥ 4 chu kỳ (mmio-map §1) → rst lên 1 sau 2 cạnh
    always @(posedge clk) rst_sync <= {rst_sync[0], rst_in};
    wire rst = rst_sync[1];

    // ------------------------------------------------------------ bus
    wire [7:0]  bus_addr;               // địa chỉ thanh ghi (byte thấp của địa chỉ MMIO)
    wire [31:0] bus_wdata;
    wire        bus_we, bus_re;
    wire [31:0] rd_soc, rd_irq, rd_rtc, rd_sw, rd_tmr, rd_al, rd_btn, rd_disp, rd_uart, rd_bcd;   // dữ liệu đọc của từng khối
    wire [31:0] bus_rdata = rd_soc | rd_irq | rd_rtc | rd_sw | rd_tmr | rd_al | rd_btn | rd_disp | rd_uart | rd_bcd;

    wire        cpu_ce, irq, div_dz, retire;
    wire [7:0]  irq_ip;
    wire [31:0] cycle_count, pc;
    wire signed [31:0] cal;
    wire        tick_ms, tick_1s, loading;
    wire [26:0] ms;
    wire [15:0] day;
    wire [2:0]  dow;
    wire        tmr_zero, tmr_beep, alarm_ev, sw_capture, btn_ev, sounding, uart_rx_ev, uart_tx_ev;
    wire [3:0]  press;

    // Chọn lõi bằng macro khi biên dịch: mặc định G1; `-DG2` → cpu_pipe (C7). Cùng tên instance u_cpu và cùng cổng
    // nên các tb đọc dut.u_cpu.* dùng được cho cả hai lõi.
`ifdef G2
    localparam G_CORE = 2;
    cpu_pipe #(.IMEM_FILE(IMEM_FILE), .DMEM_FILE(DMEM_FILE), .G_IMEM_AW(G_IMEM_AW), .G_BCD_COMB(G_BCD_COMB),
               .TRACE_FILE(TRACE_FILE)) u_cpu (
`else
    localparam G_CORE = 1;
    cpu_g1 #(.IMEM_FILE(IMEM_FILE), .DMEM_FILE(DMEM_FILE), .G_IMEM_AW(G_IMEM_AW), .G_BCD_COMB(G_BCD_COMB),
             .TRACE_FILE(TRACE_FILE)) u_cpu (
`endif
        .clk(clk), .rst(rst), .cpu_ce(cpu_ce), .bus_addr(bus_addr), .bus_wdata(bus_wdata),
        .bus_we(bus_we), .bus_re(bus_re), .bus_rdata(bus_rdata), .irq(irq), .irq_ip(irq_ip),
        .div_dz(div_dz), .pc_out(pc), .retire(retire));

    // thanh ghi hệ thống + tạo nhịp cho CPU
    soc_regs #(.G_CORE(G_CORE), .G_D_RST(G_CPU_DIV_RST)) u_regs (
        .clk(clk), .rst(rst), .bus_addr(bus_addr), .bus_wdata(bus_wdata), .bus_we(bus_we), .bus_re(bus_re),
        .bus_rdata(rd_soc), .div_dz(div_dz), .cycle_count(cycle_count), .cal(cal), .cpu_ce(cpu_ce));

    // nguồn ngắt (mmio-map §5): 0 TICK_1MS, 1 TICK_1S, 2 TMR_ZERO, 3 ALARM, 4 SW_CAPTURE, 5 BTN, 6 UART_RX, 7 UART_TX_EMPTY
    irq_ctrl u_irq (
        .clk(clk), .rst(rst), .ev({uart_tx_ev, uart_rx_ev, btn_ev, sw_capture, alarm_ev, tmr_zero, tick_1s, tick_ms}), .cycle_count(cycle_count),
        .bus_addr(bus_addr), .bus_wdata(bus_wdata), .bus_we(bus_we), .bus_re(bus_re), .bus_rdata(rd_irq),
        .irq(irq), .ip(irq_ip));

    // nhịp 1 ms chung của cả hệ thống (có hiệu chỉnh cal)
    timebase #(.G_N(G_N)) u_tb (.clk(clk), .rst(rst), .clr(1'b0), .en(1'b1), .cal(cal), .tick(tick_ms));

    // giờ trong ngày
    rtc u_rtc (
        .clk(clk), .rst(rst), .tick_ms(tick_ms), .bus_addr(bus_addr), .bus_wdata(bus_wdata),
        .bus_we(bus_we), .bus_re(bus_re), .bus_rdata(rd_rtc),
        .ms(ms), .day(day), .dow(dow), .tick_1s(tick_1s), .loading(loading));

    // bấm giờ: nhận xung nhấn nút A, B thẳng từ buttons (không qua CPU) nên chụp giờ chính xác tới chu kỳ
    stopwatch #(.G_N(G_N)) u_sw (
        .clk(clk), .rst(rst), .cal(cal), .press_a(press[1]), .press_b(press[2]), .bus_addr(bus_addr),
        .bus_wdata(bus_wdata), .bus_we(bus_we), .bus_re(bus_re), .bus_rdata(rd_sw), .capture(sw_capture));

    // hẹn giờ đếm ngược; hết giờ có thể tự kích còi (tmr_beep)
    cdtimer #(.G_N(G_N)) u_tmr (
        .clk(clk), .rst(rst), .cal(cal), .bus_addr(bus_addr), .bus_wdata(bus_wdata), .bus_we(bus_we),
        .bus_re(bus_re), .bus_rdata(rd_tmr), .zero_ev(tmr_zero), .beep(tmr_beep));

    // 4 báo thức, so với giờ của rtc; lúc đang nạp giờ (loading) thì không xét để tránh kêu oan
    alarm u_al (
        .clk(clk), .rst(rst), .inc(tick_ms && !loading), .ms(ms), .dow(dow), .bus_addr(bus_addr),
        .bus_wdata(bus_wdata), .bus_we(bus_we), .bus_re(bus_re), .bus_rdata(rd_al), .ev(alarm_ev));

    buttons #(.G_ACTIVE_LOW(G_BTN_ACTIVE_LOW)) u_btn (
        .clk(clk), .rst(rst), .btn(btn), .tick_ms(tick_ms), .ms(ms), .bus_addr(bus_addr),
        .bus_wdata(bus_wdata), .bus_we(bus_we), .bus_re(bus_re), .bus_rdata(rd_btn), .press(press), .ev(btn_ev));

    beeper u_beep (
        .clk(clk), .rst(rst), .tick_ms(tick_ms), .hw_trig(tmr_beep), .bus_addr(bus_addr), .bus_wdata(bus_wdata),
        .bus_we(bus_we), .beep(beep), .sounding(sounding));

    display_ctrl #(.G_SLOT(G_SLOT), .G_BLANK(G_BLANK)) u_disp (
        .clk(clk), .rst(rst), .tick_ms(tick_ms), .bus_addr(bus_addr), .bus_wdata(bus_wdata),
        .bus_we(bus_we), .bus_re(bus_re), .bus_rdata(rd_disp), .an(an), .seg(seg), .dp(dp),
        .vga_hs(vga_hs), .vga_vs(vga_vs), .vga_rgb(vga_rgb));

    uart #(.G_BIT(G_BIT)) u_uart (
        .clk(clk), .rst(rst), .rx(uart_rx), .tx(uart_tx), .bus_addr(bus_addr), .bus_wdata(bus_wdata),
        .bus_we(bus_we), .bus_re(bus_re), .bus_rdata(rd_uart), .rx_ev(uart_rx_ev), .tx_ev(uart_tx_ev));

    // RTC_BCD là khối tùy chọn (chỉ bật khi đo thí nghiệm so sánh); tắt thì đọc ra 0 và không tốn mạch
    generate
        if (G_BCD_RTC) begin : g_bcd
            rtc_bcd u_bcd (
                .clk(clk), .rst(rst), .tick_ms(tick_ms), .bus_addr(bus_addr), .bus_wdata(bus_wdata),
                .bus_we(bus_we), .bus_re(bus_re), .bus_rdata(rd_bcd));
        end else begin : g_nobcd
            assign rd_bcd = 32'd0;
        end
    endgenerate

    wire unused_ok = &{1'b0, retire, pc, day, sounding, press[3], press[0]};   // để tb quan sát
endmodule
