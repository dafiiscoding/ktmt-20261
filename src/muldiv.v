// muldiv.v — mul (tổ hợp) + div có dấu kiểu restoring 32 bước, giữ HI/LO
// Gói A2 · chủ: TV1 · spec: isa-spec.md §3 (#10, #24), §4; control-table.md §5; pipeline-policy.md §6
// Code do Claude viết theo yêu cầu Long (01/10/2026); chủ gói đọc hiểu để vấn đáp.
//
// Thời gian (đếm theo chu kỳ có ce = 1, tức chu kỳ CPU):
//   chu kỳ 1      : start = 1 → chốt toán hạng (đổi a, b sau đó không ảnh hưởng)
//   chu kỳ 2..33  : 32 bước chia, busy = 1; chu kỳ 33 có done = 1, HI/LO ghi ở cạnh cuối chu kỳ đó
//   chia cho 0    : done = 1 ngay ở chu kỳ 1 (LO = 0, HI = a, DZ = 1), không chạy 32 bước
// done là tổ hợp: CPU giữ lệnh khi (multi != 0 && !done), lệnh rời EX ở chu kỳ done.
module muldiv (
    input  wire        clk,
    input  wire        rst,
    input  wire        ce,      // bước 1 lần mỗi chu kỳ CPU (G1: cạnh pha A; G2: cpu_ce)
    input  wire        start,   // xung 1 chu kỳ CPU, chỉ có tác dụng khi ce = 1 và không bận
    input  wire [31:0] a,       // rs
    input  wire [31:0] b,       // rt
    output wire [31:0] mul_y,   // 32 bit thấp của a × b (có dấu hay không dấu đều như nhau)
    output wire        busy,
    output wire        done,
    output reg  [31:0] lo,
    output reg  [31:0] hi,
    output reg         dz       // lệnh div gần nhất chia cho 0
);
    assign mul_y = a * b;

    reg        run;
    reg [4:0]  cnt;
    reg [31:0] rem;    // phần dư đang tính (luôn < dvs)
    reg [31:0] quo;    // dịch dần số bị chia ra, dịch bit thương vào
    reg [31:0] dvs;    // |b|
    reg        neg_q;  // thương âm khi a, b khác dấu
    reg        neg_r;  // dư cùng dấu số bị chia

    wire [32:0] rem_sh = {rem, quo[31]};
    wire [32:0] trial  = rem_sh - {1'b0, dvs};
    wire        fits   = ~trial[32];
    wire [31:0] rem_n  = fits ? trial[31:0] : rem_sh[31:0];
    wire [31:0] quo_n  = {quo[30:0], fits};

    wire div0  = (b == 32'd0);
    wire last  = run && (cnt == 5'd31);

    assign busy = run;
    assign done = ce && ((start && !run && div0) || last);

    always @(posedge clk) begin
        if (rst) begin
            run <= 1'b0;  cnt <= 5'd0;
            rem <= 32'd0; quo <= 32'd0; dvs <= 32'd0;
            neg_q <= 1'b0; neg_r <= 1'b0;
            lo <= 32'd0;  hi <= 32'd0;  dz <= 1'b0;
        end else if (ce) begin
            if (start && !run) begin
                if (div0) begin
                    lo <= 32'd0;  hi <= a;  dz <= 1'b1;
                end else begin
                    run   <= 1'b1;
                    cnt   <= 5'd0;
                    rem   <= 32'd0;
                    quo   <= a[31] ? -a : a;   // |0x80000000| = 2^31 vẫn đúng khi hiểu không dấu
                    dvs   <= b[31] ? -b : b;
                    neg_q <= a[31] ^ b[31];
                    neg_r <= a[31];
                end
            end else if (run) begin
                rem <= rem_n;
                quo <= quo_n;
                cnt <= cnt + 5'd1;
                if (last) begin
                    run <= 1'b0;
                    lo  <= neg_q ? -quo_n : quo_n;
                    hi  <= neg_r ? -rem_n : rem_n;
                    dz  <= 1'b0;
                end
            end
        end
    end
endmodule
