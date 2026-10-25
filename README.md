# Pedal-Assist eBike Motor Controller

![SystemVerilog](https://img.shields.io/badge/RTL-SystemVerilog-1f6feb)
![ModelSim](https://img.shields.io/badge/Sim-ModelSim-555)
![Quartus](https://img.shields.io/badge/FPGA-Intel%20Quartus-0071c5)
![Genus](https://img.shields.io/badge/ASIC-Cadence%20Genus%20%7C%20FreePDK45-c41230)
![Tests](https://img.shields.io/badge/regression-8%2F8%20passing-2ea44f)

A complete digital controller for a pedal-assist electric bicycle, written in
SystemVerilog and run on a DE0-Nano FPGA (Intel Cyclone IV) driving a real
250 W brushless hub motor. It measures how hard and how fast the rider pedals
and how steep the hill is, decides how much motor current to add, and drives
the motor's six power MOSFETs to deliver it.

UW–Madison ECE 551 (Digital System Design & Synthesis), Spring 2025.

## Highlights

- **Full sensor-to-motor datapath:** SPI ADC and SPI IMU interfaces, sensor
  conditioning, an assist law, a PID current loop, six-step BLDC commutation and
  dead-time-protected PWM, plus UART telemetry.
- **Pipelining the assist datapath raised Fmax 3.8×** on the FPGA
  (36.3 → 139.6 MHz) while using 4.6 % fewer logic elements.
- **ASIC synthesis** with Cadence Genus on the FreePDK45 45 nm library:
  4,304 standard cells (~18.3k µm² cell area) at a 200 MHz clock. Pipelining
  more than doubles the fastest achievable clock (308 → ≥ 667 MHz) and, at the
  same clock, uses up to 26 % fewer cells.
- **Self-checking closed-loop verification:** 8 tests against a physics model
  of the motor, wheel and IMU, 56 M clock cycles per regression.

## Architecture

```
                 ┌──────────────── eBike.sv (synthesized top) ────────────────┐
 A2D (SPI) ────► │ A2D_intf ──► sensorCondition ──► PID ──► brushless ──► mtr_drv │ ──► 6 FET gates
 batt/curr/      │                │  ├ cadence_filt / meas / LU                 │
 brake/torque    │                │  ├ desiredDrive  (target current)           │
 Inertial ─────► │ inert_intf ────┘  └ telemetry ──► UART TX                    │ ──► TX (115200 baud)
 sensor (SPI)    │   └ inertial_integrator (incline)                          │
 Hall sensors ─► │ brushless (commutation)                                    │
 Push button ──► │ PB_intf (assist level) ──────────────────────────────────► │ ──► LED[1:0]
                 └────────────────────────────────────────────────────────────┘
```

| Stage | Module(s) | What it does |
|---|---|---|
| Sensing | `A2D_intf`, `SPI_mnrch` | Round-robin reads of battery voltage, motor current, brake lever and pedal torque from an ADC128S022 over SPI (mode 3, clk/32), one channel every 2¹⁴ clocks (~328 µs) |
| Incline | `inert_intf`, `inertial_integrator` | Configures a 6-axis IMU over SPI; on each data-ready interrupt reads gyro and accelerometer data and fuses them (complementary filter) into a 13-bit incline, zeroed when the bike leans hard into a turn |
| Cadence | `cadence_filt`, `cadence_meas`, `cadence_LU` | Debounces the noisy pedal sensor, measures the pulse period and maps it non-linearly to a 5-bit cadence. Flags `not_pedaling` after 0.3 s without a pulse |
| Conditioning | `sensorCondition` | Exponential averages of current (W=4) and torque (W=32, seeded when pedaling resumes). Produces the signed loop error `target − avg_curr`, forced to 0 on low battery or when not pedaling |
| Assist law | `desiredDrive`, `incline_sat` | `target_curr = torque_pos × incline_lim × cadence_factor × scale`: a pipelined 30-bit product, scaled and saturated to 12 bits |
| Control loop | `PID` | P + I (anti-windup, clipped, cleared when not pedaling) + D (3-sample difference, saturated), updated at 48 Hz. Output clipped to 12-bit `drv_mag` |
| Commutation | `brushless` | Synchronizes the Hall sensors and picks forward, reverse, high-Z or regenerative braking for each coil; duty = `0x400 + drv_mag/4` |
| Power stage | `mtr_drv`, `PWM`, `nonoverlap` | 11-bit PWM (24.4 kHz) to the high/low FETs with a 32-clock (640 ns) dead time, so the two FETs of a leg are never on together |
| User I/O | `PB_intf`, `PB_rise`, `telemetry`, `UART_tx` | Push button cycles the assist level (off/low/med/high) shown on LEDs; an 8-byte telemetry packet (`AA 55` + battery, current, torque) is sent ~48 times a second |
| Reset | `reset_synch` | Asynchronous assert, synchronous deassert |

## Results

### FPGA — DE0-Nano (Cyclone IV E, EP4CE22F17C6, Quartus Prime Lite)

| | Before pipelining | After pipelining |
|---|---|---|
| Logic elements | 1,203 | **1,148** (5 %) |
| Registers | 475 | 546 |
| 9-bit multipliers | 5 | 5 |
| Fmax (slow 85 °C) | 36.3 MHz ✗ | **139.6 MHz** ✓ |

The design has to run at 50 MHz. Splitting the four-way assist multiply into
register stages cut the critical path from ~27.5 ns to ~7.2 ns. The extra
latency is irrelevant to a control loop that updates at 48 Hz.

The same RTL also maps to an Intel Agilex 3 in Quartus Prime Pro (465 ALMs,
716 registers, 3 DSP blocks, no inferred latches, +15.6 ns setup slack at
50 MHz).

### ASIC — Cadence Genus 25.1, OSU FreePDK45 (gscl45nm)

Physical-aware synthesis (PLE: wire delay estimated from the cell LEF),
constraints from the course flow (0.15 ns clock uncertainty, 0.3/0.5 ns I/O
delay, NAND2X1 drive, 50 fF load, 0.2 ns max transition). Every run is checked
for a fully mapped netlist with no latches or unresolved modules. Scripts:
[`syn/genus/`](syn/genus/).

**Same 5 ns (200 MHz) constraint — final design vs. original un-pipelined datapath**

| | Pipelined (final) | Un-pipelined | Change |
|---|---|---|---|
| Standard cells | **4,304** | 5,147 | −16.4 % |
| Flip-flops | 689 | 585 | +104 |
| Cell area (µm²) | **18,302** | 19,908 | −8.1 % |
| Cell + estimated wire area (µm²) | 26,784 | 30,151 | −11.2 % |
| Worst setup slack | **+1.81 ns** | +0.007 ns | |
| Total power (Genus estimate) | | | −8.9 % |

**Clock sweep** — each design re-synthesized at tighter clocks until timing fails:

| Clock period | Pipelined: cells / cell area | Un-pipelined: cells / cell area |
|---|---|---|
| 5.0 ns (200 MHz) | 4,304 / 18,302 | 5,147 / 19,908 |
| 4.0 ns (250 MHz) | 4,499 / 18,482 | 5,503 / 20,320 |
| 3.25 ns (308 MHz) | 4,629 / 18,627 | 6,293 / 21,624 ← fastest it can go |
| 3.0 ns (333 MHz) | 4,669 / 18,812 | ✗ fails (−0.22 ns) |
| 2.5 ns (400 MHz) | 5,257 / 19,652 | |
| 2.0 ns (500 MHz) | 5,611 / 20,403 | |
| 1.5 ns (667 MHz) | 6,724 / 22,555 ← still met (sweep floor) | |

- The un-pipelined design tops out at **3.25 ns**: its critical path runs from
  the cadence period register through the four-way assist product and the
  error subtraction into the PID integrator.
- The pipelined design still meets timing at **1.5 ns**, the end of the sweep.
  There the critical path is no longer the assist datapath but an SPI shift
  register, so the pipelining moved the bottleneck out of the datapath entirely.
- At the same 3.25 ns clock, the pipelined design needs **26 % fewer cells and
  14 % less cell area**: without the long path, the tool does not have to upsize
  and restructure logic to meet timing. The 104 extra flip-flops cost less than
  the logic they save.
- Pushing the pipelined design from 5 ns to 1.5 ns costs +23 % cell area
  (larger, faster cells), the expected area-for-speed trade-off.

Synthesis-only results (no place-and-route); the OSU gscl45nm library is an
academic 45 nm library, so absolute numbers are not comparable to commercial
processes.

## Verification

`tb/eBike_tb.sv` is a closed-loop, self-checking full-chip testbench: the
controller drives a behavioral model of the motor, wheel and IMU, and the model
feeds back Hall signals, motor current and inertial data.

| # | Stimulus | Check |
|---|---|---|
| 1 | Assist level medium → high | wheel speed and current rise |
| 2 | Pedal torque up | wheel speed and current rise |
| 3 | Incline change | wheel speed and current rise |
| 4 | Faster cadence | wheel speed and current rise |
| 5 | Incline change (other direction) | wheel speed and current fall |
| 6 | Rider stops pedaling | wheel speed and current fall |
| 7 | Brake lever pulled | all coils in regenerative braking, wheel slows |
| 8 | Battery below threshold | loop error forced to 0, drive falls |

In every phase the current loop must settle to within ±45 counts of its target
(or be at full drive) before the check, or the test fails.

## Running it

**Simulation** (ModelSim / Questa):

```bash
vlib work
vlog -sv rtl/*.sv tb/models/*.sv tb/eBike_tb.sv
vsim -c eBike_tb -do "run -all; quit -f"
```

**FPGA:** open `fpga/eBike.qpf` in Quartus Prime Lite (Cyclone IV E). The
50 MHz constraint is in `fpga/eBike.sdc`. `FAST_SIM = 0` (default in
`rtl/eBike.sv`) gives real hardware timing.

**ASIC synthesis:**

```bash
cd syn/genus && bash run_genus.sh     # Cadence Genus, FreePDK45
cd syn && dc_shell -f eBike.dc         # original course Design Compiler flow
```

## Repository structure

| Folder | Contents |
|---|---|
| `rtl/` | 21 synthesizable SystemVerilog files (`eBike.sv` is the top) |
| `tb/` | Full-chip testbench; `tb/models/` holds the physics and ADC models |
| `fpga/` | Quartus projects and constraints, plus two FPGA unit-test tops |
| `syn/` | Genus and Design Compiler synthesis scripts |
| `docs/` | [Project specification](docs/ProjectSpec.pdf) and [course requirement handouts](docs/README.md) |

The `old-versions` branch keeps every earlier integration attempt from the
semester.

---

Team project with Chris Vanden Boom ([@boomchrisvanden](https://github.com/boomchrisvanden)),
Simon Puebla ([@simondpuebla](https://github.com/simondpuebla)) and Y. Wu. Course-provided blocks:
`UART_tx`, `inertial_integrator`, `cadence_LU` and the testbench models.
