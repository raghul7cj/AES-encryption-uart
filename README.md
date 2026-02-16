# AXI-Stream AES-128 Hardware Accelerator IP
**Target Board:** PYNQ-Z2 (Zynq-7020)
**Program:** Tesla VLSI Society and Research Project

---

## 📌 Project Overview
This repository contains a high-performance **AES-128 Encryption Engine** implemented in Verilog. The design is optimized for the **PYNQ-Z2**, allowing the Zynq Processing System (ARM CPU) to offload cryptographic workloads to the Programmable Logic (FPGA) fabric.

It utilizes the **AXI4-Stream** protocol for high-bandwidth data transfers and an **AXI4-Lite** interface for control signaling and key management.

---

## ⚙️ Technical Specifications
* **Algorithm:** AES-128 (FIPS 197 Standard).
* **Interfaces:** AXI4-Lite (Control/Status), AXI4-Stream (Data I/O).
* **Data Width:** 128-bit (AXI-Stream), 32-bit (AXI-Lite).
* **Handshaking:** Fully synchronous with gated `TVALID` to ensure pipeline integrity.
* **Verification:** Validated against NIST Known Answer Tests (KAT).

---

## 📊 Hardware-Software Interface (Register Map)
The IP core is mapped to the Zynq memory space via AXI4-Lite.
| Offset | Name | Description |
| :--- | :--- | :--- |
| 0x00 | REG_KEY_0 | Key Bytes [127:96]  |
| 0x04 | REG_KEY_1 | Key Bytes [95:64]   |
| 0x08 | REG_KEY_2 | Key Bytes [63:32]   |
| 0x0C | REG_KEY_3 | Key Bytes [31:0]    |
| 0x10 | REG_MODE  | 0x01:ENC, 0x11:DEC,0x11:BOTH   |
| 0x14 | REG_TRIG  | Pulse to trigger Key Expansion |
| 0x18 | REG_STAT  | Bit 1: Key Ready, Bit 0: Busy  |

# Block diagram
<img width="1548" height="413" alt="image" src="https://github.com/user-attachments/assets/01cb0643-0ad0-446a-988b-059022a58a17" />


# Simulation results
<img width="1531" height="445" alt="image" src="https://github.com/user-attachments/assets/95e40fca-dff6-463d-ab2f-d5875cefb53d" />

# Block Diagram of AES architecture

<img width="572" height="1024" alt="image" src="https://github.com/user-attachments/assets/7c71cf55-f43f-4f27-9372-cae1b604932d" />

