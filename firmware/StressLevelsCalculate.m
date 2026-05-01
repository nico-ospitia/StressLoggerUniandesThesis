%% CALCULATE STRESS LEVELS (10 levels) FROM MY DEVICE + SURVEYS

clear; clc;

% ------------------------------------------------------------------------
%  Paths and participant IDs
% -------------------------------------------------------------------------
basePath   = 'C:\Users\Lenovo\Desktop\Tesis\Data\results';  % where P#Matlab folders are
prePath    = fullfile(basePath, 'PreDataSurvey.csv');
postPath   = fullfile(basePath, 'PostDataSurvey.csv');

PIDs       = 1:8;   % adjust if you end up with fewer participants


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

% Sanity: ensure types
Pre.Participant  = double(Pre.Participant);
Post.Participant = double(Post.Participant);


%% ========================================================================
%  3) Build a long table of (Participant, Phase, StressSelf10)
% ========================================================================

% Phases we have stress labels for:
%  Relax 1   -> Pre:  Current_Stress
%  TSST Speech -> Post: TSST_Stress
%  Arithmetic -> Post: Arithmetic_Stress
%  Stroop     -> Post: SCWT_Stress
%  Cold Press -> Post: CPT_Stress

phLabelled = {'Relax 1','TSST Speech','Arithmetic','Stroop','Cold Press'};
nLabelled  = numel(phLabelled);

StressLabels = table();

for PID = PIDs
    % Find this participant in Pre and Post tables
    idxPre  = (Pre.Participant  == PID);
    idxPost = (Post.Participant == PID);

    if ~any(idxPre) || ~any(idxPost)
        warning('Participant %d not found in Pre or Post survey tables.', PID);
        % If missing, we just leave StressSelf10 = NaN for that PID
        stressVals = nan(1, nLabelled);
    else
        preRow  = Pre(idxPre, :);
        postRow = Post(idxPost, :);

        stressVals = [ ...
            preRow.Current_Stress, ...
            postRow.TSST_Stress, ...
            postRow.Arithmetic_Stress, ...
            postRow.SCWT_Stress, ...
            postRow.CPT_Stress ];
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

% Make sure Phase is string (avoid char vs string issues)
Data.Phase = string(Data.Phase);

% Allocate delta-features
Data.dHR       = nan(height(Data),1);
Data.dSDNN     = nan(height(Data),1);
Data.dRMSSD    = nan(height(Data),1);
Data.dpNN50    = nan(height(Data),1);
Data.dEDAmean  = nan(height(Data),1);
Data.dEDAslope = nan(height(Data),1);

% Trait stress = baseline "Current_Stress" from Pre, z-scored
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
    Data.dHR(idxP)       = Dp.meanHR_MyDev    - base_HR;
    Data.dSDNN(idxP)     = Dp.SDNN_MyDev      - base_SDNN;
    Data.dRMSSD(idxP)    = Dp.RMSSD_MyDev     - base_RMSSD;
    Data.dpNN50(idxP)    = Dp.pNN50_MyDev     - base_pNN50;
    Data.dEDAmean(idxP)  = Dp.EDAmean_MyDev   - base_EDAmean;
    Data.dEDAslope(idxP) = Dp.EDAslope_MyDev  - base_EDAslope;

    % Trait stress z-score (same for all phases of this participant)
    idxTrait = (Pre.Participant == PID);
    if any(idxTrait)
        Data.TraitStress_z(idxP) = Trait_z(idxTrait);
    else
        Data.TraitStress_z(idxP) = NaN;
    end
end


%% ========================================================================
%  5) Fit model: physiological deltas -> self-reported stress (1–10)
% ========================================================================

% Predictors to use (you can drop some if needed)
predictors = {'dHR','dSDNN','dRMSSD','dpNN50','dEDAmean','dEDAslope','TraitStress_z'};

Xall      = Data{:, predictors};
validPred = all(~isnan(Xall), 2);

% Train only on phases that have self-reported stress
idxTrain = validPred & ~isnan(Data.StressSelf10);

Xtrain = Xall(idxTrain, :);
ytrain = Data.StressSelf10(idxTrain);

if size(Xtrain,1) < 5
    error('Too few labelled phases with valid predictors to train the model.');
end

% Linear regression model
mdl = fitlm(Xtrain, ytrain);

disp('Model coefficients:');
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

% Simple evaluation against self-report (only labelled phases)
idxEval = ~isnan(Data.StressSelf10) & ~isnan(Data.StressPred_cont);
if any(idxEval)
    r_model   = corr(Data.StressSelf10(idxEval), Data.StressPred_cont(idxEval));
    MAE_model = mean(abs(Data.StressSelf10(idxEval) - Data.StressPred_cont(idxEval)));

    fprintf('\nModel performance (labelled phases only):\n');
    fprintf('  r = %.3f\n', r_model);
    fprintf('  MAE = %.3f stress levels (1–10)\n', MAE_model);
end


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
