# B6 raw_chain — RAW liên tiếp, forwarding đủ (pipeline-policy §3, T1), 0 bubble.
# Ca ưu tiên: addu $t0 ; addu $t0 ; addu ..,$t0 → lấy từ lệnh gần nhất (EX/MEM trước MEM/WB).
# bubbles 0
# expect $t4=0
# expect $t5=3
# expect $t3=12
# expect $t7=8
        li    $s0, 5
        li    $s1, 3
        subu  $t2, $s0, $s1         # t2 = 2
        and   $t4, $t2, $s0         # t4 = 2 & 5 = 0 (forward 10)
        or    $t5, $s1, $t2         # t5 = 3 | 2 = 3 (forward 01: t2 đã ở MEM/WB)
        addu  $t6, $t2, $t2         # t6 = 4
        addu  $t1, $t6, $t6         # t1 = 8
        addu  $t3, $t1, $t6         # t3 = 12
        addu  $t0, $s0, $zero       # t0 = 5
        addu  $t0, $t0, $s1         # t0 = 8 (ghi đè lần 1)
        addu  $t7, $t0, $zero      # phải lấy 8 (lệnh gần nhất), không lấy 5
