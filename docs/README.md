# Course requirements

Requirements and handouts from the ECE 551 professor (UW–Madison) that defined
this project. They are the Fall 2019 versions; our Spring 2025 project followed
the same architecture, with small differences: cadence is measured as a period
(`cadence_meas` + `cadence_LU`), assist uses a 3-bit `scale` from `PB_intf`, and
SPI runs at clk/32.

## Project specification

[**ProjectSpec.pdf**](ProjectSpec.pdf): the full eBike controller spec. Block
diagram, every module's interface and behavior, the `eBike` top-level pinout,
synthesis constraints and grading criteria.

## Module requirements

Each block was specified in its own handout before being integrated:

| Handout | Block |
|---|---|
| [EX04_PID](handouts/EX04_PID.pdf) | PID control concepts |
| [EX06_desiredDrive](handouts/EX06_desiredDrive.pdf) | `desiredDrive`: saturation and the assist calculation |
| [EX07_PWM](handouts/EX07_PWM.pdf) | `PWM` |
| [EX08_nonoverlap](handouts/EX08_nonoverlap.pdf) | `nonoverlap` dead-time generator |
| [EX09_SPI](handouts/EX09_SPI.pdf) | `SPI_mnrch` SPI master |
| [EX10_RST](handouts/EX10_RST.pdf) | `reset_synch` reset synchronizer |
| [EX11_FirstFPGA](handouts/EX11_FirstFPGA.pdf) | First DE0-Nano FPGA bring-up (PWM) |
| [EX12_brushless](handouts/EX12_brushless.pdf) | `brushless` commutation and its testbench |
| [EX13_mtr_drv](handouts/EX13_mtr_drv.pdf) | `mtr_drv` |
| [EX15_DesiredDriveRandoms](handouts/EX15_DesiredDriveRandoms.pdf) | Random-stimulus verification of `desiredDrive` |
| [EX17_A2Dintf_PID](handouts/EX17_A2Dintf_PID.pdf) | `A2D_intf` and `PID` |
| [EX20_SensorConditionInertialInterface](handouts/EX20_SensorConditionInertialInterface.pdf) | `sensorCondition` and `inert_intf` |

## Synthesis and physical design

| Handout | Topic |
|---|---|
| [EX14_SynthesisScript](handouts/EX14_SynthesisScript.pdf) | Writing the Synopsys Design Compiler script |
| [SynopsysTutorialF19](handouts/SynopsysTutorialF19.pdf) | Design Compiler / Design Vision tutorial |
| [StaticTiming](handouts/StaticTiming.pdf) | Static timing analysis |
| [EX16_gated_clocks](handouts/EX16_gated_clocks.pdf) | Clock gating |
| [EX18_APR_telemetry](handouts/EX18_APR_telemetry.pdf) | Automated place and route in IC Compiler |
| [post_synthesis_validation_f19](handouts/post_synthesis_validation_f19.pdf) | Simulating the gate-level netlist |

## Other course handouts

| Handout | Topic |
|---|---|
| [HW2](handouts/HW2.pdf), [HW4](handouts/HW4.pdf), [HW5](handouts/HW5.pdf) | Homework assignments that built up project blocks |
| [EX05_ShiftRot](handouts/EX05_ShiftRot.pdf) | Shifter/rotator (early RTL exercise) |
| [EX21_WhatsNext](handouts/EX21_WhatsNext.pdf) | Course wrap-up |

All handouts © ECE 551 course staff, University of Wisconsin–Madison.
