// soc_regs.v — thanh ghi của soc + sinh cpu_ce: CYCLE_COUNT, CAL, CPU_CLK_DIV, DIV_FLAGS
// Gói C4 · chủ: TV3 · spec: mmio-map.md §1 (cpu_ce, luật ép D), §2 (bus), §4; timer-spec.md §2 (CAL)
// Code do Claude viết theo yêu cầu Long (02/10/2026); chủ gói đọc hiểu để vấn đáp.
//
// cpu_ce: G1 cần 2 cạnh cpu_ce cho 1 chu kỳ CPU (2 pha) → xung mỗi D/2 chu kỳ hệ thống;
//         G2 → xung mỗi D chu kỳ. D mới có hiệu lực từ chu kỳ CPU kế tiếp (mmio-map §4.3): khoảng đếm `p`
//         nạp lại ở mỗi cạnh cpu_ce. G1 ghi D ở cạnh pha B (cùng cạnh p nạp D cũ) → nửa sau của lệnh ghi
//         vẫn theo D cũ, D mới bắt đầu từ cạnh pha A = đầu chu kỳ CPU kế. Nếu so thẳng với `period` (tổ hợp)
//         thì nửa sau lệnh ghi đã theo D mới (soc_bus_tb bit 4 bắt lỗi này).
//
// ĐỌC NHANH: khối này giữ 4 thanh ghi "hệ thống" và tạo nhịp cho CPU:
//   - CYCLE_COUNT: đếm số chu kỳ clock từ lúc reset (dùng để đo thời gian chạy).
//   - CAL: số hiệu chỉnh thạch anh, đưa sang timebase.v (xem file đó).
//   - CPU_CLK_DIV (D): chia xung để CPU chạy chậm hơn clock hệ thống. Dùng cho thí nghiệm "CPU chậm thì đo giờ lệch bao nhiêu"
//     (E3 ở xung 32 kHz). D = 1 là CPU chạy hết tốc độ.
//   - DIV_FLAGS: cờ báo lệnh div gần nhất có chia cho 0 không.
//   - cpu_ce (clock enable): xung cho phép CPU bước 1 nhịp. CPU không có clock riêng, chỉ "được phép bước"
//     mỗi D chu kỳ, như người được phép đi 1 bước mỗi khi nghe còi.
module soc_regs #(
    parameter G_CORE  = 1,               // 1 = G1 (D ≥ 2, chẵn; reset 2), 2 = G2 (D ≥ 1; reset 1)
    parameter G_D_RST = 0                // D sau reset; 0 = mặc định lõi. Phải hợp lệ theo luật ép (G1: chẵn ≥ 2)
) (
    input  wire        clk,
    input  wire        rst,
    input  wire [7:0]  bus_addr,
    input  wire [31:0] bus_wdata,
    input  wire        bus_we,
    input  wire        bus_re,
    output reg  [31:0] bus_rdata,
    input  wire        div_dz,           // từ muldiv: lệnh div gần nhất chia 0
    output reg  [31:0] cycle_count,      // cho irq_ctrl (IRQ_STAMP)
    output reg  signed [31:0] cal,       // tới timebase chính
    output wire        cpu_ce
);
    localparam A_CYCLE = 8'h00,          // −256 R
               A_CAL   = 8'h18,          // −232 R/W
               A_DIV   = 8'h8C,          // −116 R/W  CPU_CLK_DIV
               A_FLAGS = 8'h90;          // −112 R    DIV_FLAGS

    reg  [15:0] d;                       // D đã chuẩn hóa
    reg  [15:0] c;                       // đếm chu kỳ tới xung cpu_ce kế
    reg  [15:0] p;                       // số chu kỳ hệ thống giữa 2 xung cpu_ce, đang dùng
    wire [15:0] period = (G_CORE == 1) ? {1'b0, d[15:1]} : d;    // G1: D/2 (D chẵn)
    // TIM-02: ở D = 2, nửa pha A → B của G1 chỉ có 20 ns (nextpnr ECP5: IMEM → ALU → giải mã MMIO 38,8 ns cấp 6, 29,7 ns cấp 8);
    // nạp FPGA dùng G_D_RST = 4 (mỗi nửa 40 ns) + khai báo đa chu kỳ. Mô phỏng giữ mặc định → test không đổi.
    localparam [15:0] D_RST = (G_D_RST != 0) ? G_D_RST : ((G_CORE == 1) ? 2 : 1);
    localparam [15:0] P_RST = (G_CORE == 1) ? D_RST / 16'd2 : D_RST;

    // luật ép (mmio-map §1): G1 nhỏ hơn 2 → 2, lẻ → bỏ bit 0; G2 0 → 1
    // (G1 cần D chẵn vì mỗi chu kỳ CPU dùng đúng 2 xung cpu_ce)
    function [15:0] norm(input [15:0] v);
        begin
            if (G_CORE == 1) norm = (v < 16'd2) ? 16'd2 : {v[15:1], 1'b0};
            else             norm = (v == 16'd0) ? 16'd1 : v;
        end
    endfunction

    assign cpu_ce = !rst && (c >= p - 16'd1);    // đếm đủ p chu kỳ thì phát 1 xung cho phép CPU bước

    always @(posedge clk) begin
        if (rst) begin
            cycle_count <= 32'd0;
            cal <= 32'sd0;
            d   <= D_RST;                        // mặc định G1 2, G2 1
            c   <= 16'd0;
            p   <= P_RST;                        // G1 D = 2 → 1; G2 D = 1 → 1
            bus_rdata <= 32'd0;
        end else begin
            cycle_count <= cycle_count + 32'd1;
            c <= cpu_ce ? 16'd0 : c + 16'd1;
            if (cpu_ce) p <= period;             // D mới chỉ có hiệu lực từ chu kỳ CPU kế (nạp p ở cạnh cpu_ce)
            if (bus_we) begin
                case (bus_addr)
                    A_CAL: cal <= bus_wdata;
                    A_DIV: d   <= norm(bus_wdata[15:0]);
                    default: ;                       // CYCLE_COUNT, DIV_FLAGS chỉ-đọc: ghi bị bỏ
                endcase
            end
            if (bus_re) begin                        // giữ tới lần đọc sau; địa chỉ khối khác → 0
                case (bus_addr)
                    A_CYCLE: bus_rdata <= cycle_count;
                    A_CAL:   bus_rdata <= cal;
                    A_DIV:   bus_rdata <= {16'd0, d};
                    A_FLAGS: bus_rdata <= {31'd0, div_dz};
                    default: bus_rdata <= 32'd0;
                endcase
            end
        end
    end

    wire unused_ok = &{1'b0, bus_wdata[31:16]};
endmodule
