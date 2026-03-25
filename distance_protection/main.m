%% =========================================================================
%  MULTI-ZONE DISTANCE PROTECTION WITH INTELLIGENT FAULT LOCATION
%  PSCAD/MATLAB Co-Simulated Transmission Network
%
%  Author      : [Your Name]
%  Institution : [Your Institution]
%  Date        : 2024
%  Version     : 1.0
%
%  Description:
%    This script is the main entry point for the distance protection relay
%    simulation. It initialises system parameters, loads PSCAD co-simulation
%    data (or runs the internal fault generator), executes the multi-zone
%    mho/quadrilateral distance relay algorithm, performs intelligent fault
%    location estimation, and produces all result plots and reports.
%
%  Usage:
%    >> main                   % Run with default parameters
%    >> main('config','custom_config.m')   % Use a custom config file
% =========================================================================

clc; clear; close all;
addpath(genpath(pwd));

fprintf('==========================================================\n');
fprintf('  Multi-Zone Distance Protection Simulation\n');
fprintf('  PSCAD/MATLAB Co-Simulation Framework\n');
fprintf('==========================================================\n\n');

%% 1. Load System Configuration
cfg = SystemConfig();
fprintf('[INFO] System configuration loaded: %s\n', cfg.system_name);

%% 2. Load / Generate Fault Data
fprintf('[INFO] Loading simulation data...\n');
[Vabc, Iabc, t, fault_info] = load_simulation_data(cfg);
fprintf('[INFO] Data loaded: %d samples @ %.1f kHz\n', ...
        length(t), 1/(t(2)-t(1))/1e3);
%% 3. Pre-processing: Phasor Extraction (DFT)
fprintf('[INFO] Extracting fundamental-frequency phasors...\n');
[V_phasor, I_phasor] = extract_phasors(Vabc, Iabc, t, cfg);

%% 4. Sequence Component Transformation
fprintf('[INFO] Computing symmetrical components...\n');
[V_seq, I_seq] = abc_to_sequence(V_phasor, I_phasor);

%% 5. Impedance Calculation
fprintf('[INFO] Calculating apparent impedances...\n');
Z_app = calculate_apparent_impedance(V_phasor, I_phasor, I_seq, cfg);

%% 6. Distance Relay Decision (Zone 1, 2, 3 + Pilot)
fprintf('[INFO] Running multi-zone distance relay algorithm...\n');
relay_output = distance_relay(Z_app, V_phasor, I_phasor, I_seq, cfg);

%% 7. Fault Classification
fprintf('[INFO] Classifying fault type...\n');
fault_class = classify_fault(V_phasor, I_phasor, I_seq, cfg);
%% 8. Intelligent Fault Location
fprintf('[INFO] Estimating fault location...\n');
fault_loc = intelligent_fault_location(V_phasor, I_phasor, I_seq, ...
                                        Z_app, fault_class, cfg);
%% 9. Results Summary
print_results_summary(relay_output, fault_class, fault_loc, fault_info, cfg);

%% 10. Visualisation
fprintf('[INFO] Generating plots...\n');
plot_waveforms(t, Vabc, Iabc, fault_info, cfg);
plot_impedance_plane(Z_app, relay_output, cfg);
plot_fault_location(fault_loc, fault_info, cfg);
plot_relay_characteristics(cfg);
plot_sequence_components(t, V_seq, I_seq, cfg);

fprintf('\n[INFO] Simulation complete.\n');
fprintf('==========================================================\n');