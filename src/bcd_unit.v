// bcd_unit.v — lệnh bcd rd,rs: 0..99 999 999 → 8 chữ số BCD (hàng đơn vị ở [3:0]); lớn hơn → FFFFFFFF
// Gói A3 · chủ: TV1 · spec: isa-spec.md §3 #25, control-table.md (multi = 10), pipeline-policy.md §6
// Code do Claude viết theo yêu cầu Long (02/10/2026); chủ gói đọc hiểu để vấn đáp.
//
// Thuật toán: double dabble (dịch trái + cộng 3 vào chữ số ≥ 5), 27 bước vì 99 999 999 < 2^27.
// G_COMB = 0 (tuần tự, đếm theo chu kỳ có ce = 1):
//   chu kỳ 1      : start = 1 → chốt x
//   chu kỳ 2..28  : 27 bước, busy = 1; chu kỳ 28 có done = 1 và y = kết quả (tổ hợp) → CPU ghi rd ở cạnh đó
//   x > 99 999 999: done = 1 ngay ở chu kỳ 1, y = FFFFFFFF
// G_COMB = 1: 27 tầng tổ hợp; y có ngay, busy = 0 (control ra multi = 00 nên CPU không chờ).
//
// ĐỌC NHANH: đổi số nhị phân (máy hiểu) thành các chữ số thập phân (người đọc) để hiện lên LED.
// Ví dụ 1234 nhị phân → 0x00001234 (mỗi 4 bit là 1 chữ số thập phân, gọi là BCD).
// Cách làm "dịch-cộng-3" (double dabble): lấy từng bit của số nhị phân, từ bit cao xuống thấp, đẩy vào vùng BCD.
// Trước mỗi lần dịch (tức nhân đôi), chữ số BCD nào đang ≥ 5 thì cộng 3. Lý do: nhân đôi số ≥ 5 cho kết quả ≥ 10,
// mà 4 bit BCD chỉ đếm tới 9, cộng 3 trước để phần dư "nhảy" sang chữ số bên cạnh đúng như đếm thập phân.
// Có 2 bản chọn bằng G_COMB: tuần tự (mỗi chu kỳ 1 bước, 28 chu kỳ, ít mạch) hoặc tổ hợp (ra ngay, tốn thêm ~416 LUT).
module bcd_unit #(
    parameter G_COMB = 0       // 0 = tuần tự (tiết kiệm mạch), 1 = tổ hợp (nhanh)
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        ce,
    input  wire        start,
    input  wire [31:0] x,      // số nhị phân cần đổi
    output wire        busy,
    output wire        done,
    output wire [31:0] y       // 8 chữ số BCD
);
    localparam [31:0] MAXV = 32'd99999999;       // lớn nhất hiện được trên 8 chữ số

    // cộng 3 vào mọi chữ số ≥ 5 (trước khi dịch)
    function [31:0] add3(input [31:0] v);
        integer k;
        begin
            for (k = 0; k < 8; k = k + 1)
                add3[4*k +: 4] = (v[4*k +: 4] >= 4'd5) ? v[4*k +: 4] + 4'd3 : v[4*k +: 4];
        end
    endfunction

    // bản tổ hợp: lặp 27 bước liên tiếp trong 1 hàm, tổng hợp ra mạch nối tiếp 27 tầng
    function [31:0] to_bcd(input [26:0] b);
        integer k;
        reg [31:0] d;
        begin
            d = 32'd0;
            for (k = 26; k >= 0; k = k - 1) d = {add3(d)} << 1 | {31'd0, b[k]};
            to_bcd = d;
        end
    endfunction

    wire ovf = (x > MAXV);    // quá lớn thì trả FFFFFFFF thay vì hiện sai

    generate if (G_COMB != 0) begin : g_comb
        assign busy = 1'b0;                 // tổ hợp: không bao giờ làm CPU đứng chờ
        assign done = ce && start;
        assign y    = ovf ? 32'hFFFFFFFF : to_bcd(x[26:0]);
        wire unused_ok = &{1'b0, clk, rst};
    end else begin : g_seq
        reg        run;
        reg [4:0]  cnt;      // 0..26
        reg [31:0] d;        // chữ số BCD đang tích lũy
        reg [26:0] b;        // bit nhị phân còn lại, dịch ra từ bit 26

        wire [31:0] d_n  = {add3(d)} << 1 | {31'd0, b[26]};   // 1 bước: cộng 3, dịch trái, kéo bit cao nhất của b vào
        wire        last = run && (cnt == 5'd26);             // bước thứ 27 (cuối)

        assign busy = run;
        assign done = ce && ((start && !run && ovf) || last);
        assign y    = run ? d_n : 32'hFFFFFFFF;               // ở bước cuối, d_n chính là kết quả

        always @(posedge clk) begin
            if (rst) begin
                run <= 1'b0;  cnt <= 5'd0;  d <= 32'd0;  b <= 27'd0;
            end else if (ce) begin
                if (start && !run) begin
                    // bắt đầu: chốt số cần đổi (quá lớn thì không chạy, done báo ngay với y = FFFFFFFF)
                    if (!ovf) begin
                        run <= 1'b1;  cnt <= 5'd0;  d <= 32'd0;  b <= x[26:0];
                    end
                end else if (run) begin
                    d   <= d_n;
                    b   <= {b[25:0], 1'b0};
                    cnt <= cnt + 5'd1;
                    if (last) run <= 1'b0;
                end
            end
        end
    end endgenerate
endmodule
