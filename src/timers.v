// timers.v — các bộ đếm thời gian MMIO: rtc (E2), stopwatch + cdtimer (E3), alarm (E4).
// Gói E2–E4 · chủ: TV5 · spec: timer-spec.md §3–§6, mmio-map.md §2 (bus), §3 (địa chỉ)
// Code do Claude viết theo yêu cầu Long (rtc 02/10, stopwatch/cdtimer/alarm 03/10/2026); chủ gói đọc hiểu để vấn đáp.
//
// Giao diện bus chung của mọi khối MMIO (mmio-map.md §2):
//   bus_addr = byte thấp địa chỉ (0x00–0xFC); bus_we / bus_re bật đúng 1 chu kỳ mỗi lệnh sw / lw
//   và đã được giải mã "thuộc vùng MMIO"; bus_rdata có thanh ghi (chốt cùng cạnh với bus_re),
//   ra 0 nếu địa chỉ không thuộc khối này → bộ giải mã có thể OR các khối lại.

/* verilator lint_off DECLFILENAME */   // 1 file chứa nhiều khối timer (goi-viec E2–E4)

// ---------------------------------------------------------------- RTC
// ms 0..86 399 999 trong ngày, day 16 bit (ngày từ 01/01/2000), dow 0 = CN … 6 = T7.
module rtc #(
    parameter G_MS_PER_DAY = 86400000
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        tick_ms,
    input  wire [7:0]  bus_addr,
    input  wire [31:0] bus_wdata,
    input  wire        bus_we,
    input  wire        bus_re,
    output reg  [31:0] bus_rdata,
    output reg  [26:0] ms,
    output reg  [15:0] day,
    output reg  [2:0]  dow,
    output wire        tick_1s,    // xung 1 chu kỳ ở tick_ms thứ 1000 (đếm lại từ lần nạp RTC)
    output wire        loading     // tick này đang nạp SET_* → khối báo thức không xét (timer-spec §3 bước 1)
);
    localparam A_MS_OF_DAY  = 8'h04,   // −252 R  (đọc thì chụp {dow, day})
               A_DAY_SHADOW = 8'h08,   // −248 R
               A_SET_MS     = 8'h0C,   // −244 W
               A_SET_DAY    = 8'h10,   // −240 W
               A_RTC_CTRL   = 8'h14;   // −236 R/W, [0] ARM

    reg [26:0] set_ms;
    reg [15:0] set_day;
    reg [2:0]  set_dow;
    reg        arm;
    reg [18:0] shadow;                  // {dow, day} chụp khi đọc MS_OF_DAY
    reg [9:0]  c1s;                     // 0..999

    wire unused_ok = &{1'b0, bus_wdata[31:27]};
    assign loading = tick_ms && arm;
    assign tick_1s = tick_ms && !arm && (c1s == 10'd999);

    always @(posedge clk) begin
        if (rst) begin
            ms <= 27'd0;  day <= 16'd0;  dow <= 3'd6;
            set_ms <= 27'd0;  set_day <= 16'd0;  set_dow <= 3'd0;
            arm <= 1'b0;  shadow <= 19'd0;  c1s <= 10'd0;
            bus_rdata <= 32'd0;
        end else begin
            // ---- đếm thời gian
            if (tick_ms) begin
                if (arm) begin
                    ms  <= set_ms;
                    day <= set_day;
                    dow <= set_dow;
                    c1s <= 10'd0;
                end else begin
                    c1s <= (c1s == 10'd999) ? 10'd0 : c1s + 10'd1;
                    if (ms == G_MS_PER_DAY - 1) begin
                        ms  <= 27'd0;
                        day <= day + 16'd1;                         // quay vòng 16 bit
                        dow <= (dow == 3'd6) ? 3'd0 : dow + 3'd1;
                    end else begin
                        ms <= ms + 27'd1;
                    end
                end
            end

            // ---- ghi (ARM ghi cùng chu kỳ với tick: tick dùng ARM cũ, nạp ở tick sau)
            if (bus_we) begin
                case (bus_addr)
                    A_SET_MS:  set_ms <= (bus_wdata[26:0] >= G_MS_PER_DAY) ? 27'd0 : bus_wdata[26:0];
                    A_SET_DAY: begin
                        set_day <= bus_wdata[15:0];
                        set_dow <= (bus_wdata[18:16] == 3'd7) ? 3'd0 : bus_wdata[18:16];
                    end
                    A_RTC_CTRL: arm <= bus_wdata[0];                // ghi 0 = hủy lệnh nạp đang chờ
                    default: ;
                endcase
            end else if (tick_ms && arm) begin
                arm <= 1'b0;
            end

            // ---- đọc: giá trị trước cạnh này, nên cặp (ms, shadow) luôn cùng phía của tick
            if (bus_re) begin
                case (bus_addr)
                    A_MS_OF_DAY: begin
                        bus_rdata <= {5'd0, ms};
                        shadow    <= {dow, day};
                    end
                    A_DAY_SHADOW: bus_rdata <= {13'd0, shadow};
                    A_RTC_CTRL:   bus_rdata <= {31'd0, arm};
                    default:      bus_rdata <= 32'd0;
                endcase
            end
        end
    end
endmodule

// ---------------------------------------------------------------- Stopwatch (E3, timer-spec §4)
// Giá trị +1 ở mỗi tick của bộ chia riêng (en = RUN, clr khi RESET) → chạy tổng C chu kỳ thì = floor(C / G_N)
// (CAL = 0), không lệch pha khi start/stop. SRC = 1: xung nhấn A đảo RUN ngay chu kỳ đó, B (khi chạy) chụp lap.
module stopwatch #(
    parameter G_N      = 50000,
    parameter G_SW_MAX = 359999999      // 99:59:59.999
) (
    input  wire        clk,
    input  wire        rst,
    input  wire signed [31:0] cal,
    input  wire        press_a,         // xung nhấn từ buttons (cạnh đầu sau đồng bộ)
    input  wire        press_b,
    input  wire [7:0]  bus_addr,
    input  wire [31:0] bus_wdata,
    input  wire        bus_we,
    input  wire        bus_re,
    output reg  [31:0] bus_rdata,
    output wire        capture          // sự kiện SW_CAPTURE (ngắt bit 4): chụp bằng nút
);
    localparam A_CTRL = 8'h1C,          // −228 R/W
               A_VAL  = 8'h20,          // −224 R
               A_LAP  = 8'h24;          // −220 R (đọc thì lấy khỏi FIFO)

    reg [28:0] val;
    reg        run, src, ovf, lap_ovf;
    reg [28:0] fifo [0:7];
    reg [2:0]  rp, wp;
    reg [3:0]  cnt;                     // 0…8

    wire wr_ctrl = bus_we && bus_addr == A_CTRL;
    wire w_reset = wr_ctrl && bus_wdata[1];
    wire w_cpu   = wr_ctrl && !bus_wdata[2];               // ghi với SRC = 0: CPU điều khiển RUN, LAP
    wire tick;
    timebase #(.G_N(G_N)) u_div (.clk(clk), .rst(rst), .clr(w_reset), .en(run), .cal(cal), .tick(tick));

    // va chạm cùng chu kỳ (timer-spec §4): CPU ghi SRC = 0 thắng nút A/B (bỏ, không SW_CAPTURE; BTN_EVENT vẫn có);
    // RESET thắng lap bằng B (bỏ, không SW_CAPTURE); ghi SRC = 1 không chặn nút A
    wire hw_toggle = src && press_a && !w_cpu;
    wire hw_lap    = src && press_b && run && !w_cpu && !w_reset;
    wire push      = hw_lap || (w_cpu && !w_reset && bus_wdata[5]);
    wire pop       = bus_re && bus_addr == A_LAP && cnt != 4'd0;
    wire accept    = push && (cnt != 4'd8 || pop);
    assign capture = hw_toggle || hw_lap;

    always @(posedge clk) begin
        if (rst) begin
            val <= 29'd0;  run <= 1'b0;  src <= 1'b0;  ovf <= 1'b0;  lap_ovf <= 1'b0;
            rp <= 3'd0;  wp <= 3'd0;  cnt <= 4'd0;
            bus_rdata <= 32'd0;
        end else begin
            // ---- đếm
            if (w_reset) begin
                val <= 29'd0;  ovf <= 1'b0;
            end else if (tick) begin
                if (val == G_SW_MAX) ovf <= 1'b1;          // bão hòa: đứng yên
                else                 val <= val + 29'd1;
            end
            // ---- RUN / SRC
            if (wr_ctrl)        src <= bus_wdata[2];
            if (w_cpu)          run <= bus_wdata[0];
            else if (hw_toggle) run <= !run;           // hw_toggle đã loại w_cpu; giữ else cho dễ đọc
            // ---- FIFO lap 8 phần tử
            if (w_reset) begin
                rp <= 3'd0;  wp <= 3'd0;  cnt <= 4'd0;  lap_ovf <= 1'b0;
            end else begin
                if (accept) begin
                    fifo[wp] <= val;
                    wp <= wp + 3'd1;
                end else if (push) begin
                    lap_ovf <= 1'b1;                       // đầy → lap mới bị bỏ
                end
                if (pop) rp <= rp + 3'd1;
                cnt <= cnt + {3'd0, accept} - {3'd0, pop};
            end
            // ---- đọc
            if (bus_re) begin
                case (bus_addr)
                    A_CTRL:  bus_rdata <= {20'd0, cnt, 3'd0, lap_ovf, ovf, src, 1'b0, run};
                    A_VAL:   bus_rdata <= {3'd0, val};
                    A_LAP:   bus_rdata <= (cnt != 4'd0) ? {1'b1, 2'd0, fifo[rp]} : 32'd0;
                    default: bus_rdata <= 32'd0;
                endcase
            end
        end
    end

    wire unused_ok = &{1'b0, bus_wdata[31:6], bus_wdata[4:3]};
endmodule

// ---------------------------------------------------------------- Timer đếm ngược sang âm (E3, timer-spec §5)
// Mỗi tick của bộ chia riêng (en = RUN, clr khi ghi TMR_VALUE): 1 → 0 + sự kiện ZERO; −2³¹ → đứng yên + SAT;
// còn lại − 1 (qua 0 sang âm, không dừng).
module cdtimer #(
    parameter G_N = 50000
) (
    input  wire        clk,
    input  wire        rst,
    input  wire signed [31:0] cal,
    input  wire [7:0]  bus_addr,
    input  wire [31:0] bus_wdata,
    input  wire        bus_we,
    input  wire        bus_re,
    output reg  [31:0] bus_rdata,
    output wire        zero_ev,         // sự kiện TMR_ZERO (ngắt bit 2)
    output wire        beep             // = zero_ev khi BEEP_EN → beeper nạp mẫu 0x10F0F (display-spec §5)
);
    localparam A_VAL = 8'h28,           // −216 R/W
               A_CTL = 8'h2C;           // −212 R/W
    localparam [31:0] MIN = 32'h8000_0000;

    reg [31:0] val;
    reg        run, zero, beep_en, sat;

    wire w_val = bus_we && bus_addr == A_VAL;
    wire w_ctl = bus_we && bus_addr == A_CTL;
    wire tick;
    timebase #(.G_N(G_N)) u_div (.clk(clk), .rst(rst), .clr(w_val), .en(run), .cal(cal), .tick(tick));

    assign zero_ev = tick && !w_val && (val == 32'd1);
    assign beep    = zero_ev && beep_en;

    always @(posedge clk) begin
        if (rst) begin
            val <= 32'd0;  run <= 1'b0;  zero <= 1'b0;  beep_en <= 1'b0;  sat <= 1'b0;
            bus_rdata <= 32'd0;
        end else begin
            if (w_val) begin                               // ghi thắng tick cùng chu kỳ
                val <= bus_wdata;
                sat <= 1'b0;
            end else if (tick) begin
                if (val == MIN) sat <= 1'b1;
                else            val <= val - 32'd1;
            end
            if (w_ctl) begin
                run     <= bus_wdata[0];
                beep_en <= bus_wdata[2];
            end
            if (zero_ev)                    zero <= 1'b1;  // sự kiện thắng lệnh xóa cùng chu kỳ
            else if (w_ctl && bus_wdata[1]) zero <= 1'b0;
            if (bus_re) begin
                case (bus_addr)
                    A_VAL:   bus_rdata <= val;
                    A_CTL:   bus_rdata <= {28'd0, sat, beep_en, zero, run};
                    default: bus_rdata <= 32'd0;
                endcase
            end
        end
    end

    wire unused_ok = &{1'b0, bus_wdata[31:3]};
endmodule

// ---------------------------------------------------------------- Báo thức ×4 (E4, timer-spec §6)
// So ở tick làm RTC tăng (inc = tick_ms && !loading), dùng giá trị MỚI của ms/dow → so ở chu kỳ ngay sau.
// Nạp RTC (loading) không bao giờ làm kêu.
module alarm (
    input  wire        clk,
    input  wire        rst,
    input  wire        inc,             // tick_ms && !loading: RTC vừa tăng ở cạnh này
    input  wire [26:0] ms,
    input  wire [2:0]  dow,
    input  wire [7:0]  bus_addr,
    input  wire [31:0] bus_wdata,
    input  wire        bus_we,
    input  wire        bus_re,
    output reg  [31:0] bus_rdata,
    output reg         ev               // sự kiện ALARM (ngắt bit 3)
);
    // ALARMi = 0x30 + 4i (−208 … −196)
    reg        en     [0:3];
    reg [6:0]  mask   [0:3];
    reg        hit    [0:3];
    reg [10:0] minute [0:3];
    reg [26:0] target [0:3];            // MINUTE × 60 000, tính sẵn khi ghi (≥ 1440 → không bao giờ bằng ms)
    reg        chk;                     // chu kỳ sau inc: ms/dow đã là giá trị mới

    wire       is_al = (bus_addr[7:4] == 4'h3);           // 0x30…0x3C
    wire [1:0] sel   = bus_addr[3:2];
    // MINUTE × 60 000 bằng bộ cộng (60 000 = 0xEA60 = 2^15 + 2^14 + 2^13 + 2^11 + 2^9 + 2^6 + 2^5), dùng chung 4 báo thức
    wire [26:0] m27 = {16'd0, bus_wdata[10:0]};
    wire [26:0] w_target = (m27 << 15) + (m27 << 14) + (m27 << 13) + (m27 << 11) + (m27 << 9) + (m27 << 6) + (m27 << 5);

    wire [3:0] new_hit;
    genvar g;
    generate
        for (g = 0; g < 4; g = g + 1) begin : g_cmp
            assign new_hit[g] = chk && en[g] && (ms == target[g]) && mask[g][dow];
        end
    endgenerate

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 4; i = i + 1) begin
                en[i] <= 1'b0;  mask[i] <= 7'd0;  hit[i] <= 1'b0;  minute[i] <= 11'd0;  target[i] <= 27'd0;
            end
            chk <= 1'b0;  ev <= 1'b0;
            bus_rdata <= 32'd0;
        end else begin
            chk <= inc;
            ev  <= |new_hit;
            for (i = 0; i < 4; i = i + 1) begin
                if (bus_we && is_al && sel == i[1:0]) begin
                    en[i]     <= bus_wdata[31];
                    mask[i]   <= bus_wdata[30:24];
                    minute[i] <= bus_wdata[10:0];
                    target[i] <= w_target;
                end
                if (new_hit[i])                                         hit[i] <= 1'b1;   // sự kiện thắng
                else if (bus_we && is_al && sel == i[1:0] && bus_wdata[23])  hit[i] <= 1'b0;   // ghi 0 giữ nguyên
            end
            if (bus_re) begin
                if (is_al) bus_rdata <= {en[sel], mask[sel], hit[sel], 12'd0, minute[sel]};
                else       bus_rdata <= 32'd0;
            end
        end
    end

    wire unused_ok = &{1'b0, bus_wdata[22:11], bus_addr[1:0]};
endmodule
