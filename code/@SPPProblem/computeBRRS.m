function computeBRRS(obj, restart)
% compute_BR_RS(obj, restart)
%     Computes the before-replanning reachable sets for the SPP problem
%
% Inputs:
%     obj - SPPP object
%     restart - set to true to restart and overwrite computation

if nargin < 2
  restart = false;
end

if ~restart && exist(obj.BR_RS_filename_small, 'file')
  fprintf('The BR RS file %s already exists. Skipping BR RS computation.\n', ...
    obj.BR_RS_filename_small)
  return
end

%% Load files
if exist(obj.RTTRS_filename, 'file')
  fprintf('Loading RTTRS...\n')
  load(obj.RTTRS_filename)
else
  error('RTTRS file not found!')
end

if exist(obj.CARS_filename, 'file')
  fprintf('Loading CARS...\n')
  load(obj.CARS_filename)
else
  error('CARS file not found!')
end

if exist(obj.rawAugObs_filename, 'file')
  fprintf('Loading ''raw'' obstacles...\n')
  load(obj.rawAugObs_filename)
else
  error('rawObs file not found!')
end

if restart || ~exist(obj.BR_RS_filename, 'file')
  fprintf('Initializing vehicles and restarting BR RS computation...\n')
  Q = initRTT(obj, RTTRS);
  
  % File name to save RS data
  obj.BR_RS_filename = sprintf('%s_%f.mat', mfilename, now);  
else
  fprintf('Loading BR RS checkpoint...\n')
  load(obj.BR_RS_filename)
  Q = {Q1; Q2; Q3; Q4};
end

%% Time
BRS1_tau = obj.tMin:obj.dt:obj.tTarget;

%% Start the computation of reachable sets
for veh=1:length(Q)
  %% Compute the BRS (BRS1) of the vehicle with the above obstacles
  if isempty(Q{veh}.BRS1)
    fprintf('Gathering obstacles for vehicle %d...\n', veh)
    obstacles = gatherObstacles(Q(1:veh-1), obj.g, BRS1_tau, 'obsForIntr');
    
    fprintf('Computing BRS1 for vehicle %d\n', veh)
    Q{veh}.computeBRS1(BRS1_tau, obj.g, obstacles);
    
    [Q1, Q2, Q3, Q4] = Q{:};
    save(obj.BR_RS_filename, 'Q1', 'Q2', 'Q3', 'Q4', '-v7.3')
  end
  
  %% Compute the nominal trajectories based on BRS1
  if isempty(Q{veh}.nomTraj)
    fprintf('Computing nominal trajectory for vehicle %d\n', veh)
    Q{veh}.computeNomTraj(obj.g);
  end
  
  %% Compute t-IAT backward reachable set from flattened 3D obstacle
  if isempty(Q{veh}.obsForIntr)
    fprintf('Augmenting obstacles for vehicle %d\n', veh)
    Q{veh}.computeObsForIntr(obj.g, CARS, rawAugObs);
  end
end

%% Trim vehicles for a smaller file
for veh = 1:length(Q)
  Q{veh}.trimData({'BRS1', 'obsForIntr'});
end
[Q1, Q2, Q3, Q4] = Q{:};
obj.BR_RS_filename_small = sprintf('%s_sim_%f.mat', mfilename, now);
save(obj.BR_RS_filename_small, 'Q1', 'Q2', 'Q3', 'Q4', '-v7.3')

SPPP = obj;
save(obj.this_filename, 'SPPP', '-v7.3')
end