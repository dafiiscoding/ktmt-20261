# Ngắt G1 (gói C5, isa-spec §5): C5-1…C5-4 + "IE = 0 thì không vào" + Status/Cause trong handler.
# Chạy trên cpu_g1_tb: irq_ctrl thật ở −188/−184/−180; −16 = máy phát sự kiện của tb (sw {trễ[23:8], bit[7:0]}).
# Handler ghi log vào DMEM: 0x800 = số lần vào; 0x804+4n = EPC, 0x844+4n = Status, 0x884+4n = Cause của lần n;
# 0x8C0 = mặt nạ handler ghi vào IRQ_PENDING (sau đó tự đặt lại 0xFF).
# Tự kiểm: mỗi ca đúng bật 1 bit của $v0. Không phụ thuộc cpu_ce (chạy được với COSIM_CEDIV 1…7).
# nomars
# expect $v0=0x7f
# expect $s0=5
# expect $s2=0
# expect $s3=4
# expect $t6=14
# expect $t7=2
        j     main
        .org  0x180
handler:
        lw    $k0, 0x800($zero)
        sll   $k0, $k0, 2
        mfc0  $k1, $14
        sw    $k1, 0x804($k0)
        mfc0  $k1, $12
        sw    $k1, 0x844($k0)
        mfc0  $k1, $13
        sw    $k1, 0x884($k0)
        lw    $k1, 0x8c0($zero)
        sw    $k1, -184($zero)       # IRQ_PENDING: ghi 1 để xóa
        addiu $k1, $zero, 0xff
        sw    $k1, 0x8c0($zero)
        sra   $k0, $k0, 2
        addiu $k0, $k0, 1
        sw    $k0, 0x800($zero)
        eret

main:   addiu $v0, $zero, 0
        addiu $t0, $zero, 0xff
        sw    $t0, 0x8c0($zero)
        addiu $t0, $zero, 0x08
        sw    $t0, -188($zero)       # IRQ_ENABLE = bit 3

# ---- IE = 0: có sự kiện, irq = 1, nhưng không vào handler                       [bit 0]
        sw    $t0, -16($zero)
        nop
        nop
        nop
        lw    $t1, 0x800($zero)
        bne   $t1, $zero, k0
        ori   $v0, $v0, 0x01
k0:
# ---- C5-3: irq đang chờ, mtc0 bật IE → không nhận ngay sau mtc0, nhận sau lệnh kế  [bit 1]
        addiu $t2, $zero, 1
        jal   L1
L1:     mtc0  $t2, $12
        addiu $s1, $zero, 7          # L1+4: chạy xong rồi mới vào handler
        lw    $t1, 0x804($zero)      # L1+8 = EPC lần 0
        addiu $t3, $ra, 8
        bne   $t1, $t3, k1
        ori   $v0, $v0, 0x02
k1:
# ---- trong handler: Status = EXL|IE = 3, Cause.IP = 0x08                       [bit 2]
        lw    $t1, 0x844($zero)
        addiu $t3, $zero, 3
        bne   $t1, $t3, k2
        lw    $t1, 0x884($zero)
        addiu $t3, $zero, 0x800
        bne   $t1, $t3, k2
        ori   $v0, $v0, 0x04
k2:
# ---- C5-2: ngắt nhận ngay sau beq nhảy → EPC = đích nhánh                       [bit 3]
        mtc0  $zero, $12             # IE = 0
        sw    $t0, -16($zero)
        nop
        nop
        mtc0  $t2, $12               # IE = 1 (chặn ở chính lệnh này)
        beq   $zero, $zero, T2       # ngắt nhận ở cuối lệnh này
        addiu $s2, $zero, 99         # không được chạy
T2:     jal   L2
L2:     lw    $t1, 0x808($zero)      # EPC lần 1
        addiu $t3, $ra, -4           # = T2
        bne   $t1, $t3, k3
        ori   $v0, $v0, 0x08
k3:
# ---- C5-1: sự kiện đến khi div đang busy → nhận sau khi div xong, EPC = lệnh sau div   [bit 4]
        addiu $t4, $zero, 100
        addiu $t5, $zero, 7
        ori   $t1, $zero, 0x1408     # trễ 20 chu kỳ hệ thống (rơi trong div ở cả G1 và G2), bit 3
        jal   L3
L3:     sw    $t1, -16($zero)
        div   $t4, $t5               # L3+4 (33 chu kỳ CPU)
        mflo  $t6                    # L3+8 = EPC lần 2
        mfhi  $t7
        lw    $t1, 0x80c($zero)
        addiu $t3, $ra, 8
        bne   $t1, $t3, k4
        ori   $v0, $v0, 0x10
k4:
# ---- C5-4: handler không xóa PENDING → eret, chạy đúng 1 lệnh, vào lại               [bit 5]
        sw    $zero, 0x8c0($zero)    # lần vào kế: không xóa (sau đó handler tự đặt 0xFF)
        sw    $t0, -16($zero)
        addiu $s3, $s3, 1
        addiu $s3, $s3, 1
        addiu $s3, $s3, 1
        addiu $s3, $s3, 1            # mỗi lệnh chạy đúng 1 lần → $s3 = 4
        lw    $t1, 0x810($zero)      # EPC lần 3
        lw    $t3, 0x814($zero)      # EPC lần 4
        addiu $t1, $t1, 4
        bne   $t1, $t3, k5
        ori   $v0, $v0, 0x20
k5:
# ---- chặn sau mtc0: irq chờ sẵn, mtc0 bật IE rồi mtc0 tắt IE liền sau → không được vào  [bit 6]
#      (ở mtc0 thứ hai Status cũ có IE = 1; nếu không chặn thì mtc0 ghi Status và ngắt ghi EXL cùng cạnh)
        mtc0  $zero, $12             # IE = 0
        sw    $t0, -16($zero)
        nop
        nop
        mtc0  $t2, $12               # IE = 1
        mtc0  $zero, $12             # IE = 0 — ngắt bị chặn ở cả 2 lệnh
        lw    $t1, 0x800($zero)
        addiu $t3, $zero, 5
        bne   $t1, $t3, k6
        ori   $v0, $v0, 0x40
k6:     addiu $t0, $zero, 0xff
        sw    $t0, -184($zero)       # dọn PENDING
        lw    $s0, 0x800($zero)      # tổng số lần vào = 5
