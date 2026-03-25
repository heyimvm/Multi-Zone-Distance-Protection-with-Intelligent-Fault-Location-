function cfg = SystemConfig()
%SYSTEMCONFIG  All system and relay parameters.

%% Identity
cfg.system_name     = '230 kV Single-Machine Infinite-Bus System';
cfg.base_kV         = 230;
cfg.base_MVA        = 100;
cfg.frequency       = 60;
cfg.pu_mode         = false;

%% Transmission Line
cfg.line_length_km  = 200;
cfg.z1_ohm_per_km   = 0.05 + 1j*0.4;
cfg.z0_ohm_per_km   = 0.15 + 1j*1.2;
cfg.Z1_total        = cfg.z1_ohm_per_km * cfg.line_length_km;
cfg.Z0_total        = cfg.z0_ohm_per_km * cfg.line_length_km;
cfg.k0              = (cfg.Z0_total - cfg.Z1_total) / (3 * cfg.Z1_total);

%% CT / VT
cfg.CTR             = 400;
cfg.VTR             = 2000;
cfg.use_secondary   = false;

%% Zone Reaches
cfg.zone1_reach_pu  = 0.80;
cfg.zone2_reach_pu  = 1.20;
cfg.zone3_reach_pu  = 2.20;
cfg.zone4_reach_pu  = -0.20;
cfg.Z_zone1 = cfg.zone1_reach_pu * cfg.Z1_total;
cfg.Z_zone2 = cfg.zone2_reach_pu * cfg.Z1_total;
cfg.Z_zone3 = cfg.zone3_reach_pu * cfg.Z1_total;
cfg.Z_zone4 = cfg.zone4_reach_pu * cfg.Z1_total;

%% Zone Delays
cfg.t_zone1         = 0.000;
cfg.t_zone2         = 0.300;
cfg.t_zone3         = 0.600;
cfg.t_zone4         = 0.000;

%% Characteristic
cfg.characteristic  = 'mho';
cfg.relay_angle_deg = 75;
cfg.relay_angle     = deg2rad(cfg.relay_angle_deg);
cfg.blinder_R_pos   =  15;
cfg.blinder_R_neg   = -5;
cfg.blinder_X_top   =  imag(cfg.Z_zone3) * 1.1;
cfg.blinder_X_bot   = -5;

%% Load Encroachment
cfg.load_R_min      = 150;
cfg.load_angle_max  = 30;

%% Fault Detector Thresholds
cfg.delta_I_thresh  = 0.05;
cfg.delta_V_thresh  = 0.05;
cfg.I_rated_A       = cfg.base_MVA*1e6 / (sqrt(3)*cfg.base_kV*1e3);

%% DFT Settings
cfg.fs              = 10e3;
cfg.N_DFT           = cfg.fs / cfg.frequency;
cfg.window_cycles   = 1;
cfg.window_samples  = cfg.N_DFT * cfg.window_cycles;
cfg.phasor_update_rate = 1;

%% Fault Location Methods
cfg.fl_method       = 'takagi';
cfg.fl_method2      = 'eriksson';

%% Source Impedances (kept small relative to line for realistic fault currents)
cfg.Zs = 0.1 + 1j*1.0;
cfg.Zr = 0.1 + 1j*1.0;

%% PSCAD Interface
cfg.pscad_enabled   = false;
cfg.pscad_data_file = 'data/pscad_output.csv';
cfg.pscad_channels  = {'Va','Vb','Vc','Ia','Ib','Ic'};

%% Data Source
cfg.use_synthetic   = true;
cfg.data_file       = 'data/recorded_fault.csv';

%% Simulation Time
cfg.t_start         = 0.0;
cfg.t_end           = 0.5;
cfg.t_fault         = 0.1;
cfg.fault_duration  = 0.12;
cfg.fault_location  = 0.65;
cfg.fault_type      = 'AG';
end