# B6 jump — j, jal, jr ngay sau jal (T7: ID đọc $ra qua bypass regfile), jr sau lw $ra (stall 1 + nhảy 2).
# Tổng: j(2) + jal(2) + jr trong F(2) + lw→jr(1+2) = 9
# bubbles 9
# expect $t1=1
# expect $t2=0
# expect $t3=3
# expect $t9=0
# expect $s1=0x18
        j     L1                    # nhảy: 2
        li    $t0, 111              # bị xóa
F:      addu  $s1, $ra, $zero       # đọc $ra ngay sau jal (T7)
        jr    $ra                   # nhảy: 2
        li    $t9, 111              # bị xóa
L1:     jal   F                     # nhảy: 2 (địa chỉ trở về = 0x18)
        li    $t1, 1                # chạy sau khi về
        li    $t0, 0x30             # = L3 (li 1 lệnh, không dùng la; xem cp0.s)
        sw    $t0, 0x804($zero)
        lw    $ra, 0x804($zero)     # $ra nạp từ bộ nhớ
        jr    $ra                   # stall 1 (load-use) + nhảy 2
        li    $t2, 111              # bị xóa
L3:     li    $t3, 3                # rơi khỏi cuối chương trình
