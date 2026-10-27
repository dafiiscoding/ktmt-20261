# C3-1 phần bcd (MARS không có lệnh này): kết quả kiểm bằng expect; ghi vào 0x800+
# nomars
# expect $s0=0x12345678
# expect $s1=0
# expect $s2=0x99999999
# expect $s3=0xffffffff
# expect $s4=0xffffffff
# expect $s5=0x86399999
# expect $s6=0x5050
        li    $t0, 12345678
        bcd   $s0, $t0
        bcd   $s1, $zero
        li    $t1, 99999999
        bcd   $s2, $t1
        addiu $t2, $t1, 1
        bcd   $s3, $t2              # 100 000 000 → tràn
        li    $t3, -1
        bcd   $s4, $t3
        li    $t4, 86399999
        bcd   $s5, $t4
        li    $v0, 0
        li    $t0, 1
        li    $t1, 101
loop:   addu  $v0, $v0, $t0
        addiu $t0, $t0, 1
        bne   $t0, $t1, loop
        bcd   $s6, $v0              # dùng ngay kết quả vòng lặp
        sw    $s6, 0x800($zero)
        sw    $s0, 0x804($zero)
