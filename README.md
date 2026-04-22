# RECAP
## Reconfigurable Ethernet-Based Accelerator Platform

## Third-Party IP

This project uses Ethernet MAC and AXI-stream components from:
https://github.com/alexforencich/verilog-ethernet

These are located under:
rtl/vendor/verilog-ethernet/

All RECAP framework logic, UDP stack, and parsing modules are original work.

---

## 1. Overview

RECAP is a modular FPGA accelerator framework that enables custom RTL plugins to be deployed as Ethernet-connected hardware accelerators.

The platform provides:

- A standardized AXI-Stream data plane
- An AXI-Lite control plane
- A reusable Ethernet transport infrastructure

This architecture allows developers to focus on accelerator logic while RECAP manages host communication, packet transport, clocking, and system integration.

---

## 2. Motivation

Developing FPGA accelerators often requires significant system-level infrastructure:

- Ethernet transport handling
- Packet framing and parsing
- Register maps and software control
- Clock domain management
- Simulation and verification scaffolding

RECAP abstracts this infrastructure into a reusable framework, enabling new hardware accelerators to be integrated as modular plugins with minimal overhead.

The goal is to standardize the host <-> FPGA boundary, making accelerator development repeatable and scalable.

---

## 3. High-Level Architecture

RECAP is organized into two primary domains:

- **Data Plane** (high-throughput streaming path)
- **Control Plane** (software configuration and status)

---

### 3.1 Data Plane

Host PC
│
Ethernet (UDP)
│
[ MAC / PHY ]
│
[ AXI-Stream RX ]
│
[ Plugin Interface ]
│
[ AXI-Stream TX ]
│
Ethernet

Characteristics:

- 64-bit AXI-Stream interface
- `TDATA`, `TKEEP`, `TVALID`, `TREADY`, `TLAST`
- Frame-oriented processing
- Deterministic beat-level control
- Packet boundary propagation via `TLAST`

The data plane enables high-throughput streaming of Ethernet frames into accelerator plugins.

---

### 3.2 Control Plane

Host
│
UDP Control Packet
│
AXI-Lite Register Map
│
Plugin Configuration / Status

Characteristics:

- AXI-Lite register interface
- Memory-mapped configuration registers
- Software-configurable accelerator parameters
- Status monitoring and control signaling

The control plane allows software to configure and monitor accelerator behavior at runtime.

---

## 4. Current Features

- 64-bit AXI-Stream Ethernet pipeline
- GMII/RGMII MAC integration
- CRC validation
- Frame boundary detection
- Modular plugin interface
- Loopback reference plugin
- In-progress UDP parsing engine
- Structured simulation environment with packet-level testcases
- Clean-room rebuild of selected components to avoid GPL licensing constraints

---

## 5. Plugin Model

A plugin is a self-contained RTL module that integrates into RECAP via:

- AXI-Stream (data plane)
- AXI-Lite (control plane)

Plugins may:

- Process incoming Ethernet frames
- Generate response frames
- Expose configuration registers
- Implement domain-specific acceleration logic

Example use cases:

- UDP packet processing
- Low-latency trading logic
- Streaming analytics
- Real-time audio processing

This model cleanly separates transport infrastructure from application-specific acceleration logic**.

---

## 6. Example Plugin: UDP Engine (Work in Progress)

The UDP engine plugin parses incoming Ethernet frames and extracts UDP payload data for downstream processing.

Current capabilities:

- 64-bit AXI-Stream beat parsing
- Frame boundary detection via `TLAST`
- Header field extraction
- Payload length tracking
- Structured parsing aligned with Ethernet → IP → UDP layering

The UDP engine demonstrates how higher-layer protocol logic can be modularized within the RECAP framework.

---

## 7. Target Platform

- **Board:** Digilent Genesys 2
- **FPGA:** Xilinx Kintex-7
- **Toolchain:** Vivado 2025.x
- **Simulation:** Vivado XSIM

---

## 8. Design Philosophy

RECAP is built around three principles:

1. Clear separation of transport, control, and acceleration logic
2. Deterministic streaming interfaces using AXI-Stream
3. Reusability across multiple accelerator use cases

The platform is intended to serve as a reusable foundation for Ethernet-connected FPGA accelerators.

---

## 9. Roadmap

Planned enhancements include:

- Full UDP transmit path
- ARP handling
- Multi-plugin support
- DMA integration
- PCIe backend option
- Latency and throughput optimization
- Software API abstraction layer

---

## License

Source-available for educational purposes only. Not for reuse or distribution.

---


