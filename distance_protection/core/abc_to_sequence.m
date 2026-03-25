function [V_seq, I_seq] = abc_to_sequence(V_phasor, I_phasor)
%ABC_TO_SEQUENCE  Transform abc phasors to symmetrical (012) components.
%
%  Uses the Fortescue transformation:
%    [V0]       [1  1  1 ]   [Va]
%    [V1] = 1/3 [1  a  a²] × [Vb]
%    [V2]       [1  a² a ]   [Vc]
%  where a = e^(j2π/3)
%
%  Outputs:
%    V_seq - struct with fields .zero, .pos, .neg ([N x 1] complex RMS)
%    I_seq - struct with fields .zero, .pos, .neg

a  = exp(1j * 2*pi/3);     % 120° rotation operator
a2 = a^2;

% Voltage sequence components
V_seq.zero = (V_phasor.a + V_phasor.b + V_phasor.c) / 3;
V_seq.pos  = (V_phasor.a + a  * V_phasor.b + a2 * V_phasor.c) / 3;
V_seq.neg  = (V_phasor.a + a2 * V_phasor.b + a  * V_phasor.c) / 3;

% Current sequence components
I_seq.zero = (I_phasor.a + I_phasor.b + I_phasor.c) / 3;
I_seq.pos  = (I_phasor.a + a  * I_phasor.b + a2 * I_phasor.c) / 3;
I_seq.neg  = (I_phasor.a + a2 * I_phasor.b + a  * I_phasor.c) / 3;

% Matrix forms [N x 3] : columns = [zero, pos, neg]
V_seq.mat  = [V_seq.zero, V_seq.pos, V_seq.neg];
I_seq.mat  = [I_seq.zero, I_seq.pos, I_seq.neg];

% Symmetry check: negative-sequence voltage unbalance factor (%)
mag_pos = abs(V_seq.pos);
mag_neg = abs(V_seq.neg);
% Avoid div/zero
mag_pos(mag_pos < 1) = 1;
V_seq.unbalance_pct = 100 * mag_neg ./ mag_pos;
end