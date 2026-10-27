# C3-2: tổng 1..100 → $v0 = 5050 (vòng lặp nhánh lùi)
# expect $v0=5050
        li    $v0, 0
        li    $t0, 1
        li    $t1, 101
loop:   addu  $v0, $v0, $t0
        addiu $t0, $t0, 1
        bne   $t0, $t1, loop
        sw    $v0, 0x800($zero)
