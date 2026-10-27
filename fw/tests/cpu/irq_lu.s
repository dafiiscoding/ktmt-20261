# Ngắt khi load-use đang stall (pipeline-policy §10). Vòng 20 lần lw + addu phụ thuộc; máy phát sự kiện trễ 1 chu kỳ hệ thống.
# Ngắt phải được nhận đúng 1 lần, không làm mất/lặp lệnh. Vị trí ngắt cụ thể (G2: ngay lúc stall hay không) kiểm bằng trace.
# nomars
# expect $s2=20
# expect $s1=1
# expect $t5=20
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
        addiu $t0, $zero, 1
        sw    $t0, 0x810($zero)      # giá trị nạp = 1
        addiu $t0, $zero, 0x0108     # trễ 1 chu kỳ, bit 3 (đột biến bỏ chặn stall_lu bị bắt ở trễ 1 và 8)
        sw    $t0, -16($zero)        # máy phát sự kiện
        addiu $s2, $zero, 0
        addiu $t5, $zero, 0
        addiu $t4, $zero, 20
loop:   lw    $t1, 0x810($zero)
        addu  $s2, $s2, $t1          # load-use: stall 1 chu kỳ
        addiu $t5, $t5, 1
        bne   $t5, $t4, loop
        lw    $s1, 0x800($zero)      # số lần vào handler
