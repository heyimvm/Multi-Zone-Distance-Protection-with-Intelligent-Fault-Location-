function relay_output = distance_relay(Z_app, V_phasor, I_phasor, I_seq, cfg)
%DISTANCE_RELAY  Multi-zone distance relay decision logic.
%
%  Implements mho or quadrilateral characteristics for Zones 1-4.
%  Includes:
%    - Fault detector (ΔI / ΔV starter)
%    - Load encroachment blocking
%    - Zone reach comparison
%    - Timer logic with definite-time delays
%    - Trip signal generation per loop
%
%  Output struct fields:
%    .trip         - [N x 1] logical : final trip decision
%    .zone         - [N x 1] int     : zone that operated (0=no trip)
%    .loop         - [N x 1] string  : loop that operated
%    .trip_time    - scalar : time of first trip (s), NaN if no trip
%    .Z_operated   - complex : impedance at trip point

N = size(Z_app.AG, 1);
loops = Z_app.loop_names;   % {'AG','BG','CG','AB','BC','CA'}

% Pre-allocate output
relay_output.in_zone  = zeros(N, 6, 'uint8');  % [N x 6 loops] zone 1-4
relay_output.trip     = false(N, 1);
relay_output.zone     = zeros(N, 1, 'int8');
relay_output.loop_idx = zeros(N, 1, 'int8');
relay_output.trip_time= NaN;
relay_output.Z_operated = NaN + 1j*NaN;

% ---- Fault Detector ---------------------------------------------------
fd = fault_detector(V_phasor, I_phasor, cfg);
relay_output.fault_detected = fd;

% ---- Zone comparators for each loop -----------------------------------
for li = 1:6
    Z = Z_app.all(:, li);

    in_z1 = check_zone(Z, cfg.Z_zone1, cfg);
    in_z2 = check_zone(Z, cfg.Z_zone2, cfg);
    in_z3 = check_zone(Z, cfg.Z_zone3, cfg);
    in_z4 = check_zone(Z, cfg.Z_zone4, cfg);   % Reverse

    % Only assert zone when fault detector is active AND not load encroachment
    le_block = load_encroachment_block(Z, cfg);

    relay_output.zone1_assert(:, li) = in_z1 & fd & ~le_block;
    relay_output.zone2_assert(:, li) = in_z2 & fd & ~le_block & ~in_z1;
    relay_output.zone3_assert(:, li) = in_z3 & fd & ~le_block & ~in_z2;
    relay_output.zone4_assert(:, li) = in_z4 & fd;
end

% ---- Timer logic & trip decision --------------------------------------
dt = 1/cfg.fs;

% Determine N samples for each zone delay
n_z1 = max(1, round(cfg.t_zone1 / dt));
n_z2 = round(cfg.t_zone2 / dt);
n_z3 = round(cfg.t_zone3 / dt);

for li = 1:6
    % Zone 1 : no intentional delay (1 sample)
    trip_z1 = apply_timer(relay_output.zone1_assert(:,li), n_z1);
    trip_z2 = apply_timer(relay_output.zone2_assert(:,li), n_z2);
    trip_z3 = apply_timer(relay_output.zone3_assert(:,li), n_z3);

    trip_loop = trip_z1 | trip_z2 | trip_z3;

    % Update global trip arrays: closest zone takes priority
    for n = 1:N
        if trip_loop(n) && relay_output.zone(n) == 0
            if trip_z1(n),     relay_output.zone(n) = 1;
            elseif trip_z2(n), relay_output.zone(n) = 2;
            else,              relay_output.zone(n) = 3;
            end
            relay_output.loop_idx(n) = li;
        end
    end
    relay_output.trip = relay_output.trip | trip_loop;
end

% ---- Record first trip time and loop ----------------------------------
trip_idx = find(relay_output.trip, 1, 'first');
if ~isempty(trip_idx)
    t_vec = (0:N-1)' / cfg.fs + cfg.t_start;
    relay_output.trip_time   = t_vec(trip_idx);
    relay_output.Z_operated  = Z_app.all(trip_idx, relay_output.loop_idx(trip_idx));
    relay_output.zone_tripped = relay_output.zone(trip_idx);
    relay_output.loop_tripped = loops{relay_output.loop_idx(trip_idx)};

    fprintf('[RELAY] TRIP: Zone %d | Loop %s | t=%.3f s | Z=(%.3f+j%.3f) Ω\n', ...
            relay_output.zone_tripped, ...
            relay_output.loop_tripped, ...
            relay_output.trip_time, ...
            real(relay_output.Z_operated), ...
            imag(relay_output.Z_operated));
else
    relay_output.zone_tripped = 0;
    relay_output.loop_tripped = 'None';
    fprintf('[RELAY] No trip detected within simulation window.\n');
end

relay_output.loop_names = loops;
end

% =========================================================================
function inside = check_zone(Z, Z_reach, cfg)
%CHECK_ZONE  Test whether impedance Z falls inside zone characteristic.

switch lower(cfg.characteristic)
    case 'mho'
        inside = mho_comparator(Z, Z_reach, cfg);
    case 'quad'
        inside = quadrilateral_comparator(Z, Z_reach, cfg);
    case 'offset_mho'
        inside = offset_mho_comparator(Z, Z_reach, cfg);
    otherwise
        error('Unknown relay characteristic: %s', cfg.characteristic);
end
end

% =========================================================================
function inside = mho_comparator(Z, Z_reach, cfg)
%MHO_COMPARATOR  Circular mho characteristic.
%
%  The mho circle passes through the origin and has its diameter along
%  the line impedance angle (relay angle θ).
%
%  Condition (cross-product comparator form):
%    |Z - Z_reach/2| ≤ |Z_reach/2|
%  Equivalent voltage comparator form:
%    cos(angle(Z_reach) - angle(Z)) * |Z| ≤ |Z_reach| * cos²((angle(Z_reach)-angle(Z))/2 * 0)
%  Simplest form:
%    Re[(Z_reach - Z) × conj(Z)] ≥ 0

theta = cfg.relay_angle;

% Rotate to relay angle for cleaner comparison
Z_rot  = Z        .* exp(-1j * theta);
Zr_rot = Z_reach  .* exp(-1j * theta);

% Mho condition in rotated frame
inside = real((Zr_rot - Z_rot) .* conj(Z_rot)) >= 0;

% Only forward-looking (exclude reverse faults for Zones 1-3)
if real(Z_reach) > 0
    inside = inside & (real(Z) >= -abs(real(Z_reach))*0.1);
end
end

% =========================================================================
function inside = quadrilateral_comparator(Z, Z_reach, cfg)
%QUADRILATERAL_COMPARATOR  Reactance + blinder characteristic.

X  = imag(Z);
R  = real(Z);

% Reactance element (top boundary at imag(Z_reach), bottom at cfg.blinder_X_bot)
in_X = (X <= imag(Z_reach) * 1.05) & (X >= cfg.blinder_X_bot);

% Resistive blinders
in_R = (R >= cfg.blinder_R_neg) & (R <= cfg.blinder_R_pos);

inside = in_X & in_R;
end

% =========================================================================
function inside = offset_mho_comparator(Z, Z_reach, cfg)
%OFFSET_MHO_COMPARATOR  Mho circle offset from origin (for Zone 3 backup).
offset_ratio = 0.1;  % Offset = 10% of reach in reverse direction
Z_offset     = -offset_ratio * Z_reach;
Z_center     = (Z_reach - Z_offset) / 2 + Z_offset;
radius       = abs(Z_reach - Z_offset) / 2;
inside       = abs(Z - Z_center) <= radius;
end

% =========================================================================
function fd = fault_detector(V_phasor, I_phasor, cfg)
%FAULT_DETECTOR  Negative-sequence / overcurrent starter.

I2 = abs(I_phasor.a - I_phasor.b) / sqrt(3);  % Rough neg-seq proxy
V_avg = (abs(V_phasor.a) + abs(V_phasor.b) + abs(V_phasor.c)) / 3;
V_nom = cfg.base_kV * 1e3 / sqrt(3);           % Nominal phase voltage (V)
I_rated = cfg.I_rated_A;

% Undercurrent / overvoltage threshold
delta_V_pu = abs(V_avg - V_nom) / V_nom;
I_total_pu = (abs(I_phasor.a) + abs(I_phasor.b) + abs(I_phasor.c)) / ...
              (3 * I_rated);

fd = (delta_V_pu > cfg.delta_V_thresh) | (I_total_pu > 1 + cfg.delta_I_thresh);
end

% =========================================================================
function block = load_encroachment_block(Z, cfg)
%LOAD_ENCROACHMENT_BLOCK  Block trip if impedance locus is in load region.

R = real(Z);
X = imag(Z);

% Load region: high R, small angle
angle_Z = abs(atan2d(X, R));
in_load_R     = (R > cfg.load_R_min);
in_load_angle = (angle_Z < cfg.load_angle_max);

block = in_load_R & in_load_angle;
end

% =========================================================================
function tripped = apply_timer(assert_signal, n_samples)
%APPLY_TIMER  Assert trip output after assert_signal has been active for
%             n_samples consecutive samples.

N       = length(assert_signal);
tripped = false(N, 1);
count   = 0;

for k = 1:N
    if assert_signal(k)
        count = count + 1;
        if count >= n_samples
            tripped(k) = true;
        end
    else
        count = 0;
    end
end
end