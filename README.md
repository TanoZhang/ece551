# eBike Motor Controller (ECE 551, UW–Madison, Spring 2025)

A complete digital controller for a pedal-assist electric bicycle, written in
SystemVerilog. It was synthesized to a 32 nm standard-cell library with
Synopsys Design Compiler and mapped to an Intel Cyclone IV FPGA (DE0-Nano) to
drive a real 250 W brushless hub motor.

The controller measures how hard and how fast the rider pedals and how steep
the hill is, works out how much motor current to add, and drives the motor's
six power MOSFETs to deliver that current.

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

## How it works

| Stage | Module(s) | What it does |
|---|---|---|
| Sensing | `A2D_intf`, `SPI_mnrch` | Round-robin reads of battery voltage, motor current, brake lever and pedal torque from an ADC128S022 over SPI, one channel every 2¹⁴ clocks (~328 µs) |
| Incline | `inert_intf`, `inertial_integrator` | Configures an LSM6DS3 6-axis IMU over SPI. On each data-ready interrupt it reads gyro and accelerometer data, then fuses them into a 13-bit incline (zeroed when the bike leans hard into a turn) |
| Cadence | `cadence_filt`, `cadence_meas`, `cadence_LU` | Debounces the noisy pedal sensor, measures the pulse period and maps it non-linearly to a 5-bit cadence value. Flags `not_pedaling` |
| Conditioning | `sensorCondition` | Exponential averages of current (W=4) and torque (W=32, seeded when pedaling resumes). Produces the signed loop error `target − avg_curr`, forced to 0 on low battery or when the rider stops pedaling |
| Assist law | `desiredDrive` | `target_curr = torque_pos × incline_lim × cadence_factor × scale`, pipelined, scaled down and saturated to 12 bits |
| Control loop | `PID` | P + I (anti-windup, clipped, cleared when not pedaling) + D (3-sample difference, saturated). Output is clipped to 12-bit `drv_mag` |
| Commutation | `brushless` | Synchronizes the Hall sensors and picks forward, reverse, high-Z or regen-brake for each of the three coils. Sets duty = `0x400 + drv_mag/4` |
| Power stage | `mtr_drv`, `PWM`, `nonoverlap` | 11-bit PWM (~24 kHz) routed to the high/low FETs, with a guaranteed 32-clock dead time so a high and low FET are never on together |
| User I/O | `PB_intf`, `PB_rise`, `telemetry`, `UART_tx` | Push button cycles the assist level (off/low/med/high) shown on LEDs. Sends an 8-byte telemetry packet (`AA 55` + battery, current, torque) about 48 times a second |
| Reset | `reset_synch` (`rst_synch`) | Asynchronous assert, synchronous deassert of the global reset |

The models in `tb/models/` (`eBikePhysics`: motor, wheel and IMU;
`AnalogModel` + `SPI_ADC128S`: the ADC) are behavioral models used by the
testbench. They are not part of the synthesized design.

## Requirements

The professor's project specification is
[`docs/ProjectSpec.pdf`](docs/ProjectSpec.pdf). The per-module requirement
handouts and the synthesis/timing course material are indexed in
[`docs/`](docs/README.md).

## Running the simulation

Requires ModelSim / Questa (tested with ModelSim–Intel FPGA Starter 2020.1).

```bash
vlib work
vlog -sv rtl/*.sv tb/models/*.sv tb/eBike_tb.sv
vsim -c eBike_tb -do "run -all; quit -f"
```

`eBike_tb` runs a full-chip closed-loop test against the physics model,
with `FAST_SIM=1` to shorten the internal timers. It checks that the motor
responds the right way to changes in assist level, torque, incline, cadence and
pedaling stopping, that the brake engages regenerative braking and that a low
battery inhibits drive. In every phase the current loop must settle to within
±45 counts of its target (or be at full drive). All 8 tests pass in about
8.5 minutes.

## Synthesis

```bash
cd syn && dc_shell -f eBike.dc
```

`syn/eBike.dc` is the course Design Compiler flow: reads the RTL, constrains the
`clk` port, compiles, flattens and writes the gate-level netlist `eBike.vg` plus
an area report. The FPGA build is `fpga/eBike.qpf` in Quartus, with the 50 MHz
clock in `fpga/eBike.sdc`. `FAST_SIM = 0` (the default in `rtl/eBike.sv`) gives
real hardware timing.

The DE0-Nano's Cyclone IV E needs Quartus Prime Lite/Standard. As a portability
check, the same RTL was also run through Quartus Prime Pro 26.1 targeting an
Agilex 3 (`A3CW135BM16AE6S`): synthesis and fit with 0 errors and no inferred
latches, 465 ALMs / 716 registers / 3 DSP blocks, and the 50 MHz clock met with
15.6 ns of setup slack.

## Repository layout

| Folder | Contents |
|---|---|
| `rtl/` | The 21 synthesizable SystemVerilog files (`eBike.sv` is the top) |
| `tb/` | Full-chip testbench `eBike_tb.sv`; `tb/models/` holds the physics and ADC models |
| `fpga/` | Quartus projects and timing constraints for the DE0-Nano, plus two FPGA unit-test tops (`inert_intf_test`, `nonoverlap_test`) |
| `syn/` | ASIC synthesis scripts |
| `docs/` | Project specification and course requirement handouts |

| Branch | Contents |
|---|---|
| `main` | Final working design (formerly the `FinalSNIN/` folder), cleaned up and bug-fixed, with fixes merged in from the other versions |
| `old-versions` | The repository as it was at the end of the semester: every integration attempt (`Final/`, `FinalSNIO/`, `FinalSoIN/`, `Backup/`, `old/`, ...) plus the `cvandenboom` and `may2nd` branches under `branch-*/` |

## Team

Daichi (Tano) Zhang ([@TanoZhang](https://github.com/TanoZhang)),
Chris Vanden Boom ([@boomchrisvanden](https://github.com/boomchrisvanden)),
[@simondpuebla](https://github.com/simondpuebla) — ECE 551
(Digital System Design & Synthesis), University of Wisconsin–Madison.
Course-provided models (`UART_tx`, `inertial_integrator`,
`cadence_LU`, the physics/ADC models) are credited to the course staff.
