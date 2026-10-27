// beeper.v — bộ tạo âm: sóng vuông tần số BEEP_FREQ, bật/tắt theo mẫu 16 khe × 64 ms
// Gói D3 · chủ: TV4 · spec: display-spec.md §5, mmio-map.md §2–§3 (BEEP_FREQ −124, BEEP_PATTERN −120, chỉ ghi)
// Code do Claude viết theo yêu cầu Long (03/10/2026); chủ gói đọc hiểu để vấn đáp.
//
// Ghi BEEP_PATTERN (hoặc hw_trig) → phát lại từ khe 0. Khe đổi sau mỗi 64 tick_ms (khe 0 dài 63–64 ms tùy pha
// lúc ghi). REPEAT = 0: hết khe 15 thì mẫu ← 0.
// hw_trig (TMR_ZERO khi BEEP_EN) nạp 0x10F0F ngay chu kỳ đó; trùng chu kỳ với CPU ghi mẫu → hw_trig thắng
// (theo luật "sự kiện thắng" của mmio-map; mẫu báo hết giờ không bị mất).
// Ra chân: sóng vuông đảo mỗi FREQ chu kỳ khi bit khe hiện tại = 1 và FREQ ≠ 0; ngược lại 0.
//
// ĐỌC NHANH: còi kêu theo "nhịp trống" gồm 16 ô, mỗi ô dài 64 ms.
//   - pat (mẫu) là 16 bit: bit nào = 1 thì ô đó CÓ kêu, = 0 thì im. Ví dụ 0x0F0F = kêu 4 ô, nghỉ 4 ô, lặp lại.
//   - Bit 16 của pat là REPEAT: = 1 thì chạy hết 16 ô lại quay về ô đầu, = 0 thì kêu một lượt rồi tắt.
//   - freq quyết định cao độ: sóng vuông đảo mức mỗi freq chu kỳ clock (freq càng nhỏ tiếng càng cao).
//   - Hết giờ của timer thì phần cứng tự phát mẫu 0x10F0F (hw_trig), không cần CPU can thiệp.
module beeper (
    input  wire        clk,
    input  wire        rst,
    input  wire        tick_ms,         // xung mỗi 1 ms (để đếm độ dài mỗi ô)
    input  wire        hw_trig,         // phần cứng tự kích còi (hết giờ timer)
    input  wire [7:0]  bus_addr,
    input  wire [31:0] bus_wdata,
    input  wire        bus_we,
    output wire        beep,            // chân ra loa
    output wire        sounding         // bit khe hiện tại = 1 (để tb/hiển thị quan sát)
);
    localparam A_FREQ = 8'h84,          // −124
               A_PAT  = 8'h88;          // −120
    localparam [16:0] P_ALARM = 17'h10F0F;   // mẫu báo hết giờ: kêu-kêu-nghỉ-nghỉ lặp lại (bit 16 = REPEAT)

    reg [15:0] freq, wc;                // freq: nửa chu kỳ sóng; wc: bộ đếm tới freq
    reg [16:0] pat;                     // [16] REPEAT
    reg [3:0]  slot;                    // đang ở ô thứ mấy (0..15)
    reg [5:0]  tc;                      // tick_ms trong khe: 0…63
    reg        sq;                      // mức hiện tại của sóng vuông

    wire w_pat = bus_we && bus_addr == A_PAT;       // CPU vừa ghi mẫu mới
    wire load  = hw_trig || w_pat;                  // có lệnh nạp mẫu (từ phần cứng hoặc từ CPU)
    assign sounding = pat[{1'b0, slot}] && freq != 16'd0;   // ô hiện tại đang cần kêu
    assign beep     = sounding && sq;                       // kêu thật = cần kêu AND sóng đang ở mức cao

    always @(posedge clk) begin
        if (rst) begin
            freq <= 16'd12500;  pat <= 17'd0;  slot <= 4'd0;  tc <= 6'd0;  wc <= 16'd0;  sq <= 1'b0;
        end else begin
            if (bus_we && bus_addr == A_FREQ) freq <= bus_wdata[15:0];
            // ---- mẫu + khe
            if (load) begin
                // nạp mẫu mới: hw_trig thắng CPU nếu cùng chu kỳ; luôn phát lại từ ô 0
                pat  <= hw_trig ? P_ALARM : bus_wdata[16:0];
                slot <= 4'd0;
                tc   <= 6'd0;
            end else if (tick_ms && pat[15:0] != 16'd0) begin
                // mỗi 64 ms thì sang ô kế; hết ô 15 mà không REPEAT thì xóa mẫu (im hẳn)
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
                wc <= 16'd0;  sq <= !sq;      // đủ freq chu kỳ thì đảo mức sóng
            end else begin
                wc <= wc + 16'd1;
            end
        end
    end

    wire unused_ok = &{1'b0, bus_wdata[31:17]};
endmodule
