`timescale 1ns/1ps

module tb_axi_aes_stall_test;

    // =========================================================================
    // PARAMETERS
    // =========================================================================
    localparam ADDR_WIDTH = 7;
    localparam DATA_WIDTH = 32;
    localparam STRM_WIDTH = 128;
    // CRITICAL: Set this to match your new BRAM-based latency
    localparam AES_LATENCY = 21; 

    // =========================================================================
    // SIGNALS
    // =========================================================================
    logic clk;
    logic rst_n;

    // AXI-Lite Interface
    logic [ADDR_WIDTH-1:0] s_axi_awaddr;
    logic                  s_axi_awvalid;
    logic                  s_axi_awready;
    logic [DATA_WIDTH-1:0] s_axi_wdata;
    logic                  s_axi_wvalid;
    logic                  s_axi_wready;
    logic [1:0]            s_axi_bresp;
    logic                  s_axi_bvalid;
    logic                  s_axi_bready;
    // Read channels (tied off for this test)
    logic [ADDR_WIDTH-1:0] s_axi_araddr = 0;
    logic                  s_axi_arvalid = 0;
    logic                  s_axi_rready = 0;

    // AXI-Stream Slave (Encryption Input)
    logic [STRM_WIDTH-1:0] s00_axis_tdata;
    logic                  s00_axis_tvalid;
    logic                  s00_axis_tready;
    logic                  s00_axis_tlast;

    // AXI-Stream Master (Encryption Output)
    logic [STRM_WIDTH-1:0] m00_axis_tdata;
    logic                  m00_axis_tvalid;
    logic                  m00_axis_tready;
    logic                  m00_axis_tlast;

    // Unused Decrypt ports
    logic [STRM_WIDTH-1:0] s01_axis_tdata = 0;
    logic                  s01_axis_tvalid = 0;
    logic                  s01_axis_tlast = 0;
    logic                  m01_axis_tready = 1;

    // Test Data
    logic [127:0] plain_texts [0:3];
    integer i;

    // =========================================================================
    // DUT INSTANTIATION
    // =========================================================================
    axi_aes_ip #(
        .C_S_AXI_ADDR_WIDTH(ADDR_WIDTH),
        .C_S_AXI_DATA_WIDTH(DATA_WIDTH),
        .C_AXIS_TDATA_WIDTH(STRM_WIDTH),
        .AES_LATENCY(AES_LATENCY)  // <--- Ensure this is passed!
    ) dut (
        .aclk(clk),
        .aresetn(rst_n),

        // Lite
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        
        // Read ports (Minimal connection)
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_rready(s_axi_rready),

        // Stream Slave (Enc In)
        .s00_axis_tdata(s00_axis_tdata),
        .s00_axis_tvalid(s00_axis_tvalid),
        .s00_axis_tready(s00_axis_tready),
        .s00_axis_tlast(s00_axis_tlast),

        // Stream Master (Enc Out)
        .m00_axis_tdata(m00_axis_tdata),
        .m00_axis_tvalid(m00_axis_tvalid),
        .m00_axis_tready(m00_axis_tready),
        .m00_axis_tlast(m00_axis_tlast),

        // Decrypt (Unused)
        .s01_axis_tdata(s01_axis_tdata),
        .s01_axis_tvalid(s01_axis_tvalid),
        .s01_axis_tlast(s01_axis_tlast),
        .m01_axis_tready(m01_axis_tready)
    );

    // =========================================================================
    // CLOCK & TASKS
    // =========================================================================
    initial clk = 0;
    always #5 clk = ~clk; // 100MHz

    // Task: Write to AXI-Lite Register
    task axi_lite_write(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] data);
        begin
            @(posedge clk);
            s_axi_awaddr  <= addr;
            s_axi_wdata   <= data;
            s_axi_awvalid <= 1'b1;
            s_axi_wvalid  <= 1'b1;
            s_axi_bready  <= 1'b1;

            // Wait for handshake
            wait(s_axi_awready && s_axi_wready);
            
            @(posedge clk);
            s_axi_awvalid <= 1'b0;
            s_axi_wvalid  <= 1'b0;
            
            // Wait for response
            wait(s_axi_bvalid);
            @(posedge clk);
            s_axi_bready  <= 1'b0;
            
            $display("[AXI-LITE] Wrote 0x%h to Addr 0x%h", data, addr);
        end
    endtask

    // =========================================================================
    // STIMULUS
    // =========================================================================
    initial begin
        // Setup Waveform
        $dumpfile("stall_test.vcd");
        $dumpvars(0, tb_axi_aes_stall_test);

        // Test Vectors
        plain_texts[0] = 128'h00112233445566778899aabbccddeeff;
        plain_texts[1] = 128'h01010101010101010101010101010101;
        plain_texts[2] = 128'h101112131415161718191a1b1c1d1e1f;
        plain_texts[3] = 128'hffffffffffffffffffffffffffffffff;

        // Init Signals
        rst_n = 0; 
        s_axi_awvalid = 0; s_axi_wvalid = 0; s_axi_bready = 0;
        s00_axis_tvalid = 0; s00_axis_tlast = 0; s00_axis_tdata = 0;
        m00_axis_tready = 1; // Initially ready

        // Reset
        #20 rst_n = 1;
        #20;

        // --------------------------------------------------------
        // 1. CONFIGURATION
        // --------------------------------------------------------
        $display("\n--- Step 1: Loading Key & Mode ---");
        // Key: 00010203...0F (LSB at addr 0)
        axi_lite_write(7'd0,  32'h0C0D0E0F); // Addr 0
        axi_lite_write(7'd4,  32'h08090A0B); // Addr 4
        axi_lite_write(7'd8,  32'h04050607); // Addr 8
        axi_lite_write(7'd12, 32'h00010203); // Addr 12
        
        // Mode Register (Addr 16 / 0x10)
        axi_lite_write(7'd16, 32'h00000000); // Mode 0

        // Load Pulse Register (Addr 20 / 0x14)
        axi_lite_write(7'd20, 32'h00000001); // Fire pulse

        // Wait for key expansion (simulated via internal wire check or delay)
        #200; 

        // --------------------------------------------------------
        // 2. STREAMING DATA (FILL PIPE)
        // --------------------------------------------------------
        $display("\n--- Step 2: Feeding 4 Packets into Pipeline ---");
        
        for (i = 0; i < 4; i++) begin
            @(posedge clk);
            s00_axis_tvalid = 1;
            s00_axis_tdata  = plain_texts[i];
            s00_axis_tlast  = (i == 3);
            
            // Wait if slave isn't ready (it should be)
            while (!s00_axis_tready) @(posedge clk);
        end
        
        @(posedge clk);
        s00_axis_tvalid = 0; // Stop input
        s00_axis_tdata  = 0;

        // --------------------------------------------------------
        // 3. THE STALL TEST
        // --------------------------------------------------------
        $display("\n--- Step 3: Wait 10 cycles (Data moves to middle) ---");
        repeat (10) @(posedge clk);

        $display("\n!!! FREEZING PIPELINE (Assert Backpressure) !!!");
        $display("Time: %0t ns", $time);
        m00_axis_tready = 0; // <--- STALL COMMAND

        $display("--- Holding Stall for 20 cycles ---");
        repeat (20) @(posedge clk); // Pipeline should hold steady here

        $display("\n!!! RESUMING PIPELINE (Release Backpressure) !!!");
        $display("Time: %0t ns", $time);
        m00_axis_tready = 1; // <--- RELEASE COMMAND

        // --------------------------------------------------------
        // 4. DRAIN & CHECK
        // --------------------------------------------------------
        repeat (40) @(posedge clk);
        $display("\nTest Finished");
        $finish;
    end

    // Monitor Output
    always @(posedge clk) begin
        if (m00_axis_tvalid && m00_axis_tready) begin
            $display("[OUTPUT] Time:%0t | Cipher: %h | TLAST: %b", 
                     $time, m00_axis_tdata, m00_axis_tlast);
        end
        else if (m00_axis_tvalid && !m00_axis_tready) begin
            $error("[ERROR] Valid data asserted while Ready is Low! (Lost Data or Protocol Violation)");
        end
    end

endmodule