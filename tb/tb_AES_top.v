`timescale 1ns/1ps

module tb_AES_top;

    // Clock & reset
    reg clk;
    reg rst_n;

    // Key interface
    reg         load_new_key;
    reg [127:0] cipher_key;

    // Encryption interface
    reg         enc_in_valid;
    reg [127:0] plain_text;
    wire        enc_out_valid;
    wire [127:0] cipher_text_out;

    // Decryption (unused)
    reg         dec_in_valid;
    reg [127:0] cipher_text_in;
    wire        dec_out_valid;
    wire [127:0] plain_text_out;

    // Status
    wire done_key_expansion, key_is_valid;

    // Test vectors
    reg [127:0] plain_texts   [0:3];
    reg [127:0] cipher_refs   [0:3];

    // Reference tracking
    integer tx_idx;
    integer rx_idx;

    // DUT
    AES_top #(.NR(10)) dut (
        .clk(clk),
        .rst_n(rst_n),

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

    // Clock: 100 MHz
    initial clk = 0;
    always #5 clk = ~clk;

    // Input reference index (tracks inputs)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            tx_idx <= 0;
        else if (enc_in_valid)
            tx_idx <= tx_idx + 1;
    end

    // Output reference index (tracks outputs)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rx_idx <= 0;
        else if (enc_out_valid)
            rx_idx <= rx_idx + 1;
    end
    
    always @(posedge clk) begin
    if (rst_n) begin
        $display(
            "[%0t] in_valid=%b  plain=%h | out_valid=%b  cipher=%h",
            $time,
            enc_in_valid,
            plain_text,
            enc_out_valid,
            cipher_text_out
        );
    end
end

    // Stimulus
    initial begin
        // NIST AES-128 test vectors
        plain_texts[0] = 128'h00112233445566778899aabbccddeeff;
        plain_texts[1] = 128'h01010101010101010101010101010101;//
        plain_texts[2] = 128'h101112131415161718191a1b1c1d1e1f;
        plain_texts[3] = 128'hffffffffffffffffffffffffffffffff;

        cipher_refs[0] = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;
        cipher_refs[1] = 128'hc352805754237f311ac0fff4e3e03e78;
        cipher_refs[2] = 128'h07feef74e1d5036e900eee118e949293; 
        cipher_refs[3] = 128'h3c441f32ce07822364d7a2990e50bb13;

        // Defaults
        rst_n           = 0;
        load_new_key   = 0;
        cipher_key     = 0;
        enc_in_valid   = 0;
        plain_text     = 0;
        dec_in_valid   = 0;
        cipher_text_in = 0;

        // Reset
        #20;
        rst_n = 1;

        // Load key
        @(posedge clk);
        cipher_key   = 128'h000102030405060708090A0B0C0D0E0F;//
        load_new_key = 1;

        @(posedge clk);
        load_new_key = 0;

        // Wait for key expansion
        wait (done_key_expansion);
        @(posedge clk);
        //@(posedge clk);
        //@(posedge clk);
        // ---- CONTINUOUS STREAM (1 input / cycle) ----
        enc_in_valid = 1;
        for (integer i = 0; i < 4 ; i = i + 1) begin
           
            plain_text = plain_texts[i];
            @(posedge clk);
        end
        //@(posedge clk);
        enc_in_valid = 0;
        plain_text   = 0;
        
        

        // Let outputs drain
        repeat (40) @(posedge clk);
        $finish;
    end
    
    

endmodule
