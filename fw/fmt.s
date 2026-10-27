# fmt.s — 3 cách đổi ms trong ngày → màn TIME 24 h "__HH.MM.SS" (DISP7…0, display-spec §8), đo chi phí cho plan §8.1.
# Gói B7 · bản đầu 26/10/2026, Claude viết theo yêu cầu Long; TV2 đọc hiểu để vấn đáp.
#   fmt_div: chỉ div (6 lần)          fmt_bcd: 3 div + 2 mul + 1 bcd          fmt_hw: đọc RTC_BCD, chỉ dịch + mặt nạ
# Cả 3: vào $a0 = ms (fmt_hw bỏ qua $a0, lấy giờ từ RTC_BCD), ghi thẳng DISP0…DISP7 (DISP7 cuối = 1 khung), chỉ dùng
# $t0–$t4, không gọi hàm khác, không đụng $a0/$s*.
# Chạy như chương trình (bench): nạp RTC_BCD = 12:34:56.789, rồi đo ΔCYCLE_COUNT quanh từng lần gọi → DMEM RES…;
# ghi dấu xong vào −108 rồi "j .". DMEM 0x7F0 ≠ 0 → đặt CPU_CLK_DIV trước khi đo (tb -DSLOW). Test: ISS gọi thẳng từng hàm (tools/test_iss.py B2-4); RTL: tb/fmt_bench_tb.v.
        .eqv  RES  0x100                # word: 0 nop, 1–2 div/bcd(0), 3–4 div/bcd(12:34:56.789), 5–6 div/bcd(23:59:59.999), 7 hw

        j     bench

        .org  0x180
        eret                            # không bật ngắt

bench:  lw    $t0, 0x7f0($zero)         # tb ghi trước CPU_CLK_DIV muốn đo (vd. 1526); 0 = giữ mặc định
        beq   $t0, $zero, b1
        sw    $t0, -116($zero)
b1:     lui   $t0, 0x49a5
        ori   $t0, $t0, 0x6789          # 12:34:56.789 dạng RTC_BCD (timer-spec §8)
        sw    $t0, -104($zero)
        lw    $s0, -256($zero)          # nền: gọi hàm rỗng → chi phí jal + jr + lw
        jal   fmt_nop
        lw    $s1, -256($zero)
        subu  $s1, $s1, $s0
        sw    $s1, RES($zero)

        addu  $a0, $zero, $zero
        lw    $s0, -256($zero)
        jal   fmt_div
        lw    $s1, -256($zero)
        subu  $s1, $s1, $s0
        sw    $s1, 0x104($zero)
        lw    $s0, -256($zero)
        jal   fmt_bcd
        lw    $s1, -256($zero)
        subu  $s1, $s1, $s0
        sw    $s1, 0x108($zero)

        li    $a0, 45296789             # 12:34:56.789
        lw    $s0, -256($zero)
        jal   fmt_div
        lw    $s1, -256($zero)
        subu  $s1, $s1, $s0
        sw    $s1, 0x10c($zero)
        lw    $s0, -256($zero)
        jal   fmt_bcd
        lw    $s1, -256($zero)
        subu  $s1, $s1, $s0
        sw    $s1, 0x110($zero)

        li    $a0, 86399999             # 23:59:59.999
        lw    $s0, -256($zero)
        jal   fmt_div
        lw    $s1, -256($zero)
        subu  $s1, $s1, $s0
        sw    $s1, 0x114($zero)
        lw    $s0, -256($zero)
        jal   fmt_bcd
        lw    $s1, -256($zero)
        subu  $s1, $s1, $s0
        sw    $s1, 0x118($zero)

        lw    $s0, -256($zero)
        jal   fmt_hw
        lw    $s1, -256($zero)
        subu  $s1, $s1, $s0
        sw    $s1, 0x11c($zero)

        sw    $zero, -108($zero)        # dấu xong (địa chỉ MMIO trống)
end:    j     end

fmt_nop: jr   $ra

# fmt_div: chỉ div. ms → giây trong ngày → giờ, phút, giây → mỗi số 2 chữ số bằng div 10
fmt_div: ori  $t1, $zero, 1000
        div   $a0, $t1
        mflo  $t0                       # giây trong ngày
        addiu $t1, $zero, 3600
        div   $t0, $t1
        mflo  $t2                       # giờ
        mfhi  $t0
        addiu $t1, $zero, 60
        div   $t0, $t1
        mflo  $t3                       # phút
        mfhi  $t4                       # giây
        addiu $t1, $zero, 10
        div   $t4, $t1
        mflo  $t0
        sw    $t0, -160($zero)          # DISP1 chục giây
        mfhi  $t0
        sw    $t0, -164($zero)          # DISP0 đơn vị giây
        div   $t3, $t1
        mflo  $t0
        sw    $t0, -152($zero)          # DISP3 chục phút
        mfhi  $t0
        ori   $t0, $t0, 0x80
        sw    $t0, -156($zero)          # DISP2 đơn vị phút + chấm
        div   $t2, $t1
        mflo  $t0
        sw    $t0, -144($zero)          # DISP5 chục giờ
        mfhi  $t0
        ori   $t0, $t0, 0x80
        sw    $t0, -148($zero)          # DISP4 đơn vị giờ + chấm
        addiu $t0, $zero, 0x1a          # trống
        sw    $t0, -140($zero)
        sw    $t0, -136($zero)          # DISP7 cuối
        jr    $ra

# fmt_bcd: tách giờ/phút/giây bằng 3 div, ghép HHMMSS bằng 2 mul, đổi sang 6 chữ số bằng 1 lệnh bcd
fmt_bcd: ori  $t1, $zero, 1000
        div   $a0, $t1
        mflo  $t0
        addiu $t1, $zero, 3600
        div   $t0, $t1
        mflo  $t2                       # giờ
        mfhi  $t0
        addiu $t1, $zero, 60
        div   $t0, $t1
        mflo  $t3                       # phút
        mfhi  $t4                       # giây
        addiu $t1, $zero, 100
        mul   $t2, $t2, $t1
        addu  $t2, $t2, $t3
        mul   $t2, $t2, $t1
        addu  $t2, $t2, $t4             # HHMMSS
        bcd   $t0, $t2
        andi  $t1, $t0, 0xf
        sw    $t1, -164($zero)
        sra   $t0, $t0, 4
        andi  $t1, $t0, 0xf
        sw    $t1, -160($zero)
        sra   $t0, $t0, 4
        andi  $t1, $t0, 0xf
        ori   $t1, $t1, 0x80
        sw    $t1, -156($zero)
        sra   $t0, $t0, 4
        andi  $t1, $t0, 0xf
        sw    $t1, -152($zero)
        sra   $t0, $t0, 4
        andi  $t1, $t0, 0xf
        ori   $t1, $t1, 0x80
        sw    $t1, -148($zero)
        sra   $t0, $t0, 4
        andi  $t1, $t0, 0xf
        sw    $t1, -144($zero)
        addiu $t0, $zero, 0x1a
        sw    $t0, -140($zero)
        sw    $t0, -136($zero)
        jr    $ra

# fmt_hw: RTC_BCD đã là chữ số → chỉ dịch + mặt nạ (sra được vì luôn andi sau khi dịch)
fmt_hw: lw    $t0, -104($zero)
        sra   $t1, $t0, 12
        andi  $t1, $t1, 0xf
        sw    $t1, -164($zero)          # đơn vị giây [15:12]
        sra   $t1, $t0, 16
        andi  $t1, $t1, 0x7
        sw    $t1, -160($zero)          # chục giây [18:16]
        sra   $t1, $t0, 19
        andi  $t1, $t1, 0xf
        ori   $t1, $t1, 0x80
        sw    $t1, -156($zero)          # đơn vị phút [22:19]
        sra   $t1, $t0, 23
        andi  $t1, $t1, 0x7
        sw    $t1, -152($zero)          # chục phút [25:23]
        sra   $t1, $t0, 26
        andi  $t1, $t1, 0xf
        ori   $t1, $t1, 0x80
        sw    $t1, -148($zero)          # đơn vị giờ [29:26]
        sra   $t1, $t0, 30
        andi  $t1, $t1, 0x3
        sw    $t1, -144($zero)          # chục giờ [31:30]
        addiu $t0, $zero, 0x1a
        sw    $t0, -140($zero)
        sw    $t0, -136($zero)
        jr    $ra
