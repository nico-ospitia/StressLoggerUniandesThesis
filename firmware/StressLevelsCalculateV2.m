%% CALCULATE STRESS LEVELS (10 levels) FROM MY DEVICE + SURVEYS


clear; clc;

%% ------------------------------------------------------------------------
%  Paths and participant IDs
% -------------------------------------------------------------------------
basePath   = 'C:\Users\Lenovo\Desktop\Tesis\Data\results';  % where P#Matlab folders are
prePath    = fullfile(basePath, 'PreDataSurvey.csv');
postPath   = fullfile(basePath, 'PostDataSurvey.csv');

PIDs = [1 2 4 6 7 8];


%% ========================================================================
%  1) Load physiology features (ALL_P#.csv)
% ========================================================================

AllPhys = table();

for PID = PIDs
    pFolder = fullfile(basePath, sprintf('P%dMatlab', PID));
    fPhys   = fullfile(pFolder, sprintf('ALL_P%d.csv', PID));

    if ~isfile(fPhys)
        warning('Missing %s', fPhys);
        continue;
    end

    T = readtable(fPhys);
    AllPhys = [AllPhys; T]; %#ok<AGROW>
end

if isempty(AllPhys)
    error('No ALL_P#.csv files found.');
end

% Make sure Phase is string for joining later
AllPhys.Phase = string(AllPhys.Phase);


%% ========================================================================
%  2) Read survey CSVs (pre + post)
% ========================================================================

Pre  = readtable(prePath);   % columns: Participant, Current_Stress, ...
Post = readtable(postPath);  % columns: Participant, TSST_Stress, Arithmetic_Stress, ...

Pre.Participant  = double(Pre.Participant);
Post.Participant = double(Post.Participant);


%% ========================================================================
%  3) Build (Participant, Phase, StressSelf10) with COMPOSITE labels
% ========================================================================

% Phases we will label:
%   Relax 1    -> composite of several PRE items
%   TSST Speech -> composite of TSST_* items
%   Arithmetic -> composite of Arithmetic_* items
%   Stroop     -> composite of SCWT_* items
%   Cold Press -> composite of CPT_* items

phLabelled = {'Relax 1','TSST Speech','Arithmetic','Stroop','Cold Press'};
nLabelled  = numel(phLabelled);

StressLabels = table();

for PID = PIDs
    % Find this participant in Pre and Post tables
    idxPre  = (Pre.Participant  == PID);
    idxPost = (Post.Participant == PID);

    if ~any(idxPre) || ~any(idxPost)
        warning('Participant %d not found in Pre or Post survey tables.', PID);
        stressVals = nan(1, nLabelled);
    else
        preRow  = Pre(idxPre, :);
        postRow = Post(idxPost, :);

        % ---- Relax 1 composite (pre) ------------------------------------
        % Includes: Current stress, anxiety, physical pain,
        % palpitations/sweating/tremor, nervous, tense, and inverted calm.
        % relax_vec = [ ...
        %     preRow.Current_Stress, ...
        %     preRow.Current_Anxiety, ...
        %     preRow.Current_Physical_Pain, ...
        %     preRow.Palpitations_Sweating_Tremor, ...
        %     preRow.Nervous, ...
        %     preRow.Tense, ...
        %     11 - preRow.Calm ];   % invert Calm so higher = more stressed
        % 
        % relax1_label = mean(relax_vec, 'omitnan');
        % 
        % % ---- TSST composite --------------------------------------------
        % tsst_vec = [ ...
        %     postRow.TSST_Stress, ...
        %     postRow.TSST_Mental_Demand, ...
        %     postRow.TSST_Effort, ...
        %     postRow.TSST_Frustration, ...
        %     postRow.TSST_Nervous, ...
        %     postRow.TSST_Tense, ...
        %     postRow.TSST_Time_Pressure, ...
        %     postRow.TSST_Judged, ...
        %     postRow.TSST_Out_of_control, ...
        %     postRow.TSST_Palpitations, ...
        %     postRow.TSST_Sweating, ...
        %     postRow.TSST_Rapid_breathing, ...
        %     postRow.TSST_Tremor ];
        % 
        % tsst_label = mean(tsst_vec, 'omitnan');
        % 
        % % ---- Arithmetic composite --------------------------------------
        % arith_vec = [ ...
        %     postRow.Arithmetic_Stress, ...
        %     postRow.Arithmetic_Mental_demand, ...
        %     postRow.Arithmetic_Effort, ...
        %     postRow.Arithmetic_Frustration, ...
        %     postRow.Arithmetic_Nervous, ...
        %     postRow.Arithmetic_Tense, ...
        %     postRow.Arithmetic_Time_Pressure, ...
        %     postRow.Arithmetic_Judged, ...
        %     postRow.Arithmetic_out_of_control, ...
        %     postRow.Arithmetic_Palpitations, ...
        %     postRow.Arithmetic_Sweating, ...
        %     postRow.Arithmetic_Rapid_breathing, ...
        %     postRow.Arithmetic_Tremor ];
        % 
        % arithmetic_label = mean(arith_vec, 'omitnan');
        % 
        % % ---- Stroop (SCWT) composite -----------------------------------
        % scwt_vec = [ ...
        %     postRow.SCWT_Stress, ...
        %     postRow.SCWT_Mental_demand, ...
        %     postRow.SCWT_Effort, ...
        %     postRow.SCWT_Frustration, ...
        %     postRow.SCWT_Nervous, ...
        %     postRow.SCWT_Tense, ...
        %     postRow.SCWT_Time_Pressure, ...
        %     postRow.SCWT_Judged, ...
        %     postRow.SCWT_out_of_control, ...
        %     postRow.SCWT_Palpitations, ...
        %     postRow.SCWT_Rapid_breathing, ...
        %     postRow.SCWT_Tremor ];
        % 
        % scwt_label = mean(scwt_vec, 'omitnan');
        % 
        % % ---- CPT composite ---------------------------------------------
        % cpt_vec = [ ...
        %     postRow.CPT_Stress, ...
        %     postRow.CPT_Mental_demand, ...
        %     postRow.CPT_Effort, ...
        %     postRow.CPT_Frustration, ...
        %     postRow.CPT_Nervous, ...
        %     postRow.CPT_Tense, ...
        %     postRow.CPT_Time_Pressure, ...
        %     postRow.CPT_Judged, ...
        %     postRow.CPT_out_of_control, ...
        %     postRow.CPT_Palpitations, ...
        %     postRow.CPT_Sweating, ...
        %     postRow.CPT_Rapid_breathing, ...
        %     postRow.CPT_Tremor, ...
        %     postRow.CPT_Pain_Intensity, ...
        %     postRow.CPT_Unpleasantness, ...
        %     postRow.Cold_Intensity, ...
        %     postRow.Urge_to_withdraw_the_hand ];
        % 
        % cpt_label = mean(cpt_vec, 'omitnan');
                % ---- Relax 1: use only Current_Stress from PRE ------------------
        relax1_label = preRow.Current_Stress;

        % ---- TSST Speech: use only TSST_Stress from POST ----------------
        tsst_label = postRow.TSST_Stress;

        % ---- Arithmetic: use only Arithmetic_Stress ---------------------
        arithmetic_label = postRow.Arithmetic_Stress;

        % ---- Stroop (SCWT): use only SCWT_Stress ------------------------
        scwt_label = postRow.SCWT_Stress;

        % ---- Cold Press: use only CPT_Stress ----------------------------
        cpt_label = postRow.CPT_Stress;

        stressVals = [relax1_label, tsst_label, arithmetic_label, ...
                      scwt_label, cpt_label];
    end

    for k = 1:nLabelled
        newRow = table(PID, string(phLabelled{k}), stressVals(k), ...
            'VariableNames', {'Participant','Phase','StressSelf10'});
        StressLabels = [StressLabels; newRow]; %#ok<AGROW>
    end
end


%% ========================================================================
%  4) Join physiology + labels, compute baseline-relative features
% ========================================================================

% Outer join: keep all phases even if they don't have labels
Data = outerjoin(AllPhys, StressLabels, ...
                 'Keys', {'Participant','Phase'}, ...
                 'MergeKeys', true, ...
                 'Type','left');

Data.Phase = string(Data.Phase);

% Allocate delta-features
Data.dHR       = nan(height(Data),1);
Data.dSDNN     = nan(height(Data),1);
Data.dRMSSD    = nan(height(Data),1);
Data.dEDAmean  = nan(height(Data),1);

% We'll still keep dpNN50, dEDAslope computed (maybe useful later),
% but not use them as predictors in this simpler model.
Data.dpNN50    = nan(height(Data),1);
Data.dEDAslope = nan(height(Data),1);

% Trait stress = PRE Current_Stress, z-scored
Trait = Pre.Current_Stress;
muPre = mean(Trait, 'omitnan');
sdPre = std( Trait, 'omitnan');
Trait_z = (Trait - muPre) ./ sdPre;

Data.TraitStress_z = nan(height(Data),1);

participants = unique(Data.Participant);

for kk = 1:numel(participants)
    PID = participants(kk);

    idxP = (Data.Participant == PID);
    Dp   = Data(idxP, :);

    % Baseline = Relax 1 for this participant
    idxBase = (Dp.Phase == "Relax 1");
    if ~any(idxBase)
        warning('No Relax 1 phase for participant %d', PID);
        continue;
    end

    base_HR       = mean(Dp.meanHR_MyDev(idxBase),    'omitnan');
    base_SDNN     = mean(Dp.SDNN_MyDev(idxBase),      'omitnan');
    base_RMSSD    = mean(Dp.RMSSD_MyDev(idxBase),     'omitnan');
    base_pNN50    = mean(Dp.pNN50_MyDev(idxBase),     'omitnan');
    base_EDAmean  = mean(Dp.EDAmean_MyDev(idxBase),   'omitnan');
    base_EDAslope = mean(Dp.EDAslope_MyDev(idxBase),  'omitnan');

    % Deltas vs baseline
    Data.dHR(idxP)       = Dp.meanHR_MyDev   - base_HR;
    Data.dSDNN(idxP)     = Dp.SDNN_MyDev     - base_SDNN;
    Data.dRMSSD(idxP)    = Dp.RMSSD_MyDev    - base_RMSSD;
    Data.dpNN50(idxP)    = Dp.pNN50_MyDev    - base_pNN50;
    Data.dEDAmean(idxP)  = Dp.EDAmean_MyDev  - base_EDAmean;
    Data.dEDAslope(idxP) = Dp.EDAslope_MyDev - base_EDAslope;

    % Trait stress z-score (same for all phases of this participant)
    idxTrait = (Pre.Participant == PID);
    if any(idxTrait)
        Data.TraitStress_z(idxP) = Trait_z(idxTrait);
    else
        Data.TraitStress_z(idxP) = NaN;
    end
end


%% ========================================================================
%  5) Fit model: physiological deltas -> composite self-reported stress
% ========================================================================

% SIMPLER predictor set to avoid overfitting:
%   - dHR        (change in HR vs baseline)
%   - dRMSSD     (change in short-term HRV vs baseline)
%   - dEDAmean   (change in tonic EDA vs baseline)
%   - TraitStress_z (baseline stress tendency)
predictors = {'dHR','dRMSSD','dEDAmean','TraitStress_z'}; %

Xall      = Data{:, predictors};
validPred = all(~isnan(Xall), 2);

% Train only on phases that have composite stress labels
idxTrain = validPred & ~isnan(Data.StressSelf10);

Xtrain = Xall(idxTrain, :);
ytrain = Data.StressSelf10(idxTrain);

if size(Xtrain,1) < 5
    error('Too few labelled phases with valid predictors to train the model.');
end

% Linear regression model
mdl = fitlm(Xtrain, ytrain);

disp('Model coefficients (simplified model):');
disp(mdl.Coefficients);



%% ========================================================================
%  6) Predict stress for ALL phases and discretize to 10 levels
% ========================================================================

Data.StressPred_cont = nan(height(Data),1);
Data.StressLevel10   = nan(height(Data),1);

Xvalid = Xall(validPred, :);
yhat_valid = predict(mdl, Xvalid);

% Clip to [1,10] and round to integer 1..10
yhat_clip = max(1, min(10, yhat_valid));
level10   = round(yhat_clip);

Data.StressPred_cont(validPred) = yhat_valid;
Data.StressLevel10(validPred)   = level10;

% Simple evaluation against composite self-report (labelled phases only)
idxEval = ~isnan(Data.StressSelf10) & ~isnan(Data.StressPred_cont);
if any(idxEval)
    r_model   = corr(Data.StressSelf10(idxEval), Data.StressPred_cont(idxEval));
    MAE_model = mean(abs(Data.StressSelf10(idxEval) - Data.StressPred_cont(idxEval)));

    fprintf('\nModel performance (labelled phases only, composite labels):\n');
    fprintf('  r = %.3f\n', r_model);
    fprintf('  MAE = %.3f stress levels (1–10)\n', MAE_model);
end
%%
%% Per-participant performance (sensor-only model)

participants = unique(Data.Participant);
PerfByPID = table();

for i = 1:numel(participants)
    pid = participants(i);
    idxP = Data.Participant == pid & ~isnan(Data.StressSelf10) & ~isnan(Data.StressPred_cont);

    if sum(idxP) < 2
%        % Not enough labelled phases for this participant
        r_pid = NaN;
        MAE_pid = NaN;
    else
        y_true = Data.StressSelf10(idxP);
        y_pred = Data.StressPred_cont(idxP);

        r_pid   = corr(y_true, y_pred);
        MAE_pid = mean(abs(y_true - y_pred));
    end

    PerfByPID = [PerfByPID; table(pid, r_pid, MAE_pid, ...
        'VariableNames', {'Participant','r','MAE'})]; %#ok<AGROW>
end

disp('Per-participant performance:');
disp(PerfByPID)


%% ========================================================================
%  7) Save results (all participants + per-participant files)
% ========================================================================

% Full table
outAll = fullfile(basePath, 'StressLevels_AllParticipants.csv');
writetable(Data, outAll);
fprintf('\nSaved all stress levels to:\n  %s\n', outAll);

% Also save per-participant CSV with the most relevant variables
for PID = PIDs
    idxP = (Data.Participant == PID);
    if ~any(idxP), continue; end

    T = Data(idxP, {'Participant','Phase', ...
        'StressSelf10','StressPred_cont','StressLevel10', ...
        'meanHR_MyDev','SDNN_MyDev','RMSSD_MyDev','pNN50_MyDev', ...
        'EDAmean_MyDev','EDAslope_MyDev', ...
        'dHR','dSDNN','dRMSSD','dpNN50','dEDAmean','dEDAslope', ...
        'TraitStress_z'});

    pFolder = fullfile(basePath, sprintf('P%dMatlab', PID));
    if ~exist(pFolder,'dir'); mkdir(pFolder); end

    fname = fullfile(pFolder, sprintf('StressLevels_P%d.csv', PID));
    writetable(T, fname);
end

fprintf('Per-participant stress level files written into each P#Matlab folder.\n');

%%
%% ========================================================================
%  8) Group-level table + bar chart per phase (all participants)
% ========================================================================

% Use only rows with both values present
idxAll = ~isnan(Data.StressSelf10) & ~isnan(Data.StressPred_cont);

% Define the phases in the desired chronological order
phaseOrder = {'Relax 1','TSST Speech','Arithmetic','Stroop','Cold Press'};
nPh = numel(phaseOrder);

MeanSelf = nan(nPh,1);
MeanPred = nan(nPh,1);
MAEphase = nan(nPh,1);

for p = 1:nPh
    ph = phaseOrder{p};
    idxPh = idxAll & (Data.Phase == ph);

    if ~any(idxPh)
        continue;
    end

    y_true = Data.StressSelf10(idxPh);
    y_pred = Data.StressPred_cont(idxPh);

    MeanSelf(p) = mean(y_true, 'omitnan');
    MeanPred(p) = mean(y_pred, 'omitnan');
    MAEphase(p) = mean(abs(y_true - y_pred), 'omitnan');
end

% Build a table summarizing all participants per phase
PerfByPhase = table(phaseOrder', MeanSelf, MeanPred, MAEphase, ...
    'VariableNames', {'Phase','MeanSelf','MeanPred','MAE'});

disp('Group-level performance per phase (all participants):');
disp(PerfByPhase);

% (Optional) save the table
writetable(PerfByPhase, fullfile(basePath, 'Stress_PerfByPhase_AllParticipants.csv'));

figure('Color','w');

phCats = categorical(phaseOrder, phaseOrder);  % keep order
Y = [MeanSelf, MeanPred];                      % [Nphases x 2]

b = bar(phCats, Y);    % grouped bars

% Colors (you can swap these if you like)
colorSelf  = [234  77  73] / 255;   % #EA4D49
colorModel = [19  111  99] / 255;   % #136F63

b(1).FaceColor = colorSelf;
b(2).FaceColor = colorModel;

ylabel('Stress (1–10)');
    
legend({'Self-report','Sensor model'}, ...
       'Location','northoutside','Orientation','horizontal');
grid on; box off;

% ---- MAE per phase labels (using MAEphase) ----
maePhase = MAEphase;   % from the previous loop

x1 = b(1).XEndPoints;  % x positions of self-report bars
x2 = b(2).XEndPoints;  % x positions of model bars
y1 = b(1).YEndPoints;  % heights of self-report bars
y2 = b(2).YEndPoints;  % heights of model bars

for i = 1:numel(maePhase)
    x = (x1(i) + x2(i)) / 2;            % center between the two bars
    y = max(y1(i), y2(i)) + 0.05;       % a bit above the taller bar
    text(x, y, sprintf('MAE = %.2f', maePhase(i)), ...
        'HorizontalAlignment','center', ...
        'VerticalAlignment','bottom', ...
        'FontSize',8);
end

% Export figure
exportgraphics(gcf, fullfile(basePath, 'Stress_PerPhase_AllParticipants.png'), ...
               'Resolution', 300);

%% ========================================================================
%  9) Per-participant bar charts per phase (self vs model + MAE)
% ========================================================================

phaseOrder = {'Relax 1','TSST Speech','Arithmetic','Stroop','Cold Press'};

for pid = PIDs
    % Rows for this participant with both values present
    idxP = Data.Participant == pid & ...
           ~isnan(Data.StressSelf10) & ...
           ~isnan(Data.StressPred_cont);

    if ~any(idxP)
        continue;   % nothing to plot for this participant
    end

    Dp = Data(idxP,:);

    % ---- compute mean self, mean model and MAE per phase ----
    phasesUsed = {};
    MeanSelfP  = [];
    MeanPredP  = [];
    MAEphaseP  = [];

    for p = 1:numel(phaseOrder)
        ph = phaseOrder{p};
        idxPh = Dp.Phase == ph;

        if ~any(idxPh)
            continue;
        end

        y_true = Dp.StressSelf10(idxPh);
        y_pred = Dp.StressPred_cont(idxPh);

        phasesUsed{end+1,1} = ph; %#ok<AGROW>
        MeanSelfP(end+1,1)  = mean(y_true, 'omitnan');              %#ok<AGROW>
        MeanPredP(end+1,1)  = mean(y_pred, 'omitnan');              %#ok<AGROW>
        MAEphaseP(end+1,1)  = mean(abs(y_true - y_pred), 'omitnan'); %#ok<AGROW>
    end

    if isempty(MeanSelfP)
        continue;
    end

    % ---- bar chart for this participant ----
    phCats = categorical(phasesUsed, phaseOrder, 'Ordinal', true);
    Y = [MeanSelfP, MeanPredP];

    fig = figure('Color','w');
    b = bar(phCats, Y);    % grouped bars

    % Colors: self-report = #EA4D49, sensor model = #136F63
    colorSelf  = [234  77  73] / 255;   % #EA4D49
    colorModel = [19  111  99] / 255;   % #136F63

    b(1).FaceColor = colorSelf;
    b(2).FaceColor = colorModel;

    ylabel('Stress (1–10)');
    legend({'Self-report','Sensor model'}, ...
           'Location','northoutside','Orientation','horizontal');
    grid on; box off;

    % ---- MAE labels above each pair of bars ----
    x1 = b(1).XEndPoints;
    x2 = b(2).XEndPoints;
    y1 = b(1).YEndPoints;
    y2 = b(2).YEndPoints;

    for i = 1:numel(MAEphaseP)
        x = (x1(i) + x2(i)) / 2;
        y = max(y1(i), y2(i)) + 0.05;
        text(x, y, sprintf('MAE = %.2f', MAEphaseP(i)), ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','bottom', ...
            'FontSize',8);
    end

    % ---- export figure ----
    exportgraphics(fig, fullfile(basePath, ...
        sprintf('Stress_PerPhase_P%d.png', pid)), 'Resolution', 300);
end
