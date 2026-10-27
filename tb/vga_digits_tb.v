// vga_digits_tb.v — gói D5 (display-spec §7, test V-1…V-3)
// V-1: hsync thấp đúng x 656…751, vsync thấp đúng y 490…491, khung 800 × 525 pixel, pixel = 2 chu kỳ clk.
// V-2: vga_map khớp tb/vectors/vga_points.txt (ô, đoạn).
// V-3: 1 khung "12.34.56" có ô nháy (dim) + chấm → work/vga_frame.ppm (mở xem bằng mắt) và so TỪNG pixel hiện
//      (640 × 480) với mô hình trong tb (bảng đoạn của spec + bảng mã → đoạn chép từ display-spec §3).
// Code do Claude viết theo yêu cầu Long (26/10/2026).
`timescale 1ns/1ps
module vga_digits_tb;
    reg         clk = 0, rst = 1;
    reg  [63:0] disp;
    reg  [7:0]  dim;
    wire        hs, vs;
    wire [11:0] rgb;

    vga_digits dut (.clk(clk), .rst(rst), .disp(disp), .dim(dim), .hsync(hs), .vsync(vs), .rgb(rgb));

    reg  [9:0] mx, my;
    wire [2:0] mcell, msg;
    wire       mhit;
    vga_map u_m (.x(mx), .y(my), .ci(mcell), .sg(msg), .hit(mhit));

    always #10 clk = ~clk;

    integer n, nerr, fd, r, x, y, c, s, k, nbad, t0, t1, ph, pv, h0, h1, fp;
    reg [8*80:1] line;

    task check(input cond, input [8*60:1] what);
        begin
            n = n + 1;
            if (!cond) begin nerr = nerr + 1; $display("loi %0s", what); end
        end
    endtask

    // mô hình độc lập: đoạn ở (u, v) theo bảng display-spec §7; −1 = không
    function integer seg_at(input integer u, input integer v);
        begin
            seg_at = -1;
            if (u >= 20 && u < 60 && v >= 8   && v < 16)  seg_at = 0;
            if (u >= 60 && u < 68 && v >= 16  && v < 76)  seg_at = 1;
            if (u >= 60 && u < 68 && v >= 84  && v < 144) seg_at = 2;
            if (u >= 20 && u < 60 && v >= 144 && v < 152) seg_at = 3;
            if (u >= 12 && u < 20 && v >= 84  && v < 144) seg_at = 4;
            if (u >= 12 && u < 20 && v >= 16  && v < 76)  seg_at = 5;
            if (u >= 20 && u < 60 && v >= 76  && v < 84)  seg_at = 6;
            if (u >= 70 && u < 78 && v >= 144 && v < 152) seg_at = 7;
        end
    endfunction
    function [6:0] gfedcba(input [4:0] code);            // display-spec §3 (chỉ các mã dùng trong khung thử)
        case (code)
            5'h00: gfedcba = 7'h3F;  5'h01: gfedcba = 7'h06;  5'h02: gfedcba = 7'h5B;  5'h03: gfedcba = 7'h4F;
            5'h04: gfedcba = 7'h66;  5'h05: gfedcba = 7'h6D;  5'h06: gfedcba = 7'h7D;  5'h08: gfedcba = 7'h7F;
            default: gfedcba = 7'h00;                     // 0x1A trống
        endcase
    endfunction
    function [11:0] model(input integer x, input integer y);
        integer cl, sgi;
        reg [7:0] d;
        begin
            model = 12'h000;
            if (x < 640 && y >= 160 && y < 320) begin
                cl = 7 - x / 80;
                sgi = seg_at(x % 80, y - 160);
                d = disp[8*cl +: 8];
                if (sgi >= 0)
                    model = ((sgi == 7 ? d[7] : gfedcba(d[4:0]) >> sgi) & 1) && !dim[cl] ? 12'hFFF : 12'h222;
            end
        end
    endfunction

    initial begin
        n = 0; nerr = 0;
        // ---- V-2: hàm (x, y) → (ô, đoạn)
        fd = $fopen("tb/vectors/vga_points.txt", "r");
        if (fd == 0) begin $display("FAIL vga_digits_tb khong mo duoc vga_points.txt"); $finish; end
        k = 0; nbad = 0;
        r = $fgets(line, fd);                             // dòng chú thích
        while (!$feof(fd)) begin
            r = $fscanf(fd, "%d %d %d %d\n", x, y, c, s);
            if (r == 4) begin
                mx = x;  my = y;  #1;
                k = k + 1;
                if (mhit != (s != -1)) nbad = nbad + 1;
                else if (s != -1 && (mcell != c || msg != s)) nbad = nbad + 1;
                if (c != -1 && mcell != c) nbad = nbad + 1;      // trong vùng chữ số: ô đúng cả ở điểm nền
            end
        end
        $fclose(fd);
        check(k == 595 && nbad == 0, "V-2: 595 diem vga_points.txt");
        if (k != 595 || nbad) $display("  %0d diem, %0d sai", k, nbad);

        // ---- V-1: thời gian quét
        disp = {8'h1A, 8'h1A, 8'h01, 8'h82, 8'h03, 8'h84, 8'h05, 8'h06};   // "  12.34.56"
        dim  = 8'b0000_0100;                              // ô 2 ("4.") đang ở nửa tắt của nháy
        repeat (4) @(negedge clk);
        rst = 0;
        @(negedge vs);  t0 = $time;
        @(negedge vs);  t1 = $time;
        check(t1 - t0 == 800 * 525 * 2 * 20, "V-1: khung = 800 x 525 pixel x 2 chu ky");
        @(negedge hs);  t0 = $time;
        @(posedge hs);  t1 = $time;
        check(t1 - t0 == 96 * 40, "V-1: hsync thap 96 pixel");
        @(negedge hs);
        check($time - t0 == 800 * 40, "V-1: dong = 800 pixel");
        @(posedge vs);  t1 = $time;
        @(negedge vs);
        check($time - t1 == 523 * 800 * 40, "V-1: vsync thap 2 dong (cao 523 dong)");

        // ---- V-3: 1 khung pixel theo pixel. rgb chốt ở cạnh pe với hc, vc cũ → pixel (x, y) nằm ở rgb sau cạnh đó
        @(posedge vs);                                    // đầu dòng 492 → chờ về đầu khung (hc = vc = 0)
        while (!(dut.hc == 0 && dut.vc == 0 && dut.pe)) @(negedge clk);
        fp = $fopen("work/vga_frame.ppm", "w");
        $fwrite(fp, "P3\n640 480\n15\n");
        nbad = 0;  h0 = 0;  h1 = 0;
        for (y = 0; y < 480; y = y + 1) begin
            for (x = 0; x < 800; x = x + 1) begin
                ph = dut.hc;  pv = dut.vc;                // pixel sắp chốt ở cạnh kế (pe = 1)
                @(posedge clk); #1;
                if (ph != x || pv != y) nbad = nbad + 1;
                if (x < 640) begin
                    if (rgb !== model(x, y)) begin
                        if (nbad < 5) $display("  pixel (%0d,%0d) rgb %h, mong %h", x, y, rgb, model(x, y));
                        nbad = nbad + 1;
                    end
                    $fwrite(fp, "%0d %0d %0d ", rgb[11:8], rgb[7:4], rgb[3:0]);
                    if (rgb == 12'hFFF) h1 = h1 + 1;
                    if (rgb == 12'h222) h0 = h0 + 1;
                end else if (rgb !== 12'h000) nbad = nbad + 1;   // ngoài vùng hiện: đen
                @(posedge clk); #1;                       // chu kỳ không có pe
            end
            $fwrite(fp, "\n");
        end
        $fclose(fp);
        check(nbad == 0, "V-3: 640 x 480 pixel dung mo hinh (sang FFF / mo 222 / nen 000)");
        $display("  V-3: %0d pixel sang, %0d pixel vet mo -> work/vga_frame.ppm", h1, h0);
        check(h1 > 0 && h0 > 0, "khung co ca doan sang va vet mo");

        if (nerr == 0) $display("PASS vga_digits_tb %0d", n);
        else           $display("FAIL vga_digits_tb %0d loi / %0d kiem tra", nerr, n);
        $finish;
    end
endmodule
