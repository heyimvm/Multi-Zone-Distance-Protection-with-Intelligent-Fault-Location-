function plot_relay_characteristics(cfg)
%PLOT_RELAY_CHARACTERISTICS  Zone boundaries on R-X plane.
theta     = linspace(0,2*pi,500);
zones     = {cfg.Z_zone1, cfg.Z_zone2, cfg.Z_zone3};
colors    = {[0.1 0.7 0.1],[0.1 0.3 0.9],[0.7 0.1 0.7]};
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

line_pts = linspace(0,1,100);
Z1_locus = line_pts * cfg.Z1_total;
Z1_mag   = abs(cfg.Z1_total);
Z1_ang   = angle(cfg.Z1_total)*180/pi;
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
