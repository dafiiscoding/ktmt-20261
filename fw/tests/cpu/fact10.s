# C3-2: giai thừa đệ quy qua stack: fact(10) = 3628800 = 0x375F00
# expect $v0=0x375f00
        li    $sp, 0xff8
        li    $a0, 10
        jal   fact
        sw    $v0, 0x800($zero)
        j     end
fact:   addiu $sp, $sp, -8
        sw    $ra, 4($sp)
        sw    $a0, 0($sp)
        slti  $t0, $a0, 2
        beq   $t0, $zero, rec
        li    $v0, 1
        addiu $sp, $sp, 8
        jr    $ra
rec:    addiu $a0, $a0, -1
        jal   fact
        lw    $a0, 0($sp)
        lw    $ra, 4($sp)
        addiu $sp, $sp, 8
        mul   $v0, $v0, $a0
        jr    $ra
end:    nop
