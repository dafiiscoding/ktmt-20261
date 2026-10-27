# irq_lat.s — C5-5: độ trễ ngắt ở D = 1526, chỉ bật 1 nguồn (TICK_1S). tb (soc_irqlat_tb) đo
# CYCLE_COUNT lúc lệnh đầu handler xong − IRQ_STAMP, chia theo pha $s1: 0 = vòng chờ toàn lệnh 1 chu kỳ, 1 = vòng có div.
# Chạy: bash tools/run_unit.sh soc_irqlat
        j     main

        .org  0x180
handler:
        addiu $k0, $zero, 2             # lệnh đầu handler: tb đo ở lúc nó xong
        sw    $k0, -184($zero)          # IRQ_PENDING: xóa bit 1
        addiu $s0, $s0, 1               # đếm ngắt
        eret

main:   addiu $t0, $zero, 1526
        sw    $t0, -116($zero)          # CPU_CLK_DIV = 1526
        addiu $t0, $zero, 2
        sw    $t0, -184($zero)          # xóa TICK_1S cũ
        sw    $t0, -188($zero)          # IRQ_ENABLE = TICK_1S
        addiu $t0, $zero, 1
        mtc0  $t0, $12                  # Status.IE = 1
        addiu $t1, $zero, 6
w1:     bne   $s0, $t1, w1              # pha 0: 6 ngắt trong vòng 1 lệnh (1 lệnh → không thể có 2 ngắt giữa 2 lần so)
        addiu $s1, $zero, 1
        addiu $t2, $zero, 7
        addiu $t1, $zero, 12
w2:     div   $t2, $t2                  # pha 1: 6 ngắt trong vòng có div (33 chu kỳ CPU, chặn ngắt khi stall)
        slt   $t3, $s0, $t1             # so < (không so ≠): 2 ngắt có thể chen giữa 2 lần so
        bne   $t3, $zero, w2
        mtc0  $zero, $12                # tắt IE
        addiu $t0, $zero, 2
        sw    $t0, -116($zero)          # D = 2
end:    j     end
