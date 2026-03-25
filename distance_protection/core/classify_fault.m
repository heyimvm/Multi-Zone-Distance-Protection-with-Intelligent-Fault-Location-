function fault_class = classify_fault(V_phasor, I_phasor, I_seq, cfg)
N = length(I_seq.zero);
I0 = abs(I_seq.zero);
I1 = abs(I_seq.pos);
I2 = abs(I_seq.neg);
Ia = abs(I_phasor.a);
Ib = abs(I_phasor.b);
Ic = abs(I_phasor.c);
a = exp(1j*2*pi/3);
V1 = abs((V_phasor.a + a.*V_phasor.b + (a^2).*V_phasor.c)/3);
I_rated = cfg.I_rated_A;
I0_thresh = 0.1 * I_rated;
[~, peak_idx] = max(I0 + I2);
I0_pk = I0(peak_idx);
I1_pk = I1(peak_idx);
I2_pk = I2(peak_idx);
Ia_pk = Ia(peak_idx);
Ib_pk = Ib(peak_idx);
Ic_pk = Ic(peak_idx);
is_ground = I0_pk > I0_thresh;
ph_thresh = 1.3 * I_rated;
ph_a = Ia_pk > ph_thresh;
ph_b = Ib_pk > ph_thresh;
ph_c = Ic_pk > ph_thresh;
I_delta_ab = abs(I_phasor.a(peak_idx) - I_phasor.b(peak_idx));
I_delta_bc = abs(I_phasor.b(peak_idx) - I_phasor.c(peak_idx));
I_delta_ca = abs(I_phasor.c(peak_idx) - I_phasor.a(peak_idx));
n_phases = ph_a + ph_b + ph_c;
if ~is_ground && n_phases >= 3
    fault_type = 'ABC'; phases = {'A','B','C'}; confidence = 0.90;
elseif is_ground && n_phases >= 3
    fault_type = 'ABCG'; phases = {'A','B','C','G'}; confidence = 0.85;
elseif is_ground && n_phases == 2
    if ph_a && ph_b, fault_type = 'ABG';
    elseif ph_b && ph_c, fault_type = 'BCG';
    else, fault_type = 'CAG'; end
    phases = {fault_type(1), fault_type(2), 'G'}; confidence = 0.88;
elseif ~is_ground && n_phases == 2
    [~, max_loop] = max([I_delta_ab, I_delta_bc, I_delta_ca]);
    loop_names = {'AB','BC','CA'};
    fault_type = loop_names{max_loop};
    phases = {fault_type(1), fault_type(2)}; confidence = 0.92;
elseif is_ground && n_phases == 1
    [~, max_ph] = max([Ia_pk, Ib_pk, Ic_pk]);
    ph_labels = {'A','B','C'};
    fault_type = [ph_labels{max_ph}, 'G'];
    phases = {ph_labels{max_ph}, 'G'}; confidence = 0.95;
else
    fault_type = 'AG'; phases = {'A','G'}; confidence = 0.50;
end
fault_class.type       = fault_type;
fault_class.is_ground  = is_ground;
fault_class.phases     = phases;
fault_class.confidence = confidence;
fault_class.peak_idx   = peak_idx;
fault_class.I0_pk_A    = I0_pk;
fault_class.I2_pk_A    = I2_pk;
fault_class.n_phases   = n_phases;
fprintf('[CLASS] Fault type: %s (confidence: %.0f%%)', fault_type, confidence*100);
end
