// beeper.v — bộ tạo âm: sóng vuông tần số BEEP_FREQ, bật/tắt theo mẫu 16 khe × 64 ms
// Gói D3 · chủ: TV4 · spec: display-spec.md §5, mmio-map.md §2–§3 (BEEP_FREQ −124, BEEP_PATTERN −120, chỉ ghi)
// Code do Claude viết theo yêu cầu Long (03/10/2026); chủ gói đọc hiểu để vấn đáp.
//
// Ghi BEEP_PATTERN (hoặc hw_trig) → phát lại từ khe 0. Khe đổi sau mỗi 64 tick_ms (khe 0 dài 63–64 ms tùy pha
// lúc ghi). REPEAT = 0: hết khe 15 thì mẫu ← 0.
// hw_trig (TMR_ZERO khi BEEP_EN) nạp 0x10F0F ngay chu kỳ đó; trùng chu kỳ với CPU ghi mẫu → hw_trig thắng
// (theo luật "sự kiện thắng" của mmio-map; mẫu báo hết giờ không bị mất).
// Ra chân: sóng vuông đảo mỗi FREQ chu kỳ khi bit khe hiện tại = 1 và FREQ ≠ 0; ngược lại 0.
module beeper (
    input  wire        clk,
    input  wire        rst,
    input  wire        tick_ms,
    input  wire        hw_trig,
    input  wire [7:0]  bus_addr,
    input  wire [31:0] bus_wdata,
    input  wire        bus_we,
    output wire        beep,
    output wire        sounding         // bit khe hiện tại = 1 (để tb/hiển thị quan sát)
);
    localparam A_FREQ = 8'h84,          // −124
               A_PAT  = 8'h88;          // −120
    localparam [16:0] P_ALARM = 17'h10F0F;

    reg [15:0] freq, wc;
    reg [16:0] pat;                     // [16] REPEAT
    reg [3:0]  slot;
    reg [5:0]  tc;                      // tick_ms trong khe: 0…63
    reg        sq;

    wire w_pat = bus_we && bus_addr == A_PAT;
    wire load  = hw_trig || w_pat;
    assign sounding = pat[{1'b0, slot}] && freq != 16'd0;
    assign beep     = sounding && sq;

    always @(posedge clk) begin
        if (rst) begin
            freq <= 16'd12500;  pat <= 17'd0;  slot <= 4'd0;  tc <= 6'd0;  wc <= 16'd0;  sq <= 1'b0;
        end else begin
            if (bus_we && bus_addr == A_FREQ) freq <= bus_wdata[15:0];
            // ---- mẫu + khe
            if (load) begin
                pat  <= hw_trig ? P_ALARM : bus_wdata[16:0];
                slot <= 4'd0;
                tc   <= 6'd0;
            end else if (tick_ms && pat[15:0] != 16'd0) begin
                tc <= tc + 6'd1;
                if (tc == 6'd63) begin
                    slot <= slot + 4'd1;
                    if (slot == 4'd15 && !pat[16]) pat <= 17'd0;
                end
            end
            // ---- sóng vuông: pha bắt đầu lại mỗi lần im → nạp
            if (load || !sounding) begin
                wc <= 16'd0;  sq <= 1'b0;
            end else if (wc == freq - 16'd1) begin
                wc <= 16'd0;  sq <= !sq;
            end else begin
                wc <= wc + 16'd1;
            end
        end
    end

    wire unused_ok = &{1'b0, bus_wdata[31:17]};
endmodule
