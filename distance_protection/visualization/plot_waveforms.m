function plot_waveforms(t, Vabc, Iabc, fault_info, cfg)
%PLOT_WAVEFORMS  Plot 3-phase voltage and current waveforms.
t_ms = t * 1e3;
figure('Name','Fault Waveforms','NumberTitle','off','Position',[50 50 1200 700]);

%plot the varaibles of Phase voltages
subplot(2,1,1);
plot(t_ms, Vabc(:,1)/1e3, 'b-',  'LineWidth',1.0, 'DisplayName','Va'); hold on;
plot(t_ms, Vabc(:,2)/1e3, 'r--', 'LineWidth',1.0, 'DisplayName','Vb');
plot(t_ms, Vabc(:,3)/1e3, 'g:',  'LineWidth',1.2, 'DisplayName','Vc');
if ~isnan(fault_info.t_inception)
    xline(fault_info.t_inception*1e3,'k--','Fault inception','LineWidth',1.5,'LabelVerticalAlignment','bottom','HandleVisibility','off');
    xline(fault_info.t_clear*1e3,'k-.','Fault cleared','LineWidth',1.5,'LabelVerticalAlignment','bottom','HandleVisibility','off');
end
ylabel('Voltage (kV)'); grid on; legend('Location','northeast');
title(sprintf('3-Phase Voltages - %s Fault @ %.0f km', fault_info.type, fault_info.location_km));
xlim([t_ms(1) t_ms(end)]); set(gca,'FontSize',10);

subplot(2,1,2);
plot(t_ms, Iabc(:,1), 'b-',  'LineWidth',1.0, 'DisplayName','Ia'); hold on;
plot(t_ms, Iabc(:,2), 'r--', 'LineWidth',1.0, 'DisplayName','Ib');
plot(t_ms, Iabc(:,3), 'g:',  'LineWidth',1.2, 'DisplayName','Ic');
if ~isnan(fault_info.t_inception)
    xline(fault_info.t_inception*1e3,'k--','LineWidth',1.5,'HandleVisibility','off');
    xline(fault_info.t_clear*1e3,'k-.','LineWidth',1.5,'HandleVisibility','off');
end
xlabel('Time (ms)'); ylabel('Current (A)'); grid on; legend('Location','northeast');
title('3-Phase Currents');
xlim([t_ms(1) t_ms(end)]); set(gca,'FontSize',10);
end


function plot_impedance_plane(Z_app, relay_output, cfg)
%PLOT_IMPEDANCE_PLANE  R-X plane with zone characteristics and impedance locus.
theta  = linspace(0,2*pi,360);
colors = {[0.1 0.7 0.1],[0.1 0.3 0.9],[0.7 0.1 0.7]};
zones  = {cfg.Z_zone1, cfg.Z_zone2, cfg.Z_zone3};
labels = {'Zone 1','Zone 2','Zone 3'};

figure('Name','R-X Impedance Plane','NumberTitle','off','Position',[100 100 800 800]);
hold on;

for zi = 1:3
    center = zones{zi}/2;
    radius = abs(zones{zi})/2;
    Z_circ = center + radius*exp(1j*theta);
    plot(real(Z_circ), imag(Z_circ), '--', 'Color', colors{zi}, ...
         'LineWidth',1.5, 'DisplayName', labels{zi});
end

lp_colors = {'b','r','g','m','c','k'};
loops = Z_app.loop_names;
for li = 1:6
    Z = Z_app.all(:,li);
    mask = abs(Z) < 3*abs(cfg.Z_zone3) & real(Z) > -200 & imag(Z) > -200;
    plot(real(Z(mask)), imag(Z(mask)), '.', 'Color', lp_colors{li}, ...
         'MarkerSize',2, 'DisplayName',['Z ' loops{li}]);
end

if ~isnan(real(relay_output.Z_operated))
    plot(real(relay_output.Z_operated), imag(relay_output.Z_operated), ...
         'rp','MarkerSize',15,'MarkerFaceColor','r', ...
         'DisplayName',sprintf('TRIP Z%d', relay_output.zone_tripped));
end

plot([0 real(cfg.Z1_total)],[0 imag(cfg.Z1_total)],'k-o','LineWidth',2,...
     'DisplayName','Line Z1','MarkerFaceColor','k');
plot([-200 200],[0 0],'k-','HandleVisibility','off','LineWidth',0.5);
plot([0 0],[-200 200],'k-','HandleVisibility','off','LineWidth',0.5);

xlabel('Resistance R (Ohm)'); ylabel('Reactance X (Ohm)');
title(sprintf('R-X Impedance Plane - %s Characteristic', upper(cfg.characteristic)));
legend('Location','northwest','FontSize',8); grid on; axis equal;
lim_v = abs(cfg.Z_zone3)*0.6;
xlim([-lim_v*0.3, lim_v*0.5]); ylim([-lim_v*0.3, lim_v*1.2]);
set(gca,'FontSize',10);
end


function plot_fault_location(fault_loc, fault_info, cfg)
%PLOT_FAULT_LOCATION  Fault location estimates vs truth.
figure('Name','Fault Location','NumberTitle','off','Position',[150 150 900 500]);

subplot(1,2,1);
bar_data = fault_loc.estimates_pu * cfg.line_length_km;
b = bar(bar_data, 0.6, 'FaceColor','flat');
b.CData = [0.2 0.5 0.8; 0.8 0.3 0.2; 0.3 0.7 0.3; 0.7 0.4 0.8];
hold on;
yline(fault_loc.d_km,'k--','LineWidth',2,'DisplayName','Ensemble');
if ~isnan(fault_info.location_km)
    yline(fault_info.location_km,'r-','LineWidth',2,'DisplayName','True');
end
set(gca,'XTickLabel', fault_loc.methods, 'XTickLabelRotation',15);
ylabel('Estimated Location (km)'); title('Method Comparison');
legend('Location','best'); grid on;
ylim([0, cfg.line_length_km*1.05]);

subplot(1,2,2);
plot([0 cfg.line_length_km],[0 0],'k-','LineWidth',4); hold on;
plot(0, 0,'ks','MarkerSize',14,'MarkerFaceColor','k');
plot(cfg.line_length_km, 0,'ks','MarkerSize',14,'MarkerFaceColor','k');

neg_err = max(0, fault_loc.d_km - fault_loc.ci_95_km(1));
pos_err = max(0, fault_loc.ci_95_km(2) - fault_loc.d_km);
errorbar(fault_loc.d_km, 0.05, 0, 0, neg_err, pos_err, ...
    'ko','LineWidth',2,'MarkerFaceColor','b','MarkerSize',10,...
    'DisplayName',sprintf('Estimated: %.1f km', fault_loc.d_km));

if ~isnan(fault_info.location_km)
    plot(fault_info.location_km, 0,'r^','MarkerSize',12,'MarkerFaceColor','r',...
         'DisplayName',sprintf('True: %.1f km', fault_info.location_km));
end
text(0,-0.15,'Bus A','HorizontalAlignment','center','FontSize',9);
text(cfg.line_length_km,-0.15,'Bus B','HorizontalAlignment','center','FontSize',9);
xlabel('Distance from Relay (km)'); yticks([]); ylim([-0.4 0.4]);
xlim([-10 cfg.line_length_km+10]);
title(sprintf('Line Diagram - Error: %.2f%%', fault_loc.error_pct));
legend('Location','north','FontSize',8); grid on;
end


function plot_relay_characteristics(cfg)
%PLOT_RELAY_CHARACTERISTICS  Zone boundaries on R-X plane.
theta  = linspace(0,2*pi,500);
zones  = {cfg.Z_zone1, cfg.Z_zone2, cfg.Z_zone3};
colors = {[0.1 0.7 0.1],[0.1 0.3 0.9],[0.7 0.1 0.7]};
reach_pct = [cfg.zone1_reach_pu, cfg.zone2_reach_pu, cfg.zone3_reach_pu] * 100;

figure('Name','Relay Characteristics','NumberTitle','off','Position',[200 200 700 700]);
hold on;

for zi = 1:3
    center = zones{zi}/2;
    radius = abs(zones{zi})/2;
    Z_circ = center + radius*exp(1j*theta);
    fill(real(Z_circ), imag(Z_circ), colors{zi}, 'FaceAlpha',0.12,...
         'EdgeColor',colors{zi},'LineWidth',2,...
         'DisplayName',sprintf('Zone %d (%.0f%%)', zi, reach_pct(zi)));
end

line_pts  = linspace(0,1,100);
Z1_locus  = line_pts * cfg.Z1_total;
Z1_mag    = abs(cfg.Z1_total);
Z1_ang    = angle(cfg.Z1_total)*180/pi;
plot(real(Z1_locus), imag(Z1_locus),'k-','LineWidth',2.5,...
     'DisplayName',sprintf('Line Z1 (%.1f @ %.1f deg)', Z1_mag, Z1_ang));

plot([-500 500],[0 0],'k-','LineWidth',0.5,'HandleVisibility','off');
plot([0 0],[-500 500],'k-','LineWidth',0.5,'HandleVisibility','off');

rng_x = [0, abs(cfg.Z_zone3)*cos(cfg.relay_angle)*1.1];
rng_y = [0, abs(cfg.Z_zone3)*sin(cfg.relay_angle)*1.1];
plot(rng_x, rng_y,'k:','LineWidth',1.5,...
     'DisplayName',sprintf('Relay Angle %d deg', cfg.relay_angle_deg));

xlabel('R (Ohm)'); ylabel('X (Ohm)');
title(sprintf('%s Relay Characteristic - %s', upper(cfg.characteristic), cfg.system_name));
legend('Location','northwest','FontSize',9); grid on; axis equal;
lim_v = abs(cfg.Z_zone3)*0.6;
xlim([-lim_v*0.4, lim_v*0.8]); ylim([-lim_v*0.3, lim_v*1.2]);
set(gca,'FontSize',10);
end


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
