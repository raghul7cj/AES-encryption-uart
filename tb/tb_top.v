`timescale 1ns/1ps

module tb_AES_top;

    // Clock & reset
    reg clk;
    reg rst_n;
    reg sys_en;

    // Key interface
    reg             load_new_key;
    reg [127:0]     cipher_key;

    // Encryption interface
    reg             enc_in_valid;
    reg [127:0]     plain_text;
    wire            enc_out_valid;
    wire [127:0]    cipher_text_out;

    // Decryption (unused in this test)
    reg             dec_in_valid;
    reg [127:0]     cipher_text_in;
    wire            dec_out_valid;
    wire [127:0]    plain_text_out;

    // Status
    wire done_key_expansion, key_is_valid;

    // Test vectors
    reg [127:0] plain_texts    [0:3];
    reg [127:0] cipher_refs    [0:3];

    // DUT Instance
    AES_top #(.NR(10)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .sys_en(sys_en),        // <--- Connected here

        .load_new_key(load_new_key),
        .cipher_key(cipher_key),

        .enc_in_valid(enc_in_valid),
        .plain_text(plain_text),
        .enc_out_valid(enc_out_valid),
        .cipher_text_out(cipher_text_out),

        .dec_in_valid(dec_in_valid),
        .cipher_text_in(cipher_text_in),
        .dec_out_valid(dec_out_valid),
        .plain_text_out(plain_text_out),

        .done_key_expansion(done_key_expansion),
        .key_is_valid(key_is_valid)
    );

    // Clock Generation: 100 MHz
    initial clk = 0;
    always #5 clk = ~clk;

    // Monitor Output
    always @(posedge clk) begin
        if (rst_n) begin
            // Only print when something interesting happens (valid in or valid out)
            if (enc_in_valid || enc_out_valid || sys_en == 0) begin
                $display(
                    "[%0t] EN=%b | IN_V=%b DATA=%h... | OUT_V=%b CIPHER=%h...",
                    $time,
                    sys_en,
                    enc_in_valid,
                    plain_text[127:112],      // showing top 16 bits to save space
                    enc_out_valid,
                    cipher_text_out[127:112]
                );
            end
        end
    end

    // Stimulus
    initial begin
        // Setup Test Vectors (NIST AES-128)
        plain_texts[0] = 128'h00112233445566778899aabbccddeeff;
        plain_texts[1] = 128'h01010101010101010101010101010101;
        plain_texts[2] = 128'h101112131415161718191a1b1c1d1e1f;
        plain_texts[3] = 128'hffffffffffffffffffffffffffffffff;

        // Initial States
        sys_en         = 1;
        rst_n          = 0;
        load_new_key   = 0;
        cipher_key     = 0;
        enc_in_valid   = 0;
        plain_text     = 0;
        dec_in_valid   = 0;
        cipher_text_in = 0;

        // 1. Reset
        #20;
        rst_n = 1;

        // 2. Load Key
        @(posedge clk);
        cipher_key   = 128'h000102030405060708090A0B0C0D0E0F;
        load_new_key = 1;
        @(posedge clk);
        load_new_key = 0;

        // 3. Wait for Key Expansion
        wait (done_key_expansion);
        @(posedge clk);
        
        $display("---------------------------------------------------");
        $display("[%0t] KEY EXPANSION DONE. STARTING PIPELINE FILL.", $time);
        $display("---------------------------------------------------");

        // 4. PHASE 1: FILL PIPELINE
        // Feed 4 packets consecutively
        enc_in_valid = 1;
        sys_en = 1;
        
        for (integer i = 0; i < 4 ; i = i + 1) begin
            plain_text = plain_texts[i];
            @(posedge clk);
        end

        // 5. PHASE 2: PUSH TO MIDDLE
        // Stop feeding new data, but let the pipe run for 2 cycles 
        // to move data into the middle of the rounds.
        enc_in_valid = 0;
        plain_text   = 0;
        repeat(2) @(posedge clk);

        // 6. PHASE 3: THE FREEZE (STALL)
        // Suddenly stop the clock enable. 
        // Data is now sitting inside the registers (e.g. Round 3, Round 4, etc.)
        $display("---------------------------------------------------");
        $display("[%0t] !!! FREEZING PIPELINE NOW (sys_en = 0) !!!", $time);
        $display("---------------------------------------------------");
        sys_en = 0;
        
        // Hold the freeze for 10 clocks.
        // During this time, NO outputs should appear, and NO data should be lost.
        repeat(10) @(posedge clk);

        // 7. PHASE 4: RESUME
        $display("---------------------------------------------------");
        $display("[%0t] !!! RESUMING PIPELINE NOW (sys_en = 1) !!!", $time);
        $display("---------------------------------------------------");
        sys_en = 1;

        // 8. WAIT FOR RESULTS
        // We expect 4 valid outputs to pop out here.
        repeat(40) @(posedge clk);
        
        $display("---------------------------------------------------");
        $display("[%0t] TEST FINISHED", $time);
        $finish;
    end

endmodule