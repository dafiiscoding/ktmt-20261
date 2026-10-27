# C3-1 (phần 27 lệnh có trong MARS; bcd ở bcd.s): mỗi lệnh ít nhất 1 lần, kết quả cất vào 0x800+
        li    $sp, 0xff8
        li    $s0, 0x800            # con trỏ kết quả
        li    $t0, 0x12345678       # lui + ori
        li    $t1, -100             # addiu
        addu  $t2, $t0, $t1
        subu  $t3, $t1, $t0
        and   $t4, $t0, $t1
        or    $t5, $t0, $t1
        xor   $t6, $t0, $t1
        slt   $t7, $t1, $t0
        slt   $t8, $t0, $t1
        sll   $t9, $t0, 7
        sra   $s1, $t1, 3
        sra   $s2, $t0, 31
        slti  $s3, $t1, -99
        slti  $s4, $t1, -100
        andi  $s5, $t1, 0xff0f
        ori   $s6, $t1, 0x8001
        lui   $s7, 0xbeef
        sw    $t2, 0($s0)
        sw    $t3, 4($s0)
        sw    $t4, 8($s0)
        sw    $t5, 12($s0)
        sw    $t6, 16($s0)
        sw    $t7, 20($s0)
        sw    $t8, 24($s0)
        sw    $t9, 28($s0)
        sw    $s1, 32($s0)
        sw    $s2, 36($s0)
        sw    $s3, 40($s0)
        sw    $s4, 44($s0)
        sw    $s5, 48($s0)
        sw    $s6, 52($s0)
        sw    $s7, 56($s0)
        lw    $a0, 0($s0)
        lw    $a1, 56($s0)
        addu  $a2, $a0, $a1
        # div có dấu, mfhi/mflo ngay sau (C3-3)
        li    $t0, -7
        li    $t1, 2
        div   $t0, $t1
        mflo  $v0
        mfhi  $v1
        sw    $v0, 60($s0)
        sw    $v1, 64($s0)
        li    $t0, 0x80000000
        li    $t1, -1
        div   $t0, $t1
        mflo  $a3
        mfhi  $k0
        sw    $a3, 68($s0)
        sw    $k0, 72($s0)
        mul   $k1, $t0, $t1         # 0x80000000 * -1
        li    $t2, 123456
        mul   $t3, $t2, $t2
        sw    $k1, 76($s0)
        sw    $t3, 80($s0)
        # nhánh: beq/bne nhảy và không nhảy, j, jal/jr
        li    $t4, 0
        beq   $t4, $zero, b1
        addiu $t4, $t4, 100         # bỏ qua
b1:     bne   $t4, $zero, b2        # không nhảy
        addiu $t4, $t4, 1
b2:     beq   $t4, $zero, b3        # không nhảy
        addiu $t4, $t4, 2
b3:     bne   $t4, $zero, b4        # nhảy
        addiu $t4, $t4, 100
b4:     j     b5
        addiu $t4, $t4, 100
b5:     jal   sub1
        sw    $t4, 84($s0)
        sw    $ra, 88($s0)
        # CP0: ghi Status rồi đọc; EPC; eret về nhãn
        li    $t5, 3
        mtc0  $t5, $12
        mfc0  $t6, $12
        jal   mkepc                 # $ra = back (không dùng la: MARS dịch la thành addi)
back:   mfc0  $t9, $12              # EXL bị xóa → 1
        sw    $t6, 92($s0)
        sw    $t8, 96($s0)
        sw    $t9, 100($s0)
        mtc0  $zero, $12
        j     end
sub1:   addiu $t4, $t4, 10
        jr    $ra
mkepc:  mtc0  $ra, $14
        mfc0  $t8, $14
        addu  $t7, $ra, $zero
        eret                        # PC ← EPC = back
        addiu $t4, $t4, 1000        # bỏ qua (eret nhảy)
end:    nop
