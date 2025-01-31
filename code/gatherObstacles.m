function obstacles = gatherObstacles(vehicles, g, tau, obs_type, tMode)
% obstacles = gatherObstacles(vehicles, schemeData, tau, obs_type)
%     Gathers obstacles by combining obstacles in the field obs_type of each
%     vehicle in the vehicles list

% If there are no vehicles in the input, and there is no static obstacles...
if isempty(vehicles)
  obstacles = inf(g.N');
  return
end

% Assume obstacles are for BRS computation by default
if nargin < 5
  tMode = 'backward';
end

% Gather the obstacle set
obsSet = cell(length(vehicles), 1);
obsSet_tau = cell(length(vehicles), 1);

for i = 1:length(obsSet)
  obsSet{i} = vehicles{i}.(obs_type);
  obsSet_tau{i} = vehicles{i}.(sprintf('%s_tau', obs_type));
end

obstacles = gO_helper(g, obsSet, obsSet_tau, tau, tMode);

end

function obstacles = gO_helper(g, obsSet, obsSet_tau, common_tau, tMode)

% Initialize empty obstacle
obstacles = inf([g.N', length(common_tau)]);

small = 1e-4;
% Go through each vehicle in the input
for i = 1:length(obsSet)
  % Determine time bound
  min_tau = max( min(obsSet_tau{i}), min(common_tau) ) - small;
  max_tau = min( max(obsSet_tau{i}), max(common_tau) ) + small;
  
  % Determine indices within the time bound
  tau_inds = common_tau > min_tau & common_tau < max_tau;
  obs_inds = obsSet_tau{i} > min_tau & obsSet_tau{i} < max_tau;

  % Take union with previous obstacles for obstacles within the time bound
  obstacles(:,:,:,tau_inds) = ...
    min(obstacles(:,:,:,tau_inds), obsSet{i}(:,:,:,obs_inds));
end

% Flip the obstacles so that it goes backwards in time; this is needed since the
% BRS computation goes backwards in time
if strcmp(tMode, 'backward')
  obstacles = flip(obstacles, 4);
end
end