# C3-4: lw/sw lệch 4 byte → bỏ 2 bit thấp (MARS báo lỗi căn lề nên không chạy MARS)
# nomars
# expect $t4=0x901
# expect $t5=0
# expect $t6=0x901
        li    $t3, 0x901
        sw    $t3, 0x903($zero)     # lệch 3 → ghi word 0x900
        lw    $t4, 0x901($zero)     # lệch 1 → đọc word 0x900
        lw    $t5, 0x806($zero)     # word 0x804 = 0
        sw    $t4, 0x80a($zero)     # lệch 2 → word 0x808
        lw    $t6, 0x808($zero)
