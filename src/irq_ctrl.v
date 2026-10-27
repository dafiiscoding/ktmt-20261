// irq_ctrl.v — bộ điều khiển ngắt: IRQ_ENABLE, IRQ_PENDING (ghi 1 để xóa), IRQ_STAMP
// Gói C5 · chủ: TV3 · spec: mmio-map.md §5, §2 (bus); isa-spec.md §5 (Cause.IP)
// Code do Claude viết theo yêu cầu Long (02/10/2026); chủ gói đọc hiểu để vấn đáp.
//
// Nguồn (xung 1 chu kỳ): 0 TICK_1MS · 1 TICK_1S · 2 TMR_ZERO · 3 ALARM · 4 SW_CAPTURE · 5 BTN · 6 UART_RX · 7 UART_TX_EMPTY
//
// ĐỌC NHANH: ngắt giống chuông cửa. Có 8 nút chuông (8 nguồn sự kiện ở trên).
//   - pending: "ai đó đã bấm chuông" (mỗi nguồn 1 bit). Sự kiện đến thì bit bật và GIỮ cho tới khi CPU xóa,
//     nên dù CPU bận cũng không bỏ lỡ.
//   - enable : CPU chọn nút chuông nào được phép làm kêu (che các nguồn không quan tâm).
//   - irq    : = 1 nếu có bit nào vừa pending vừa enable. Đây là tín hiệu "báo CPU".
//   - stamp  : chụp CYCLE_COUNT đúng lúc irq lên 1, để đo ngắt trễ bao lâu (phục vụ thí nghiệm).
// CPU xóa pending bằng cách GHI 1 vào đúng bit (ghi 0 không làm gì).
module irq_ctrl (
    input  wire        clk,
    input  wire        rst,
    input  wire [7:0]  ev,               // 8 sự kiện, mỗi bit là xung 1 chu kỳ
    input  wire [31:0] cycle_count,      // bộ đếm chu kỳ toàn hệ thống (để chụp stamp)
    input  wire [7:0]  bus_addr,         // địa chỉ thanh ghi trên bus MMIO
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
    reg        irq_q;                    // irq của chu kỳ trước, để phát hiện "vừa mới lên 1"

    assign ip  = pending & enable;       // chỉ tính nguồn đã được phép
    assign irq = |ip;                    // có ít nhất 1 nguồn thì báo CPU

    // Các bit CPU muốn xóa: ghi 1 vào bit nào thì xóa bit đó
    wire [7:0] clr = (bus_we && bus_addr == A_PEND) ? bus_wdata[7:0] : 8'd0;

    always @(posedge clk) begin
        if (rst) begin
            enable <= 8'd0;  pending <= 8'd0;  stamp <= 32'd0;  irq_q <= 1'b0;
            bus_rdata <= 32'd0;
        end else begin
            // xóa các bit CPU yêu cầu, rồi bật các bit có sự kiện mới.
            // Nếu cùng chu kỳ vừa xóa vừa có sự kiện mới thì sự kiện thắng (không làm mất ngắt).
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

    wire unused_ok = &{1'b0, bus_wdata[31:8]};   // báo cho công cụ biết 24 bit cao của wdata cố ý không dùng
endmodule
