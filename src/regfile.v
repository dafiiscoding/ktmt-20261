// regfile.v — 32 thanh ghi × 32 bit, 2 cổng đọc tổ hợp, 1 cổng ghi sườn lên, $0 = 0
// Gói C1 · chủ: TV3 · spec: pipeline-policy.md §2 (bypass nội bộ, G_BYPASS), isa-spec.md §1 (reset = 0)
// Code do Claude viết theo yêu cầu Long (01/10/2026); chủ gói đọc hiểu để vấn đáp.
// G_BYPASS = 1 (G2): đọc trùng thanh ghi đang ghi → trả luôn wd (ghi nửa đầu, đọc nửa sau).
// G_BYPASS = 0 (G1): bắt buộc, vì cổng ghi là của chính lệnh đang đọc → bypass sẽ tạo vòng tổ hợp.
// CPU tự AND `we` với clock enable của mình.
module regfile #(
    parameter G_BYPASS = 1
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        we,
    input  wire [4:0]  wa,
    input  wire [31:0] wd,
    input  wire [4:0]  ra1,
    input  wire [4:0]  ra2,
    output wire [31:0] rd1,
    output wire [31:0] rd2
);
    reg [31:0] r [0:31];   // r[0] không bao giờ được ghi
    integer i;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                r[i] <= 32'd0;
        end else if (we && wa != 5'd0) begin
            r[wa] <= wd;
        end
    end

    wire byp1 = (G_BYPASS != 0) && we && (wa == ra1);
    wire byp2 = (G_BYPASS != 0) && we && (wa == ra2);

    assign rd1 = (ra1 == 5'd0) ? 32'd0 : (byp1 ? wd : r[ra1]);
    assign rd2 = (ra2 == 5'd0) ? 32'd0 : (byp2 ? wd : r[ra2]);
endmodule
