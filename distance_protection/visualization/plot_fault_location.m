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
