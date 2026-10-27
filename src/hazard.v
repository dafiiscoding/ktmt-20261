// hazard.v — đơn vị phát hiện hazard + forwarding cho CPU G2 (pipeline 5 tầng)
// Gói B5 · chủ: TV2 · spec: pipeline-policy.md §3 (forwarding), §4 (load-use), §5 (flush), §0 (ưu tiên)
// Code do Claude viết theo yêu cầu Long (20/10/2026, ngoại lệ luật tự viết); chủ gói đọc hiểu để vấn đáp.
//
// Mọi tổ hợp, không có trạng thái. cpu_pipe áp dụng theo thứ tự ưu tiên: busy > flush > load-use > bình thường.
//   stall_lu : lệnh ở IF/ID (tầng ID) đọc thanh ghi mà lệnh load ở ID/EX (tầng EX) đang ghi → giữ 1 chu kỳ
//   flush    : nhánh/nhảy đang quyết định ở EX và nhảy thật → xóa IF/ID và ID/EX (phạt 2)
//   fwd_a/b  : 00 giá trị đọc ở ID, 10 kết quả EX/MEM, 01 giá trị đang ghi ở MEM/WB
//
// ĐỌC NHANH: pipeline giống dây chuyền 5 trạm; nhiều lệnh nằm trên dây chuyền cùng lúc nên có thể
// lệnh sau cần kết quả của lệnh trước khi nó chưa kịp "ghi sổ" (hazard = xung đột dữ liệu).
// Khối này giải quyết bằng 2 cách:
//   1. Forwarding (lấy tắt): kết quả vừa tính xong ở trạm sau được đưa thẳng ngược về, khỏi chờ ghi vào thanh ghi.
//   2. Stall (chờ 1 nhịp): riêng lệnh lw chỉ có dữ liệu ở cuối trạm MEM, lấy tắt không kịp, đành đứng chờ 1 chu kỳ.
// Ngoài ra khi nhánh nhảy thật thì 2 lệnh đã nạp nhầm phải bị xóa (flush).
module hazard (
    input  wire       ifid_valid,     // lệnh ở tầng ID có hợp lệ không (không phải bong bóng)
    input  wire [4:0] ifid_rs,        // 2 thanh ghi nguồn của lệnh đang ở tầng ID
    input  wire [4:0] ifid_rt,
    input  wire       ifid_uses_rs,   // control-table.md: lệnh thật sự đọc rs/rt
    input  wire       ifid_uses_rt,
    input  wire       idex_mem_read,  // lệnh ở EX là load
    input  wire [4:0] idex_dst,       // thanh ghi đích đã chọn ở ID (0 = không ghi)
    input  wire [4:0] idex_rs,        // 2 thanh ghi nguồn của lệnh đang ở tầng EX (nơi cần lấy tắt)
    input  wire [4:0] idex_rt,
    input  wire       exmem_reg_write, // lệnh ở tầng MEM có ghi thanh ghi không
    input  wire [4:0] exmem_dst,
    input  wire       memwb_reg_write, // lệnh ở tầng WB có ghi thanh ghi không
    input  wire [4:0] memwb_dst,
    input  wire       taken,          // nhánh/nhảy ở EX quyết định nhảy (đã loại trừ busy ở cpu_pipe)
    output wire       stall_lu,       // 1 = giữ lệnh ở ID 1 chu kỳ (load-use)
    output wire       flush,          // 1 = xóa 2 lệnh đã nạp nhầm
    output reg  [1:0] fwd_a,          // chọn nguồn cho toán hạng A của ALU
    output reg  [1:0] fwd_b           // chọn nguồn cho toán hạng B
);
    // Load-use: lệnh ở EX là lw (ghi vào idex_dst) và lệnh ở ID cần đúng thanh ghi đó.
    // idex_dst != 0 vì ghi vào $zero là vô nghĩa. Chỉ xét rs/rt mà lệnh THẬT SỰ đọc (uses_rs/rt),
    // để không chờ oan (ví dụ addiu không đọc rt).
    assign stall_lu = idex_mem_read && (idex_dst != 5'd0) && ifid_valid &&
                      ((ifid_uses_rs && (idex_dst == ifid_rs)) || (ifid_uses_rt && (idex_dst == ifid_rt)));
    assign flush = taken;

    always @* begin
        // Toán hạng A. Ưu tiên kết quả ở EX/MEM (10) vì nó MỚI hơn kết quả ở MEM/WB (01).
        // exmem_dst != 0 vì $zero luôn bằng 0, không được lấy tắt.
        if (exmem_reg_write && (exmem_dst != 5'd0) && (exmem_dst == idex_rs))  fwd_a = 2'b10;
        else if (memwb_reg_write && (memwb_dst != 5'd0) && (memwb_dst == idex_rs)) fwd_a = 2'b01;
        else fwd_a = 2'b00;      // không trùng: dùng giá trị đã đọc ở tầng ID

        // Toán hạng B: logic y hệt, chỉ khác là so với rt.
        if (exmem_reg_write && (exmem_dst != 5'd0) && (exmem_dst == idex_rt))  fwd_b = 2'b10;
        else if (memwb_reg_write && (memwb_dst != 5'd0) && (memwb_dst == idex_rt)) fwd_b = 2'b01;
        else fwd_b = 2'b00;
    end
endmodule
