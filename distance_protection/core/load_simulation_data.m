function [Vabc, Iabc, t, fault_info] = load_simulation_data(cfg)
%LOAD_SIMULATION_DATA  Load or generate 3-phase voltage and current data.

if cfg.pscad_enabled
    [Vabc, Iabc, t, fault_info] = load_pscad_data(cfg);
elseif cfg.use_synthetic
    [Vabc, Iabc, t, fault_info] = generate_synthetic_fault(cfg);
else
    [Vabc, Iabc, t, fault_info] = load_csv_data(cfg);
end
end

% =========================================================================
function [Vabc, Iabc, t, fault_info] = generate_synthetic_fault(cfg)

dt  = 1 / cfg.fs;
t   = (cfg.t_start : dt : cfg.t_end - dt)';
N   = length(t);
w   = 2*pi*cfg.frequency;

% System base values
Vm      = cfg.base_kV * 1e3 * sqrt(2) / sqrt(3);   % Phase peak voltage (V)
phi     = deg2rad(30);                               % Load power factor angle

% Line and source impedances
Z1      = cfg.Z1_total;
Z0      = cfg.Z0_total;
Zs      = cfg.Zs;
d       = cfg.fault_location;

% Fault impedance (small arc resistance)
Rf      = 0.5;

% ---- Sequence network fault current calculation ----------------------
% Positive sequence impedance seen from relay to fault
Z1d     = Zs + d * Z1;          % Total pos-seq impedance to fault
Z0d     = Zs + d * Z0;          % Total zero-seq impedance to fault

% Pre-fault voltage at relay bus (source voltage behind Zs)
Vs_pk   = Vm;                    % Peak source voltage

switch upper(cfg.fault_type)
    case 'AG'
        % SLG: I1 = Vs / (Z1d + Z1d + Z0d + 3*Rf)
        Z_total = 2*Z1d + Z0d + 3*Rf;
        I1_pk   = Vs_pk / abs(Z_total);
        I_fault_pk = 3 * I1_pk;    % Ia = 3*I1 for SLG

        % Voltage at relay bus during fault
        Va_fault_pk = Vs_pk - abs(Zs) * I_fault_pk * 0.3;
        Vb_fault_pk = Vm;
        Vc_fault_pk = Vm;
        Ia_fault_pk = I_fault_pk;
        Ib_fault_pk = cfg.I_rated_A * sqrt(2) * 0.1;
        Ic_fault_pk = cfg.I_rated_A * sqrt(2) * 0.1;

    case 'BG'
        Z_total = 2*Z1d + Z0d + 3*Rf;
        I1_pk   = Vs_pk / abs(Z_total);
        I_fault_pk = 3 * I1_pk;
        Va_fault_pk = Vm;
        Vb_fault_pk = Vs_pk - abs(Zs) * I_fault_pk * 0.3;
        Vc_fault_pk = Vm;
        Ia_fault_pk = cfg.I_rated_A * sqrt(2) * 0.1;
        Ib_fault_pk = I_fault_pk;
        Ic_fault_pk = cfg.I_rated_A * sqrt(2) * 0.1;

    case 'CG'
        Z_total = 2*Z1d + Z0d + 3*Rf;
        I1_pk   = Vs_pk / abs(Z_total);
        I_fault_pk = 3 * I1_pk;
        Va_fault_pk = Vm;
        Vb_fault_pk = Vm;
        Vc_fault_pk = Vs_pk - abs(Zs) * I_fault_pk * 0.3;
        Ia_fault_pk = cfg.I_rated_A * sqrt(2) * 0.1;
        Ib_fault_pk = cfg.I_rated_A * sqrt(2) * 0.1;
        Ic_fault_pk = I_fault_pk;

    case {'AB','ABG'}
        Z_total = Z1d + Rf;
        I_fault_pk = Vs_pk * sqrt(3) / abs(Z_total);
        Va_fault_pk = Vm * 0.6;
        Vb_fault_pk = Vm * 0.6;
        Vc_fault_pk = Vm;
        Ia_fault_pk = I_fault_pk;
        Ib_fault_pk = I_fault_pk;
        Ic_fault_pk = cfg.I_rated_A * sqrt(2) * 0.1;

    case {'BC','BCG'}
        Z_total = Z1d + Rf;
        I_fault_pk = Vs_pk * sqrt(3) / abs(Z_total);
        Va_fault_pk = Vm;
        Vb_fault_pk = Vm * 0.6;
        Vc_fault_pk = Vm * 0.6;
        Ia_fault_pk = cfg.I_rated_A * sqrt(2) * 0.1;
        Ib_fault_pk = I_fault_pk;
        Ic_fault_pk = I_fault_pk;

    case {'CA','CAG'}
        Z_total = Z1d + Rf;
        I_fault_pk = Vs_pk * sqrt(3) / abs(Z_total);
        Va_fault_pk = Vm * 0.6;
        Vb_fault_pk = Vm;
        Vc_fault_pk = Vm * 0.6;
        Ia_fault_pk = I_fault_pk;
        Ib_fault_pk = cfg.I_rated_A * sqrt(2) * 0.1;
        Ic_fault_pk = I_fault_pk;

    otherwise  % ABC
        Z_total = Z1d + Rf;
        I_fault_pk = Vs_pk / abs(Z_total);
        Va_fault_pk = Vm * 0.15;
        Vb_fault_pk = Vm * 0.15;
        Vc_fault_pk = Vm * 0.15;
        Ia_fault_pk = I_fault_pk;
        Ib_fault_pk = I_fault_pk;
        Ic_fault_pk = I_fault_pk;
end

% Pre-fault load current (small, rated)
I_load  = cfg.I_rated_A * sqrt(2) * 0.3;

% Build waveforms
Va = Vm     * sin(w*t);
Vb = Vm     * sin(w*t - 2*pi/3);
Vc = Vm     * sin(w*t + 2*pi/3);
Ia = I_load * sin(w*t - phi);
Ib = I_load * sin(w*t - 2*pi/3 - phi);
Ic = I_load * sin(w*t + 2*pi/3 - phi);

% Fault window indices
t_fault  = cfg.t_fault;
t_clear  = cfg.t_fault + cfg.fault_duration;
idx_f    = t >= t_fault & t < t_clear;

% DC offset decay (tau ~ 50ms typical)
tau_dc   = 0.05;
t_rel    = t(idx_f) - t_fault;
dc_env   = exp(-t_rel / tau_dc);

% Apply fault voltages
Va(idx_f) = Va_fault_pk * sin(w*t(idx_f));
Vb(idx_f) = Vb_fault_pk * sin(w*t(idx_f) - 2*pi/3);
Vc(idx_f) = Vc_fault_pk * sin(w*t(idx_f) + 2*pi/3);

% Apply fault currents with DC offset
Ia(idx_f) = Ia_fault_pk * sin(w*t(idx_f) - phi) + ...
            Ia_fault_pk * 0.8 * dc_env;
Ib(idx_f) = Ib_fault_pk * sin(w*t(idx_f) - 2*pi/3 - phi);
Ic(idx_f) = Ic_fault_pk * sin(w*t(idx_f) + 2*pi/3 - phi);

% Small measurement noise
noise_scale_v = Vm * 0.001;
noise_scale_i = cfg.I_rated_A * sqrt(2) * 0.002;
Va = Va + noise_scale_v * randn(N,1);
Vb = Vb + noise_scale_v * randn(N,1);
Vc = Vc + noise_scale_v * randn(N,1);
Ia = Ia + noise_scale_i * randn(N,1);
Ib = Ib + noise_scale_i * randn(N,1);
Ic = Ic + noise_scale_i * randn(N,1);

Vabc = [Va, Vb, Vc];
Iabc = [Ia, Ib, Ic];

fault_info.type           = cfg.fault_type;
fault_info.location_pu    = cfg.fault_location;
fault_info.location_km    = cfg.fault_location * cfg.line_length_km;
fault_info.t_inception    = t_fault;
fault_info.t_clear        = t_clear;
fault_info.resistance_ohm = Rf;

fprintf('[SYN] Generated %s fault at %.1f%% (%.1f km), Rf=%.2f Ohm\n', ...
        cfg.fault_type, d*100, fault_info.location_km, Rf);
end

% =========================================================================
function [Vabc, Iabc, t, fault_info] = load_pscad_data(cfg)
warning('PSCAD live link not implemented. Using CSV fallback.');
[Vabc, Iabc, t, fault_info] = load_csv_data(cfg);
end

% =========================================================================
function [Vabc, Iabc, t, fault_info] = load_csv_data(cfg)
if ~isfile(cfg.data_file)
    error('Data file not found: %s\nSet cfg.use_synthetic=true to generate data.', cfg.data_file);
end
data  = readmatrix(cfg.data_file);
t     = data(:,1);
Vabc  = data(:, 2:4);
Iabc  = data(:, 5:7);
fault_info.type           = 'Unknown';
fault_info.location_pu    = NaN;
fault_info.location_km    = NaN;
fault_info.t_inception    = NaN;
fault_info.t_clear        = NaN;
fault_info.resistance_ohm = NaN;
fprintf('[CSV] Loaded %d samples from %s\n', length(t), cfg.data_file);
end
