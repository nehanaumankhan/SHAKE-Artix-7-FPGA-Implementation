# SHAKE-Artix-7-FPGA-Implementation
Wrapper modules built on an open‑source SHAKE (Secure Hash Algorithm Keccak) core, optimised for FPGA (Artix‑7) implementation with on‑chip input/output buffers and a byte‑wide read interface for UART serialisation.

## Overview
Top-level module that integrates SHAKE hash computation with UART serial output.

## Parameters
| Parameter | Default | Description |
|-----------|---------|-------------|
| `clkdiv` | 868 | Clock divider for UART baud rate (868 = 115200 baud @ 100MHz) |
| `OUTPUT_BUFFER_DEPTH_WORDS` | 131072 | Depth of output buffer in words |

## I/O Interface

### Inputs
| Port | Type | Description |
|------|------|-------------|
| `clk` | logic | System clock |
| `rst_n` | logic | Active-low asynchronous reset |
| `start` | logic | Start SHAKE computation (pulse) |

### Outputs
| Port | Type | Description |
|------|------|-------------|
| `tr_start` | logic | SHAKE computation done flag |
| `tr_end` | logic | UART transmission complete flag |
| `tx` | logic | UART serial output (connect to PC RX) |

## Internal Modules

1. **shake_top** - SHAKE hash engine with BRAM interface
2. **uart_controller** - Manages reading from buffer and controlling transmitter
3. **transmitter** - UART serial transmitter (start, data, parity, stop bits)

## Operation Flow

1. Assert `start` pulse to begin SHAKE computation
2. Wait for `tr_start` (SHAKE done)
3. UART automatically transmits 360 bytes of hash digest
4. Monitor `tr_end` for transmission complete
5. `tx` pin outputs serial data (115200 baud, 8 data bits, 1 parity, 1 stop)

## UART Configuration
- **Baud Rate**: 115200 (with 100MHz clock)
- **Data Bits**: 8
- **Parity**: Odd (calculated as ~^data)
- **Stop Bits**: 1
- **Idle State**: High (1)

## FPGA Connections
| FPGA Pin | Connect to |
|----------|------------|
| `tx` | USB-UART RX |
| GND | USB-UART GND |

## Example Usage
```verilog
// Start computation
start = 1;
@(posedge clk);
start = 0;

// Wait for completion
wait(tr_end == 1);
