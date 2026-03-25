function Z_app = calculate_apparent_impedance(V_phasor, I_phasor, I_seq, cfg)
k0 = cfg.k0;
I0 = I_seq.zero;
denom_AG = I_phasor.a + k0 * I0;
denom_BG = I_phasor.b + k0 * I0;
denom_CG = I_phasor.c + k0 * I0;
Z_app.AG = safe_divide(V_phasor.a, denom_AG);
Z_app.BG = safe_divide(V_phasor.b, denom_BG);
Z_app.CG = safe_divide(V_phasor.c, denom_CG);
Z_app.AB = safe_divide(V_phasor.a - V_phasor.b, I_phasor.a - I_phasor.b);
Z_app.BC = safe_divide(V_phasor.b - V_phasor.c, I_phasor.b - I_phasor.c);
Z_app.CA = safe_divide(V_phasor.c - V_phasor.a, I_phasor.c - I_phasor.a);
a = exp(1j * 2*pi/3);
V1 = (V_phasor.a + a .* V_phasor.b + (a^2) .* V_phasor.c) / 3;
Z_app.pos_seq = safe_divide(V1, I_seq.pos);
Z_app.all = [Z_app.AG, Z_app.BG, Z_app.CG, Z_app.AB, Z_app.BC, Z_app.CA];
Z_app.loop_names = {'AG','BG','CG','AB','BC','CA'};
Z_mag = abs(Z_app.all);
Z_mag(Z_mag > 1e6) = NaN;
[Z_app.Z_min_mag, Z_app.Z_min_idx] = min(Z_mag, [], 2, 'omitnan');
end
function result = safe_divide(num, denom)
THRESH = 1e-6;
result = complex(zeros(size(num)));
valid = abs(denom) > THRESH;
result(valid) = num(valid) ./ denom(valid);
result(~valid) = complex(1e9, 1e9);
end
