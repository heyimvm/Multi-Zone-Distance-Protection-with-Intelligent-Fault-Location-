# Multi-Zone Distance Protection with Intelligent Fault Location
### PSCAD/MATLAB Co-Simulated Transmission Network

![MATLAB](https://img.shields.io/badge/MATLAB-R2021a%2B-blue)
![Status](https://img.shields.io/badge/status-active-green)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

---

## Overview

This project implements a **multi-zone distance protection relay** with **intelligent fault location** for a 230 kV transmission network, simulated using MATLAB with optional PSCAD co-simulation support.

### Key Features
- Full-cycle sliding DFT phasor extraction (IEEE C37.111)
- Symmetrical component (012) transformation — Fortescue method
- 6 measuring loops: AG, BG, CG (with k₀ compensation), AB, BC, CA
- Mho and quadrilateral relay characteristics
- Zone 1 / 2 / 3 distance protection with definite-time delays
- Fault classification (AG, BG, CG, AB, BC, CA, ABG, BCG, CAG, ABC)
- Intelligent fault location: Takagi, Eriksson, Reactance, Ensemble
- Load encroachment blocking
- Full parametric study across fault types, locations, and resistances

---

## Project Structure

```
distance_protection/
├── main.m                                  ← Entry point
├── core/
│   ├── SystemConfig.m                      ← All system parameters
│   ├── load_simulation_data.m              ← PSCAD interface / synthetic data
│   ├── extract_phasors.m                   ← Sliding DFT phasor extraction
│   ├── abc_to_sequence.m                   ← Symmetrical components
│   ├── calculate_apparent_impedance.m      ← 6-loop impedance calculation
│   ├── distance_relay.m                    ← Multi-zone relay algorithm
│   └── classify_fault.m                    ← Fault type classifier
├── fault_location/
│   └── intelligent_fault_location.m        ← Takagi/Eriksson/Ensemble
├── visualization/
│   ├── plot_waveforms.m
│   ├── plot_impedance_plane.m
│   ├── plot_relay_characteristics.m
│   ├── plot_fault_location.m
│   └── plot_sequence_components.m
├── utils/
│   └── print_results_summary.m
├── tests/
│   ├── run_tests.m                         ← Unit test suite
│   └── parametric_study.m                  ← Full fault sweep
└── data/                                   ← Place PSCAD CSV exports here
```

---

## Quick Start

```matlab
cd distance_protection
addpath(genpath(pwd))
main
```

---

## System Parameters (SystemConfig.m)

| Parameter | Value | Description |
|-----------|-------|-------------|
| Base voltage | 230 kV | L-L system voltage |
| Line length | 200 km | Protected line |
| Z1 | 0.05+j0.4 Ω/km | Positive-sequence impedance |
| Z0 | 0.15+j1.2 Ω/km | Zero-sequence impedance |
| Zone 1 reach | 80% | Instantaneous trip |
| Zone 2 reach | 120% | 300 ms delay |
| Zone 3 reach | 220% | 600 ms delay |
| Relay angle | 75° | Maximum torque angle |
| Sampling rate | 10 kHz | DFT window = 1 cycle |

---

## Fault Location Methods

| Method | Type | Notes |
|--------|------|-------|
| Takagi | Single-ended | Uses incremental current |
| Eriksson | Single-ended | Compensates for remote infeed |
| Reactance | Single-ended | Simple X/X1 ratio |
| Ensemble | Weighted average | Best overall accuracy |

---

## Running Tests

```matlab
run_tests          % 6 unit tests
parametric_study   % 456-scenario sweep (19 locations × 6 types × 4 Rf)
```

---

## PSCAD Integration

Set `cfg.pscad_enabled = true` in `SystemConfig.m` and export these channels from PSCAD to `data/pscad_output.csv`:

```
t (s), Va (V), Vb (V), Vc (V), Ia (A), Ib (A), Ic (A)
```

---

## References

1. Phadke & Thorp — *Computer Relaying for Power Systems*, Wiley 2009
2. Takagi et al. — IEEE Trans. PAS, 1982
3. Eriksson et al. — IEEE Trans. PWRD, 1985
4. Anderson — *Analysis of Faulted Power Systems*, IEEE Press 1995
5. IEEE Std C37.113-2015 — Protective Relay Applications to Transmission Lines
