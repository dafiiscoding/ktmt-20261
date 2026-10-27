// display_ctrl.v — Display RAM (8 ô) + BLINK_MASK + BRIGHT trên bus MMIO, nối seg7_scan
// Gói D2 · chủ: TV4 · spec: display-spec.md §2, mmio-map.md §2–§3
// Code do Claude viết theo yêu cầu Long (02/10/2026); chủ gói đọc hiểu để vấn đáp.
// Mọi thanh ghi chỉ-ghi → bus_rdata luôn 0 (mmio-map §2). Display RAM là flip-flop, đọc tổ hợp.
module display_ctrl #(
    parameter G_SLOT           = 50000,
    parameter G_BLANK          = 100,
    parameter G_AN_ACTIVE_LOW  = 0,
    parameter G_SEG_ACTIVE_LOW = 0
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        tick_ms,
    input  wire [7:0]  bus_addr,
    input  wire [31:0] bus_wdata,
    input  wire        bus_we,
    input  wire        bus_re,
    output wire [31:0] bus_rdata,
    output wire [7:0]  an,
    output wire [6:0]  seg,
    output wire        dp,
    output wire        vga_hs,          // VGA (D5, display-spec §7): cùng Display RAM, cùng pha nháy với LED
    output wire        vga_vs,
    output wire [11:0] vga_rgb
);
    localparam A_DISP0  = 8'h5C,   // −164; DISPi = 0x5C + 4i, i = 0..7 (DISP0 = phải nhất)
               A_DISP7  = 8'h78,   // −136
               A_BLINK  = 8'h7C,   // −132
               A_BRIGHT = 8'h80;   // −128

    reg [63:0] disp;
    reg [7:0]  blink_mask;
    reg [3:0]  bright;

    wire       is_disp = (bus_addr >= A_DISP0) && (bus_addr <= A_DISP7);
    wire [7:0] doff    = bus_addr - A_DISP0;      // 0, 4, …, 28
    wire [2:0] di      = doff[4:2];               // số ô 0..7
    // tổ hợp: mask mới và pha nháy về 0 cùng một cạnh → không lóe tắt 1 chu kỳ (D-5)
    wire       blink_restart = bus_we && (bus_addr == A_BLINK);

    always @(posedge clk) begin
        if (rst) begin
            disp          <= {8{8'h1A}};   // trống
            blink_mask    <= 8'd0;
            bright        <= 4'd15;
        end else begin
            if (bus_we) begin
                if (is_disp)
                    disp[8*di +: 8] <= bus_wdata[7:0];
                else if (bus_addr == A_BLINK)
                    blink_mask <= bus_wdata[7:0];   // kèm blink_restart: pha nháy về đầu (đang sáng)
                else if (bus_addr == A_BRIGHT)
                    bright <= bus_wdata[3:0];
            end
        end
    end

    assign bus_rdata = 32'd0;
    wire unused_ok = &{1'b0, bus_re, bus_wdata[31:8], doff[7:5], doff[1:0]};  // cổng giữ cho đồng bộ giao diện bus

    wire blink_ph;
    seg7_scan #(.G_DIGITS(8), .G_SLOT(G_SLOT), .G_BLANK(G_BLANK),
                .G_AN_ACTIVE_LOW(G_AN_ACTIVE_LOW), .G_SEG_ACTIVE_LOW(G_SEG_ACTIVE_LOW)) u_scan (
        .clk(clk), .rst(rst), .tick_ms(tick_ms), .disp(disp), .blink_mask(blink_mask),
        .blink_restart(blink_restart), .bright(bright), .an(an), .seg(seg), .dp(dp), .blink_ph(blink_ph));

    vga_digits u_vga (.clk(clk), .rst(rst), .disp(disp), .dim(blink_mask & {8{blink_ph}}),
                      .hsync(vga_hs), .vsync(vga_vs), .rgb(vga_rgb));
endmodule
