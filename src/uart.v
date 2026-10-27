// uart.v — UART 8N1: TX bộ đệm 1 byte + thanh ghi dịch, RX đồng bộ 2 FF + FIFO 64 byte
// Gói D4 · chủ: TV4 · spec: display-spec.md §6, mmio-map.md §2–§3, §5 (ngắt bit 6, 7)
// Code do Claude viết theo yêu cầu Long (26/10/2026); chủ gói đọc hiểu để vấn đáp.
//
// G_BIT = số chu kỳ clk mỗi bit (chạy thật 434 @ 50 MHz ≈ 115 200 baud; mô phỏng 8). Không tạo clock mới.
// TX: ghi UART_TX khi bộ đệm trống → bộ đệm; thanh ghi dịch rảnh thì lấy byte từ bộ đệm (xung tx_ev = bộ đệm vừa
//     trống). TX_READY = bộ đệm trống, nên CPU ghi được byte kế tiếp trong lúc byte trước còn đang phát.
//     Ghi khi bộ đệm đầy → bỏ byte, TX_DROP = 1.
// RX: cạnh xuống → chờ G_BIT/2 → còn 0 thì là start thật → lấy mẫu giữa mỗi bit → bit stop = 1 thì vào FIFO
//     (FIFO đầy → bỏ, RX_OVF = 1), stop = 0 thì bỏ, FRAME_ERR = 1. Xong bit stop là về nghỉ ngay (giữa bit stop).
// Cờ dính (RX_OVF, FRAME_ERR, TX_DROP): ghi 1 để xóa; sự kiện và lệnh xóa cùng chu kỳ → sự kiện thắng.
module uart #(
    parameter G_BIT = 434
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        rx,              // chân RX (không đồng bộ, nghỉ = 1)
    output reg         tx,              // chân TX (nghỉ = 1)
    input  wire [7:0]  bus_addr,
    input  wire [31:0] bus_wdata,
    input  wire        bus_we,
    input  wire        bus_re,
    output reg  [31:0] bus_rdata,
    output wire        rx_ev,           // nhận xong 1 byte vào FIFO (ngắt bit 6)
    output wire        tx_ev            // bộ đệm phát vừa trống (ngắt bit 7)
);
    localparam A_STATUS = 8'h50,        // −176
               A_RX     = 8'h54,        // −172
               A_TX     = 8'h58;        // −168
    localparam [15:0] BIT = G_BIT, HALF = G_BIT / 2;

    // ------------------------------------------------------------ TX
    reg [7:0]  tbuf;
    reg        tfull;                   // bộ đệm có byte chờ
    reg [8:0]  tsh;                     // {stop, data} còn phải phát, bit 0 ra trước
    reg [3:0]  tleft;                   // số bit còn lại của khung (0 = rảnh)
    reg [15:0] tcnt;
    wire w_tx   = bus_we && bus_addr == A_TX;
    // nạp ngay cạnh cuối bit stop → khung liền nhau không có chu kỳ nghỉ thừa (đúng 10 bit/byte)
    wire t_load = tfull && (tleft == 4'd0 || (tleft == 4'd1 && tcnt == BIT - 16'd1));
    assign tx_ev = t_load;

    // ------------------------------------------------------------ RX
    reg        r1, r2, r2q;             // đồng bộ 2 FF + mẫu trước để thấy cạnh xuống
    reg [1:0]  rst_st;                  // 0 nghỉ, 1 kiểm start, 2 nhận bit
    reg [15:0] rcnt;
    reg [3:0]  rbit;                    // bit đang chờ lấy mẫu: 0…7 dữ liệu, 8 stop
    reg [7:0]  rsh;
    reg [7:0]  fifo [0:63];
    reg [5:0]  rp, wp;
    reg [6:0]  n;                       // 0…64
    reg        ovf, ferr, drop;
    localparam R_IDLE = 2'd0, R_START = 2'd1, R_DATA = 2'd2;

    wire r_done = rst_st == R_DATA && rcnt == BIT - 16'd1 && rbit == 4'd8;
    wire r_good = r_done && r2;
    wire pop    = bus_re && bus_addr == A_RX && n != 7'd0;
    wire push   = r_good && (n != 7'd64 || pop);
    assign rx_ev = push;

    wire w_st = bus_we && bus_addr == A_STATUS;

    always @(posedge clk) begin
        if (rst) begin
            tx <= 1'b1;  tfull <= 1'b0;  tleft <= 4'd0;  tcnt <= 16'd0;  tsh <= 9'h1FF;  tbuf <= 8'd0;
            r1 <= 1'b1;  r2 <= 1'b1;  r2q <= 1'b1;  rst_st <= R_IDLE;  rcnt <= 16'd0;  rbit <= 4'd0;  rsh <= 8'd0;
            rp <= 6'd0;  wp <= 6'd0;  n <= 7'd0;  ovf <= 1'b0;  ferr <= 1'b0;  drop <= 1'b0;
            bus_rdata <= 32'd0;
        end else begin
            // ---- TX
            if (w_tx) begin
                if (!tfull) begin tbuf <= bus_wdata[7:0];  tfull <= 1'b1; end
            end
            if (t_load) begin                                   // start bit ra ngay chu kỳ sau
                tfull <= 1'b0;
                tx    <= 1'b0;
                tsh   <= {1'b1, tbuf};
                tleft <= 4'd10;
                tcnt  <= 16'd0;
            end else if (tleft != 4'd0) begin
                if (tcnt == BIT - 16'd1) begin
                    tcnt  <= 16'd0;
                    tleft <= tleft - 4'd1;
                    tx    <= (tleft == 4'd1) ? 1'b1 : tsh[0];   // hết khung → nghỉ
                    tsh   <= {1'b1, tsh[8:1]};
                end else begin
                    tcnt <= tcnt + 16'd1;
                end
            end
            // ---- RX
            r1 <= rx;  r2 <= r1;  r2q <= r2;
            case (rst_st)
                R_IDLE:  if (r2q && !r2) begin rst_st <= R_START;  rcnt <= 16'd0; end
                R_START: if (rcnt == HALF - 16'd1) begin
                             rst_st <= r2 ? R_IDLE : R_DATA;             // nhiễu ngắn → về nghỉ
                             rcnt <= 16'd0;  rbit <= 4'd0;
                         end else rcnt <= rcnt + 16'd1;
                default: if (rcnt == BIT - 16'd1) begin                  // R_DATA: giữa bit rbit
                             rcnt <= 16'd0;
                             if (rbit == 4'd8) rst_st <= R_IDLE;
                             else begin rsh <= {r2, rsh[7:1]};  rbit <= rbit + 4'd1; end
                         end else rcnt <= rcnt + 16'd1;
            endcase
            // ---- FIFO 64 byte
            if (push) begin fifo[wp] <= rsh;  wp <= wp + 6'd1; end
            if (pop) rp <= rp + 6'd1;
            n <= n + {6'd0, push} - {6'd0, pop};
            // ---- cờ dính: sự kiện thắng lệnh xóa
            ovf  <= (r_good && !push)  || (ovf  && !(w_st && bus_wdata[1]));
            ferr <= (r_done && !r2)    || (ferr && !(w_st && bus_wdata[3]));
            drop <= (w_tx && tfull)    || (drop && !(w_st && bus_wdata[4]));
            // ---- đọc (mỗi bus_re đều nạp; không phải địa chỉ của mình → 0)
            if (bus_re) begin
                case (bus_addr)
                    A_STATUS: bus_rdata <= {17'd0, n, 3'd0, drop, ferr, !tfull, ovf, n != 7'd0};
                    A_RX:     bus_rdata <= (n != 7'd0) ? {1'b1, 23'd0, fifo[rp]} : 32'd0;
                    default:  bus_rdata <= 32'd0;
                endcase
            end
        end
    end

    wire unused_ok = &{1'b0, bus_wdata[31:8], bus_wdata[2], bus_wdata[0]};
endmodule
