# bus.s — kiểm bus MMIO + thanh ghi soc trên soc_top (gói C4, mmio-map §6 BUS-2, -3, -5 và §4).
# Chạy: bash tools/run_unit.sh soc_bus. Tự kiểm: mỗi ca đúng bật 1 bit $v0; tb đòi $v0 = 0x7FFF.
# BUS-1 (độ trễ 1 cạnh) được kiểm gián tiếp ở mọi lw; BUS-4 dùng FIFO lap của stopwatch (E3).
        lw    $s1, -256($zero)        # lệnh đầu tiên: CYCLE_COUNT = 0 (pha B đầu tiên sau reset)
        addiu $v0, $zero, 0
        bne   $s1, $zero, kc
        ori   $v0, $v0, 0x200                                                     # [bit 9]
kc:
# ---- BUS-2: địa chỉ trống trong MMIO và ngoài mọi vùng → đọc 0 (kể cả sau khi ghi)      [bit 0]
        addiu $t0, $zero, 0x77
        sw    $t0, -108($zero)
        sw    $t0, -100($zero)
        sw    $t0, 0x2000($zero)
        lw    $t1, -108($zero)
        lw    $t2, -100($zero)
        lw    $t3, 0x2000($zero)
        or    $t1, $t1, $t2
        or    $t1, $t1, $t3
        bne   $t1, $zero, k0
        ori   $v0, $v0, 0x01
k0:
# ---- BUS-3: ghi CYCLE_COUNT bị bỏ; 2 lần đọc cách 1 lệnh = 2 chu kỳ CPU = 4 chu kỳ hệ thống (D = 2)  [bit 1]
        lw    $t1, -256($zero)
        sw    $zero, -256($zero)
        lw    $t2, -256($zero)
        subu  $t2, $t2, $t1
        addiu $t3, $zero, 4
        bne   $t2, $t3, k1
        ori   $v0, $v0, 0x02
k1:
# ---- BUS-5: CPU_CLK_DIV ghi 0, 1, 3, 1526 → đọc 2, 2, 2, 1526                          [bit 2]
        sw    $zero, -116($zero)
        lw    $t1, -116($zero)
        addiu $t0, $zero, 1
        sw    $t0, -116($zero)
        lw    $t2, -116($zero)
        addiu $t0, $zero, 3
        sw    $t0, -116($zero)
        lw    $t3, -116($zero)
        addiu $t0, $zero, 1526
        sw    $t0, -116($zero)
        lw    $t4, -116($zero)
        lw    $t5, -256($zero)        # 2 lần đọc liền nhau ở D = 1526 → cách 1526 chu kỳ   [bit 3]
        lw    $t6, -256($zero)
        addiu $t0, $zero, 2
        sw    $t0, -116($zero)
        addiu $t7, $zero, 2
        bne   $t1, $t7, k2
        bne   $t2, $t7, k2
        bne   $t3, $t7, k2
        addiu $t7, $zero, 1526
        bne   $t4, $t7, k2
        ori   $v0, $v0, 0x04
k2:     subu  $t6, $t6, $t5
        bne   $t6, $t7, k3
        ori   $v0, $v0, 0x08
k3:
# ---- D mới có hiệu lực từ chu kỳ CPU kế (mmio-map §4.3): lw CC; sw D=6; lw CC → 2 + 1 + 3 = 6   [bit 4]
        addiu $t0, $zero, 6
        lw    $t1, -256($zero)
        sw    $t0, -116($zero)
        lw    $t2, -256($zero)
        nop
        lw    $t3, -256($zero)        # cách lần trước 2 chu kỳ CPU = 12
        addiu $t0, $zero, 2
        sw    $t0, -116($zero)
        subu  $t2, $t2, $t1
        subu  $t3, $t3, $t1
        addiu $t7, $zero, 6
        bne   $t2, $t7, k4
        addiu $t7, $zero, 18
        bne   $t3, $t7, k4
        ori   $v0, $v0, 0x10
k4:
# ---- DIV_FLAGS.DZ theo lệnh div gần nhất                                                [bit 5]
        addiu $t0, $zero, 5
        div   $t0, $zero
        lw    $t1, -112($zero)
        addiu $t2, $zero, 1
        div   $t0, $t2
        lw    $t3, -112($zero)
        bne   $t1, $t2, k5
        bne   $t3, $zero, k5
        ori   $v0, $v0, 0x20
k5:
# ---- CAL đọc/ghi (số âm), rồi trả 0                                                     [bit 6]
        lui   $t0, 0xfffd
        ori   $t0, $t0, 0x8000        # −163 840
        sw    $t0, -232($zero)
        lw    $t1, -232($zero)
        sw    $zero, -232($zero)
        bne   $t1, $t0, k6
        ori   $v0, $v0, 0x40
k6:
# ---- irq_ctrl qua bus soc: ENABLE đọc lại; PENDING[0] (TICK_1MS) bật dù ENABLE = 0, ghi 1 xóa  [bit 7]
        addiu $t0, $zero, 0xa4        # bit 0 tắt → TICK_1MS không gây irq
        sw    $t0, -188($zero)
        lw    $t1, -188($zero)
        sw    $zero, -188($zero)
        bne   $t1, $t0, k7
        addiu $t0, $zero, 0xff
        sw    $t0, -184($zero)        # xóa hết
        addiu $t9, $zero, 200         # chờ tối đa 200 vòng (> 1 ms = 50 chu kỳ)
w7:     lw    $t1, -184($zero)
        andi  $t1, $t1, 1
        bne   $t1, $zero, g7
        addiu $t9, $t9, -1
        bne   $t9, $zero, w7
        j     k7
g7:     addiu $t0, $zero, 1
        sw    $t0, -184($zero)
        lw    $t1, -184($zero)
        andi  $t1, $t1, 1
        bne   $t1, $zero, k7
        ori   $v0, $v0, 0x80
k7:
# ---- RTC MS_OF_DAY tăng đúng 1 sau 1 ms                                                [bit 8]
        lw    $t1, -252($zero)
        addiu $t9, $zero, 200
w8:     lw    $t2, -252($zero)
        bne   $t2, $t1, g8
        addiu $t9, $t9, -1
        bne   $t9, $zero, w8
        j     k8
g8:     subu  $t2, $t2, $t1
        addiu $t3, $zero, 1
        bne   $t2, $t3, k8
        ori   $v0, $v0, 0x100
k8:
# ---- BUS-4: FIFO lap có 5 phần tử, D = 1526, 3 lệnh lw SW_LAP liên tiếp → lấy ra đúng 3, còn 2   [bit 10]
        addiu $t0, $zero, 2
        sw    $t0, -228($zero)        # SW RESET (SRC = 0)
        addiu $t0, $zero, 0x21        # RUN + LAP
        sw    $t0, -228($zero)
        sw    $t0, -228($zero)
        sw    $t0, -228($zero)
        sw    $t0, -228($zero)
        sw    $t0, -228($zero)
        sw    $zero, -228($zero)      # dừng
        addiu $t0, $zero, 1526
        sw    $t0, -116($zero)
        lw    $t1, -220($zero)
        lw    $t2, -220($zero)
        lw    $t3, -220($zero)
        addiu $t0, $zero, 2
        sw    $t0, -116($zero)
        lw    $t4, -228($zero)
        and   $t1, $t1, $t2
        and   $t1, $t1, $t3
        slt   $t1, $t1, $zero         # cả 3 lần đọc phải VALID (bit 31) — G1 không có bgez/srl
        beq   $t1, $zero, k10
        andi  $t4, $t4, 0xf00
        addiu $t5, $zero, 0x200
        bne   $t4, $t5, k10           # LAP_COUNT [11:8] còn 2
        ori   $v0, $v0, 0x400
k10:
# ---- ngắt E3/E4 qua soc_top: mỗi nguồn bật đúng bit IRQ_PENDING của nó (mmio-map §5). IRQ_ENABLE = 0 (ca bit 7).
# Mỗi ca: xóa PENDING, gây sự kiện, chờ bit, rồi đòi (PENDING & 0x3C) = đúng bit đó.
# TMR_ZERO → bit 2                                                                          [bit 11]
        addiu $t0, $zero, 0xff
        sw    $t0, -184($zero)
        addiu $t0, $zero, 1
        sw    $t0, -216($zero)        # TMR_VALUE = 1
        sw    $t0, -212($zero)        # TMR_CTRL.RUN
        addiu $t9, $zero, 200
w11:    lw    $t1, -184($zero)
        andi  $t2, $t1, 0x04
        bne   $t2, $zero, g11
        addiu $t9, $t9, -1
        bne   $t9, $zero, w11
        j     k11
g11:    sw    $zero, -212($zero)      # dừng timer
        andi  $t1, $t1, 0x3c
        addiu $t2, $zero, 0x04
        bne   $t1, $t2, k11
        ori   $v0, $v0, 0x800
k11:
# ALARM → bit 3: ALARM0 = EN, mọi thứ, 07:00. Nạp RTC đúng 07:00:00.000 → không kêu (AL-4 qua dây
# inc = tick_ms && !loading của soc_top); rồi nạp 06:59:59.995 → kêu                        [bit 12]
        lui   $t0, 0xff00
        ori   $t0, $t0, 420
        sw    $t0, -208($zero)
        lui   $t0, 0x0180
        ori   $t0, $t0, 0x8580        # 25 200 000
        sw    $t0, -244($zero)
        addiu $t0, $zero, 1
        sw    $t0, -236($zero)        # ARM
        addiu $t0, $zero, 0xff
        sw    $t0, -184($zero)
        addiu $t9, $zero, 100         # ~20 ms không được có bit 3
v12:    lw    $t1, -184($zero)
        andi  $t2, $t1, 0x08
        bne   $t2, $zero, k12
        addiu $t9, $t9, -1
        bne   $t9, $zero, v12
        lui   $t0, 0x0180
        ori   $t0, $t0, 0x857b        # 25 199 995
        sw    $t0, -244($zero)        # SET_MS
        addiu $t0, $zero, 1
        sw    $t0, -236($zero)        # ARM
        addiu $t0, $zero, 0xff
        sw    $t0, -184($zero)
        addiu $t9, $zero, 200
w12:    lw    $t1, -184($zero)
        andi  $t2, $t1, 0x08
        bne   $t2, $zero, g12
        addiu $t9, $t9, -1
        bne   $t9, $zero, w12
        j     k12
g12:    lui   $t0, 0x0080
        sw    $t0, -208($zero)        # tắt ALARM0, xóa HIT
        andi  $t1, $t1, 0x3c
        addiu $t2, $zero, 0x08
        bne   $t1, $t2, k12
        ori   $v0, $v0, 0x1000
k12:
# nút qua soc_top (tb nhấn C rồi A sau 60 ms, khi thấy SW SRC = 1)                          [bit 13]
#   C → chỉ bit 5 BTN (không chụp), BTN_EVENT mã 3; A → bit 4 SW_CAPTURE + bit 5, stopwatch chạy, mã 1
        addiu $t0, $zero, 0xff
        sw    $t0, -184($zero)
        addiu $t0, $zero, 4
        sw    $t0, -228($zero)        # SW_CTRL.SRC = 1
        addiu $t9, $zero, 400
u13:    lw    $t1, -184($zero)
        andi  $t2, $t1, 0x20
        bne   $t2, $zero, h13
        addiu $t9, $t9, -1
        bne   $t9, $zero, u13
        j     k13
h13:    andi  $t1, $t1, 0x3c
        addiu $t2, $zero, 0x20
        bne   $t1, $t2, k13
        lw    $t4, -192($zero)        # BTN_EVENT
        lui   $t5, 0xe000
        and   $t4, $t4, $t5
        bne   $t4, $t5, k13           # VALID, mã 11
        addiu $t0, $zero, 0xff
        sw    $t0, -184($zero)
        addiu $t9, $zero, 800
w13:    lw    $t1, -184($zero)
        andi  $t2, $t1, 0x20
        bne   $t2, $zero, g13
        addiu $t9, $t9, -1
        bne   $t9, $zero, w13
        j     k13
g13:    andi  $t1, $t1, 0x3c
        addiu $t2, $zero, 0x30
        bne   $t1, $t2, k13
        lw    $t3, -228($zero)
        andi  $t3, $t3, 1
        beq   $t3, $zero, k13         # RUN = 1
        lw    $t4, -192($zero)        # BTN_EVENT
        lui   $t5, 0xe000
        and   $t4, $t4, $t5
        lui   $t5, 0xa000             # VALID, mã 01
        bne   $t4, $t5, k13
        ori   $v0, $v0, 0x2000
k13:
        addiu $t0, $zero, 2
        sw    $t0, -228($zero)        # SW về CPU, RESET
# ---- TMR_ZERO + BEEP_EN → beeper nạp 0x10F0F bằng phần cứng (tb kiểm phía beeper, display-spec §5)   [bit 14]
        addiu $t0, $zero, 4
        sw    $t0, -124($zero)        # BEEP_FREQ = 4 chu kỳ (đủ nhanh để tb thấy chân beep đảo)
        addiu $t0, $zero, 0xff
        sw    $t0, -184($zero)
        addiu $t0, $zero, 1
        sw    $t0, -216($zero)        # TMR_VALUE = 1
        addiu $t0, $zero, 5
        sw    $t0, -212($zero)        # RUN + BEEP_EN
        addiu $t9, $zero, 200
w14:    lw    $t1, -184($zero)
        andi  $t2, $t1, 0x04
        bne   $t2, $zero, g14
        addiu $t9, $t9, -1
        bne   $t9, $zero, w14
        j     k14
g14:    addiu $t9, $zero, 40          # để chuông kêu ~ vài trăm chu kỳ
d14:    addiu $t9, $t9, -1
        bne   $t9, $zero, d14
        sw    $zero, -212($zero)      # dừng timer
        sw    $zero, -120($zero)      # BEEP_PATTERN = 0: tắt
        ori   $v0, $v0, 0x4000
k14:
end:    j     end
