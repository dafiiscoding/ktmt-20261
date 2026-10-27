# Đường bus MMIO (mmio-map §2): sw/lw offset âm qua $zero; tb mô hình MMIO = RAM 64 word.
# Kiểm thêm: ghi MMIO / ngoài vùng không lọt vào DMEM (bit [11:2] trùng), đọc ngoài vùng ra 0 dù DMEM có dữ liệu.
# nomars
# expect $t1=0x1234
# expect $t2=0xabcd0000
# expect $t3=0
# expect $t4=0x1234
# expect $t5=0x55
# expect $t6=0
# expect $t7=0
        li    $t0, 0x55
        sw    $t0, 0($zero)         # DMEM[0] = 0x55
        li    $t0, 0x1234
        sw    $t0, -256($zero)      # 0xFFFFFF00 (bit [11:2] = 0x3C0)
        li    $t0, 0xabcd0000
        sw    $t0, -4($zero)        # 0xFFFFFFFC
        lw    $t1, -256($zero)
        lw    $t2, -4($zero)
        lw    $t3, 0x2000($zero)    # ngoài DMEM, ngoài MMIO → 0 (không phải DMEM[0])
        sw    $t1, 0x2004($zero)    # bị bỏ (không lọt vào DMEM[1])
        lw    $t4, -253($zero)      # lệch → word 0xFFFFFF00
        lw    $t5, 0($zero)         # DMEM[0] vẫn 0x55
        lw    $t6, 0xf00($zero)     # DMEM[0x3C0] không bị ghi bởi sw MMIO
        lw    $t7, 4($zero)         # DMEM[1] không bị ghi bởi sw 0x2004
