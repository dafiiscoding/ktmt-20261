# uart.s — kiểm UART (gói D4, display-spec §6, mmio-map §3, §5 bit 6–7) trên soc_top.
# Chạy: bash tools/run_unit.sh soc_uart. tb nối uart_tx → uart_rx (vòng lại), G_BIT = 8.
# Tự kiểm: mỗi ca đúng bật 1 bit $v0; tb đòi $v0 = 0x3F. Chỉ polling, không bật ngắt.
        addiu $v0, $zero, 0
# ---- sau reset: UART_STATUS = TX_READY (0x4)                                           [bit 0]
        lw    $t1, -176($zero)
        addiu $t0, $zero, 4
        bne   $t1, $t0, k0
        ori   $v0, $v0, 0x01
k0:
# ---- phát 0x48 → vòng lại → UART_RX = VALID | 0x48                                     [bit 1]
        addiu $t0, $zero, 0xFF
        sw    $t0, -184($zero)        # xóa IRQ_PENDING
        addiu $t0, $zero, 0x48
        sw    $t0, -168($zero)
        addiu $a0, $zero, 1
        jal   waitrx
        lw    $t1, -172($zero)
        lui   $t0, 0x8000
        ori   $t0, $t0, 0x48
        bne   $t1, $t0, k1
        ori   $v0, $v0, 0x02
k1:
# ---- IRQ_PENDING bit 6 (UART_RX) và bit 7 (UART_TX_EMPTY) đã bật                      [bit 2]
        lw    $t1, -184($zero)
        andi  $t1, $t1, 0xC0
        addiu $t0, $zero, 0xC0
        bne   $t1, $t0, k2
        ori   $v0, $v0, 0x04
k2:
# ---- 3 byte 0x31..0x33, chờ TX_READY trước mỗi byte → đọc ra đúng thứ tự               [bit 3]
        addiu $s0, $zero, 0x31
        addiu $s1, $zero, 0x34
tx3:    lw    $t1, -176($zero)
        andi  $t1, $t1, 4
        beq   $t1, $zero, tx3
        sw    $s0, -168($zero)
        addiu $s0, $s0, 1
        bne   $s0, $s1, tx3
        addiu $a0, $zero, 3
        jal   waitrx
        lw    $t1, -172($zero)
        lw    $t2, -172($zero)
        lw    $t3, -172($zero)
        lui   $t0, 0x8000
        ori   $t4, $t0, 0x31
        bne   $t1, $t4, k3
        ori   $t4, $t0, 0x32
        bne   $t2, $t4, k3
        ori   $t4, $t0, 0x33
        bne   $t3, $t4, k3
        ori   $v0, $v0, 0x08
k3:
# ---- FIFO rỗng: UART_RX = 0, STATUS = 0x4                                              [bit 4]
        lw    $t1, -172($zero)
        lw    $t2, -176($zero)
        bne   $t1, $zero, k4
        addiu $t0, $zero, 4
        bne   $t2, $t0, k4
        ori   $v0, $v0, 0x10
k4:
# ---- 3 lần sw liền: byte 1 vào bộ dịch, byte 2 vào bộ đệm, byte 3 bị bỏ (TX_DROP)       [bit 5]
#      ghi 1 xóa TX_DROP; chờ đủ lâu → chỉ 2 byte vòng lại; đọc hết → STATUS = 0x4
        addiu $t0, $zero, 0x41
        sw    $t0, -168($zero)
        sw    $t0, -168($zero)
        sw    $t0, -168($zero)
        lw    $t1, -176($zero)
        andi  $t1, $t1, 0x10
        beq   $t1, $zero, k5
        addiu $t0, $zero, 0x10
        sw    $t0, -176($zero)
        addiu $a0, $zero, 2
        jal   waitrx
        addiu $t9, $zero, 200         # thêm > 1 khung: byte thứ 3 (nếu có) cũng đã về
d5:     addiu $t9, $t9, -1
        bne   $t9, $zero, d5
        lw    $t1, -176($zero)
        addiu $t0, $zero, 0x205       # RX_COUNT = 2, TX_READY, RX_AVAIL, không cờ
        bne   $t1, $t0, k5
        lw    $t1, -172($zero)
        lw    $t1, -172($zero)
        lw    $t1, -176($zero)
        addiu $t0, $zero, 4
        bne   $t1, $t0, k5
        ori   $v0, $v0, 0x20
k5:
        sw    $zero, -108($zero)      # dấu xong: địa chỉ MMIO trống (đọc 0, ghi bỏ); tb nhìn bus → chạy được cả G1/G2
end:    j     end

# waitrx: chờ RX_COUNT ≥ $a0 (tối đa ~2000 vòng). Dùng $t7–$t9.
waitrx: addiu $t9, $zero, 2000
wr1:    lw    $t8, -176($zero)
        sra   $t8, $t8, 8
        andi  $t8, $t8, 0x7F
        slt   $t7, $t8, $a0
        beq   $t7, $zero, wr2
        addiu $t9, $t9, -1
        bne   $t9, $zero, wr1
wr2:    jr    $ra
