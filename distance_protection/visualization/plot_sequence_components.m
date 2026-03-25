function plot_sequence_components(t, V_seq, I_seq, cfg)
%PLOT_SEQUENCE_COMPONENTS  Positive/negative/zero sequence magnitudes.
t_ms = t * 1e3;
figure('Name','Sequence Components','NumberTitle','off','Position',[250 50 1100 600]);

subplot(2,1,1);
plot(t_ms, abs(V_seq.pos)/1e3,  'b-',  'LineWidth',1.2, 'DisplayName','V1 pos'); hold on;
plot(t_ms, abs(V_seq.neg)/1e3,  'r--', 'LineWidth',1.2, 'DisplayName','V2 neg');
plot(t_ms, abs(V_seq.zero)/1e3, 'g:',  'LineWidth',1.5, 'DisplayName','V0 zero');
if ~isnan(cfg.t_fault)
    xline(cfg.t_fault*1e3,'k--','LineWidth',1.5,'HandleVisibility','off');
end
ylabel('Voltage (kV)'); title('Sequence Voltages');
legend('Location','east'); grid on;
xlim([t_ms(1) t_ms(end)]); set(gca,'FontSize',10);

subplot(2,1,2);
plot(t_ms, abs(I_seq.pos),  'b-',  'LineWidth',1.2, 'DisplayName','I1 pos'); hold on;
plot(t_ms, abs(I_seq.neg),  'r--', 'LineWidth',1.2, 'DisplayName','I2 neg');
plot(t_ms, abs(I_seq.zero), 'g:',  'LineWidth',1.5, 'DisplayName','I0 zero');
if ~isnan(cfg.t_fault)
    xline(cfg.t_fault*1e3,'k--','LineWidth',1.5,'HandleVisibility','off');
end
xlabel('Time (ms)'); ylabel('Current (A)'); title('Sequence Currents');
legend('Location','east'); grid on;
xlim([t_ms(1) t_ms(end)]); set(gca,'FontSize',10);
end
