"""Assert cho phép tính tay và khẳng định kiểm được của bài P5 (CP0, ngắt, cpu_ce)."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
nguon = (Path(__file__).resolve().parents[1] / "nguon" / "02-code.md").read_text(encoding="utf-8")
p5 = nguon.split("## P5 ·")[1].split("\n## ")[0]


def dong(rel):
    return (ROOT / rel).read_text(encoding="utf-8").splitlines()


iq, sr, g1, pp = dong("src/irq_ctrl.v"), dong("src/soc_regs.v"), dong("src/cpu_g1.v"), dong("src/cpu_pipe.v")


# --- norm: luật ép D (đúng từng dòng soc_regs.v 46-51)
def norm(v, g):
    if g == 1:
        return 2 if v < 2 else (v & 0xFFFE)
    return 1 if v == 0 else v


assert [norm(d, 1) for d in (4, 5, 1, 1526, 7, 0)] == [4, 4, 2, 1526, 6, 2]
assert norm(0, 2) == 1 and norm(3, 2) == 3


# --- mô phỏng bộ sinh cpu_ce: c đếm, xung khi c >= p-1, p nạp lại ở xung
def xung(period, n):
    c, p, ra = 0, 1, []
    for t in range(n):
        ce = c >= p - 1
        ra.append(ce)
        c = 0 if ce else c + 1
        if ce:
            p = period
    return ra


ra = xung(2, 20)                     # G1, D = 4 → period 2
vt = [t for t, v in enumerate(ra) if v]
assert vt[1:] == list(range(vt[1], 20, 2)) and all(b - a == 2 for a, b in zip(vt[1:], vt[2:]))
ra = xung(3, 30)                     # G1, D = 6 → period 3
vt = [t for t, v in enumerate(ra) if v]
assert all(b - a == 3 for a, b in zip(vt[1:], vt[2:]))
assert all(xung(1, 10))              # D = 2 (G1) hoặc D = 1 (G2): xung mỗi chu kỳ
ra = xung(763, 5000)
vt = [t for t, v in enumerate(ra) if v]
assert all(b - a == 763 for a, b in zip(vt[1:], vt[2:])) and 2 * 763 == 1526
assert round(50_000_000 / 1526) == 32765 and abs(50_000_000 / 1526 - 32768) < 5
assert 6 * 20 == 120                                            # D = 6 ở 50 MHz = 120 ns

# --- pending: (pending & ~clr) | ev
def pend(p, clr, ev):
    return ((p & ~clr) | ev) & 0xFF


assert pend(0x08, 0x08, 0x08) == 0x08 and pend(0x08, 0x08, 0) == 0
assert (((0x08 | 0x08) & ~0x08) & 0xFF) == 0                    # bản đảo thứ tự nuốt sự kiện
assert pend(0x0C, 0x08, 0) == 0x04                              # IRQ-4: ghi 0x08 vào 0x0C còn 0x04

# --- Cause
assert (0x08 << 8) == 0x800

# --- EPC của G2: lệnh cũ nhất chưa retire
def irq_epc(idex_v, idex_pc, ifid_v, ifid_pc, pc):
    return idex_pc if idex_v else ifid_pc if ifid_v else pc


assert irq_epc(1, 0x84, 1, 0x88, 0x8C) == 0x84 and irq_epc(0, 0, 1, 0x88, 0x8C) == 0x88 and irq_epc(0, 0, 0, 0, 0x8C) == 0x8C

# --- địa chỉ MMIO
assert (256 - 188, 256 - 184, 256 - 180) == (0x44, 0x48, 0x4C) and (256 - 256, 256 - 232, 256 - 116, 256 - 112) == (0, 0x18, 0x8C, 0x90)

# --- khớp dòng code được nhắc
assert "module irq_ctrl (" in iq[13] and "input  wire [7:0]  ev" in iq[16]
assert "A_EN = 8'h44, A_PEND = 8'h48, A_STAMP = 8'h4C" in iq[26]
assert "assign ip  = pending & enable" in iq[32] and "assign irq = |ip" in iq[33]
assert "// Các bit CPU muốn xóa" in iq[35] and "wire [7:0] clr = (bus_we && bus_addr == A_PEND) ? bus_wdata[7:0] : 8'd0" in iq[36]
assert "always @(posedge clk) begin" in iq[38]
assert "pending <= (pending & ~clr) | ev" in iq[45] and "enable <= bus_wdata[7:0]" in iq[46]
assert "irq_q <= irq" in iq[47] and "if (irq && !irq_q) stamp <= cycle_count" in iq[48]
assert "bus_rdata <= {24'd0, enable}" in iq[51] and "default: bus_rdata <= 32'd0" in iq[54]
assert "localparam A_CYCLE" in sr[33] and "A_DIV   = 8'h8C" in sr[35] and "A_FLAGS = 8'h90" in sr[36]
assert "wire [15:0] period = (G_CORE == 1) ? {1'b0, d[15:1]} : d" in sr[41]
assert "norm = (v < 16'd2) ? 16'd2 : {v[15:1], 1'b0}" in sr[47] and "norm = (v == 16'd0) ? 16'd1 : v" in sr[48]
assert "assign cpu_ce = !rst && (c >= p - 16'd1)" in sr[52]
assert "d   <= (G_CORE == 1) ? 16'd2 : 16'd1" in sr[58] and "p   <= 16'd1" in sr[60]
assert "c <= cpu_ce ? 16'd0 : c + 16'd1" in sr[64] and "if (cpu_ce) p <= period" in sr[65]
assert "A_DIV: d   <= norm(bus_wdata[15:0])" in sr[69] and "A_FLAGS: bus_rdata <= {31'd0, div_dz}" in sr[78]
assert "// ---- CP0" in g1[106] or "CP0" in g1[106]
assert "cp0_rd = {30'd0, status}" in g1[111] and "cp0_rd = {16'd0, irq_ip, 8'd0}" in g1[112] and "cp0_rd = epc" in g1[113]
assert "case (f_rd)" in g1[110] and "default: cp0_rd = 32'd0" in g1[114]
assert "cp0_op == 2'b10) next_pc = epc" in g1[156] and "status[1] <= 1'b0" in g1[218]
assert "epc       <= next_pc" in g1[220] and "status[1] <= 1'b1" in g1[221]
assert "cp0_rd = {16'd0, irq_ip, 8'd0}" in pp[153]
assert "wire        take_irq;" in pp[118] and "reg         irq_tr;" in pp[119] and "reg         last_cp0;" in pp[120]
assert "irq_epc = idex_v ? idex_pc : ifid_v ? ifid_pc : pc" in pp[121]
assert "nhận ngắt" in pp[200] and "assign take_irq = cpu_ce && irq && status[0] && !status[1] && !stall_busy && !stall_lu" in pp[201]
assert "idex_cp0 != 2'b00" in pp[202] and "idex_multi == 2'b00" in pp[202] and "last_cp0" in pp[203]
assert "wire id_ok = ifid_v && !take && !stall_lu && !take_irq" in pp[204]
assert "if (idex_v && !stall_busy) begin" in pp[246] and "status <= opB[1:0]" in pp[248] and "epc    <= {opB[31:2], 2'b00}" in pp[249]
assert "status[1] <= 1'b0" in pp[251] and "if (take_irq) begin" in pp[253]
assert "epc       <= irq_epc" in pp[254] and "status[1] <= 1'b1" in pp[255]
assert "started <= (idex_multi != 2'b00) && !mdone" in pp[257]
assert "ifid_v  <= !take && !take_irq" in pp[293]

# bài thử có đúng các ca nhắc
tb = (ROOT / "tb/irq_tb.v").read_text(encoding="utf-8")
for t in ("IRQ-3 su kien thang lenh xoa", "IRQ-4 ghi 0x08 -> 0x04", "STAMP chi chot o canh len"):
    assert t in tb, t
assert "D moi tu chu ky CPU ke" in (ROOT / "tb/soc_bus_tb.v").read_text(encoding="utf-8")
assert (ROOT / "fw/tests/cpu/irq.s").exists()
assert len(p5.splitlines()) >= 300, len(p5.splitlines())
print("PASS P5")
