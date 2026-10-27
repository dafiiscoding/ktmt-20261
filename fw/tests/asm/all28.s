# all28.s — B1-1: đủ 28 lệnh + 5 lệnh giả, mã máy tính TAY (ghi sau "# =", isa-spec §2–§3, §7).
# tools/test_asm.py dịch file này và so từng dòng với số ghi tay. Chương trình không để chạy.
top:    addu  $t2, $t0, $t1             # = 0x01095021   rs 8, rt 9, rd 10, funct 0x21
        subu  $t2, $t0, $t1             # = 0x01095023
        and   $t2, $t0, $t1             # = 0x01095024
        or    $t2, $t0, $t1             # = 0x01095025
        xor   $t2, $t0, $t1             # = 0x01095026
        slt   $t2, $t0, $t1             # = 0x0109502a
        sll   $t2, $t1, 4               # = 0x00095100   rt 9, rd 10, sa 4
        sra   $t2, $t1, 31              # = 0x000957c3   sa 31 → 0x7c0
        jr    $ra                       # = 0x03e00008   rs 31
        div   $t0, $t1                  # = 0x0109001a
        mfhi  $t3                       # = 0x00005810   rd 11
        mflo  $t3                       # = 0x00005812
        addiu $t1, $t0, -1              # = 0x2509ffff   op 0x09
        slti  $t1, $t0, 100             # = 0x29090064   op 0x0a
        andi  $t1, $t0, 0xff00          # = 0x3109ff00   op 0x0c
        ori   $t1, $t0, 0x1234          # = 0x35091234   op 0x0d
        lui   $t1, 0xffff               # = 0x3c09ffff   op 0x0f
        lw    $t1, -4($sp)              # = 0x8fa9fffc   op 0x23, rs 29
        sw    $t1, 8($sp)               # = 0xafa90008   op 0x2b
        beq   $t0, $t1, top             # = 0x1109ffec   ở 0x4c: (0 − 0x50) / 4 = −20
        bne   $t0, $t1, fwd             # = 0x15090006   ở 0x50: (0x6c − 0x54) / 4 = 6
        j     top                       # = 0x08000000
        jal   fwd                       # = 0x0c00001b   0x6c >> 2
        mul   $t2, $t0, $t1             # = 0x71095002   SPECIAL2 0x1c, funct 0x02
        bcd   $t2, $t0                  # = 0x71005010   rs 8, rd 10, funct 0x10
        mfc0  $t1, $12                  # = 0x40096000   COP0 rs 0, rt 9, rd 12
        mtc0  $t1, $14                  # = 0x40897000   COP0 rs 4, rd 14
fwd:    eret                            # = 0x42000018
        nop                             # = 0x00000000
        move  $t2, $t1                  # = 0x00095021   addu $t2, $0, $t1
        li    $t1, -5                   # = 0x2409fffb   addiu $t1, $0, −5
        li    $t1, 0x8000               # = 0x34098000   ori $t1, $0, 0x8000
        li    $t1, 0x12345678           # = 0x3c011234 0x34295678   lui $at + ori $t1, $at
        la    $t1, fwd                  # = 0x3c010000 0x3429006c   luôn 2 lệnh
        b     top                       # = 0x1000ffdb   beq $0,$0 ở 0x90: (0 − 0x94) / 4 = −37
        .word 0xdeadbeef, fwd           # = 0xdeadbeef 0x0000006c
        addu  $10, $8, $9               # = 0x01095021   thanh ghi viết bằng số
