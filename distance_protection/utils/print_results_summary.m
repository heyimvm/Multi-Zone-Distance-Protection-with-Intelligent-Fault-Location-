function print_results_summary(relay_output, fault_class, fault_loc, fault_info, cfg)
%PRINT_RESULTS_SUMMARY  Console report of all relay and fault location results.

w = 60;
sep = repmat('=', 1, w);
fprintf('\n%s\n', sep);
fprintf('  SIMULATION RESULTS SUMMARY\n');
fprintf('%s\n', sep);

fprintf('\n  SYSTEM\n');
fprintf('  %-30s %s\n', 'Name:',        cfg.system_name);
fprintf('  %-30s %.0f kV\n','Voltage:',  cfg.base_kV);
fprintf('  %-30s %.0f km\n','Line Length:', cfg.line_length_km);
fprintf('  %-30s %.3f+j%.3f Ω\n', 'Z1 total:', real(cfg.Z1_total), imag(cfg.Z1_total));
fprintf('  %-30s %.3f+j%.3f\n', 'k0 factor:', real(cfg.k0), imag(cfg.k0));

fprintf('\n  TRUE FAULT CONDITIONS\n');
fprintf('  %-30s %s\n',   'Fault Type:',      fault_info.type);
fprintf('  %-30s %.3f pu (%.1f km)\n', 'Location:', ...
        fault_info.location_pu, fault_info.location_km);
fprintf('  %-30s %.3f s\n','Inception Time:',  fault_info.t_inception);
fprintf('  %-30s %.2f Ω\n','Fault Resistance:',fault_info.resistance_ohm);

fprintf('\n  RELAY OPERATION\n');
if relay_output.zone_tripped > 0
    fprintf('  %-30s TRIP — Zone %d, Loop %s\n', 'Decision:', ...
            relay_output.zone_tripped, relay_output.loop_tripped);
    fprintf('  %-30s %.3f s\n', 'Trip Time:', relay_output.trip_time);
    fprintf('  %-30s %.3f s\n', 'Operating Time (from fault):', ...
            relay_output.trip_time - fault_info.t_inception);
    fprintf('  %-30s %.3f+j%.3f Ω\n', 'Impedance at Trip:', ...
            real(relay_output.Z_operated), imag(relay_output.Z_operated));
else
    fprintf('  %-30s NO TRIP\n', 'Decision:');
end

fprintf('\n  FAULT CLASSIFICATION\n');
fprintf('  %-30s %s\n', 'Type:', fault_class.type);
fprintf('  %-30s %.0f%%\n', 'Confidence:', fault_class.confidence*100);
fprintf('  %-30s %s\n', 'Ground Fault:', mat2str(fault_class.is_ground));

fprintf('\n  FAULT LOCATION\n');
for mi = 1:length(fault_loc.methods)
    fprintf('  %-20s %.3f pu  (%.1f km)\n', ...
            [fault_loc.methods{mi} ':'], ...
            fault_loc.estimates_pu(mi), ...
            fault_loc.estimates_pu(mi)*cfg.line_length_km);
end
fprintf('  %-20s %.3f pu  (%.1f km)\n', 'ENSEMBLE:', ...
        fault_loc.d_pu, fault_loc.d_km);
if ~isnan(fault_loc.error_pct)
    fprintf('  %-20s %.2f%%\n', 'Error:', fault_loc.error_pct);
    fprintf('  %-20s [%.1f, %.1f] km\n', '95%% CI (km):', ...
            fault_loc.ci_95_km(1), fault_loc.ci_95_km(2));
end

fprintf('\n%s\n\n', sep);
end