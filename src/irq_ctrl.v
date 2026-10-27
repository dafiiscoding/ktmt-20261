// irq_ctrl.v — bộ điều khiển ngắt: IRQ_ENABLE, IRQ_PENDING (ghi 1 để xóa), IRQ_STAMP
// Gói C5 · chủ: TV3 · spec: mmio-map.md §5, §2 (bus); isa-spec.md §5 (Cause.IP)
// Code do Claude viết theo yêu cầu Long (02/10/2026); chủ gói đọc hiểu để vấn đáp.
//
// Nguồn (xung 1 chu kỳ): 0 TICK_1MS · 1 TICK_1S · 2 TMR_ZERO · 3 ALARM · 4 SW_CAPTURE · 5 BTN · 6 UART_RX · 7 UART_TX_EMPTY
module irq_ctrl (
    input  wire        clk,
    input  wire        rst,
    input  wire [7:0]  ev,
    input  wire [31:0] cycle_count,
    input  wire [7:0]  bus_addr,
    input  wire [31:0] bus_wdata,
    input  wire        bus_we,
    input  wire        bus_re,
    output reg  [31:0] bus_rdata,
    output wire        irq,              // mức: OR(PENDING & ENABLE) → CPU
    output wire [7:0]  ip                // Cause.IP
);
    localparam A_EN = 8'h44, A_PEND = 8'h48, A_STAMP = 8'h4C;   // −188, −184, −180

    reg [7:0]  enable, pending;
    reg [31:0] stamp;
    reg        irq_q;

    assign ip  = pending & enable;
    assign irq = |ip;

    wire [7:0] clr = (bus_we && bus_addr == A_PEND) ? bus_wdata[7:0] : 8'd0;

    always @(posedge clk) begin
        if (rst) begin
            enable <= 8'd0;  pending <= 8'd0;  stamp <= 32'd0;  irq_q <= 1'b0;
            bus_rdata <= 32'd0;
        end else begin
            pending <= (pending & ~clr) | ev;              // sự kiện cùng chu kỳ lệnh xóa → sự kiện thắng
            if (bus_we && bus_addr == A_EN) enable <= bus_wdata[7:0];
            irq_q <= irq;
            if (irq && !irq_q) stamp <= cycle_count;       // CYCLE_COUNT của chu kỳ irq lên 1
            if (bus_re) begin
                case (bus_addr)
                    A_EN:    bus_rdata <= {24'd0, enable};
                    A_PEND:  bus_rdata <= {24'd0, pending};
                    A_STAMP: bus_rdata <= stamp;
                    default: bus_rdata <= 32'd0;
                endcase
            end
        end
    end

    wire unused_ok = &{1'b0, bus_wdata[31:8]};
endmodule
