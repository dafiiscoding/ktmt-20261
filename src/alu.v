// alu.v — ALU 32 bit, tổ hợp
// Gói A1 · chủ: TV1 · spec: control-table.md §1.1 (mã ctl), isa-spec.md §3
// Code do Claude viết theo yêu cầu Long (01/10/2026); chủ gói đọc hiểu để vấn đáp.
//
// ĐỌC NHANH: ALU là "máy tính bỏ túi" của CPU. Nhận 2 số a, b và một mã lệnh ctl, trả kết quả y.
// "Tổ hợp" nghĩa là không có đồng hồ bên trong: đổi đầu vào thì đầu ra đổi ngay, không nhớ gì.
// ctl do control.v quyết định (cộng, trừ, and, or, xor, so sánh, dịch trái, dịch phải giữ dấu).
module alu (
    input  wire [31:0] a,        // số thứ nhất (thường là giá trị thanh ghi rs)
    input  wire [31:0] b,        // số thứ hai (thanh ghi rt, hoặc hằng số trong lệnh)
    input  wire [4:0]  shamt,    // số bit cần dịch (chỉ dùng cho lệnh dịch, 0..31)
    input  wire [3:0]  ctl,      // chọn phép tính, xem localparam bên dưới
    output reg  [31:0] y,        // kết quả
    output wire        zero      // = 1 khi y == 0 (lệnh beq/bne dùng để biết hai số bằng nhau)
);
    // Mã phép tính. Số phải khớp bảng trong control-table.md, đổi ở đây phải đổi ở đó.
    localparam ALU_ADD = 4'd0, ALU_SUB = 4'd1, ALU_AND = 4'd2, ALU_OR  = 4'd3,
               ALU_XOR = 4'd4, ALU_SLT = 4'd5, ALU_SLL = 4'd6, ALU_SRA = 4'd7;

    wire [31:0] diff = a - b;
    // slt = "set if less than": ra 1 nếu a < b (có dấu), ngược lại ra 0.
    // Không thể chỉ nhìn bit dấu của a - b, vì phép trừ có thể tràn.
    //   Ví dụ a = -2^31 (nhỏ nhất), b = 1: a - b tràn thành số dương, nhìn dấu sẽ tưởng a > b (sai).
    // Cách làm đúng: hai số khác dấu thì số âm nhỏ hơn, tức a < b khi a âm (a[31] = 1).
    //                hai số cùng dấu thì phép trừ không bao giờ tràn, nên bit dấu của hiệu đúng.
    wire        lt   = (a[31] != b[31]) ? a[31] : diff[31];

    always @* begin
        case (ctl)
            ALU_ADD: y = a + b;
            ALU_SUB: y = diff;
            ALU_AND: y = a & b;                         // and từng bit
            ALU_OR:  y = a | b;
            ALU_XOR: y = a ^ b;
            ALU_SLT: y = {31'd0, lt};                   // kết quả chỉ là 0 hoặc 1
            ALU_SLL: y = b << shamt;                    // dịch toán hạng B (rt)
            ALU_SRA: y = $unsigned($signed(b) >>> shamt); // chép bit dấu
            default: y = 32'd0;                         // mã lạ thì ra 0 cho an toàn
        endcase
    end

    assign zero = (y == 32'd0);
endmodule
