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
