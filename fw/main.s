# main.s — firmware đồng hồ: 5 chế độ TIME → STOPWATCH → TIMER → ALARM → SET (plan §2), bố cục màn display-spec §8.
# Gói B7 (main) + E5 (SET) + D6 (alarm/snooze/chuông giờ) · bản đầu 03/10/2026, Claude viết theo yêu cầu Long;
# các chủ gói (TV2, TV5, TV4) đọc hiểu, tách file khi có asm.py (B1). Chỉ dùng 28 lệnh G1 (isa-spec).
# Dịch: python tools/fw_build.py fw/main.s work/main.hex · Test: bash tools/run_unit.sh system (system_tb, kịch bản 1–6)
#
# Vòng chính: events (1 sự kiện nút) → ringchk (timer/báo thức/snooze/chuông giờ) → sync (câu UART) → draw (ghi màn).
# Ngắt (USE_IRQ = 1, từ 26/10): chỉ UART_RX — handler 0x180 gom byte + chụp giờ lúc '\n' đến (sy_rx); mọi việc khác
# vẫn polling. USE_IRQ = 0: sync gọi sy_rx mỗi vòng (giờ chụp trễ ≤ 1 vòng chính).
# Quyết định của bản này (plan §2 chưa nói, ghi vào goi-viec):
#   - TIME: B xoay vòng giờ → giây.ms → ngày (nút chỉ báo lúc nhấn, không biết "giữ"); A 12/24 h; C độ sáng 15 → 9 → 3.
#   - STOPWATCH: A/B nối thẳng phần cứng (SRC = 1); firmware chỉ lấy lap khỏi FIFO, B khi dừng = RESET, C xem lap
#     (DISP7 = số thứ tự lap đang xem — display-spec chưa có bố cục này).
#   - ALARM: B chọn AL1…AL4 → trang chuông giờ "CH o"; A bật/tắt; C (không chuông) sửa giờ/phút báo thức
#     (B đổi trường, A +1, C lưu). Snooze = C khi đang chuông báo thức, 5 phút tính từ lúc nhấn (dấu thời gian BTN_EVENT).
#   - Đang chuông: nút đầu tiên chỉ tắt chuông (không làm việc khác, không bíp). Chuông tự tắt sau 60 s.
#   - SET: trường giờ, phút, giây (A → 00), ngày, tháng, năm (2000–2099); đổi tháng/năm thì kẹp ngày (31/01 → 28 hoặc 29/02).
#   - Khối cấu hình khởi động ở DMEM 0x7E0 (tb ghi trước reset; chip thật: SET/sync): MAGIC ≠ 0 thì nạp giờ + giá trị đặt timer.
# Biến (DMEM, byte):
        .eqv  V_MODE  0x400             # 0 TIME, 1 STOPWATCH, 2 TIMER, 3 ALARM, 4 SET
        .eqv  V_TV    0x404             # TIME: 0 giờ, 1 giây.ms, 2 ngày
        .eqv  V_H12   0x408
        .eqv  V_BRI   0x40c
        .eqv  V_PRE   0x410             # giá trị đặt timer (ms)
        .eqv  V_ALK   0x414             # 0…3 = AL1…AL4, 4 = chuông giờ
        .eqv  V_CHIME 0x418
        .eqv  V_LASTH 0x41c             # giờ lần trước (−1 = vừa nạp giờ)
        .eqv  V_RING  0x420             # 0 im, 1 timer, 2 báo thức
        .eqv  V_RINGT 0x424             # ms trong ngày lúc bắt đầu chuông
        .eqv  V_SNZ   0x428             # giờ kêu lại (ms trong ngày)
        .eqv  V_SNZON 0x42c
        .eqv  V_LAPN  0x430             # số lap đã lấy (≤ 8)
        .eqv  V_LAPI  0x434             # 0 = hiện giá trị chạy, k = xem lap k
        .eqv  V_SF    0x438             # SET: trường đang chỉnh 0…5
        .eqv  V_AED   0x43c             # ALARM: 0 không sửa, 1 giờ, 2 phút
        .eqv  V_LAPV  0x440             # 8 word
        .eqv  V_SH    0x460             # SET: giờ, phút, giây, ngày, tháng, năm−2000 (liên tiếp, chỉ số = trường)
        .eqv  V_SM    0x464
        .eqv  V_SS    0x468
        .eqv  V_SD    0x46c
        .eqv  V_SMO   0x470
        .eqv  V_SY    0x474
        .eqv  V_AEH   0x478
        .eqv  V_AEM   0x47c
        .eqv  D0      0x480             # bộ đệm màn: D0 = DISP0 (phải nhất) … D7
        .eqv  D2      0x488
        .eqv  D3      0x48c
        .eqv  D4      0x490
        .eqv  D5      0x494
        .eqv  D6      0x498
        .eqv  D7      0x49c
        .eqv  V_SLEN  0x4a0             # sync: số byte câu đang gom (33 = câu quá dài, bỏ tới '\n')
        .eqv  V_SQMS  0x4a4             # sync: MS_OF_DAY, DAY_SHADOW chụp lúc nhận '\n'
        .eqv  V_SQDY  0x4a8
        .eqv  V_T1OK  0x4ac             # sync: đã có lần đặt giờ trước (T1) để tính CAL
        .eqv  V_T1MS  0x4b0
        .eqv  V_T1DY  0x4b4
        .eqv  V_SRDY  0x4b8             # sync: 1 = sy_rx đã gom xong 1 câu (tới '\n'), chờ sync xử lý
        .eqv  V_DACC  0x4bc             # sync: tổng D của các lần đặt giờ xen giữa (giữ T1)
        .eqv  V_SBUF  0x4c0             # sync: câu, 1 byte/word, tối đa 32 (0x4C0…0x53C)
        .eqv  V_SBUF1 0x4c4
        .eqv  V_SBUF2 0x4c8
        .eqv  V_IT0   0x540             # handler: chỗ cất $t0–$t2
        .eqv  V_IT1   0x544
        .eqv  V_IT2   0x548
        .eqv  V_RLEN  0x550             # sync, bộ đệm NHẬN (sy_rx gom): số byte, như V_SLEN
        .eqv  V_RQMS  0x554             # giờ chụp lúc '\n' của câu trong bộ đệm nhận
        .eqv  V_RQDY  0x558
        .eqv  V_RRDY  0x55c             # 1 = bộ đệm nhận đủ 1 câu, chờ bộ đệm xử lý (V_SBUF) trống
        .eqv  V_RBUF  0x560             # 32 word (0x560…0x5DC)
        .eqv  USE_IRQ 1                 # 1 = ngắt UART_RX; 0 = polling hoàn toàn
        .eqv  CFG_MAG 0x7e0
        .eqv  CFG_MS  0x7e4
        .eqv  CFG_DAY 0x7e8
        .eqv  CFG_PRE 0x7ec

        j     boot

        .org  0x180                     # chỉ UART_RX được bật (IRQ_ENABLE = 0x40) → không cần xét Cause
        sw    $t0, V_IT0($zero)
        sw    $t1, V_IT1($zero)
        sw    $t2, V_IT2($zero)
        addu  $k1, $ra, $zero
        addiu $k0, $zero, 0x40
        sw    $k0, -184($zero)          # xóa PENDING bit 6 TRƯỚC khi lấy byte: byte đến sau đó bật lại → vào lại handler
        jal   sy_rx
        addu  $ra, $k1, $zero
        lw    $t0, V_IT0($zero)
        lw    $t1, V_IT1($zero)
        lw    $t2, V_IT2($zero)
        eret

boot:   lw    $t0, CFG_MAG($zero)
        beq   $t0, $zero, b_def
        lw    $t0, CFG_MS($zero)
        sw    $t0, -244($zero)          # SET_MS
        lw    $t0, CFG_DAY($zero)
        sw    $t0, -240($zero)          # SET_DAY
        addiu $t0, $zero, 1
        sw    $t0, -236($zero)          # RTC_CTRL.ARM
b_wait: lw    $t0, -236($zero)
        bne   $t0, $zero, b_wait        # chờ nạp xong
        lw    $t0, CFG_PRE($zero)
        j     b_pre
b_def:  ori   $t0, $zero, 60000         # timer mặc định 01:00.000
b_pre:  sw    $t0, V_PRE($zero)
        sw    $t0, -216($zero)          # TMR_VALUE
        addiu $t0, $zero, 4
        sw    $t0, -212($zero)          # TMR_CTRL = BEEP_EN
        lui   $t0, 0x3e00               # AL1: 07:00, thứ 2 → thứ 6, tắt
        ori   $t0, $t0, 420
        sw    $t0, -208($zero)
        lui   $t0, 0x7f00               # AL2…AL4: 00:00, mọi ngày, tắt
        sw    $t0, -204($zero)
        sw    $t0, -200($zero)
        sw    $t0, -196($zero)
        addiu $t0, $zero, -1
        sw    $t0, V_LASTH($zero)
        addiu $t0, $zero, 15
        sw    $t0, V_BRI($zero)
        addiu $t0, $zero, USE_IRQ
        sll   $t0, $t0, 6
        sw    $t0, -188($zero)          # IRQ_ENABLE = UART_RX (nếu USE_IRQ); Status.IE bật trong sync

loop:   jal   events
        jal   ringchk
        jal   sync
        jal   draw
        j     loop

# ======================================================================== nút
events: lw    $t0, -192($zero)          # BTN_EVENT (đọc = lấy khỏi FIFO)
        slt   $t1, $t0, $zero           # VALID = bit 31
        beq   $t1, $zero, ev_ret
        sra   $t1, $t0, 29
        andi  $a0, $t1, 3               # mã nút: 0 MODE, 1 A, 2 B, 3 C
        lui   $t1, 0x07ff
        ori   $t1, $t1, 0xffff
        and   $a1, $t0, $t1             # MS_OF_DAY lúc nhấn
        lw    $t2, V_RING($zero)
        beq   $t2, $zero, ev_norm
        sw    $zero, -120($zero)        # đang chuông: tắt, nuốt nút
        sw    $zero, V_RING($zero)
        addiu $t1, $zero, 3
        bne   $a0, $t1, ev_ret
        addiu $t1, $zero, 2
        bne   $t2, $t1, ev_ret
        lui   $t1, 4                    # C khi chuông báo thức: snooze = lúc nhấn + 300 000 ms (quay vòng ngày)
        ori   $t1, $t1, 0x93e0
        addu  $a1, $a1, $t1
        lui   $t1, 0x0526
        ori   $t1, $t1, 0x5c00          # 86 400 000
        slt   $t2, $a1, $t1
        bne   $t2, $zero, ev_snz
        subu  $a1, $a1, $t1
ev_snz: sw    $a1, V_SNZ($zero)
        addiu $t1, $zero, 1
        sw    $t1, V_SNZON($zero)
ev_ret: jr    $ra

ev_norm: addiu $t1, $zero, 1
        sw    $t1, -120($zero)          # bíp nút: BEEP_PATTERN = 0x00001
        lw    $t3, V_MODE($zero)
        bne   $a0, $zero, ev_btn
        addiu $t1, $zero, 1             # ---- MODE: rời chế độ cũ
        bne   $t3, $t1, em1
        lw    $t0, -228($zero)          # rời STOPWATCH: SRC = 0, giữ RUN
        andi  $t0, $t0, 1
        sw    $t0, -228($zero)
        sw    $zero, V_LAPI($zero)
em1:    sw    $zero, -132($zero)        # BLINK_MASK = 0 (rời SET / sửa báo thức)
        sw    $zero, V_AED($zero)
        addiu $t3, $t3, 1
        addiu $t1, $zero, 5
        bne   $t3, $t1, em2
        addu  $t3, $zero, $zero
em2:    sw    $t3, V_MODE($zero)
        addiu $t1, $zero, 1
        bne   $t3, $t1, em3
        addiu $t0, $zero, 4
        sw    $t0, -228($zero)          # vào STOPWATCH: SRC = 1 (A/B nối thẳng phần cứng, không đổi RUN)
        jr    $ra
em3:    addiu $t1, $zero, 4
        beq   $t3, $t1, set_in
        jr    $ra

ev_btn: beq   $t3, $zero, tm_btn
        addiu $t1, $zero, 1
        beq   $t3, $t1, sw_btn
        addiu $t1, $zero, 2
        beq   $t3, $t1, tr_btn
        addiu $t1, $zero, 3
        beq   $t3, $t1, al_btn
        j     st_btn

# ---- TIME
tm_btn: addiu $t1, $zero, 1
        bne   $a0, $t1, tm_b
        lw    $t0, V_H12($zero)         # A: 12/24 h
        subu  $t0, $t1, $t0
        sw    $t0, V_H12($zero)
        jr    $ra
tm_b:   addiu $t1, $zero, 2
        bne   $a0, $t1, tm_c
        lw    $t0, V_TV($zero)          # B: giờ → giây.ms → ngày → giờ
        addiu $t0, $t0, 1
        addiu $t1, $zero, 3
        bne   $t0, $t1, tm_b1
        addu  $t0, $zero, $zero
tm_b1:  sw    $t0, V_TV($zero)
        jr    $ra
tm_c:   lw    $t0, V_BRI($zero)         # C: độ sáng 15 → 9 → 3 → 15
        addiu $t0, $t0, -6
        slti  $t1, $t0, 1
        beq   $t1, $zero, tm_c1
        addiu $t0, $zero, 15
tm_c1:  sw    $t0, V_BRI($zero)
        sw    $t0, -128($zero)          # BRIGHT
        jr    $ra

# ---- STOPWATCH (A/B đã tác động phần cứng ở cạnh nhấn)
sw_btn: addiu $t1, $zero, 2
        beq   $a0, $t1, sw_b
        addiu $t1, $zero, 3
        beq   $a0, $t1, sw_c
        sw    $zero, V_LAPI($zero)      # A: thôi xem lap
        jr    $ra
sw_b:   lw    $t0, -228($zero)
        andi  $t0, $t0, 1
        bne   $t0, $zero, sw_r          # đang chạy: phần cứng đã chụp lap
        addiu $t0, $zero, 6
        sw    $t0, -228($zero)          # đang dừng: RESET, giữ SRC = 1
        sw    $zero, V_LAPN($zero)
        sw    $zero, V_LAPI($zero)
sw_r:   jr    $ra
sw_c:   lw    $t0, V_LAPI($zero)        # C: lap 1 → … → lap n → giá trị chạy
        lw    $t1, V_LAPN($zero)
        addiu $t0, $t0, 1
        slt   $t2, $t1, $t0
        beq   $t2, $zero, sw_c1
        addu  $t0, $zero, $zero
sw_c1:  sw    $t0, V_LAPI($zero)
        jr    $ra

# ---- TIMER
tr_btn: lw    $t0, -212($zero)          # TMR_CTRL
        andi  $t2, $t0, 1               # RUN
        addiu $t1, $zero, 1
        bne   $a0, $t1, tr_b
        andi  $t0, $t0, 0xc             # A: đảo RUN, giữ BEEP_EN/SAT, không xóa ZERO
        bne   $t2, $zero, tr_a1
        ori   $t0, $t0, 1
tr_a1:  sw    $t0, -212($zero)
        jr    $ra
tr_b:   addiu $t1, $zero, 2
        bne   $a0, $t1, tr_c
tr_rst: lw    $t0, V_PRE($zero)         # B: về giá trị đặt, dừng, xóa ZERO
        sw    $t0, -216($zero)
        addiu $t0, $zero, 6
        sw    $t0, -212($zero)
        jr    $ra
tr_c:   bne   $t2, $zero, tr_r          # C khi dừng: +1 phút (≥ 60 phút thì quay về)
        lw    $t0, V_PRE($zero)
        ori   $t1, $zero, 60000
        addu  $t0, $t0, $t1
        lui   $t1, 0x36
        ori   $t1, $t1, 0xee80          # 3 600 000
        slt   $t2, $t0, $t1
        bne   $t2, $zero, tr_c1
        subu  $t0, $t0, $t1
tr_c1:  sw    $t0, V_PRE($zero)
        j     tr_rst
tr_r:   jr    $ra

# ---- ALARM
al_btn: lw    $t4, V_ALK($zero)
        lw    $t5, V_AED($zero)
        sll   $t6, $t4, 2
        addiu $t6, $t6, -208            # offset ALARMk
        addiu $t1, $zero, 1
        bne   $a0, $t1, al_b
        bne   $t5, $zero, al_inc
        addiu $t1, $zero, 4
        bne   $t4, $t1, al_en
        lw    $t0, V_CHIME($zero)       # A ở trang chuông giờ: bật/tắt
        addiu $t1, $zero, 1
        subu  $t0, $t1, $t0
        sw    $t0, V_CHIME($zero)
        jr    $ra
al_en:  lw    $t0, 0($t6)               # A: đảo EN (ghi lại cả DAYMASK, MINUTE; HIT đọc = 1 thì ghi xóa luôn)
        lui   $t1, 0x8000
        xor   $t0, $t0, $t1
        sw    $t0, 0($t6)
        jr    $ra
al_inc: addiu $t1, $zero, 1             # A khi sửa: +1 giờ (23 → 0) / +1 phút (59 → 0)
        bne   $t5, $t1, al_im
        lw    $t0, V_AEH($zero)
        addiu $t0, $t0, 1
        addiu $t1, $zero, 24
        bne   $t0, $t1, al_ih
        addu  $t0, $zero, $zero
al_ih:  sw    $t0, V_AEH($zero)
        jr    $ra
al_im:  lw    $t0, V_AEM($zero)
        addiu $t0, $t0, 1
        addiu $t1, $zero, 60
        bne   $t0, $t1, al_im1
        addu  $t0, $zero, $zero
al_im1: sw    $t0, V_AEM($zero)
        jr    $ra
al_b:   addiu $t1, $zero, 2
        bne   $a0, $t1, al_c
        bne   $t5, $zero, al_bf
        addiu $t4, $t4, 1               # B: AL1 → AL4 → chuông giờ → AL1
        addiu $t1, $zero, 5
        bne   $t4, $t1, al_b1
        addu  $t4, $zero, $zero
al_b1:  sw    $t4, V_ALK($zero)
        jr    $ra
al_bf:  addiu $t1, $zero, 3             # B khi sửa: giờ ↔ phút
        subu  $t5, $t1, $t5
        sw    $t5, V_AED($zero)
        j     al_bl
al_c:   addiu $t1, $zero, 4
        beq   $t4, $t1, al_r
        bne   $t5, $zero, al_sv
        lw    $t0, 0($t6)               # C: bắt đầu sửa giờ báo thức
        andi  $t0, $t0, 0x7ff
        addiu $t1, $zero, 60
        div   $t0, $t1
        mflo  $t2
        sw    $t2, V_AEH($zero)
        mfhi  $t2
        sw    $t2, V_AEM($zero)
        addiu $t5, $zero, 1
        sw    $t5, V_AED($zero)
al_bl:  addiu $t0, $zero, 0x0c          # nháy: giờ = DISP3,2; phút = DISP1,0
        addiu $t1, $zero, 1
        beq   $t5, $t1, al_bl1
        addiu $t0, $zero, 0x03
al_bl1: sw    $t0, -132($zero)
al_r:   jr    $ra
al_sv:  lw    $t0, 0($t6)               # C khi sửa: lưu MINUTE, giữ EN + DAYMASK, HIT ghi 0 = giữ
        lui   $t1, 0xff00
        and   $t0, $t0, $t1
        lw    $t2, V_AEH($zero)
        addiu $t1, $zero, 60
        mul   $t2, $t2, $t1
        lw    $t1, V_AEM($zero)
        addu  $t2, $t2, $t1
        or    $t0, $t0, $t2
        sw    $t0, 0($t6)
        sw    $zero, V_AED($zero)
        sw    $zero, -132($zero)
        jr    $ra

# ---- SET (gói E5)
set_in: addu  $s7, $ra, $zero           # vào SET: chụp giờ + ngày hiện tại vào các trường
        mtc0  $zero, $12                # tắt ngắt: handler đọc MS_OF_DAY sẽ chụp lại DAY_SHADOW giữa cặp
        lw    $t0, -252($zero)          # MS_OF_DAY rồi DAY_SHADOW
        lw    $a0, -248($zero)
        addiu $t1, $zero, USE_IRQ
        mtc0  $t1, $12
        ori   $t1, $zero, 1000
        div   $t0, $t1
        mflo  $t0
        addiu $t1, $zero, 3600
        div   $t0, $t1
        mflo  $t2
        sw    $t2, V_SH($zero)
        mfhi  $t0
        addiu $t1, $zero, 60
        div   $t0, $t1
        mflo  $t2
        sw    $t2, V_SM($zero)
        mfhi  $t2
        sw    $t2, V_SS($zero)
        andi  $a0, $a0, 0xffff
        jal   d2ymd
        sw    $t5, V_SD($zero)
        sw    $a0, V_SMO($zero)
        slti  $t1, $a1, 100             # SET chỉ chỉnh 2000–2099
        bne   $t1, $zero, set_y
        addiu $a1, $a1, -100
set_y:  sw    $a1, V_SY($zero)
        addu  $t4, $zero, $zero
        j     st_f

st_btn: addu  $s7, $ra, $zero
        lw    $t4, V_SF($zero)
        addiu $t1, $zero, 2
        beq   $a0, $t1, st_b
        addiu $t1, $zero, 3
        beq   $a0, $t1, st_sv
        sll   $t6, $t4, 2               # ---- A: +1 trường t4
        lw    $t0, V_SH($t6)
        addiu $t0, $t0, 1
        addiu $t1, $zero, 2
        bne   $t4, $t1, st_a1
        addu  $t0, $zero, $zero         # giây: A → 00
st_a1:  addiu $t2, $zero, 24            # $t2 = giá trị vượt, $t3 = giá trị quay về
        addu  $t3, $zero, $zero
        beq   $t4, $zero, st_w
        addiu $t2, $zero, 60
        slti  $t1, $t4, 3
        bne   $t1, $zero, st_w          # phút, giây
        addiu $t3, $zero, 1
        addiu $t2, $zero, 13
        addiu $t1, $zero, 4
        beq   $t4, $t1, st_w            # tháng
        addiu $t2, $zero, 100
        addu  $t3, $zero, $zero
        addiu $t1, $zero, 5
        beq   $t4, $t1, st_w            # năm
        lw    $a0, V_SMO($zero)         # ngày: vượt số ngày của tháng → 1
        lw    $a1, V_SY($zero)
        jal   mlen
        addiu $t2, $v0, 1
        addiu $t3, $zero, 1
st_w:   bne   $t0, $t2, st_w1
        addu  $t0, $t3, $zero
st_w1:  sw    $t0, V_SH($t6)
        lw    $a0, V_SMO($zero)         # kẹp ngày theo tháng/năm mới
        lw    $a1, V_SY($zero)
        jal   mlen
        lw    $t0, V_SD($zero)
        slt   $t1, $v0, $t0
        beq   $t1, $zero, st_r
        sw    $v0, V_SD($zero)
st_r:   jr    $s7
st_b:   addiu $t4, $t4, 1               # ---- B: trường kế (giờ, phút, giây, ngày, tháng, năm)
        addiu $t1, $zero, 6
        bne   $t4, $t1, st_f
        addu  $t4, $zero, $zero
st_f:   sw    $t4, V_SF($zero)
        addiu $t0, $zero, 0x30          # BLINK_MASK theo display-spec §8
        beq   $t4, $zero, st_m
        addiu $t0, $zero, 0x0c
        addiu $t1, $zero, 1
        beq   $t4, $t1, st_m
        addiu $t0, $zero, 0xc0
        addiu $t1, $zero, 3
        beq   $t4, $t1, st_m
        addiu $t0, $zero, 0x18
        addiu $t1, $zero, 4
        beq   $t4, $t1, st_m
        addiu $t0, $zero, 0x03          # giây, năm
st_m:   sw    $t0, -132($zero)
        jr    $s7
st_sv:  jal   ymd2d                     # ---- C: lưu → rtcset; về TIME
        addu  $a1, $v0, $zero
        lw    $t0, V_SH($zero)
        addiu $t1, $zero, 60
        mul   $t0, $t0, $t1
        lw    $t2, V_SM($zero)
        addu  $t0, $t0, $t2
        mul   $t0, $t0, $t1
        lw    $t2, V_SS($zero)
        addu  $t0, $t0, $t2
        ori   $t1, $zero, 1000
        mul   $a0, $t0, $t1
        jal   rtcset
        sw    $zero, V_T1OK($zero)      # đặt tay: lần sync kế là "lần 1" (không tính CAL qua lần đặt tay)
        sw    $zero, V_MODE($zero)
        sw    $zero, -132($zero)
        jr    $s7

# rtcset: $a0 = ms trong ngày, $a1 = ngày (từ 01/01/2000) → SET_MS, SET_DAY (thứ = (ngày + 6) mod 7), ARM, chờ nạp.
# Dùng $t0, $t1. Dùng chung cho SET (st_sv) và sync.
rtcset: sw    $a0, -244($zero)          # SET_MS
        addiu $t0, $a1, 6               # 01/01/2000 là thứ 7
        addiu $t1, $zero, 7
        div   $t0, $t1
        mfhi  $t0
        sll   $t0, $t0, 16
        or    $t0, $t0, $a1
        sw    $t0, -240($zero)          # SET_DAY
        addiu $t0, $zero, 1
        sw    $t0, -236($zero)          # ARM: nạp ở tick ms kế
rs_arm: lw    $t0, -236($zero)
        bne   $t0, $zero, rs_arm        # chờ nạp xong, rồi mới bỏ "giờ cũ" (system_tb bắt 03/10: đặt LASTH
        addiu $t0, $zero, -1            # trước khi nạp → ringchk đọc giờ cũ 23 → 0 h sau nạp → kêu chuông giờ sai)
        sw    $t0, V_LASTH($zero)       # nhảy giờ: không tính là "qua giờ tròn"
        jr    $ra

# mlen: $a0 = tháng, $a1 = năm − 2000 → $v0 = số ngày. Năm chia hết cho 4 là nhuận (đúng 2000–2099;
# d2ymd tự bù 2100). Tháng ≠ 2: 30 + ((m + m/8) mod 2). Dùng $t8.
mlen:   addiu $t8, $zero, 2
        bne   $a0, $t8, ml_n
        andi  $t8, $a1, 3
        addiu $v0, $zero, 29
        beq   $t8, $zero, ml_r
        addiu $v0, $zero, 28
ml_r:   jr    $ra
ml_n:   sra   $t8, $a0, 3
        addu  $t8, $t8, $a0
        andi  $t8, $t8, 1
        addiu $v0, $t8, 30
        jr    $ra

# d2ymd: $a0 = số ngày từ 01/01/2000 → $a1 = năm − 2000, $a0 = tháng, $t5 = ngày. Chu kỳ 4 năm = 1461 ngày;
# từ 01/03/2100 (ngày 36 584) cộng 1 để bỏ qua 29/02/2100 không tồn tại. Đúng tới ngày 65 535 (năm 2179).
d2ymd:  addu  $s6, $ra, $zero
        ori   $t0, $zero, 36584
        slt   $t1, $a0, $t0
        bne   $t1, $zero, dy1
        addiu $a0, $a0, 1
dy1:    ori   $t1, $zero, 1461
        div   $a0, $t1
        mflo  $t0
        sll   $a1, $t0, 2
        mfhi  $t5                       # ngày trong chu kỳ 4 năm
        slti  $t1, $t5, 366
        bne   $t1, $zero, dy3
        addiu $t5, $t5, -366
        addiu $a1, $a1, 1
dy2:    slti  $t1, $t5, 365
        bne   $t1, $zero, dy3
        addiu $t5, $t5, -365
        addiu $a1, $a1, 1
        j     dy2
dy3:    addiu $a0, $zero, 1
dy4:    jal   mlen
        slt   $t1, $t5, $v0
        bne   $t1, $zero, dy5
        subu  $t5, $t5, $v0
        addiu $a0, $a0, 1
        j     dy4
dy5:    addiu $t5, $t5, 1
        jr    $s6

# ymd2d: các trường SET (ngày, tháng, năm 2000–2099) → $v0 = số ngày từ 01/01/2000
ymd2d:  addu  $s6, $ra, $zero
        lw    $a1, V_SY($zero)
        sra   $t0, $a1, 2
        ori   $t1, $zero, 1461
        mul   $t5, $t0, $t1
        andi  $t0, $a1, 3
        beq   $t0, $zero, yd1
        addiu $t1, $zero, 365           # năm thứ k (1…3) của chu kỳ: + 365k + 1
        mul   $t0, $t0, $t1
        addu  $t5, $t5, $t0
        addiu $t5, $t5, 1
yd1:    addiu $a0, $zero, 1
        lw    $t4, V_SMO($zero)
yd2:    beq   $a0, $t4, yd3
        jal   mlen
        addu  $t5, $t5, $v0
        addiu $a0, $a0, 1
        j     yd2
yd3:    lw    $t0, V_SD($zero)
        addu  $t5, $t5, $t0
        addiu $v0, $t5, -1
        jr    $s6

# ======================================================================== đồng bộ giờ (gói E6, timer-spec §9)
# sy_rx: lấy byte trong FIFO RX (đọc UART_RX khi rỗng thì VALID = 0, không lấy gì), gom câu vào V_RBUF tới '\n',
# ở '\n' chụp giờ (giờ trả lời $Q và B2 khi tính CAL) và đặt V_RRDY. Bộ đệm xử lý V_SBUF trống (V_SRDY = 0) thì chép
# câu sang, đặt V_SRDY rồi gom tiếp → câu 2 sát câu 1 vẫn chụp giờ đúng lúc '\n' của nó (sửa 27/10).
# Cả hai bộ đệm đầy thì không lấy gì (byte nằm lại FIFO). Gọi từ handler (ngắt) hoặc từ sync khi ngắt tắt. Chỉ dùng $t0–$t2.
# sync: tắt ngắt, gọi sy_rx (vét byte handler để lại / chế độ polling), bật lại; có câu thì xử lý:
#   "$Q*51" → "$R,<ms>,<day>*CS";  "$T,<ms>,<day>*CS" → (tính CAL nếu có T1) → đặt giờ. Sai bất kỳ chỗ nào → bỏ im lặng.
# T1 (Long chốt 26/10): câu đặt giờ thành T1 của lần sau, trừ khi 0 ≤ I < 10 phút và |D| ≤ 120 ms — khi đó chỉ đặt giờ,
# giữ T1 và cộng D vào V_DACC (độ trôi bị xóa khi đặt giờ xen giữa), lần tính CAL sau dùng D + V_DACC. SET bằng nút xóa T1.
# Dùng $t0–$t9, $a0–$a3, $v0, $v1; $s3 giữ $ra (sy_send dùng $s2).
sy_rx:  lw    $t0, V_RRDY($zero)
        beq   $t0, $zero, rx1
        lw    $t0, V_SRDY($zero)
        bne   $t0, $zero, rx_r          # câu trước chưa xử lý xong, bộ đệm nhận cũng đầy
        lw    $t2, V_RLEN($zero)        # ---- chép câu nhận → bộ đệm xử lý
        sw    $t2, V_SLEN($zero)
        slti  $t1, $t2, 33
        bne   $t1, $zero, rx_c
        addu  $t2, $zero, $zero         # câu quá dài: sync bỏ theo V_SLEN, không cần chép byte
rx_c:   beq   $t2, $zero, rx_c2
        addiu $t2, $t2, -1
        sll   $t1, $t2, 2
        lw    $t0, V_RBUF($t1)
        sw    $t0, V_SBUF($t1)
        j     rx_c
rx_c2:  lw    $t0, V_RQMS($zero)
        sw    $t0, V_SQMS($zero)
        lw    $t0, V_RQDY($zero)
        sw    $t0, V_SQDY($zero)
        sw    $zero, V_RLEN($zero)
        sw    $zero, V_RRDY($zero)
        addiu $t0, $zero, 1
        sw    $t0, V_SRDY($zero)
rx1:    lw    $t0, -172($zero)          # UART_RX: [31] VALID, [7:0] byte
        slt   $t1, $t0, $zero
        beq   $t1, $zero, rx_r          # FIFO rỗng
        andi  $t0, $t0, 0xff
        addiu $t1, $zero, 10
        beq   $t0, $t1, rx_nl
        lw    $t2, V_RLEN($zero)
        slti  $t1, $t2, 32
        bne   $t1, $zero, rx2
        addiu $t2, $zero, 33            # quá 32 byte: đánh dấu hỏng tới '\n' (không cắt rồi nhận nhầm)
        sw    $t2, V_RLEN($zero)
        j     rx1
rx2:    sll   $t1, $t2, 2
        sw    $t0, V_RBUF($t1)
        addiu $t2, $t2, 1
        sw    $t2, V_RLEN($zero)
        j     rx1
rx_nl:  lw    $t0, -252($zero)          # '\n': chụp MS_OF_DAY rồi DAY_SHADOW
        sw    $t0, V_RQMS($zero)
        lw    $t0, -248($zero)
        sw    $t0, V_RQDY($zero)
        addiu $t0, $zero, 1
        sw    $t0, V_RRDY($zero)
        j     sy_rx                     # bộ đệm xử lý trống thì chép sang ngay rồi gom tiếp
rx_r:   jr    $ra

sync:   addu  $s3, $ra, $zero
sy1:    mtc0  $zero, $12
        jal   sy_rx
        addiu $t0, $zero, USE_IRQ
        mtc0  $t0, $12
        lw    $t0, V_SRDY($zero)
        bne   $t0, $zero, sy_nl
        jr    $s3

sy_nl:  lw    $t9, V_SLEN($zero)        # ---- khung câu: 5 ≤ độ dài ≤ 32, '$' đầu, '*' rồi đúng 2 hex hoa
        slti  $t1, $t9, 33
        beq   $t1, $zero, sy_done
        slti  $t1, $t9, 5               # ngắn nhất "$Q*51"
        bne   $t1, $zero, sy_done
        lw    $t0, V_SBUF($zero)
        addiu $t1, $zero, 0x24          # '$'
        bne   $t0, $t1, sy_done
        sll   $t9, $t9, 2               # $t9 = độ dài × 4 (vị trí tính theo word)
        addiu $t2, $zero, 4             # $t2 = vị trí × 4, $t3 = XOR các byte giữa '$' và '*'
        addu  $t3, $zero, $zero
sc1:    beq   $t2, $t9, sy_done         # hết câu mà chưa gặp '*'
        lw    $t0, V_SBUF($t2)
        addiu $t1, $zero, 0x2a          # '*'
        beq   $t0, $t1, sc2
        xor   $t3, $t3, $t0
        addiu $t2, $t2, 4
        j     sc1
sc2:    addiu $t1, $t2, 12              # '*' + 2 hex = hết câu
        bne   $t1, $t9, sy_done
        lw    $a0, V_SBUF1($t2)
        jal   hexv
        slt   $t1, $v0, $zero
        bne   $t1, $zero, sy_done
        sll   $t4, $v0, 4
        lw    $a0, V_SBUF2($t2)
        jal   hexv
        slt   $t1, $v0, $zero
        bne   $t1, $zero, sy_done
        or    $t4, $t4, $v0
        bne   $t4, $t3, sy_done         # sai checksum
        lw    $t0, V_SBUF1($zero)       # ---- loại câu
        addiu $t1, $zero, 0x51          # 'Q'
        bne   $t0, $t1, sy_t
        addiu $t1, $zero, 8             # "$Q*": '*' ở byte 2
        bne   $t2, $t1, sy_done
        addiu $a0, $zero, 0x52          # 'R'
        lw    $a1, V_SQMS($zero)
        lw    $a2, V_SQDY($zero)
        jal   sy_send
        j     sy_done
sy_t:   addiu $t1, $zero, 0x54          # 'T'
        bne   $t0, $t1, sy_done
        lw    $t0, V_SBUF2($zero)
        addiu $t1, $zero, 0x2c          # ','
        bne   $t0, $t1, sy_done
        addiu $a0, $zero, 12            # ms từ byte 3
        jal   sy_num
        lw    $t0, V_SBUF($a0)
        addiu $t1, $zero, 0x2c
        bne   $t0, $t1, sy_done         # số ms phải dừng ở ','
        addu  $a2, $v0, $zero
        addiu $a0, $a0, 4
        jal   sy_num
        bne   $a0, $t2, sy_done         # số ngày phải dừng đúng ở '*'
        addu  $a3, $v0, $zero
        lui   $t5, 0x0526
        ori   $t5, $t5, 0x5c00          # $t5 = 86 400 000
        slt   $t1, $a2, $t5
        beq   $t1, $zero, sy_done       # ms ≥ 86 400 000
        lui   $t1, 1
        slt   $t1, $a3, $t1
        beq   $t1, $zero, sy_done       # ngày > 65 535
        lw    $t0, V_T1OK($zero)        # ---- CAL (timer-spec §9), chỉ khi đã có T1
        beq   $t0, $zero, sy_set
        lw    $t0, V_T1DY($zero)        # I = T2 − T1: chênh ngày (quay vòng 16 bit) phải là 0 hoặc 1
        subu  $t0, $a3, $t0
        andi  $t0, $t0, 0xffff
        slti  $t1, $t0, 2
        beq   $t1, $zero, sy_set        # ≥ 2 ngày → I > 86 400 000
        mul   $t6, $t0, $t5
        addu  $t6, $t6, $a2
        lw    $t0, V_T1MS($zero)
        subu  $t6, $t6, $t0             # $t6 = I (ms)
        slt   $t0, $t6, $zero
        bne   $t0, $zero, sy_set        # T2 trước T1 (PC lùi giờ): mốc mới
        slt   $t0, $t5, $t6
        bne   $t0, $zero, sy_set        # I > 86 400 000
        lw    $t0, V_SQDY($zero)        # D = B2 − T2: chênh ngày 0, +1 hoặc −1 (0xFFFF)
        subu  $t0, $t0, $a3
        andi  $t0, $t0, 0xffff
        lw    $t7, V_SQMS($zero)
        subu  $t7, $t7, $a2
        beq   $t0, $zero, sd2
        addiu $t1, $zero, 1
        bne   $t0, $t1, sd1
        addu  $t7, $t7, $t5             # chip đã sang ngày sau
        j     sd2
sd1:    ori   $t1, $zero, 0xffff
        bne   $t0, $t1, sy_set          # lệch ≥ 2 ngày: chắc chắn quá 200 ppm
        subu  $t7, $t7, $t5
sd2:    lui   $t1, 0x9
        ori   $t1, $t1, 0x27c0          # 600 000
        slt   $t0, $t6, $t1
        beq   $t0, $zero, sd5
        addu  $t8, $t7, $zero           # I < 10 phút: |D| ≤ 120 ms (200 ppm × 10 phút) → giữ T1, cộng dồn D
        slt   $t0, $t7, $zero
        beq   $t0, $zero, sd4
        subu  $t8, $zero, $t7
sd4:    slti  $t0, $t8, 121
        beq   $t0, $zero, sy_set        # lệch lớn: chỉnh giờ chứ không phải trôi → mốc mới
        lw    $t0, V_DACC($zero)
        addu  $t0, $t0, $t7
        sw    $t0, V_DACC($zero)
        j     sy_rs
sd5:    lw    $t0, V_DACC($zero)
        addu  $t7, $t7, $t0             # D = trôi kể từ T1 = D lần này + D các lần đặt giờ xen giữa
        ori   $t1, $zero, 5000          # nhận khi |D| ≤ I / 5000 (chia trước: |D| × 5000 tràn 32 bit)
        div   $t6, $t1
        mflo  $t1
        addu  $t8, $t7, $zero
        slt   $t0, $t7, $zero
        beq   $t0, $zero, sd3
        subu  $t8, $zero, $t7           # $t8 = |D|
sd3:    slt   $t0, $t1, $t8
        bne   $t0, $zero, sy_set
        sll   $t7, $t7, 16              # ΔCAL = ((D × 65536) / (I / 1000)) × 50; |D| ≤ 17 280 nên không tràn
        ori   $t1, $zero, 1000
        div   $t6, $t1
        mflo  $t1
        div   $t7, $t1
        mflo  $t7
        addiu $t1, $zero, 50
        mul   $t7, $t7, $t1
        lw    $t0, -232($zero)          # CAL
        addu  $t0, $t0, $t7
        lui   $t1, 0xa                  # chặn |CAL| ≤ 655 360 (±200 ppm, timer-spec §2: firmware chặn)
        slt   $t7, $t1, $t0
        beq   $t7, $zero, sc3
        addu  $t0, $t1, $zero
sc3:    subu  $t1, $zero, $t1
        slt   $t7, $t0, $t1
        beq   $t7, $zero, sc4
        addu  $t0, $t1, $zero
sc4:    sw    $t0, -232($zero)
sy_set: sw    $a2, V_T1MS($zero)        # ---- đặt giờ T2, nó thành T1 của lần sau
        sw    $a3, V_T1DY($zero)
        addiu $t0, $zero, 1
        sw    $t0, V_T1OK($zero)
        sw    $zero, V_DACC($zero)
sy_rs:  addu  $a0, $a2, $zero
        addu  $a1, $a3, $zero
        jal   rtcset
sy_done: sw   $zero, V_SLEN($zero)
        sw    $zero, V_SRDY($zero)
        j     sy1

# sy_num: số thập phân từ V_SBUF + $a0 (vị trí × 4) → $v0; $a0 = vị trí byte dừng (không phải chữ số).
# 0 chữ số hoặc quá 9 chữ số → nhảy thẳng sy_done (bỏ câu). Chắc chắn dừng vì câu đã có '*'. Dùng $t0, $t1, $v1.
sy_num: addu  $v0, $zero, $zero
        addu  $v1, $zero, $zero
sn1:    lw    $t0, V_SBUF($a0)
        addiu $t0, $t0, -48             # '0'
        slt   $t1, $t0, $zero
        bne   $t1, $zero, sn2
        slti  $t1, $t0, 10
        beq   $t1, $zero, sn2
        addiu $t1, $zero, 10
        mul   $v0, $v0, $t1
        addu  $v0, $v0, $t0
        addiu $v1, $v1, 1
        addiu $a0, $a0, 4
        j     sn1
sn2:    beq   $v1, $zero, sy_done
        slti  $t1, $v1, 10
        beq   $t1, $zero, sy_done
        jr    $ra

# hexv: $a0 = byte → $v0 = 0…15 nếu '0'…'9' hoặc 'A'…'F' (chỉ hex hoa), ngược lại −1. Dùng $t0.
hexv:   addiu $v0, $a0, -48             # '0'
        slti  $t0, $v0, 10
        beq   $t0, $zero, hx1
        slt   $t0, $v0, $zero
        beq   $t0, $zero, hx_r
        j     hx_bad
hx1:    addiu $v0, $a0, -55             # 'A' → 10
        slti  $t0, $v0, 10
        bne   $t0, $zero, hx_bad
        slti  $t0, $v0, 16
        bne   $t0, $zero, hx_r
hx_bad: addiu $v0, $zero, -1
hx_r:   jr    $ra

# sy_send: phát "$<a0>,<a1>,<a2 & 0xFFFF>*CS\n" ($a0 = 'R' / 'Z', $a1 = ms, $a2 = DAY_SHADOW). $s2 giữ $ra.
# shortcut: chờ TX_READY từng byte (≤ 21 byte ≈ 1,8 ms ở 115 200 baud, vòng chính đứng); cần thì đổi sang hàng đợi + ngắt TX.
sy_send: addu $s2, $ra, $zero
        addu  $t4, $a0, $zero
        addiu $a0, $zero, 0x24          # '$'
        jal   putc
        addu  $v1, $zero, $zero         # CS tính từ byte sau '$'
        addu  $a0, $t4, $zero
        jal   putc
        addiu $a0, $zero, 0x2c
        jal   putc
        jal   putn
        addiu $a0, $zero, 0x2c
        jal   putc
        andi  $a1, $a2, 0xffff
        jal   putn
        addu  $t4, $v1, $zero
        addiu $a0, $zero, 0x2a          # '*'
        jal   putc
        sra   $a0, $t4, 4
        jal   hexc
        andi  $a0, $t4, 0xf
        jal   hexc
        addiu $a0, $zero, 10            # '\n'
        jal   putc
        jr    $s2

# putn: $a1 (< 10⁸) → chữ số thập phân, bỏ số 0 đầu (0 → "0"). Dùng $t0–$t3, $t7, $a0.
putn:   addu  $t7, $ra, $zero
        bcd   $t1, $a1
        addiu $t2, $zero, 8             # còn 8 chữ số
        addu  $t3, $zero, $zero         # ≠ 0: đã gặp chữ số khác 0
pn1:    sra   $a0, $t1, 28
        andi  $a0, $a0, 0xf
        sll   $t1, $t1, 4
        addiu $t2, $t2, -1
        or    $t3, $t3, $a0
        bne   $t3, $zero, pn2
        bne   $t2, $zero, pn1           # bỏ số 0 đầu, giữ chữ số cuối
pn2:    addiu $a0, $a0, 48
        jal   putc
        bne   $t2, $zero, pn1
        jr    $t7

# hexc: $a0 = 0…15 → '0'…'9', 'A'…'F' rồi phát
hexc:   slti  $t0, $a0, 10
        bne   $t0, $zero, hc1
        addiu $a0, $a0, 7
hc1:    addiu $a0, $a0, 48
        j     putc

# putc: chờ UART_STATUS.TX_READY rồi ghi UART_TX; $v1 ^= byte. Dùng $t0.
putc:   lw    $t0, -176($zero)
        andi  $t0, $t0, 4
        beq   $t0, $zero, putc
        sw    $a0, -168($zero)
        xor   $v1, $v1, $a0
        jr    $ra

# ======================================================================== chuông (gói D6)
ringchk: mtc0 $zero, $12                # tắt ngắt quanh cặp MS_OF_DAY → DAY_SHADOW
        lw    $s4, -252($zero)          # bây giờ (ms trong ngày)
        lw    $a2, -248($zero)          # DAY_SHADOW chụp cùng lần đọc $s4 (cho $Z)
        addiu $t0, $zero, USE_IRQ
        mtc0  $t0, $12
        lw    $t0, -212($zero)          # 1) timer về 0: cờ ZERO dính, phần cứng đã tự nạp chuông (BEEP_EN)
        andi  $t1, $t0, 2
        beq   $t1, $zero, rc2
        andi  $t0, $t0, 0xd
        ori   $t0, $t0, 2               # ghi 1 vào ZERO = xóa; giữ RUN, BEEP_EN, SAT
        sw    $t0, -212($zero)
        addu  $s1, $ra, $zero
        addiu $a0, $zero, 0x5a          # gửi PC "$Z,<ms>,<day>" (timer-spec §9)
        addu  $a1, $s4, $zero
        jal   sy_send
        addu  $ra, $s1, $zero
        addiu $t0, $zero, 1
        j     rc_on
rc2:    lw    $t0, -184($zero)          # 2) báo thức: IRQ_PENDING bit 3 (polling)
        andi  $t0, $t0, 8
        beq   $t0, $zero, rc3
        addiu $t0, $zero, 8
        sw    $t0, -184($zero)
        addiu $t2, $zero, -208
rc2a:   lw    $t0, 0($t2)               # ALARMk có HIT → ghi lại chính nó (HIT = 1 → xóa)
        lui   $t1, 0x80
        and   $t1, $t0, $t1
        beq   $t1, $zero, rc2b
        sw    $t0, 0($t2)
rc2b:   addiu $t2, $t2, 4
        addiu $t1, $zero, -192
        bne   $t2, $t1, rc2a
        sw    $zero, V_SNZON($zero)
        j     rc_al
rc3:    lw    $t0, V_SNZON($zero)       # 3) snooze tới giờ: 0 ≤ (bây giờ − giờ hẹn) mod ngày < 60 s
        beq   $t0, $zero, rc4
        lw    $t0, V_SNZ($zero)
        subu  $t0, $s4, $t0
        slt   $t1, $t0, $zero
        beq   $t1, $zero, rc3a
        lui   $t1, 0x0526
        ori   $t1, $t1, 0x5c00
        addu  $t0, $t0, $t1
rc3a:   ori   $t1, $zero, 60000
        slt   $t1, $t0, $t1
        beq   $t1, $zero, rc4
        sw    $zero, V_SNZON($zero)
rc_al:  lui   $t0, 1
        ori   $t0, $t0, 0x0f0f
        sw    $t0, -120($zero)          # chuông báo thức 0x10F0F (lặp)
        addiu $t0, $zero, 2
rc_on:  sw    $t0, V_RING($zero)
        sw    $s4, V_RINGT($zero)
        jr    $ra
rc4:    lw    $t0, V_RING($zero)        # 4) chuông quá 60 s → tự tắt
        beq   $t0, $zero, rc5
        lw    $t0, V_RINGT($zero)
        subu  $t0, $s4, $t0
        slt   $t1, $t0, $zero
        beq   $t1, $zero, rc4a
        lui   $t1, 0x0526
        ori   $t1, $t1, 0x5c00
        addu  $t0, $t0, $t1
rc4a:   ori   $t1, $zero, 60000
        slt   $t1, $t0, $t1
        bne   $t1, $zero, rc5
        sw    $zero, -120($zero)
        sw    $zero, V_RING($zero)
rc5:    lui   $t1, 0x36                 # 5) chuông giờ: giờ đổi (không phải vừa nạp giờ), đang bật, không chuông khác
        ori   $t1, $t1, 0xee80
        div   $s4, $t1
        mflo  $t0
        lw    $t2, V_LASTH($zero)
        sw    $t0, V_LASTH($zero)
        beq   $t0, $t2, rc_r
        slt   $t1, $t2, $zero
        bne   $t1, $zero, rc_r
        lw    $t1, V_CHIME($zero)
        beq   $t1, $zero, rc_r
        lw    $t1, V_RING($zero)
        bne   $t1, $zero, rc_r
        addiu $t1, $zero, 5
        sw    $t1, -120($zero)          # 0x00005
rc_r:   jr    $ra

# ======================================================================== màn
draw:   addu  $s7, $ra, $zero
        lw    $t3, V_MODE($zero)
        beq   $t3, $zero, dr_tm
        addiu $t1, $zero, 1
        beq   $t3, $t1, dr_sw
        addiu $t1, $zero, 2
        beq   $t3, $t1, dr_tr
        addiu $t1, $zero, 3
        beq   $t3, $t1, dr_al
        j     dr_st
dr_out: jal   flush
        jr    $s7

dr_tm:  mtc0  $zero, $12                # tắt ngắt quanh cặp (handler chụp lại DAY_SHADOW)
        lw    $a0, -252($zero)          # MS_OF_DAY rồi DAY_SHADOW: cùng một lần chụp (không xé ngày/giờ)
        lw    $t4, -248($zero)
        addiu $t0, $zero, USE_IRQ
        mtc0  $t0, $12
        lw    $t0, V_TV($zero)
        addiu $t1, $zero, 1
        beq   $t0, $t1, dt_ms
        addiu $t1, $zero, 2
        beq   $t0, $t1, dt_dy
        lw    $a1, V_H12($zero)
        jal   fmtB
        j     dr_out
dt_ms:  lui   $t1, 0x36
        ori   $t1, $t1, 0xee80
        div   $a0, $t1
        mfhi  $a0
        jal   fmtA
        j     dr_out
dt_dy:  andi  $a0, $t4, 0xffff
        jal   d2ymd
dt_dd:  slti  $t1, $a1, 100             # $t5 = ngày, $a0 = tháng, $a1 = năm − 2000 → "dd-MM-YY"
        bne   $t1, $zero, dt_d1
        addiu $a1, $a1, -100
dt_d1:  lui   $t1, 0xf
        ori   $t1, $t1, 0x4240          # 1 000 000
        mul   $t5, $t5, $t1
        ori   $t1, $zero, 1000
        mul   $t0, $a0, $t1
        addu  $t5, $t5, $t0
        addu  $a0, $t5, $a1             # dd 0 MM 0 YY
        addiu $a1, $zero, 8
        jal   putd
        addiu $t0, $zero, 0x19
        sw    $t0, D2($zero)
        sw    $t0, D5($zero)
        j     dr_out

dr_sw:  lw    $t0, -220($zero)          # lấy hết lap khỏi FIFO phần cứng (giữ tối đa 8)
        slt   $t1, $t0, $zero
        beq   $t1, $zero, ds2
        lw    $t2, V_LAPN($zero)
        slti  $t1, $t2, 8
        beq   $t1, $zero, dr_sw
        lui   $t1, 0x1fff
        ori   $t1, $t1, 0xffff
        and   $t0, $t0, $t1
        sll   $t3, $t2, 2
        sw    $t0, V_LAPV($t3)
        addiu $t2, $t2, 1
        sw    $t2, V_LAPN($zero)
        j     dr_sw
ds2:    lw    $t4, V_LAPI($zero)
        lw    $a0, -224($zero)          # SW_VALUE
        beq   $t4, $zero, ds3
        sll   $t3, $t4, 2
        addiu $t3, $t3, -4
        lw    $a0, V_LAPV($t3)
ds3:    jal   fmtD
        lw    $t4, V_LAPI($zero)
        beq   $t4, $zero, dr_out
        sw    $t4, D7($zero)            # xem lap: DISP7 = số thứ tự lap
        j     dr_out

dr_tr:  lw    $a0, -216($zero)          # TMR_VALUE (có dấu)
        addiu $t7, $zero, 0x1a
        lui   $t1, 0xea8a
        ori   $t1, $t1, 0xd601          # −359 999 999
        slt   $t0, $a0, $t1             # x ≤ −360 000 000: so TRƯỚC khi lấy trị tuyệt đối (|−2³¹| vẫn âm)
        beq   $t0, $zero, dtr1
        addiu $t7, $zero, 0x19
        lui   $a0, 0x1575
        ori   $a0, $a0, 0x2a00          # → nhánh "--.--.--"
        j     dtr2
dtr1:   slt   $t0, $a0, $zero
        beq   $t0, $zero, dtr2
        addiu $t7, $zero, 0x19
        subu  $a0, $zero, $a0
dtr2:   jal   fmtD
        sw    $t7, D7($zero)            # dấu
        j     dr_out

dr_al:  lw    $t4, V_ALK($zero)
        addiu $t1, $zero, 4
        bne   $t4, $t1, da1
        addiu $t0, $zero, 0x1a          # trang chuông giờ "CH o    "
        sw    $t0, D0($zero)
        sw    $t0, 0x484($zero)
        sw    $t0, D2($zero)
        sw    $t0, D3($zero)
        sw    $t0, D5($zero)
        lw    $t1, V_CHIME($zero)
        beq   $t1, $zero, da0
        addiu $t0, $zero, 0x13
da0:    sw    $t0, D4($zero)
        addiu $t0, $zero, 0x0c
        sw    $t0, D7($zero)
        addiu $t0, $zero, 0x10
        sw    $t0, D6($zero)
        j     dr_out
da1:    sll   $t6, $t4, 2
        addiu $t6, $t6, -208
        lw    $t5, 0($t6)               # ALARMk
        andi  $a0, $t5, 0x7ff
        lw    $t0, V_AED($zero)
        beq   $t0, $zero, da2
        lw    $a0, V_AEH($zero)         # đang sửa: hiện giá trị đang sửa
        addiu $t1, $zero, 60
        mul   $a0, $a0, $t1
        lw    $t1, V_AEM($zero)
        addu  $a0, $a0, $t1
da2:    addiu $t1, $zero, 60            # "ALko HH.MM"
        div   $a0, $t1
        mflo  $t0
        mfhi  $t2
        addiu $t1, $zero, 100
        mul   $t0, $t0, $t1
        addu  $a0, $t0, $t2
        addiu $a1, $zero, 4
        jal   putd
        lw    $t0, D2($zero)
        ori   $t0, $t0, 0x80
        sw    $t0, D2($zero)
        addiu $t0, $zero, 0x0a
        sw    $t0, D7($zero)
        addiu $t0, $zero, 0x11
        sw    $t0, D6($zero)
        addiu $t0, $t4, 1
        sw    $t0, D5($zero)
        addiu $t0, $zero, 0x1a
        slt   $t1, $t5, $zero           # EN = bit 31
        beq   $t1, $zero, da3
        addiu $t0, $zero, 0x13
da3:    sw    $t0, D4($zero)
        j     dr_out

dr_st:  lw    $t0, V_SF($zero)
        slti  $t1, $t0, 3
        beq   $t1, $zero, dst_d
        lw    $t0, V_SH($zero)          # trường giờ/phút/giây: bố cục TIME 24 h
        addiu $t1, $zero, 60
        mul   $t0, $t0, $t1
        lw    $t2, V_SM($zero)
        addu  $t0, $t0, $t2
        mul   $t0, $t0, $t1
        lw    $t2, V_SS($zero)
        addu  $t0, $t0, $t2
        ori   $t1, $zero, 1000
        mul   $a0, $t0, $t1
        addu  $a1, $zero, $zero
        jal   fmtB
        j     dr_out
dst_d:  lw    $t5, V_SD($zero)          # trường ngày/tháng/năm: bố cục trang 2
        lw    $a0, V_SMO($zero)
        lw    $a1, V_SY($zero)
        j     dt_dd

# ---- định dạng (ghi bộ đệm D0…D7; $s5 giữ $ra)
# fmtD: $a0 = ms ≥ 0 → ≥ 360 000 000: "_--.--.--"; ≥ 1 h: fmtB; còn lại fmtA. DISP7 = trống.
fmtD:   lui   $t1, 0x1575
        ori   $t1, $t1, 0x2a00          # 360 000 000
        slt   $t0, $a0, $t1
        beq   $t0, $zero, fd_x
        lui   $t1, 0x36
        ori   $t1, $t1, 0xee80
        slt   $t0, $a0, $t1
        bne   $t0, $zero, fmtA
        addu  $a1, $zero, $zero
        j     fmtB
fd_x:   addiu $t0, $zero, 0x19
        sw    $t0, D0($zero)
        sw    $t0, 0x484($zero)
        sw    $t0, D3($zero)
        sw    $t0, D5($zero)
        addiu $t0, $zero, 0x99          # '-' có chấm
        sw    $t0, D2($zero)
        sw    $t0, D4($zero)
        addiu $t0, $zero, 0x1a
        sw    $t0, D6($zero)
        sw    $t0, D7($zero)
        jr    $ra

# fmtA: $a0 = ms < 3 600 000 → "_MM.SS.mmm"
fmtA:   addu  $s5, $ra, $zero
        ori   $t1, $zero, 60000
        div   $a0, $t1
        mflo  $t0
        mfhi  $t2
        lui   $t1, 1
        ori   $t1, $t1, 0x86a0          # 100 000
        mul   $t0, $t0, $t1
        addu  $a0, $t0, $t2             # MM SS mmm
        addiu $a1, $zero, 7
        jal   putd
        addiu $t0, $zero, 0x1a
        sw    $t0, D7($zero)
        lw    $t0, D5($zero)
        ori   $t0, $t0, 0x80
        sw    $t0, D5($zero)
        lw    $t0, D3($zero)
        ori   $t0, $t0, 0x80
        sw    $t0, D3($zero)
        jr    $s5

# fmtB: $a0 = ms (< 100 h), $a1 = 1 nếu 12 h → "__HH.MM.SS" / "A_HH.MM.SS" / "P_HH.MM.SS"
fmtB:   addu  $s5, $ra, $zero
        ori   $t1, $zero, 1000
        div   $a0, $t1
        mflo  $t0                       # giây
        addiu $t1, $zero, 3600
        div   $t0, $t1
        mflo  $t2                       # giờ
        mfhi  $t0
        addiu $t1, $zero, 60
        div   $t0, $t1
        mflo  $t3                       # phút
        mfhi  $t4                       # giây
        addiu $t6, $zero, 0x1a
        beq   $a1, $zero, fb2
        addiu $t6, $zero, 0x0a          # A
        slti  $t1, $t2, 12
        bne   $t1, $zero, fb1
        addiu $t6, $zero, 0x14          # P
        addiu $t2, $t2, -12
fb1:    bne   $t2, $zero, fb2
        addiu $t2, $zero, 12            # 0 h → 12
fb2:    addiu $t1, $zero, 10000
        mul   $t2, $t2, $t1
        addiu $t1, $zero, 100
        mul   $t3, $t3, $t1
        addu  $a0, $t2, $t3
        addu  $a0, $a0, $t4             # HH MM SS
        addiu $a1, $zero, 6
        jal   putd
        sw    $t6, D7($zero)
        addiu $t0, $zero, 0x1a
        sw    $t0, D6($zero)
        lw    $t0, D4($zero)
        ori   $t0, $t0, 0x80
        sw    $t0, D4($zero)
        lw    $t0, D2($zero)
        ori   $t0, $t0, 0x80
        sw    $t0, D2($zero)
        jr    $s5

# putd: $a0 = số thập phân (< 10⁸), $a1 = số chữ số → D0…D(a1−1) (mã 0x00–0x09 = chữ số, display-spec §3)
putd:   bcd   $t0, $a0
        addiu $t1, $zero, D0
pd1:    andi  $t2, $t0, 0xf
        sw    $t2, 0($t1)
        sra   $t0, $t0, 4
        addiu $t1, $t1, 4
        addiu $a1, $a1, -1
        bne   $a1, $zero, pd1
        jr    $ra

# flush: D0…D7 → DISP0…DISP7 (DISP7 ghi cuối: tb lấy "khung" ở lần ghi này)
flush:  addiu $t1, $zero, D0
        addiu $t2, $zero, -164
        addiu $t3, $zero, -132
fl1:    lw    $t0, 0($t1)
        sw    $t0, 0($t2)
        addiu $t1, $t1, 4
        addiu $t2, $t2, 4
        bne   $t2, $t3, fl1
        jr    $ra
