"""Assert cho phép tính tay và khẳng định kiểm được của bài P2 (hazard, forwarding, MEM, WB)."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
nguon = (Path(__file__).resolve().parents[1] / "nguon" / "02-code.md").read_text(encoding="utf-8")
p2 = nguon.split("## P2 ·")[1].split("\n## ")[0]


def dong(rel):
    return (ROOT / rel).read_text(encoding="utf-8").splitlines()


hz, pp, g1 = dong("src/hazard.v"), dong("src/cpu_pipe.v"), dong("src/cpu_g1.v")


# --- mô hình tham chiếu viết lại theo lời của tài liệu chính sách (không chép biểu thức của RTL)
def fwd(rw_m, dst_m, rw_w, dst_w, src):
    if rw_m and dst_m != 0 and dst_m == src:
        return 0b10
    if rw_w and dst_w != 0 and dst_w == src:
        return 0b01
    return 0b00


def lu(ex_load, ex_dst, id_valid, uses_rs, rs, uses_rt, rt):
    return int(ex_load and ex_dst != 0 and id_valid and ((uses_rs and ex_dst == rs) or (uses_rt and ex_dst == rt)))


# Tự luận 1: ba trường hợp
assert fwd(1, 5, 1, 5, 5) == 0b10
assert fwd(1, 6, 1, 5, 5) == 0b01
assert fwd(1, 6, 1, 0, 5) == 0b00 and fwd(1, 0, 1, 0, 0) == 0b00   # $zero không bao giờ lấy tắt

# Phép 3: lw rồi addiu (không đọc rt) không chờ; lw rồi addu có đọc rt trùng thì chờ
assert lu(1, 8, 1, 1, 17, 0, 8) == 0
assert lu(1, 8, 1, 1, 8, 0, 0) == 1 and lu(1, 8, 1, 0, 0, 1, 8) == 1 and lu(1, 8, 0, 1, 8, 0, 0) == 0

# Phép 2 (T1): subu $2 rồi and $12,$2,$5 ; or $13,$6,$2 ; addu $14,$2,$2
assert fwd(1, 2, 0, 0, 2) == 0b10          # and: subu đang ở EX/MEM
assert fwd(0, 0, 1, 2, 2) == 0b01          # or : subu đang ở MEM/WB
assert fwd(0, 0, 0, 0, 2) == 0b00          # addu: subu đã xong, regfile bypass


# Phép 1: số chu kỳ = số lệnh + 4 + số chu kỳ chờ
def chu_ky(n_lenh, cho):
    return n_lenh + 4 + cho


assert chu_ky(3, 1) == 8 and chu_ky(4, 1) == 9 and chu_ky(3, 0) == 7

# bảng chu kỳ trong bài: lw, addu, sw
bang = {"lw": (1, 5), "addu": (2, 7), "sw": (3, 8)}   # (chu kỳ IF đầu tiên, chu kỳ WB)
assert bang["sw"][1] == 8

# --- khớp dòng code được nhắc
assert "module hazard (" in hz[15] and "// Load-use" in hz[35]
assert "assign stall_lu = idex_mem_read && (idex_dst != 5'd0) && ifid_valid" in hz[38]
assert "ifid_uses_rs && (idex_dst == ifid_rs)" in hz[39] and "ifid_uses_rt && (idex_dst == ifid_rt)" in hz[39]
assert "assign flush = taken" in hz[40] and "always @*" in hz[42]
assert "fwd_a = 2'b10" in hz[45] and "else if" in hz[46] and "fwd_a = 2'b01" in hz[46] and "fwd_a = 2'b00" in hz[47]
assert "idex_rt" in hz[50] and "idex_rt" in hz[51]
assert "EX/MEM" in pp[70] and "MEM/WB" in pp[77] and "hazard + forwarding" in pp[111]
assert "hazard u_haz" in pp[122] and ".taken(take)" in pp[126]
assert "in_dmem" in pp[185] and "in_mmio" in pp[186]
assert "assign bus_we    = cpu_ce && exm_v && exm_mwr && in_mmio" in pp[189]
assert "wb_ld = mw_lmmio ? bus_rdata : mw_mdata" in pp[193] and "assign wb = mw_m2r ? wb_ld : mw_res" in pp[194]
assert "assign retire = cpu_ce && mw_v" in pp[197]
assert "wire id_ok = ifid_v && !take && !stall_lu && !take_irq" in pp[204]
assert "mw_mdata <= in_dmem ? dmem[exm_res[11:2]] : 32'd0" in pp[264]
assert "if (stall_busy) begin" in pp[267] and "exm_v <= 1'b0" in pp[269]
assert "exm_v <= idex_v && !take_irq" in pp[272]
assert "idex_v <= id_ok" in pp[278] and "ifid_v  <= !take && !take_irq" in pp[293]
assert "mw_v <= exm_v" in pp[260] and "mw_lmmio <= exm_mrd && in_mmio" in pp[261]
assert "assign bus_we    = ph_b && mem_write && in_mmio" in g1[126] and "assign bus_re    = ph_b && mem_read  && in_mmio" in g1[127]
assert "wire [31:0] maddr   = alu_y" in g1[121] and "assign wb = mem_to_reg ? load_v : res" in g1[145]

# khẳng định "flush chỉ được nối dây": mọi chỗ có chữ flush trong cpu_pipe.v
chi_flush = [i + 1 for i, l in enumerate(pp) if "flush" in l]
assert chi_flush == [115, 127, 302], chi_flush
assert all("flush" not in l for l in g1)

# test đơn vị có chứa các ca bài nhắc
tb = (ROOT / "tb/hazard_tb.v").read_text(encoding="utf-8")
for t in ("loi lu rs", "loi lu rt", "loi lu thua", "loi uu tien EX/MEM", "loi fwd MEM/WB", "loi fwd $0"):
    assert t in tb, t
for f in ("load_use", "raw_chain", "branch", "zero_reg"):
    assert (ROOT / "fw/tests/hazard" / (f + ".s")).exists(), f
assert "# bubbles 3" in (ROOT / "fw/tests/hazard/load_use.s").read_text(encoding="utf-8")
assert len(p2.splitlines()) >= 300, len(p2.splitlines())
print("PASS P2")
