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

`eBikePhysics.sv`, `hub_wheel_model.sv`, `coil_volt.sv`, `AnalogModel.sv`,
`SPI_ADC128S.sv` and `ADC128S.sv` are behavioral models of the bike, motor, IMU
and ADC used by the testbench. They are not part of the synthesized design.

## Running the simulation

Requires ModelSim / Questa (tested with ModelSim–Intel FPGA Starter 2020.1).

```bash
vlib work
vlog -sv *.sv
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
dc_shell -f eBike.dc
```

Reads the RTL, constrains the `clk` port, compiles, flattens and writes the
gate-level netlist `eBike.vg` plus an area report. The FPGA build uses
`eBike.qpf` / `eBike.qsf` in Quartus. Set `FAST_SIM = 0` (the default in
`eBike.sv`) for real hardware timing.

## Repository layout

| Branch | Contents |
|---|---|
| `main` | Final working design (formerly the `FinalSNIN/` folder), cleaned up and bug-fixed, with fixes merged in from the other versions |
| `old-versions` | The repository as it was at the end of the semester: every integration attempt (`Final/`, `FinalSNIO/`, `FinalSoIN/`, `Backup/`, `old/`, ...) plus the `cvandenboom` and `may2nd` branches under `branch-*/` |

## Team

Daichi (Tano) Zhang ([@TanoZhang](https://github.com/TanoZhang)),
Chris Vanden Boom, [@simondpuebla](https://github.com/simondpuebla),
[@ywu647](https://github.com/ywu647) — ECE 551
(Digital System Design & Synthesis), University of Wisconsin–Madison.
Course-provided models (`UART_tx`, `UART_rcv`, `inertial_integrator`,
`cadence_LU`, the physics/ADC models) are credited to the course staff.
