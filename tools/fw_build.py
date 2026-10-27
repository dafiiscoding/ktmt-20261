"""Dịch firmware .s → .hex cho IMEM.

  python tools/fw_build.py fw/demo/clock.s work/clock.hex          # asm.py (B1), mặc định từ 03/10
  python tools/fw_build.py --mars fw/demo/clock.s work/clock.hex   # MARS 4.5 như trước (bcd qua teq, .org → nop)

Từ 03/10 dùng `tools/asm.py`: cho ra .hex giống MARS từng word với mọi file trong fw/ (tools/test_asm.py B1-2),
nhanh hơn, không cần Java, có `.lst` và báo lỗi có số dòng.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


def main():
    args = sys.argv[1:]
    use_mars = "--mars" in args
    args = [a for a in args if a != "--mars"]
    if len(args) != 2:
        print(__doc__)
        sys.exit(2)
    src, hexf = args
    os.makedirs(os.path.dirname(os.path.abspath(hexf)), exist_ok=True)
    if use_mars:
        from cosim_mars import mars_assemble
        _, n = mars_assemble(src, hexf)
    else:
        import asm
        if asm.main([src, "-o", hexf, "--aw", "11"]) != 0:   # soc_top G_IMEM_AW = 11 (main.s > 1024 lệnh, 26/10)
            sys.exit(1)
        return
    print("%s: %d word -> %s" % (src, n, hexf))


if __name__ == "__main__":
    main()
