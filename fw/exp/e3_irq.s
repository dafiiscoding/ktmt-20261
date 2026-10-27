# e3_irq.s — thí nghiệm E3 (chủ TV3 + TV2), cách 2: NGẮT BTN (bit 5). tb/exp_e3_tb.v bấm nút B, đo lúc handler có MS_OF_DAY.
# Nền = cùng việc W như e3_poll.s (div + 4 lệnh ALU) chạy mãi; ngắt bị chặn khi div đang stall (pipeline-policy §6).
# Stopwatch SRC = 1, RUN = 1 → mỗi lần B phần cứng chụp lap (cách 3).
# D (CPU_CLK_DIV) do tools/exp_e3.py thay vào dòng .eqv dưới.
        .eqv  D_VAL 2
        j     main

        .org  0x180
handler:
        lw    $k0, -252($zero)          # cách 2: lệnh đầu handler đọc MS_OF_DAY
        lw    $k1, -192($zero)          # lấy sự kiện khỏi BTN_EVENT
        lw    $k1, -220($zero)          # lấy lap khỏi FIFO (tb đọc giá trị)
        addiu $k1, $zero, 0x30
        sw    $k1, -184($zero)          # IRQ_PENDING: xóa BTN (bit 5) và SW_CAPTURE (bit 4)
        eret

main:   addiu $t0, $zero, D_VAL
        sw    $t0, -116($zero)          # CPU_CLK_DIV = D
        addiu $t0, $zero, 1
        sw    $t0, -228($zero)          # SW_CTRL: SRC = 0, RUN = 1
        addiu $t0, $zero, 4
        sw    $t0, -228($zero)          # SRC = 1 (RUN giữ)
        addiu $t0, $zero, 0x30
        sw    $t0, -184($zero)          # xóa pending cũ
        addiu $t0, $zero, 0x20
        sw    $t0, -188($zero)          # IRQ_ENABLE = BTN
        addiu $t0, $zero, 1
        mtc0  $t0, $12                  # Status.IE = 1
        addiu $t5, $zero, 7
        sw    $t0, 0($zero)             # DMEM[0] = 1: báo tb bắt đầu bấm
work:   div   $t5, $t5                  # việc nền W
        addu  $t6, $t6, $t5
        addu  $t7, $t7, $t6
        addu  $t8, $t8, $t7
        addu  $t9, $t9, $t8
        j     work
