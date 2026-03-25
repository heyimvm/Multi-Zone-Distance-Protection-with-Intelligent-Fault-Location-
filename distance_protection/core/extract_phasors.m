function [V_phasor, I_phasor] = extract_phasors(Vabc, Iabc, t, cfg)
%EXTRACT_PHASORS  Full-cycle DFT phasor extraction for all 3 phases.
%
%  Implements the recursive/sliding DFT to extract the fundamental
%  frequency phasor from each voltage and current channel.
%
%  Outputs (complex arrays, RMS phasors):
%    V_phasor - struct with fields .a, .b, .c  ([N x 1] complex, RMS)
%    I_phasor - struct with fields .a, .b, .c  ([N x 1] complex, RMS)

N_win = round(cfg.window_samples);
N     = size(Vabc, 1);

Va_ph = sliding_dft(Vabc(:,1), N_win);
Vb_ph = sliding_dft(Vabc(:,2), N_win);
Vc_ph = sliding_dft(Vabc(:,3), N_win);
Ia_ph = sliding_dft(Iabc(:,1), N_win);
Ib_ph = sliding_dft(Iabc(:,2), N_win);
Ic_ph = sliding_dft(Iabc(:,3), N_win);

% Pack into structs
V_phasor.a = Va_ph;
V_phasor.b = Vb_ph;
V_phasor.c = Vc_ph;

I_phasor.a = Ia_ph;
I_phasor.b = Ib_ph;
I_phasor.c = Ic_ph;

% Also store time-indexed matrix forms for convenience
V_phasor.mat = [Va_ph, Vb_ph, Vc_ph];   % [N x 3] complex
I_phasor.mat = [Ia_ph, Ib_ph, Ic_ph];
end

% =========================================================================
function phasor = sliding_dft(x, N_win)
%SLIDING_DFT  Compute full-cycle DFT phasor (complex RMS) at each sample.
%
%  Reference: IEEE C37.111 / Phadke & Thorp "Computer Relaying for
%             Power Systems", 2nd Ed., Chapter 3.

N = length(x);
phasor = complex(zeros(N, 1));

% DFT kernel (pre-compute)
k_vec = (0 : N_win - 1)';
W     = exp(-1j * 2*pi/N_win * k_vec);   % Fundamental bin (k=1)

% Initial window (zero-padded if signal shorter than window)
for n = N_win : N
    segment  = x(n - N_win + 1 : n);
    % DFT at fundamental frequency k=1
    X_k      = (2/N_win) * sum(segment .* W);
    phasor(n) = X_k / sqrt(2);            % Convert peak → RMS
end

% Fill pre-window samples with first valid value
if N_win <= N
    phasor(1 : N_win - 1) = phasor(N_win);
end
end