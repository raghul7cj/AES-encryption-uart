/*
 * ============================================================================
 * Vitis Application: Custom AES IP Debug with ILA and TeraTerm
 * ============================================================================
 *
 * PURPOSE:
 *   This code is specifically designed for debugging a custom AES-128 IP
 *   that fails for non-zero input patterns (0xFF) but works for 0x00.
 *   It uses a blocking UART read (inbyte()) to pause execution before
 *   starting the DMA transfer, allowing you to arm the ILA in Vivado
 *   Hardware Manager.
 *
 * REQUIRED SETUP:
 *   1. Board: Pynq-Z2 (Zynq-7020)
 *   2. Toolchain: Vitis 2022.2
 *   3. Connection: USB-UART (TeraTerm @ 115200, 8N1, no flow control)
 *   4. Vivado Hardware Manager open with ILA probes on SAXIS of AES IP
 *   5. BSP Configuration: stdin/stdout must be set to ps7_uart_1
 *
 * WORKFLOW (execute exactly in this order):
 *   1. Open TeraTerm and connect to Pynq-Z2 COM port.
 *   2. In Vitis, build project and launch hardware debug.
 *   3. Program FPGA from Vitis (debug launch does this automatically).
 *   4. Run to breakpoint at wait_for_ila_setup().
 *   5. Switch to Vivado Hardware Manager, reprogram FPGA with ILA bitstream.
 *   6. Set ILA trigger condition (e.g., s_axis_tdata != 0) and arm trigger.
 *   7. Return to TeraTerm, press any key.
 *   8. DMA transfer starts, ILA triggers on non-zero data, capture waveform.
 *
 * NOTE: This file contains NO fake hardware-software triggers.
 *       The pause is purely human-mediated via UART console input.
 *
 * ============================================================================
 */

#include <stdio.h>
#include <string.h>
#include "xil_cache.h"
#include "xil_printf.h"
#include "xparameters.h"
#include "xaxidma.h"
#include "xuartps_hw.h"        // For UART hardware definitions (optional)

// ----------------------------------------------------------------------------
// Hardware Parameters
// ----------------------------------------------------------------------------
#define DMA_DEV_ID          XPAR_AXIDMA_0_DEVICE_ID
#define MEM_SIZE            32          // 32 bytes = 2 x 128-bit blocks

// ----------------------------------------------------------------------------
// Global Data
// ----------------------------------------------------------------------------
u8 TxBuffer[MEM_SIZE] __attribute__ ((aligned(32)));
u8 RxBuffer[MEM_SIZE] __attribute__ ((aligned(32)));

XAxiDma AxiDma;

// ----------------------------------------------------------------------------
// Function: wait_for_ila_setup()
//
//   Prints instructions, then blocks until a character is received via UART.
//   Place a breakpoint on the call to this function in Vitis.
// ----------------------------------------------------------------------------
void wait_for_ila_setup(void)
{
    xil_printf("\n\r");
    xil_printf("========================================================\n\r");
    xil_printf("   ILA SETUP - DEBUG PAUSE\n\r");
    xil_printf("========================================================\n\r");
    xil_printf("1. Switch to Vivado Hardware Manager.\n\r");
    xil_printf("2. Program FPGA with ILA bitstream (if not already done).\n\r");
    xil_printf("3. Select ILA core, set trigger: s_axis_tdata != 0.\n\r");
    xil_printf("4. Click 'Run Trigger' (triangle icon).\n\r");
    xil_printf("5. Verify status shows 'Waiting for trigger'.\n\r");
    xil_printf("6. Return to TeraTerm and press ANY key to continue.\n\r");
    xil_printf("========================================================\n\r\n\r");

    // Block until a key is pressed in TeraTerm
    char c = 0;
    while (c == 0) {
        c = inbyte();   // Waits indefinitely for UART RX character
    }

    xil_printf("Resuming DMA transfer...\n\r\n\r");
}

// ----------------------------------------------------------------------------
// Function: print_buffer()
//
//   Utility to print a buffer in hex, 16 bytes per line.
// ----------------------------------------------------------------------------
void print_buffer(u8 *Buffer, int Length, const char *Label)
{
    xil_printf("\n\r--- %s ---\n\r", Label);
    for (int i = 0; i < Length; i++) {
        xil_printf("%02X ", Buffer[i]);
        if ((i + 1) % 16 == 0) xil_printf("\n\r");
    }
    xil_printf("\n\r");
}

// ----------------------------------------------------------------------------
// MAIN APPLICATION
// ----------------------------------------------------------------------------
int main(void)
{
    XAxiDma_Config *CfgPtr;

    xil_printf("\n\r=== AES-128 IP Debug with ILA ===\n\r");

    // 1. Initialize the AXI DMA engine
    CfgPtr = XAxiDma_LookupConfig(DMA_DEV_ID);
    XAxiDma_CfgInitialize(&AxiDma, CfgPtr);
    // Disable interrupts (polling mode)
    XAxiDma_IntrDisable(&AxiDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);
    XAxiDma_IntrDisable(&AxiDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);

    // 2. Prepare test data – ALL NON-ZERO (0xFF) to trigger the failure case
    for (int i = 0; i < MEM_SIZE; i++) {
        TxBuffer[i] = 0xFF;      // Failing pattern
        RxBuffer[i] = 0x00;      // Clear receive buffer
    }

    // 3. Display initial buffer contents (for verification)
    print_buffer(TxBuffer, MEM_SIZE, "SENT DATA (TX)");
    print_buffer(RxBuffer, MEM_SIZE, "RECEIVED DATA (PRE-TRANSFER)");

    // 4. Cache maintenance before DMA
    Xil_DCacheFlushRange((UINTPTR)TxBuffer, MEM_SIZE);
    Xil_DCacheInvalidateRange((UINTPTR)RxBuffer, MEM_SIZE);

    // ------------------------------------------------------------------------
    // 5. DEBUG BREAKPOINT – ILA SETUP
    // ------------------------------------------------------------------------
    // SET YOUR BREAKPOINT HERE in Vitis debugger.
    // When the breakpoint hits, execution stops; follow the instructions
    // printed to TeraTerm to arm the ILA, then press any key to continue.
    // ------------------------------------------------------------------------
    wait_for_ila_setup();

    // 6. Start DMA transfers:
    //    - MM2S: Send TxBuffer to AES IP (plaintext input)
    //    - S2MM: Receive ciphertext from AES IP into RxBuffer
    XAxiDma_SimpleTransfer(&AxiDma, (UINTPTR)RxBuffer, MEM_SIZE, XAXIDMA_DEVICE_TO_DMA);
    XAxiDma_SimpleTransfer(&AxiDma, (UINTPTR)TxBuffer, MEM_SIZE, XAXIDMA_DMA_TO_DEVICE);

    // 7. Wait for both channels to complete
    while (XAxiDma_Busy(&AxiDma, XAXIDMA_DMA_TO_DEVICE));
    while (XAxiDma_Busy(&AxiDma, XAXIDMA_DEVICE_TO_DMA));

    // 8. Invalidate cache before reading RxBuffer
    Xil_DCacheInvalidateRange((UINTPTR)RxBuffer, MEM_SIZE);

    // 9. Display results
    print_buffer(RxBuffer, MEM_SIZE, "RECEIVED DATA (POST-TRANSFER)");

    // 10. Compare buffers
    if (memcmp(TxBuffer, RxBuffer, MEM_SIZE) == 0) {
        xil_printf("\n\rRESULT: SUCCESS – Buffers match.\n\r");
    } else {
        xil_printf("\n\rRESULT: FAILURE – Data mismatch (expected).\n\r");
    }

    xil_printf("\n\r=== Test Complete ===\n\r");
    return 0;
}

/* ============================================================================
 * ADDITIONAL NOTES:
 *
 * 1. If inbyte() never returns:
 *    - Ensure TeraTerm is opened BEFORE launching the Vitis debug session.
 *    - Check that the correct COM port and baud rate (115200) are set.
 *    - Verify that stdin/stdout are mapped to UART in BSP settings.
 *
 * 2. To verify UART input works, add this test before wait_for_ila_setup():
 *        xil_printf("Press a key in TeraTerm...\n");
 *        char test = inbyte();
 *        xil_printf("Received: 0x%02x\n", test);
 *
 * 3. After capturing ILA waveforms, you can comment out the call to
 *    wait_for_ila_setup() for normal, non-debug operation.
 *
 * ============================================================================
 */
