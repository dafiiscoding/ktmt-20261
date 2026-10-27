// uart_tb.v — gói D4 (UART): U-1…U-5 (display-spec §9) + U-6 (goi-viec D4) + reset, nhiễu ngắn không thành byte,
// đọc FIFO rỗng, xóa cờ dính (sự kiện thắng lệnh xóa cùng chu kỳ), 2 byte phát liền cách đúng 10 bit, địa chỉ lạ đọc 0, đếm xung rx_ev/tx_ev. G_BIT = 8 → 1 bit = 8 chu kỳ = 160 ns.
`timescale 1ns/1ps
module uart_tb;
    localparam A_STATUS = 8'h50, A_RX = 8'h54, A_TX = 8'h58, B = 8;

    reg         clk = 0, rst = 1, bus_we = 0, bus_re = 0, rx_drv = 1, loop = 0;
    reg  [7:0]  bus_addr = 0;
    reg  [31:0] bus_wdata = 0;
    wire        tx, rx_ev, tx_ev;
    wire [31:0] bus_rdata;
    wire        rx = loop ? tx : rx_drv;

    uart #(.G_BIT(B)) dut (.clk(clk), .rst(rst), .rx(rx), .tx(tx), .bus_addr(bus_addr), .bus_wdata(bus_wdata),
                           .bus_we(bus_we), .bus_re(bus_re), .bus_rdata(bus_rdata), .rx_ev(rx_ev), .tx_ev(tx_ev));

    always #10 clk = ~clk;

    integer n, nerr, i, k, nrx_ev, ntx_ev, nbad, t_a, t_b;
    reg [31:0] d;
    reg [9:0]  wave;

    always @(posedge clk) begin
        if (rx_ev) nrx_ev = nrx_ev + 1;
        if (tx_ev) ntx_ev = ntx_ev + 1;
    end

    task check(input cond, input [8*48:1] what);
        begin
            n = n + 1;
            if (!cond) begin nerr = nerr + 1; if (nerr <= 10) $display("loi %0s: d=%h n=%0d", what, d, dut.n); end
        end
    endtask
    task wr(input [7:0] a, input [31:0] v);
        begin @(negedge clk); bus_addr = a; bus_wdata = v; bus_we = 1; @(negedge clk); bus_we = 0; end
    endtask
    task rd(input [7:0] a);
        begin @(negedge clk); bus_addr = a; bus_re = 1; @(negedge clk); bus_re = 0; d = bus_rdata; end
    endtask
    // tb phát 1 khung 8N1 lên rx; bt = độ dài 1 bit (ns), stop = mức bit stop
    task send(input [7:0] b, input stop, input real bt);
        begin
            rx_drv = 0;  #(bt);
            for (k = 0; k < 8; k = k + 1) begin rx_drv = b[k];  #(bt); end
            rx_drv = stop;  #(bt);
            rx_drv = 1;  #(bt);
        end
    endtask
    // tb thu 1 khung từ tx: chờ start, lấy mẫu giữa bit
    task recv(output [7:0] b, output ok);
        begin
            @(negedge tx);
            t_b = t_a;  t_a = $time;    // thời điểm cạnh start của 2 khung gần nhất
            #(B * 20 / 2);
            ok = (tx == 0);
            for (k = 0; k < 8; k = k + 1) begin #(B * 20); b[k] = tx; end
            #(B * 20);
            ok = ok && tx;
        end
    endtask

    reg [7:0] got;
    reg       ok;

    initial begin #2000000; $display("FAIL uart_tb het gio"); $finish; end
    // ghi 1 xóa cờ đúng chu kỳ khung RX lấy mẫu bit stop (sự kiện cờ xảy ra cùng cạnh)
    task clr_at_stop(input [31:0] v);
        begin
            while (!(dut.rst_st == 2'd2 && dut.rbit == 4'd8 && dut.rcnt == B - 1)) @(negedge clk);
            bus_addr = A_STATUS;  bus_wdata = v;  bus_we = 1;
            @(negedge clk);  bus_we = 0;
        end
    endtask

    initial begin
        n = 0; nerr = 0; nrx_ev = 0; ntx_ev = 0;
        repeat (4) @(negedge clk);
        rst = 0;
        repeat (2) @(negedge clk);
        rd(A_STATUS);
        check(d == 32'h4 && tx === 1'b1, "reset: chi TX_READY, tx nghi = 1");

        // ---- U-1: TX 0x55 → 0,1,0,1,0,1,0,1,0,1, mỗi bit đúng 8 chu kỳ, rồi nghỉ 1
        wr(A_TX, 32'h55);
        @(negedge tx);
        nbad = 0;
        wave = 10'b1010101010;          // bit 0 = start
        for (i = 0; i < 10 * B; i = i + 1) begin
            @(negedge clk);
            if (tx !== wave[i / B]) nbad = nbad + 1;
        end
        repeat (2 * B) begin @(negedge clk); if (tx !== 1'b1) nbad = nbad + 1; end
        check(nbad == 0, "U-1 0x55: 10 bit x 8 chu ky dung");
        check(ntx_ev == 1, "U-1 tx_ev 1 lan");

        // ---- U-6: A vào bộ dịch, B vào bộ đệm, C bị bỏ (TX_DROP); dây ra đúng A rồi B
        ntx_ev = 0;
        fork
            begin
                wr(A_TX, 32'hA1);
                wr(A_TX, 32'hB2);
                rd(A_STATUS);
                check(d[2] == 1'b0, "U-6 bo dem day -> TX_READY = 0");
                wr(A_TX, 32'hC3);
                rd(A_STATUS);
                check(d[4] == 1'b1, "U-6 ghi khi day -> TX_DROP = 1");
            end
            begin
                recv(got, ok);  check(ok && got == 8'hA1, "U-6 byte 1 = A1");
                recv(got, ok);  check(ok && got == 8'hB2, "U-6 byte 2 = B2");
            end
        join
        check(t_a - t_b == 10 * B * 20, "U-6 2 byte lien nhau cach dung 10 bit");
        repeat (12 * B) @(negedge clk);
        check(tx === 1'b1 && ntx_ev == 2, "U-6 C3 khong phat, tx_ev 2 lan");
        wr(A_STATUS, 32'h10);
        rd(A_STATUS);
        check(d == 32'h4, "U-6 ghi 1 xoa TX_DROP");

        // ---- U-2: RX 0xA5 ở baud lệch −2%, 0, +2%
        nrx_ev = 0;
        send(8'hA5, 1, B * 20 * 1.02);
        send(8'hA5, 1, B * 20 * 0.98);
        send(8'h3C, 1, B * 20);
        rd(A_STATUS);
        check(d[0] && d[14:8] == 3 && !d[1] && !d[3], "U-2 3 byte, khong co");
        rd(A_RX);  check(d == 32'h800000A5, "U-2 baud -2% -> A5");
        rd(A_RX);  check(d == 32'h800000A5, "U-2 baud +2% -> A5");
        rd(A_RX);  check(d == 32'h8000003C, "U-2 baud dung -> 3C");
        rd(A_RX);  check(d == 32'h0, "doc FIFO rong -> VALID = 0");
        check(nrx_ev == 3, "rx_ev 3 lan");

        // ---- nhiễu ngắn (< G_BIT/2) không thành byte
        rx_drv = 0;  #(B * 20 / 4);  rx_drv = 1;
        repeat (12 * B) @(negedge clk);
        rd(A_STATUS);
        check(d[14:8] == 0 && !d[3], "xung nhieu ngan -> khong co byte");

        // ---- U-4: bit stop = 0 → bỏ byte, FRAME_ERR
        fork
            send(8'h5A, 0, B * 20);
            clr_at_stop(32'h8);
        join
        rd(A_STATUS);
        check(d[3] && d[14:8] == 0, "U-4 stop = 0 -> bo byte, FRAME_ERR (thang lenh xoa)");
        send(8'h77, 1, B * 20);
        rd(A_STATUS);
        check(d[3] && d[14:8] == 1, "U-4 byte sau van nhan, co van dinh");
        wr(A_STATUS, 32'h8);
        rd(A_STATUS);
        check(!d[3], "U-4 ghi 1 xoa FRAME_ERR");
        rd(A_RX);  check(d == 32'h80000077, "U-4 byte sau = 77");

        // ---- U-3: 65 byte không đọc → giữ 64 byte đầu, RX_OVF
        nrx_ev = 0;
        for (i = 0; i < 64; i = i + 1) send(i * 3 + 1, 1, B * 20);
        fork
            send(64 * 3 + 1, 1, B * 20);
            clr_at_stop(32'h2);
        join
        rd(A_STATUS);
        check(d[14:8] == 64 && d[1], "U-3 65 byte -> 64, RX_OVF = 1 (thang lenh xoa)");
        check(nrx_ev == 64, "U-3 rx_ev 64 lan (byte bo khong bao)");
        nbad = 0;
        for (i = 0; i < 64; i = i + 1) begin
            rd(A_RX);
            if (d !== {1'b1, 23'd0, i[7:0] * 8'd3 + 8'd1}) nbad = nbad + 1;
        end
        check(nbad == 0, "U-3 64 byte dung thu tu");
        rd(A_STATUS);
        check(d[14:8] == 0 && d[1], "U-3 FIFO rong, RX_OVF van dinh");
        wr(A_STATUS, 32'h2);
        rd(A_STATUS);
        check(d == 32'h4, "U-3 ghi 1 xoa RX_OVF");
        rd(8'h5C);
        check(d == 32'h0, "dia chi la doc 0");

        // ---- U-5: loopback TX → RX 256 byte; CPU giả: ghi khi TX_READY, đọc khi RX_AVAIL
        loop = 1;
        nbad = 0;  k = 0;               // k: số byte đã đọc (dùng chung tên với task, task không chạy ở đây)
        i = 0;
        while (k < 256) begin
            rd(A_STATUS);
            if (d[0]) begin
                rd(A_RX);
                if (d !== {1'b1, 23'd0, k[7:0] ^ 8'h5A}) nbad = nbad + 1;
                k = k + 1;
            end else if (d[2] && i < 256) begin
                wr(A_TX, i ^ 8'h5A);
                i = i + 1;
            end
        end
        rd(A_STATUS);
        check(nbad == 0 && !d[1] && !d[3] && !d[4], "U-5 loopback 256 byte khop, khong co loi");
        loop = 0;

        if (nerr == 0) $display("PASS uart_tb %0d", n);
        else           $display("FAIL uart_tb %0d/%0d", nerr, n);
        $finish;
    end
endmodule
