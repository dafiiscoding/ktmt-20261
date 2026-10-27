# B6 multi — div K = 33 chu kỳ EX (+32 bubble); chia 0 = 1 chu kỳ (+0); mflo/mfhi ngay sau div (+0);
# lw → div: load-use stall 1 rồi div 32 (+33). Tổng = 32 + 0 + 33 = 65 (pipeline-policy §6, T5).
# bubbles 65
# expect $t0=14
# expect $t1=2
# expect $t2=16
# expect $t3=0
# expect $t4=100
# expect $t6=14
        li    $s0, 100
        li    $s1, 7
        div   $s0, $s1              # 100 / 7: LO = 14, HI = 2
        mflo  $t0                   # 14 (chờ div xong vì mflo nằm sau div)
        mfhi  $t1                   # 2
        addu  $t2, $t0, $t1         # 16
        div   $s0, $zero            # chia 0: LO = 0, HI = rs = 100, 1 chu kỳ
        mflo  $t3                   # 0
        mfhi  $t4                   # 100
        sw    $s1, 0x800($zero)     # M[800] = 7
        lw    $t5, 0x800($zero)     # t5 = 7
        div   $s0, $t5              # rt là load: stall 1, rồi 32 bước
        mflo  $t6                   # 14
