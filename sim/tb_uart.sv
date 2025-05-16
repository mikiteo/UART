`timescale 1ns / 1ps

module tb_uart_top;

    logic clk = 0;
    logic rx;
    logic tx;
    logic [1:0] sw;
    logic [1:0] btn;
    logic bin;
    logic [3:0] led;

  // Clock generation (100 MHz)
    always #5 clk = ~clk;  // 10 ns period

    // Instantiate DUT
    uart_top #(
      .SYNTHESIS(1'b0)
    ) dut (
      .clk_in(clk),
      .sw(sw),
      .btn(btn),
      .ck_io2(bin),
      .ck_io1(rx),
      .ck_io0(tx),
      .led(led)
    );

    // Stimulus
    initial begin
      // Reset
      #25;
      sw = "00";
      btn <= "01";
      #1000us
      btn <= "00";
      #2000us
      btn <= 2'b10;
      
      #1000us
      btn <= "01";
      #1000us
      btn <= "00";
      $display("[INFO] UART test completed");
      $finish;
    end

endmodule
