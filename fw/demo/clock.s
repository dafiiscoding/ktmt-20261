# clock.s — firmware demo: đồng hồ chạy trên CPU G1 thật trong soc_top (thay phần "firmware giả" của clock_demo_tb).
# KHÔNG phải main.s (gói B7 của TV2): chỉ chế độ TIME, không nút, không nháy. Dùng ngắt TICK_1S.
# Dịch: python tools/fw_build.py fw/demo/clock.s work/clock.hex   (MARS + vá bcd + .org)
# Chạy: bash tools/run_unit.sh soc_clock  → màn ảo work/screen_soc_clock.log (python tools/screen.py ...)
# Bộ nhớ: 0x800 = cờ "sang giây mới" (handler đặt, vòng chính xóa); $sp = 0xff8.
        j     main

        .org  0x180
handler:                                # nguồn duy nhất được bật: TICK_1S (bit 1)
        addiu $k0, $zero, 2
        sw    $k0, -184($zero)          # IRQ_PENDING: xóa bit 1
        addiu $k1, $zero, 1
        sw    $k1, 0x800($zero)
        eret

main:   ori   $sp, $zero, 0xff8
        lui   $t0, 0x0526
        ori   $t0, $t0, 0x4878          # 86 395 000 ms = 23:59:55.000
        sw    $t0, -244($zero)          # SET_MS
        lui   $t0, 5
        ori   $t0, $t0, 0x262b          # dow 5 (Thứ Sáu), day 9771 (02/10/2026)
        sw    $t0, -240($zero)          # SET_DAY
        addiu $t0, $zero, 1
        sw    $t0, -236($zero)          # RTC_CTRL.ARM: nạp ở tick ms kế
wait:   lw    $t0, -236($zero)
        bne   $t0, $zero, wait          # chờ nạp xong (TICK_1S cũng đếm lại từ đây)
        jal   show
        addiu $t0, $zero, 2
        sw    $t0, -188($zero)          # IRQ_ENABLE = TICK_1S
        addiu $t0, $zero, 1
        mtc0  $t0, $12                  # Status.IE = 1
loop:   lw    $t0, 0x800($zero)
        beq   $t0, $zero, loop
        sw    $zero, 0x800($zero)
        jal   show
        j     loop

# show: đọc MS_OF_DAY → ghi DISP7…0 dạng "__HH.MM.SS" (display-spec §8). Dùng div (3 lần) + mul + bcd.
show:   lw    $t0, -252($zero)          # MS_OF_DAY
        addiu $t1, $zero, 1000
        div   $t0, $t1
        mflo  $t0                       # giây trong ngày
        addiu $t1, $zero, 3600
        div   $t0, $t1
        mflo  $t2                       # giờ
        mfhi  $t0                       # giây trong giờ
        addiu $t1, $zero, 60
        div   $t0, $t1
        mflo  $t3                       # phút
        mfhi  $t4                       # giây
        addiu $t1, $zero, 10000
        mul   $t2, $t2, $t1
        addiu $t1, $zero, 100
        mul   $t3, $t3, $t1
        addu  $t2, $t2, $t3
        addu  $t2, $t2, $t4             # HHMMSS (thập phân)
        bcd   $t2, $t2                  # → 0x00HHMMSS
        andi  $t1, $t2, 0xf
        sw    $t1, -164($zero)          # DISP0 = giây đơn vị
        sra   $t2, $t2, 4
        andi  $t1, $t2, 0xf
        sw    $t1, -160($zero)          # DISP1 = giây chục
        sra   $t2, $t2, 4
        andi  $t1, $t2, 0xf
        ori   $t1, $t1, 0x80
        sw    $t1, -156($zero)          # DISP2 = phút đơn vị + dấu chấm
        sra   $t2, $t2, 4
        andi  $t1, $t2, 0xf
        sw    $t1, -152($zero)          # DISP3 = phút chục
        sra   $t2, $t2, 4
        andi  $t1, $t2, 0xf
        ori   $t1, $t1, 0x80
        sw    $t1, -148($zero)          # DISP4 = giờ đơn vị + dấu chấm
        sra   $t2, $t2, 4
        andi  $t1, $t2, 0xf
        sw    $t1, -144($zero)          # DISP5 = giờ chục
        addiu $t1, $zero, 0x1a
        sw    $t1, -140($zero)          # DISP6, DISP7 trống
        sw    $t1, -136($zero)
        jr    $ra
