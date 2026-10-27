# B6 branch — nhánh quyết định ở EX (pipeline-policy §5, T3, T4):
#   nhảy thật 2 bubble; không nhảy 0; nhánh ngay sau ALU 0 (forward vào EX); lw rồi nhánh 1 + 2 khi nhảy.
# Tổng: bne(2) + beq(0) + beq(2) + lw→beq(1+2) + beq-không-nhảy(0) + bne(2) = 9
# bubbles 9
# expect $t0=0
# expect $t1=5
# expect $t2=0
# expect $t3=1
# expect $t4=0
# expect $t5=0
# expect $t6=9
# expect $t7=1
        li    $s0, 1
        li    $s1, 2
        bne   $s0, $s1, A          # nhảy (1 ≠ 2): 2
        li    $t0, 111             # bị xóa
A:      beq   $s0, $s1, B          # không nhảy: 0
        li    $t1, 5               # chạy
        beq   $s0, $s0, B          # nhảy: 2
        li    $t2, 222             # bị xóa
B:      sw    $s0, 0x800($zero)    # M[800] = 1
        lw    $t3, 0x800($zero)    # t3 = 1
        beq   $t3, $s0, C          # lw rồi nhánh: stall 1, nhảy: 2
        li    $t4, 333             # bị xóa
C:      addiu $t7, $zero, 1        # t7 = 1
        beq   $t7, $zero, D        # ngay sau ALU, không nhảy: 0
        bne   $t3, $zero, D        # nhảy (t3 = 1): 2
        li    $t5, 444             # bị xóa
D:      li    $t6, 9
