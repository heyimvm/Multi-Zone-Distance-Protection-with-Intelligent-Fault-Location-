function fault_loc = intelligent_fault_location(V_phasor, I_phasor, ...
                                            I_seq, Z_app, fault_class, cfg)
%INTELLIGENT_FAULT_LOCATION  Multi-method fault distance estimation.
%
%  Methods implemented:
%    1. Takagi (single-ended, uses pre-fault current for source estimation)
%    2. Eriksson (single-ended, improved source modelling)
%    3. Reactance method (simple X/X1 ratio)
%    4. Ensemble / weighted average
%
%  Reference:
%    Takagi, T. et al. (1982) - "Development of a new type fault locator"
%    IEEE Trans. PAS, vol.101, no.8
%    Eriksson, L. et al. (1985) - "An accurate fault locator with
%    compensation for apparent reactance in the fault resistance"
%    IEEE Trans. PWRD, vol.4, no.4

N = length(V_phasor.a);

% ---- Select appropriate phasors based on fault type -------------------
[Vm, Im, Im_comp] = select_measuring_loop(V_phasor, I_phasor, I_seq, ...
                                           fault_class, cfg);

% ---- Find fault window (samples where fault is active) ----------------
fault_start = round((cfg.t_fault + 0.5/cfg.frequency) * cfg.fs);
fault_start = min(fault_start, N - round(2*cfg.N_DFT));
fault_end   = min(fault_start + round(3*cfg.N_DFT), N);

% Use median over fault window for robustness
V_f  = median_phasor(Vm(fault_start:fault_end));
I_f  = median_phasor(Im(fault_start:fault_end));
Ic_f = median_phasor(Im_comp(fault_start:fault_end));   % Compensated

% Pre-fault phasors (last cycle before fault)
pf_end   = max(1, fault_start - 1);
pf_start = max(1, pf_end - round(cfg.N_DFT));
V_pf = median_phasor(Vm(pf_start:pf_end));
I_pf = median_phasor(Im(pf_start:pf_end));

% ---- Method 1: Takagi -------------------------------------------------
d_takagi = takagi_method(V_f, I_f, I_pf, cfg);

% ---- Method 2: Eriksson -----------------------------------------------
d_eriksson = eriksson_method(V_f, I_f, cfg);

% ---- Method 3: Simple Reactance ---------------------------------------
d_reactance = reactance_method(V_f, Ic_f, cfg);

% ---- Method 4: Modified Takagi (accounts for fault resistance) --------
d_modified = modified_takagi(V_f, I_f, I_pf, fault_class, cfg);

% ---- Ensemble / Weighted Average --------------------------------------
methods   = {'Takagi', 'Eriksson', 'Reactance', 'Mod. Takagi'};
estimates = [d_takagi, d_eriksson, d_reactance, d_modified];
weights   = [0.35, 0.30, 0.15, 0.20];

% Clip to [0, 1] before weighting
estimates_clipped = max(0, min(1, estimates));
d_ensemble = sum(weights .* estimates_clipped) / sum(weights);

% ---- Uncertainty Estimation -------------------------------------------
d_std = std(estimates_clipped);

% ---- Pack results -------------------------------------------------
fault_loc.d_pu         = d_ensemble;
fault_loc.d_km         = d_ensemble * cfg.line_length_km;
fault_loc.d_pct        = d_ensemble * 100;
fault_loc.d_std        = d_std;
fault_loc.ci_95_km     = [fault_loc.d_km - 2*d_std*cfg.line_length_km, ...
                           fault_loc.d_km + 2*d_std*cfg.line_length_km];

fault_loc.methods      = methods;
fault_loc.estimates_pu = estimates;
fault_loc.weights      = weights;
fault_loc.method_names = methods;

% ---- Error vs true location (if known) --------------------------------
if ~isnan(cfg.fault_location)
    true_d = cfg.fault_location;
    fault_loc.error_pu  = d_ensemble - true_d;
    fault_loc.error_km  = fault_loc.error_pu * cfg.line_length_km;
    fault_loc.error_pct = fault_loc.error_pu * 100;
    fprintf('[FL] Estimated: %.3f pu (%.1f km) | True: %.3f pu (%.1f km) | Error: %.2f%%\n', ...
            d_ensemble, fault_loc.d_km, ...
            true_d, true_d*cfg.line_length_km, ...
            fault_loc.error_pct);
else
    fault_loc.error_pu  = NaN;
    fault_loc.error_km  = NaN;
    fault_loc.error_pct = NaN;
    fprintf('[FL] Estimated location: %.3f pu (%.1f km) ± %.2f pu\n', ...
            d_ensemble, fault_loc.d_km, d_std);
end
end

% =========================================================================
function d = takagi_method(Vm, Im, Im_pf, cfg)
%TAKAGI_METHOD  Fault location by Takagi algorithm.
%
%  d = Im( Vm * conj(delta_I) ) / Im( Z1 * Im * conj(delta_I) )
%  delta_I = Im - Im_pf  (incremental current)

delta_I = Im - Im_pf;
Z1      = cfg.Z1_total;

num  = imag(Vm * conj(delta_I));
den  = imag(Z1 * Im * conj(delta_I));

if abs(den) < 1e-10
    d = 0.5;   % Default to mid-line if degenerate
else
    d = num / den;
end
end

% =========================================================================
function d = eriksson_method(Vm, Im, cfg)
%ERIKSSON_METHOD  Fault location by Eriksson algorithm.
%  Accounts for remote source current contribution.
%
%  Model: Vm = d*Z1*Im + Rf*If
%  Solve for d iteratively (2 iterations usually sufficient)

Z1  = cfg.Z1_total;
Zs  = cfg.Zs;
Zr  = cfg.Zr;
ZL  = Z1;

% Initial estimate (ignore Rf)
d0 = imag(Vm / Im) / imag(ZL);
d0 = max(0.01, min(0.99, d0));

% Refined estimate
for iter = 1:3
    % Remote infeed fraction
    Zs_eff = Zs + d0 * ZL;
    Zr_eff = Zr + (1 - d0) * ZL;
    k_inf  = Zs_eff / (Zs_eff + Zr_eff);

    num = imag(Vm * conj(Im)) - ...
          imag(d0 * ZL * abs(Im)^2 * k_inf);
    den = imag(ZL * abs(Im)^2);

    d_new = num / den;
    d0    = max(0.01, min(0.99, d_new));
end
d = d0;
end

% =========================================================================
function d = reactance_method(Vm, Im, cfg)
%REACTANCE_METHOD  Simplest single-ended method: d = X_app / X1_total
X_app = imag(Vm / Im);
X1    = imag(cfg.Z1_total);
d     = X_app / X1;
end

% =========================================================================
function d = modified_takagi(Vm, Im, Im_pf, fault_class, cfg)
%MODIFIED_TAKAGI  Takagi with zero-sequence current decoupling for SLG.

if fault_class.is_ground && fault_class.n_phases == 1
    % Compensated current = I_ph + k0 * I0  (already in Im_comp)
    % Re-use Takagi with modified delta current
    delta_I = Im - Im_pf;
    Z1      = cfg.Z1_total;
    num     = imag(Vm * conj(Im));
    den     = imag(Z1 * Im * conj(delta_I));
    if abs(den) < 1e-10, d = 0.5; return; end
    d = num / den;
else
    d = takagi_method(Vm, Im, Im_pf, cfg);
end
end

% =========================================================================
function [Vm, Im, Im_comp] = select_measuring_loop(V_phasor, I_phasor, ...
                                                    I_seq, fault_class, cfg)
%SELECT_MEASURING_LOOP  Choose correct phasors based on fault type.

k0 = cfg.k0;
I0 = I_seq.zero;

switch upper(fault_class.type(1:min(2,end)))
    case 'AG'
        Vm      = V_phasor.a;
        Im      = I_phasor.a;
        Im_comp = I_phasor.a + k0 * I0;
    case 'BG'
        Vm      = V_phasor.b;
        Im      = I_phasor.b;
        Im_comp = I_phasor.b + k0 * I0;
    case 'CG'
        Vm      = V_phasor.c;
        Im      = I_phasor.c;
        Im_comp = I_phasor.c + k0 * I0;
    case 'AB'
        Vm      = V_phasor.a - V_phasor.b;
        Im      = I_phasor.a - I_phasor.b;
        Im_comp = Im;
    case 'BC'
        Vm      = V_phasor.b - V_phasor.c;
        Im      = I_phasor.b - I_phasor.c;
        Im_comp = Im;
    case 'CA'
        Vm      = V_phasor.c - V_phasor.a;
        Im      = I_phasor.c - I_phasor.a;
        Im_comp = Im;
    otherwise  % ABC, ABG, BCG, CAG
        Vm      = V_phasor.a;
        Im      = I_phasor.a;
        Im_comp = I_phasor.a + k0 * I0;
end
end

%USED VARIABLES 
% =========================================================================
function p = median_phasor(x)
%MEDIAN_PHASOR  Robust phasor estimate using angle-magnitude median.
mag = median(abs(x));
ang = angle(x);
% Circular mean for angle
ang_mean = atan2(mean(sin(ang)), mean(cos(ang)));
p = mag * exp(1j * ang_mean);
end
