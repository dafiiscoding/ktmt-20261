# B6 cp0 — mtc0/mfc0 cùng thanh ghi không stall (T6); eret nhảy về EPC, phạt 2 (pipeline-policy §5, T6).
# eret lấy EPC; EXL ← 0 nên mfc0 Status sau eret = 1 (IE = 1, EXL = 0).
# bubbles 2
# expect $t1=3
# expect $t4=0x24
# expect $t5=3
# expect $t6=0
# expect $t7=1
        li    $t0, 3
        mtc0  $t0, $12              # Status = 3
        mfc0  $t1, $12              # ngay sau mtc0: đọc Status mới → 3 (0 stall)
        li    $t3, 0x24             # back = 0x24 (li 1 lệnh; không dùng la vì assembler nở la thành 2 lệnh, MARS thì 1)
        mtc0  $t3, $14              # EPC = back
        mfc0  $t4, $14              # → back (0x24)
        mfc0  $t5, $12              # EXL vẫn 1 → 3
        eret                        # nhảy về EPC: 2
        li    $t6, 111              # bị xóa
back:   mfc0  $t7, $12              # EXL đã về 0 → 1
