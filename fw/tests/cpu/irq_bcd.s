# Ngắt khi bcd đang busy (pipeline-policy §10). Vòng 20 lần bcd; máy phát sự kiện trễ 5 chu kỳ hệ thống.
# Ngắt phải được nhận đúng 1 lần và không làm mất/lặp lệnh. Vị trí ngắt cụ thể (G2: trong busy hay ngay sau) kiểm bằng trace.
# nomars
# expect $s0=20
# expect $s1=1
# expect $t5=0x12345678
        j     main
        .org  0x180
handler:
        lw    $k0, 0x800($zero)
        sll   $k0, $k0, 2
        mfc0  $k1, $14
        sw    $k1, 0x804($k0)
        ori   $k1, $zero, 0x08
        sw    $k1, -184($zero)       # IRQ_PENDING: ghi 1 để xóa bit 3
        sra   $k0, $k0, 2
        addiu $k0, $k0, 1
        sw    $k0, 0x800($zero)
        eret

main:   addiu $t0, $zero, 8
        sw    $t0, -188($zero)       # IRQ_ENABLE = bit 3
        addiu $t2, $zero, 1
        mtc0  $t2, $12               # IE = 1, EXL = 0
        addiu $t0, $zero, 0x0508     # trễ 5 chu kỳ, bit 3
        sw    $t0, -16($zero)        # máy phát sự kiện
        li    $t6, 12345678
        addiu $s0, $zero, 0
        addiu $t4, $zero, 20
loop:   bcd   $t5, $t6
        addiu $s0, $s0, 1
        bne   $s0, $t4, loop
        lw    $s1, 0x800($zero)      # số lần vào handler
