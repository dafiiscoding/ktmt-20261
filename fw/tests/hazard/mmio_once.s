# B6 mmio_once — lw MMIO (SW_LAP = −220($zero)) không chạy khi nằm trong bóng nhánh nhảy thật;
# chạy đúng 1 lần khi nằm sau div (lúc busy, lệnh ở ID chờ). Testbench đếm bus_re = số lw MMIO đã retire.
# Tổng bubble: beq nhảy 2 + div 32 = 34
# bubbles 34
# expect $t1=0
# expect $t2=77
# expect $t3=3
# expect $t9=0
        li    $t0, 77
        sw    $t0, -220($zero)      # MMIO SW_LAP (tb: RAM mmio) = 77
        li    $s0, 1
        beq   $s0, $s0, T           # nhảy: 2
        lw    $t1, -220($zero)      # bóng nhánh: không được chạy (không bus_re)
        li    $t9, 5                # bị xóa
T:      li    $s1, 9
        li    $s2, 3
        div   $s1, $s2              # 9 / 3 = 3: 32 bubble
        lw    $t2, -220($zero)      # nằm ở ID lúc div bận; chạy đúng 1 lần sau div
        mflo  $t3                   # 3
