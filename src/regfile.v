// regfile.v — 32 thanh ghi × 32 bit, 2 cổng đọc tổ hợp, 1 cổng ghi sườn lên, $0 = 0
// Gói C1 · chủ: TV3 · spec: pipeline-policy.md §2 (bypass nội bộ, G_BYPASS), isa-spec.md §1 (reset = 0)
// Code do Claude viết theo yêu cầu Long (01/10/2026); chủ gói đọc hiểu để vấn đáp.
// G_BYPASS = 1 (G2): đọc trùng thanh ghi đang ghi → trả luôn wd (ghi nửa đầu, đọc nửa sau).
// G_BYPASS = 0 (G1): bắt buộc, vì cổng ghi là của chính lệnh đang đọc → bypass sẽ tạo vòng tổ hợp.
// CPU tự AND `we` với clock enable của mình.
//
// ĐỌC NHANH: giống 32 ngăn kéo đánh số 0..31, mỗi ngăn chứa 1 số 32 bit.
//   - Đọc: đưa số ngăn (ra1, ra2), lấy giá trị ra ngay (đọc được 2 ngăn cùng lúc).
//   - Ghi: chỉ xảy ra ở cạnh lên của clock, khi we = 1.
//   - Ngăn số 0 luôn bằng 0 và không ghi được (đây là quy ước của MIPS, thanh ghi $zero).
module regfile #(
    parameter G_BYPASS = 1
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        we,      // 1 = cho phép ghi
    input  wire [4:0]  wa,      // số ngăn cần ghi
    input  wire [31:0] wd,      // giá trị cần ghi
    input  wire [4:0]  ra1,     // số ngăn cần đọc (cổng 1)
    input  wire [4:0]  ra2,     // số ngăn cần đọc (cổng 2)
    output wire [31:0] rd1,
    output wire [31:0] rd2
);
    reg [31:0] r [0:31];   // r[0] không bao giờ được ghi
    integer i;

    always @(posedge clk) begin
        if (rst) begin
            // reset: xóa sạch 32 ngăn về 0
            for (i = 0; i < 32; i = i + 1)
                r[i] <= 32'd0;
        end else if (we && wa != 5'd0) begin
            r[wa] <= wd;       // wa = 0 bị bỏ qua nên $zero không đổi
        end
    end

    // Bypass: lệnh trước đang ghi đúng ngăn mà lệnh sau muốn đọc (cùng chu kỳ).
    // Ghi chỉ có hiệu lực ở cạnh clock kế tiếp, nên nếu không bypass thì lệnh sau đọc phải giá trị CŨ.
    // Bypass đưa thẳng wd ra, như "chuyền tay" giá trị mới thay vì chờ nó vào ngăn kéo.
    wire byp1 = (G_BYPASS != 0) && we && (wa == ra1);
    wire byp2 = (G_BYPASS != 0) && we && (wa == ra2);

    // Đọc ngăn 0 luôn ra 0; ngoài ra ưu tiên giá trị bypass, không có thì đọc từ ngăn.
    assign rd1 = (ra1 == 5'd0) ? 32'd0 : (byp1 ? wd : r[ra1]);
    assign rd2 = (ra2 == 5'd0) ? 32'd0 : (byp2 ? wd : r[ra2]);
endmodule
