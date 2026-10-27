// alu.v — ALU 32 bit, tổ hợp
// Gói A1 · chủ: TV1 · spec: control-table.md §1.1 (mã ctl), isa-spec.md §3
// Code do Claude viết theo yêu cầu Long (01/10/2026); chủ gói đọc hiểu để vấn đáp.
module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [4:0]  shamt,
    input  wire [3:0]  ctl,
    output reg  [31:0] y,
    output wire        zero
);
    localparam ALU_ADD = 4'd0, ALU_SUB = 4'd1, ALU_AND = 4'd2, ALU_OR  = 4'd3,
               ALU_XOR = 4'd4, ALU_SLT = 4'd5, ALU_SLL = 4'd6, ALU_SRA = 4'd7;

    wire [31:0] diff = a - b;
    // slt có dấu, đúng cả khi a - b tràn: khác dấu thì a < b đúng khi a âm
    wire        lt   = (a[31] != b[31]) ? a[31] : diff[31];

    always @* begin
        case (ctl)
            ALU_ADD: y = a + b;
            ALU_SUB: y = diff;
            ALU_AND: y = a & b;
            ALU_OR:  y = a | b;
            ALU_XOR: y = a ^ b;
            ALU_SLT: y = {31'd0, lt};
            ALU_SLL: y = b << shamt;                    // dịch toán hạng B (rt)
            ALU_SRA: y = $unsigned($signed(b) >>> shamt); // chép bit dấu
            default: y = 32'd0;
        endcase
    end

    assign zero = (y == 32'd0);
endmodule
