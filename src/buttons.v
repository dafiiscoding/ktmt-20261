// buttons.v — 4 nút (MODE 0, A 1, B 2, C 3): đồng bộ 2 FF + chống rung cạnh đầu có khóa + FIFO sự kiện
// Gói E4 · chủ: TV5 · spec: timer-spec.md §7, mmio-map.md §2–§3, §5 (ngắt bit 5)
// Code do Claude viết theo yêu cầu Long (03/10/2026); chủ gói đọc hiểu để vấn đáp.
//
// Mỗi nút: IDLE --nhấn--> (xung nhấn, chụp MS_OF_DAY) LOCK_P --10 tick ms--> HELD (còn nhấn) / IDLE (đã nhả)
//          HELD --nhả--> LOCK_R --10 tick ms--> IDLE. Thay đổi mức trong LOCK_P/LOCK_R bị bỏ qua (rung).
// Phản ứng ở cạnh đầu → 1 xung nhiễu đơn lẻ cũng thành 1 lần nhấn (BTN-4, hành vi đã biết).
// Hai nút nhấn cùng chu kỳ: mỗi nút giữ "chờ ghi" riêng, FIFO nhận lần lượt nút số nhỏ trước (trễ ≤ 3 chu kỳ).
module buttons #(
    parameter G_ACTIVE_LOW = 0
) (
    input  wire        clk,
    input  wire        rst,
    input  wire [3:0]  btn,             // chân nút (không đồng bộ)
    input  wire        tick_ms,
    input  wire [26:0] ms,              // MS_OF_DAY của RTC
    input  wire [7:0]  bus_addr,
    input  wire [31:0] bus_wdata,
    input  wire        bus_we,
    input  wire        bus_re,
    output reg  [31:0] bus_rdata,
    output wire [3:0]  press,           // xung nhấn 1 chu kỳ (A, B → stopwatch)
    output wire        ev               // sự kiện mới vào FIFO (ngắt bit 5)
);
    localparam A_EVT = 8'h40;           // −192 R (đọc thì lấy ra)
    localparam S_IDLE = 2'd0, S_LOCK_P = 2'd1, S_HELD = 2'd2, S_LOCK_R = 2'd3;

    reg [3:0]  s1, s2;                  // đồng bộ 2 FF
    reg [1:0]  st  [0:3];
    reg [3:0]  cnt [0:3];               // đếm tick ms trong LOCK_*
    reg [3:0]  pend;                    // đã nhấn, chờ ghi vào FIFO
    reg [26:0] ts  [0:3];               // MS_OF_DAY lúc cạnh đầu
    reg [28:0] fifo [0:3];              // {mã[1:0], ms[26:0]}
    reg [1:0]  rp, wp;
    reg [2:0]  n;                       // 0…4
    reg        lost;

    localparam [3:0] IDLE_LVL = G_ACTIVE_LOW ? 4'hF : 4'h0;
    wire [3:0] lvl = G_ACTIVE_LOW ? ~s2 : s2;              // 1 = đang nhấn

    genvar g;
    generate
        for (g = 0; g < 4; g = g + 1) begin : g_press
            assign press[g] = (st[g] == S_IDLE) && lvl[g];
        end
    endgenerate

    // nút chờ có số nhỏ nhất
    reg        has;
    reg [1:0]  code;
    always @* begin
        has = |pend;
        code = pend[0] ? 2'd0 : pend[1] ? 2'd1 : pend[2] ? 2'd2 : 2'd3;
    end

    wire pop    = bus_re && bus_addr == A_EVT && n != 3'd0;
    wire accept = has && (n != 3'd4 || pop);
    assign ev   = accept;

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            s1 <= IDLE_LVL;  s2 <= IDLE_LVL;  pend <= 4'd0;     // mức "nhả": không sinh lần nhấn ma sau reset
            for (i = 0; i < 4; i = i + 1) begin st[i] <= S_IDLE;  cnt[i] <= 4'd0;  ts[i] <= 27'd0; end
            rp <= 2'd0;  wp <= 2'd0;  n <= 3'd0;  lost <= 1'b0;
            bus_rdata <= 32'd0;
        end else begin
            s1 <= btn;
            s2 <= s1;
            // ---- máy trạng thái từng nút
            for (i = 0; i < 4; i = i + 1) begin
                case (st[i])
                    S_IDLE:   if (lvl[i]) begin st[i] <= S_LOCK_P;  cnt[i] <= 4'd0;  ts[i] <= ms; end
                    S_LOCK_P: if (tick_ms) begin
                                  if (cnt[i] == 4'd9) st[i] <= lvl[i] ? S_HELD : S_IDLE;
                                  cnt[i] <= cnt[i] + 4'd1;
                              end
                    S_HELD:   if (!lvl[i]) begin st[i] <= S_LOCK_R;  cnt[i] <= 4'd0; end
                    default:  if (tick_ms) begin                                     // S_LOCK_R
                                  if (cnt[i] == 4'd9) st[i] <= S_IDLE;
                                  cnt[i] <= cnt[i] + 4'd1;
                              end
                endcase
            end
            // ---- FIFO 4 sự kiện
            if (accept) begin
                fifo[wp] <= {code, ts[code]};
                wp <= wp + 2'd1;
            end
            pend <= (pend & ~(has ? (4'd1 << code) : 4'd0)) | press;
            if (pop) rp <= rp + 2'd1;
            n <= n + {2'd0, accept} - {2'd0, pop};
            // ---- đọc: LOST báo ở lần đọc kế tiếp rồi xóa (mất cùng chu kỳ đọc → giữ lại cho lần sau)
            if (has && !accept)          lost <= 1'b1;
            else if (bus_re && bus_addr == A_EVT) lost <= 1'b0;
            if (bus_re) begin
                if (bus_addr == A_EVT)
                    bus_rdata <= (n != 3'd0) ? {1'b1, fifo[rp][28:27], lost, 1'b0, fifo[rp][26:0]}
                                             : {3'd0, lost, 28'd0};
                else
                    bus_rdata <= 32'd0;
            end
        end
    end

    wire unused_ok = &{1'b0, bus_wdata, bus_we};          // chỉ-đọc
endmodule
