clear;
clc;
%%
% ---- Publication defaults (applies to this MATLAB session) ----
set(groot,'defaultFigureColor','w');

% Fonts & sizes (tweak to your journal)
set(groot,'defaultAxesFontName','Times', ...
          'defaultTextFontName','Times',  ...
          'defaultAxesFontSize',9, ...
          'defaultTextFontSize',9);

% Axes aesthetics
set(groot,'defaultAxesLineWidth',1, ...
          'defaultAxesTickDir','out', ...
          'defaultAxesBox','off', ...
          'defaultAxesXMinorTick','on', ...
          'defaultAxesYMinorTick','on', ...
          'defaultAxesXGrid','on', ...
          'defaultAxesYGrid','on', ...
          'defaultAxesGridAlpha',0.12, ...
          'defaultAxesMinorGridAlpha',0.08);

% Lines, markers, legends
set(groot,'defaultLineLineWidth',0.8, ...
          'defaultLineMarkerSize',5, ...
          'defaultLegendBox','off');

% (Optional) LaTeX text rendering — comment out if not using TeX
set(groot,'defaultTextInterpreter','latex', ...
          'defaultAxesTickLabelInterpreter','latex', ...
          'defaultLegendInterpreter','latex');
%%
basePath = 'C:\Users\Lenovo\Desktop\Tesis\Data\results';

%all the dogs (Who let the dogs out tho)
PIDs = 1:8;  

% Tables with all the universe knowledge 
AllSummary   = table();
AllHRV       = table();
AllBA_SDNN   = table();
AllBA_RMSSD  = table();

for pid = PIDs
    pFolder = fullfile(basePath, sprintf('P%dMatlab', pid));

    % ----- Summary -----
    fSummary = fullfile(pFolder, sprintf('Summary_P%d.csv', pid));
    if isfile(fSummary)
        T = readtable(fSummary);
        AllSummary = [AllSummary; T]; %#ok<AGROW>
    else
        warning('Missing %s', fSummary);
    end

    % ----- HRV per phase -----
    fHRV = fullfile(pFolder, sprintf('HRV_P%d.csv', pid));
    if isfile(fHRV)
        T = readtable(fHRV);
        AllHRV = [AllHRV; T]; %#ok<AGROW>
    else
        warning('Missing %s', fHRV);
    end

    % ----- Bland–Altman SDNN points -----
    fBA_SDNN = fullfile(pFolder, sprintf('BA_SDNN_P%d.csv', pid));
    if isfile(fBA_SDNN)
        T = readtable(fBA_SDNN);
        AllBA_SDNN = [AllBA_SDNN; T]; %#ok<AGROW>
    else
        warning('Missing %s', fBA_SDNN);
    end

    % ----- Bland–Altman RMSSD points -----
    fBA_RMSSD = fullfile(pFolder, sprintf('BA_RMSSD_P%d.csv', pid));
    if isfile(fBA_RMSSD)
        T = readtable(fBA_RMSSD);
        AllBA_RMSSD = [AllBA_RMSSD; T]; %#ok<AGROW>
    else
        warning('Missing %s', fBA_RMSSD);
    end
end
%% Now, Bland Altmann plots ¡Hell yeah!

%SDNN

mean_SDNN  = AllBA_SDNN.SDNN;
diff_SDNN  = AllBA_SDNN.DiffSDNN;

bias_SDNN   = mean(diff_SDNN, 'omitnan');
sd_SDNN     = std(diff_SDNN,  'omitnan');
LoA_SDNN_lo = bias_SDNN - 1.96*sd_SDNN;
LoA_SDNN_hi = bias_SDNN + 1.96*sd_SDNN;


fig = figure('Color','w'); 
scatter(mean_SDNN, diff_SDNN, 100,".",MarkerEdgeColor= '#136F63'); 
hold on;
yline(bias_SDNN, '-', 'Bias', Color='#EA4D49');
yline(LoA_SDNN_lo, 'k--','+1.96 SD');
yline(LoA_SDNN_hi, 'k--','-1.96 SD');

xlabel('Mean SDNN (Biopac & Stress Logger) [ms]');
ylabel('Difference (Stress Logger - Biopac) [ms]');

grid on;

exportgraphics(fig, fullfile(basePath, 'BA_SDNN_all.png'), 'Resolution', 300);
%%
%RMSSD
mean_RMSSD  = AllBA_RMSSD.RMSSD;
diff_RMSSD  = AllBA_RMSSD.DiffRMSSD;

bias_RMSSD   = mean(diff_RMSSD, 'omitnan');
sd_RMSSD     = std(diff_RMSSD,  'omitnan');
LoA_RMSSD_lo = bias_RMSSD - 1.96*sd_RMSSD;
LoA_RMSSD_hi = bias_RMSSD + 1.96*sd_RMSSD;



fig = figure('Color','w'); 
scatter(mean_RMSSD, diff_RMSSD, 100,".",MarkerEdgeColor= '#136F63');
hold on;
yline(bias_RMSSD,  '-', 'Bias', Color='#EA4D49');
yline(LoA_RMSSD_lo, 'k--','+1.96 SD');
yline(LoA_RMSSD_hi,  'k--','-1.96 SD');

xlabel('Mean RMSSD (Biopac & Stress Logger) [ms]');
ylabel('Difference (Stress Logger - Biopac) [ms]');

grid on;

exportgraphics(fig, fullfile(basePath, 'BA_RMSSD_all.png'), 'Resolution', 300);

%%
disp(AllSummary);
writetable(AllSummary,  fullfile(basePath, 'AllSummary_AllParticipants.csv'));
%% Group-level summary (means and SDs across participants)

metrics = {'r_HR','ME_HR','MAE_HR', ...
           'r_EDA','ME_EDA','MAE_EDA', ...
           'r_SDNN','ME_SDNN','MAE_SDNN','icc_SDNN', ...
           'r_RMSSD','ME_RMSSD','MAE_RMSSD','icc_RMSSD'};

meanVals = varfun(@mean, AllSummary, 'InputVariables', metrics, 'OutputFormat','table');
stdVals  = varfun(@std,  AllSummary, 'InputVariables', metrics, 'OutputFormat','table');

disp('Group means:');
disp(meanVals);

disp('Group standard deviations:');
disp(stdVals);

%%
figure('Color','w');

Y = [AllSummary.MAE_HR, AllSummary.MAE_SDNN, ...
     AllSummary.MAE_RMSSD, AllSummary.MAE_EDA];

b = bar(Y);   % b is an array of 4 bar objects

cols = [234  77  73;    % #EA4D49
        63  136 197;    % #3F88C5
        19  111  99;    % #136F63
        255 186   8] / 255;

for k = 1:4
    b(k).FaceColor = cols(k,:);
end

xlabel('Participant');
ylabel('MAE');
legend({'HR [bpm]','SDNN [ms]','RMSSD [ms]','EDA [$\mu$ S]'}, ...
       'Location','northoutside','Orientation','horizontal');
grid on;
exportgraphics(gcf, fullfile(basePath, 'Bar_MeanAbsoluteErrorPerParticipant.png'), ...
               'Resolution', 300);


%%
figure('Color','w');

Y = [AllSummary.r_phase_HR, ...
     AllSummary.r_SDNN, ...
     AllSummary.r_RMSSD, ...
     AllSummary.r_EDA];

b = bar(Y);   % 4 bar groups

cols = [234  77  73;    % #EA4D49
        63  136 197;    % #3F88C5
        19  111  99;    % #136F63
        255 186   8] / 255;   % #FFBA08

for k = 1:4
    b(k).FaceColor = cols(k,:);
end

xlabel('Participant');
ylabel('r');
legend({'HR','SDNN','RMSSD','EDA'}, ...
       'Location','northoutside','Orientation','horizontal');

grid on;

exportgraphics(gcf, fullfile(basePath, 'PearsonCorrelationPerParticipant.png'), ...
               'Resolution', 300);

%%
valid = ~isnan(AllHRV.SDNN_BioPac) & ~isnan(AllHRV.SDNN_MyDev);
x = AllHRV.SDNN_BioPac(valid);
y = AllHRV.SDNN_MyDev(valid);
r_SDNN_phase_all  = corr(x,y)
ME_SDNN_phase_all = mean(y - x)
MAE_SDNN_phase_all= mean(abs(y - x))
%%
valid = ~isnan(AllHRV.RMSSD_BioPac) & ~isnan(AllHRV.RMSSD_MyDev);
x = AllHRV.RMSSD_BioPac(valid);
y = AllHRV.RMSSD_MyDev(valid);
r_RMSSD_phase_all  = corr(x,y)
ME_RMSSD_phase_all = mean(y - x)
MAE_RMSSD_phase_all= mean(abs(y - x))
%%
% Unique phases in the order they appear
phases = unique(AllHRV.Phase, 'stable');
nPh    = numel(phases);

meanHR_MY = nan(nPh,1);

for i = 1:nPh
    idx = strcmp(AllHRV.Phase, phases{i});   % rows for this phase
    meanHR_MY(i) = mean(AllHRV.meanHR_MyDev(idx), 'omitnan');
end

figure('Color','w');
bar(meanHR_MY);
set(gca,'XTick',1:nPh,'XTickLabel',phases);
ylabel('HR [bpm]');
title('Mean Stress Logger HR per phase (all participants)');
grid on;

