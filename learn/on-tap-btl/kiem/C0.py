"""Assert cho bảng chu kỳ và các dòng code nhắc trong bài C0 (lw rồi beq đi qua năm lát)."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
nguon = (Path(__file__).resolve().parents[1] / "nguon" / "02-code.md").read_text(encoding="utf-8")
c0 = nguon.split("## C0 ·")[1].split("\n## ")[0]


def dong(rel):
    return (ROOT / rel).read_text(encoding="utf-8").splitlines()


cp, hz, ct, rf = dong("src/cpu_pipe.v"), dong("src/hazard.v"), dong("src/control.v"), dong("src/regfile.v")

# --- mô hình đường ống 5 tầng theo đúng luật stall_lu / take / id_ok của RTL
# lệnh: (tên, đích, nguồn, là_lw, là_beq)
CT = [("sw", 0, (0,), False, False), ("lw", 8, (0,), True, False), ("beq", 0, (8, 0), False, True),
      ("A", 9, (0,), False, False), ("B", 10, (0,), False, False), ("L", 11, (0,), False, False)]
DICH = {"beq": 5}                      # beq nhảy thật tới chỉ số 5 (lệnh L, địa chỉ 0x14)


def chay(prog, nhay=True):
    pc, ifid, idex, exm, mw = 0, None, None, None, None
    vet, rv = [], {}
    for cyc in range(0, 40):
        # WB: lệnh rời ở chu kỳ này
        if mw:
            rv[mw[0]] = cyc
        stall = bool(idex and idex[3] and ifid and idex[1] != 0 and idex[1] in ifid[2])
        take = bool(idex and idex[4] and nhay)
        id_ok = bool(ifid) and not take and not stall
        vet.append((cyc, ifid and ifid[0], idex and idex[0], stall, take))
        mw, exm = exm, idex
        idex = ifid if id_ok else None
        if not stall:
            if take:
                pc, ifid = DICH["beq"], None
            else:
                ifid = prog[pc] if pc < len(prog) else None
                pc += 1
        if cyc > 20 and not (ifid or idex or exm or mw):
            break
    return rv, vet


rv, vet = chay(CT)
assert [rv[n] for n in ("sw", "lw", "beq", "L")] == [4, 5, 7, 10], rv     # đúng trace thật: 4, 5, 7, 10
assert "A" not in rv and "B" not in rv                                    # hai lệnh nạp nhầm không bao giờ retire
assert (rv["beq"] - rv["lw"] - 1, rv["L"] - rv["beq"] - 1) == (1, 2)       # 1 bong bóng load-use, 2 bong bóng nhánh
# bne không nhảy: chỉ còn 1 bong bóng
CT2 = [CT[0], CT[1], ("bne", 0, (8, 0), False, True)] + CT[3:]
rv2, _ = chay([CT2[0], CT2[1], CT2[2], CT2[3], CT2[4], CT2[5]], nhay=False)
assert rv2["bne"] - rv2["lw"] - 1 == 1 and rv2["A"] - rv2["bne"] - 1 == 0
# chèn một lệnh độc lập giữa lw và beq: không còn load-use
CT3 = [CT[0], CT[1], ("X", 12, (0,), False, False), CT[2]] + CT[3:]
DICH["beq"] = 6
rv3, _ = chay(CT3)
assert rv3["beq"] - rv3["X"] - 1 == 0 and rv3["X"] - rv3["lw"] - 1 == 0
DICH["beq"] = 5
# đích nhánh: (pc + 4) + imm × 4
assert 0x08 + 4 + 2 * 4 == 0x14

# --- khớp dòng code được nhắc (chỉ số 0-based = dòng - 1)
assert "6'h23: begin i_alu(A_ADD, E_SE, 1); mem_read = 1; mem_to_reg = 1; end" in ct[86]
assert "6'h04: begin valid = 1; branch = 2'b01; uses_rs = 1; uses_rt = 1; end" in ct[91]
assert "wire [31:0] imm_x" in cp[97] and "wire [31:0] rs_v, rt_v, wb;" in cp[106]
assert "wire        we_rf = cpu_ce && mw_v && mw_rw" in cp[107] and ".G_BYPASS(1)" in cp[108]
assert "wire byp1" in rf[40] and "wire byp2" in rf[41] and "assign rd1" in rf[44]
assert "assign stall_lu = idex_mem_read" in hz[38] and "ifid_uses_rs && (idex_dst == ifid_rs)" in hz[39]
assert "// Toán hạng A" in hz[43] and "fwd_a = 2'b10" in hz[45] and "fwd_a = 2'b01" in hz[46] and "fwd_a = 2'b00" in hz[47]
assert "assign flush = taken" in hz[40]
assert "wire [31:0] opA = (fwd_a == 2'b10) ? exm_res : (fwd_a == 2'b01) ? wb : idex_a" in cp[130]
assert "alu_b = idex_asrc ? idex_imm : opB" in cp[132] and "alu u_alu" in cp[135]
assert "wire eq = (opA == opB)" in cp[175] and "assign take = idex_v && !stall_busy" in cp[176]
assert "idex_pc4 + {idex_imm[29:0], 2'b00}" in cp[181]
assert "quyết định tầng ID" in cp[199] and "wire id_ok = ifid_v && !take && !stall_lu && !take_irq" in cp[204]
assert "if (!stall_lu) begin" in cp[291] and "pc      <= take_irq ? 32'h0000_0180 : take ? tgt : pc + 32'd4" in cp[292]
assert "ifid_v  <= !take && !take_irq" in cp[293]
assert "mw_lmmio <= exm_mrd && in_mmio" in cp[261] and "mw_mdata <= in_dmem ? dmem[exm_res[11:2]] : 32'd0" in cp[264]
assert "wire [31:0] wb_ld = mw_lmmio ? bus_rdata : mw_mdata" in cp[193] and "assign wb = mw_m2r ? wb_ld : mw_res" in cp[194]
assert "assign take_irq = cpu_ce && irq && status[0] && !status[1] && !stall_busy && !stall_lu" in cp[201]
assert "wire unused_ok = &{1'b0, alu_zero, md_busy, bc_busy, flush, mw_addr[1:0]}" in cp[301]
assert "(!ifid_v)      ? 5'd0" in cp[101]
assert "wire in_dmem = (exm_res[31:12] == 20'd0)" in cp[185] and "wire in_mmio = (exm_res[31:8] == 24'hFFFFFF)" in cp[186]
assert "cp0_op = 2'b01" in ct[106] and "cp0_op = 2'b10" in ct[108]
assert "else if (cpu_ce) begin" in cp[239]
g1 = dong("src/cpu_g1.v")
assert "epc       <= next_pc" in g1[220] and "wire        take = (branch == 2'b01 && eq)" in g1[150]
# chương trình mẫu có thật trong test của nhóm
assert "lw rồi nhánh: stall 1, nhảy: 2" in (ROOT / "fw/tests/hazard/branch.s").read_text(encoding="utf-8")
assert (ROOT / "fw/tests/cpu/irq_lu.s").exists() and (ROOT / "fw/tests/hazard/load_use.s").exists()
assert len([x for x in c0.splitlines() if x.startswith(":::thay-hoi")]) == 15
assert len([x for x in c0.splitlines() if x.strip()]) >= 200
print("PASS C0")
