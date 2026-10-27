// hazard.v — đơn vị phát hiện hazard + forwarding cho CPU G2 (pipeline 5 tầng)
// Gói B5 · chủ: TV2 · spec: pipeline-policy.md §3 (forwarding), §4 (load-use), §5 (flush), §0 (ưu tiên)
// Code do Claude viết theo yêu cầu Long (20/10/2026, ngoại lệ luật tự viết); chủ gói đọc hiểu để vấn đáp.
//
// Mọi tổ hợp, không có trạng thái. cpu_pipe áp dụng theo thứ tự ưu tiên: busy > flush > load-use > bình thường.
//   stall_lu : lệnh ở IF/ID (tầng ID) đọc thanh ghi mà lệnh load ở ID/EX (tầng EX) đang ghi → giữ 1 chu kỳ
//   flush    : nhánh/nhảy đang quyết định ở EX và nhảy thật → xóa IF/ID và ID/EX (phạt 2)
//   fwd_a/b  : 00 giá trị đọc ở ID, 10 kết quả EX/MEM, 01 giá trị đang ghi ở MEM/WB
module hazard (
    input  wire       ifid_valid,
    input  wire [4:0] ifid_rs,
    input  wire [4:0] ifid_rt,
    input  wire       ifid_uses_rs,   // control-table.md: lệnh thật sự đọc rs/rt
    input  wire       ifid_uses_rt,
    input  wire       idex_mem_read,  // lệnh ở EX là load
    input  wire [4:0] idex_dst,       // thanh ghi đích đã chọn ở ID (0 = không ghi)
    input  wire [4:0] idex_rs,
    input  wire [4:0] idex_rt,
    input  wire       exmem_reg_write,
    input  wire [4:0] exmem_dst,
    input  wire       memwb_reg_write,
    input  wire [4:0] memwb_dst,
    input  wire       taken,          // nhánh/nhảy ở EX quyết định nhảy (đã loại trừ busy ở cpu_pipe)
    output wire       stall_lu,
    output wire       flush,
    output reg  [1:0] fwd_a,
    output reg  [1:0] fwd_b
);
    assign stall_lu = idex_mem_read && (idex_dst != 5'd0) && ifid_valid &&
                      ((ifid_uses_rs && (idex_dst == ifid_rs)) || (ifid_uses_rt && (idex_dst == ifid_rt)));
    assign flush = taken;

    always @* begin
        if (exmem_reg_write && (exmem_dst != 5'd0) && (exmem_dst == idex_rs))  fwd_a = 2'b10;
        else if (memwb_reg_write && (memwb_dst != 5'd0) && (memwb_dst == idex_rs)) fwd_a = 2'b01;
        else fwd_a = 2'b00;

        if (exmem_reg_write && (exmem_dst != 5'd0) && (exmem_dst == idex_rt))  fwd_b = 2'b10;
        else if (memwb_reg_write && (memwb_dst != 5'd0) && (memwb_dst == idex_rt)) fwd_b = 2'b01;
        else fwd_b = 2'b00;
    end
endmodule
