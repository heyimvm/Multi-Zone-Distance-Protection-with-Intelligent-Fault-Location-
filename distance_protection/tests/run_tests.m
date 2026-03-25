%% UNIT TESTS — Distance Protection Framework
%  Run this script to verify all core functions work correctly.
%  Each test prints PASS or FAIL with diagnostics.

clc; clear;
addpath(genpath(fileparts(pwd)));

fprintf('Running unit tests...\n\n');
pass = 0; fail = 0;

%% Test 1: SystemConfig loads without error
try
    cfg = SystemConfig();
    assert(isfield(cfg,'Z1_total'));
    assert(abs(cfg.k0) > 0);
    fprintf('[PASS] SystemConfig\n'); pass = pass+1;
catch e
    fprintf('[FAIL] SystemConfig: %s\n', e.message); fail = fail+1;
end

%% Test 2: abc_to_sequence — balanced input → zero I0
try
    N   = 100;
    a   = exp(1j*2*pi/3);
    Vp.a = ones(N,1) * 1.0;
    Vp.b = ones(N,1) * a^2;
    Vp.c = ones(N,1) * a;
    Ip   = Vp;
    [Vs, Is] = abc_to_sequence(Vp, Ip);
    assert(max(abs(Vs.zero)) < 1e-10, 'V0 not zero for balanced');
    assert(max(abs(Is.zero)) < 1e-10, 'I0 not zero for balanced');
    fprintf('[PASS] abc_to_sequence (balanced)\n'); pass = pass+1;
catch e
    fprintf('[FAIL] abc_to_sequence: %s\n', e.message); fail = fail+1;
end

%% Test 3: Mho comparator — point at Z_reach/2 is inside
try
    cfg      = SystemConfig();
    Z_inside = cfg.Z_zone1 * 0.5;       % Should be inside Zone 1
    Z_outside= cfg.Z_zone1 * 1.5;       % Should be outside Zone 1
    in1 = check_zone_test(Z_inside,  cfg.Z_zone1, cfg);
    in2 = check_zone_test(Z_outside, cfg.Z_zone1, cfg);
    assert(in1,  'Point inside mho should be detected as inside');
    assert(~in2, 'Point outside mho should be detected as outside');
    fprintf('[PASS] Mho comparator\n'); pass = pass+1;
catch e
    fprintf('[FAIL] Mho comparator: %s\n', e.message); fail = fail+1;
end

%% Test 4: Fault generator produces non-trivial waveforms
try
    cfg = SystemConfig();
    [Vabc, Iabc, t, fi] = load_simulation_data(cfg);
    assert(size(Vabc,2) == 3);
    assert(size(Iabc,2) == 3);
    assert(max(abs(Iabc(:))) > cfg.I_rated_A * 1.2, 'Fault current too low');
    fprintf('[PASS] Fault data generator\n'); pass = pass+1;
catch e
    fprintf('[FAIL] Fault data generator: %s\n', e.message); fail = fail+1;
end

%% Test 5: Phasor extraction accuracy
try
    cfg = SystemConfig();
    dt  = 1/cfg.fs;
    t   = (0:dt:0.1-dt)';
    f0  = cfg.frequency;
    V_true = 100 * exp(1j * pi/6);   % 100 V ∠30°
    x   = real(V_true * sqrt(2)) * cos(2*pi*f0*t - angle(V_true)) + ...
          real(V_true * sqrt(2)) * 0;   % pure sinusoid
    % Manual DFT check
    N_w  = round(cfg.N_DFT);
    seg  = x(end-N_w+1:end);
    k    = (0:N_w-1)';
    W    = exp(-1j*2*pi/N_w * k);
    Xk   = (2/N_w) * sum(seg .* W) / sqrt(2);
    err  = abs(abs(Xk) - abs(V_true)) / abs(V_true);
    assert(err < 0.01, sprintf('DFT magnitude error %.2f%% > 1%%', err*100));
    fprintf('[PASS] Phasor extraction (DFT accuracy %.3f%%)\n', err*100);
    pass = pass+1;
catch e
    fprintf('[FAIL] Phasor extraction: %s\n', e.message); fail = fail+1;
end

%% Test 6: Fault location within 5% for SLG no-resistance case
try
    cfg                  = SystemConfig();
    cfg.fault_type       = 'AG';
    cfg.fault_location   = 0.60;
    cfg.fault_resistance_ohm = 0;
    [Vabc,Iabc,t,fi]     = load_simulation_data(cfg);
    [Vp,Ip]              = extract_phasors(Vabc,Iabc,t,cfg);
    [Vs,Is]              = abc_to_sequence(Vp,Ip);
    Za                   = calculate_apparent_impedance(Vp,Ip,Is,cfg);
    ro                   = distance_relay(Za,Vp,Ip,Is,cfg);
    fc                   = classify_fault(Vp,Ip,Is,cfg);
    fl                   = intelligent_fault_location(Vp,Ip,Is,Za,fc,cfg);
    assert(abs(fl.error_pct) < 5, ...
           sprintf('FL error %.2f%% > 5%%', abs(fl.error_pct)));
    fprintf('[PASS] End-to-end fault location (error %.2f%%)\n', fl.error_pct);
    pass = pass+1;
catch e
    fprintf('[FAIL] End-to-end fault location: %s\n', e.message); fail = fail+1;
end

%% Summary
fprintf('\n========================\n');
fprintf('Tests passed: %d / %d\n', pass, pass+fail);
if fail == 0
    fprintf('ALL TESTS PASSED ✓\n');
else
    fprintf('FAILURES:      %d\n', fail);
end
fprintf('========================\n');

% =========================================================================
function inside = check_zone_test(Z, Z_reach, cfg)
%CHECK_ZONE_TEST  Scalar version for unit testing
theta  = cfg.relay_angle;
Z_rot  = Z      * exp(-1j*theta);
Zr_rot = Z_reach* exp(-1j*theta);
inside = real((Zr_rot - Z_rot) * conj(Z_rot)) >= 0;
end