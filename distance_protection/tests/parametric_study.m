%% PARAMETRIC FAULT LOCATION STUDY
%  Sweeps fault location, fault resistance, and fault type to evaluate
%  relay and fault-locator performance across the full operating envelope.
%
%  Run AFTER verifying main.m works correctly.
%  Results saved to data/parametric_results.mat and a summary CSV.

clc; clear; close all;
addpath(genpath(pwd));

fprintf('Starting parametric study...\n');

%% Study Parameters
fault_locations = 0.05 : 0.05 : 0.95;       % 19 distances
fault_types     = {'AG','BG','CG','AB','BC','ABC'};
fault_res       = [0, 5, 20, 50];             % Ω

N_loc  = length(fault_locations);
N_type = length(fault_types);
N_Rf   = length(fault_res);
N_total= N_loc * N_type * N_Rf;

% Pre-allocate results table
results = struct();
results.d_true     = zeros(N_total, 1);
results.d_est      = zeros(N_total, 1);
results.error_pct  = zeros(N_total, 1);
results.zone       = zeros(N_total, 1, 'int8');
results.classified = cell(N_total, 1);
results.true_type  = cell(N_total, 1);
results.Rf         = zeros(N_total, 1);

idx = 0;
cfg_base = SystemConfig();

for ti = 1:N_type
    for ri = 1:N_Rf
        for li = 1:N_loc
            idx = idx + 1;

            cfg = cfg_base;
            cfg.fault_type     = fault_types{ti};
            cfg.fault_location = fault_locations(li);
            cfg.fault_resistance_ohm = fault_res(ri);  % Note for info

            % Generate data and run pipeline silently
            [Vabc, Iabc, t, fi]   = load_simulation_data(cfg);
            [Vp, Ip]              = extract_phasors(Vabc, Iabc, t, cfg);
            [Vs, Is]              = abc_to_sequence(Vp, Ip);
            Za                    = calculate_apparent_impedance(Vp, Ip, Is, cfg);
            ro                    = distance_relay(Za, Vp, Ip, Is, cfg);
            fc                    = classify_fault(Vp, Ip, Is, cfg);
            fl                    = intelligent_fault_location(Vp, Ip, Is, Za, fc, cfg);

            results.d_true(idx)     = fault_locations(li);
            results.d_est(idx)      = fl.d_pu;
            results.error_pct(idx)  = fl.error_pct;
            results.zone(idx)       = ro.zone_tripped;
            results.classified{idx} = fc.type;
            results.true_type{idx}  = fault_types{ti};
            results.Rf(idx)         = fault_res(ri);

            if mod(idx, 20) == 0
                fprintf('  [%d/%d] %s @ %.0f%% Rf=%dΩ — est: %.2f%%, err: %.2f%%\n', ...
                        idx, N_total, fault_types{ti}, fault_locations(li)*100, ...
                        fault_res(ri), fl.d_pct, fl.error_pct);
            end
        end
    end
end

%% Performance Metrics
fprintf('\n===== Parametric Study Results =====\n');
fprintf('Total scenarios: %d\n', N_total);
fprintf('MAE (%%):        %.3f\n', mean(abs(results.error_pct)));
fprintf('RMSE (%%):       %.3f\n', sqrt(mean(results.error_pct.^2)));
fprintf('Max error (%%):  %.3f\n', max(abs(results.error_pct)));

% Accuracy within 1%, 2%, 5%
for thr = [1, 2, 5]
    pct_within = 100 * mean(abs(results.error_pct) <= thr);
    fprintf('Within %d%%: %.1f%% of cases\n', thr, pct_within);
end

%% Save Results
save('data/parametric_results.mat', 'results', 'fault_locations', ...
     'fault_types', 'fault_res');

% CSV export
T = table(results.true_type, results.d_true*100, results.d_est*100, ...
          results.error_pct, results.zone, results.classified, results.Rf, ...
          'VariableNames', {'FaultType','TrueLoc_pct','EstLoc_pct', ...
                            'Error_pct','Zone','Classified','Rf_ohm'});
writetable(T, 'data/parametric_results.csv');
fprintf('\nResults saved to data/parametric_results.mat and .csv\n');

%% Summary Plot
figure('Name','Parametric Study Summary','Position',[50 50 1400 500]);

subplot(1,3,1);
scatter(results.d_true*100, results.d_est*100, 10, results.Rf, 'filled');
hold on; plot([0 100],[0 100],'k--','LineWidth',1.5);
colorbar; xlabel('True Location (%)'); ylabel('Estimated Location (%)');
title('Estimation Accuracy'); grid on; axis equal;
xlim([0 100]); ylim([0 100]);

subplot(1,3,2);
boxplot(results.error_pct, results.true_type, 'Colors','rbgmck');
xlabel('Fault Type'); ylabel('Location Error (%)');
title('Error by Fault Type'); grid on; yline(0,'k--');

subplot(1,3,3);
histogram(results.error_pct, 40, 'FaceColor',[0.2 0.5 0.8],'EdgeColor','none');
xlabel('Location Error (%)'); ylabel('Count');
title(sprintf('Error Distribution (MAE = %.2f%%)', mean(abs(results.error_pct))));
grid on;

saveas(gcf, 'results_parametric_study.png');
fprintf('Parametric study complete.\n');