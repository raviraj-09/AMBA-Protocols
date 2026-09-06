# AXI4-Lite Protocol Verification using UVM

## Overview

This project focuses on verifying an **AXI4-Lite slave interface** using **SystemVerilog and UVM**. A reusable UVM-based verification environment is developed to generate, drive, monitor, and check AXI read/write transactions.

The project is kept simple initially and can later be extended to advanced AXI4 features such as burst transfers and outstanding transactions.

## AXI4-Lite Channels

AXI4-Lite consists of five independent channels:

| Channel | Direction | Purpose |
|---|---|---|
| AW | Master → Slave | Write Address |
| W | Master → Slave | Write Data |
| B | Slave → Master | Write Response |
| AR | Master → Slave | Read Address |
| R | Slave → Master | Read Data |

AXI transfers are completed using the `VALID && READY` handshake.

### Write Transaction

```text
Master                         Slave

AWADDR  -------------------->
AWVALID -------------------->
        <-------------------- AWREADY

WDATA   -------------------->
WSTRB   -------------------->
WVALID  -------------------->
        <-------------------- WREADY

        <-------------------- BRESP
        <-------------------- BVALID
BREADY  -------------------->
```

Important handshakes:

```text
AWVALID && AWREADY   → Write address transfer
WVALID  && WREADY    → Write data transfer
BVALID  && BREADY    → Write response transfer
```

### Read Transaction

```text
Master                         Slave

ARADDR  -------------------->
ARVALID -------------------->
        <-------------------- ARREADY

        <-------------------- RDATA
        <-------------------- RRESP
        <-------------------- RVALID

RREADY  -------------------->
```

Important handshakes:

```text
ARVALID && ARREADY   → Read address transfer
RVALID  && RREADY    → Read data transfer
```

## UVM Verification Architecture

```text
                 UVM TESTBENCH
                      |
                      v
                  TEST
                      |
                      v
                  SEQUENCE
                      |
                      v
                 SEQUENCER
                      |
                      v
                   DRIVER
                      |
                      | AXI4-Lite signals
                      v
                    DUT
                 AXI4-Lite
                   SLAVE
                      |
                      v
                  MONITOR
                      |
                      v
                 SCOREBOARD
                      |
                      v
                  PASS/FAIL
```

The UVM environment follows a transaction-level verification approach:

```text
Sequence
   ↓
Transaction
   ↓
Sequencer
   ↓
Driver
   ↓
DUT
   ↓
Monitor
   ↓
Scoreboard
   ↓
PASS / FAIL
```

## Project Structure

```text
axi_uvm_verification/
│
├── rtl/
│   └── axi_slave.sv
│
├── tb/
│   ├── axi_if.sv
│   ├── axi_transaction.sv
│   ├── axi_sequence.sv
│   ├── axi_sequencer.sv
│   ├── axi_driver.sv
│   ├── axi_monitor.sv
│   ├── axi_agent.sv
│   ├── axi_scoreboard.sv
│   ├── axi_env.sv
│   ├── axi_test.sv
│   └── tb_top.sv
│
├── sim/
│
└── README.md
```

## Verification Plan

The verification environment will cover:

- Basic AXI4-Lite write transactions
- Basic AXI4-Lite read transactions
- Multiple read/write transactions
- Different address and data combinations
- `VALID/READY` handshake behavior
- Backpressure conditions
- Directed test cases
- Constrained-random transactions
- Scoreboard-based checking
- Waveform debugging
- Protocol compliance checking

## Example Transactions

### Write

```text
Address = 0x00001000
Data    = 0x12345678
```

Expected behavior:

```text
Write Address → Write Data → Write Response
```

### Read

```text
Address = 0x00001000
```

If the previous write was successful:

```text
Expected RDATA = 0x12345678
```

## Verification Components

### Transaction

Represents an AXI operation at the transaction level.

Example:

```text
is_write = 1
addr     = 0x00001000
data     = 0x12345678
```

### Sequence

Generates AXI transactions and provides stimulus to the sequencer.

### Sequencer

Controls the flow of sequence items from the sequence to the driver.

### Driver

Converts transaction-level information into actual AXI4-Lite interface signals and drives them to the DUT.

### Monitor

Observes AXI signals and reconstructs transactions without driving the interface.

### Scoreboard

Compares the expected behavior with the actual transactions observed by the monitor and reports PASS/FAIL.

## Testing and Debugging

Simulation waveforms will be used to verify:

```text
AWVALID / AWREADY
AWADDR

WVALID / WREADY
WDATA / WSTRB

BVALID / BREADY
BRESP

ARVALID / ARREADY
ARADDR

RVALID / RREADY
RDATA / RRESP
```

Special attention will be given to cases where:

```text
VALID = 1
READY = 0
```

to verify that transactions are not incorrectly lost or changed before the handshake occurs.

## Expected Outcome

The final verification environment should be capable of:

1. Generating AXI4-Lite read/write transactions.
2. Driving transactions to the DUT.
3. Monitoring AXI channel activity.
4. Checking expected versus actual results.
5. Detecting incorrect handshake behavior.
6. Debugging protocol issues using simulation waveforms.

## Tools

- SystemVerilog
- UVM
- QuestaSim / ModelSim or another UVM-compatible simulator
- Waveform viewer
- Git / GitHub

## Resume Alignment

This project supports the following resume points:

- **Developed a UVM-based verification environment for AXI protocol verification.**
- **Created and executed test cases to verify AXI read/write transactions.**
- **Performed simulation and waveform debugging to validate protocol compliance.**

## Future Enhancements

The environment can be extended with:

- Constrained-random verification
- Functional coverage
- SystemVerilog assertions
- Error-response testing
- AXI4 burst transactions
- Outstanding transactions
- More comprehensive protocol checking
