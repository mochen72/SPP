function computeRTTRS2D(obj, v, tR, save_png)
% computeRTTRS(obj, vR, wR, trackingRadius, save_png)
%     Computes the robust trajectory tracking reachable set and updates the SPPP
%     object with the RTTRS file name
%
% Inputs:
%     SPPP - SPP problem object
%     vR - reserved vehicle speed
%     wR - reserved angular acceleration
%     tR - tracking radius
%     save_png - set to true to save figures
%
% Output:
%     SPPP - SPP problem object updated with RTTRS file name

if nargin < 2
  v = 1.25;
end

if nargin < 3
  tR = 4;
end

if nargin < 4
  save_png = true;
end

if exist(obj.RTTRS_filename, 'file')
  fprintf('The RTTRS file %s already exists. Skipping RTTRS computation.\n', ...
    obj.RTTRS_filename)
  return
end

% Grid
grid_min = [-1.25*tR; -1.25*tR; -pi]; % Lower corner of computation domain
grid_max = [1.25*tR; 1.25*tR; pi];    % Upper corner of computation domain

% Number of grid points per dimension
N = [101; 101; 101];
schemeData.grid = createGrid(grid_min, grid_max, N, 3);

% Track trajectory for up to this time
tMax = 10;
dt = 0.1;
tau = 0:dt:tMax;

% 2D virtual vehicle
dynSys = PlanePursue2DKV([0;0;0], obj.wMaxA, obj.vRangeA, obj.dMaxA, v);
schemeData.dynSys = dynSys;

% Initial conditions
RTTRS.trackingRadius = tR;
data0 = -shapeCylinder(schemeData.grid, 3, [ 0; 0; 0 ], RTTRS.trackingRadius);
schemeData.uMode = 'max';
schemeData.dMode = 'min';
extraArgs.visualize = true;
extraArgs.deleteLastPlot = true;
extraArgs.stopInit = [0;0;0];

if save_png
  folder = sprintf('%s_%f', mfilename, now);
  system(sprintf('mkdir %s', folder));
  extraArgs.fig_filename = sprintf('%s/', folder);
end

% Compute
data = HJIPDE_solve(data0, tau, schemeData, 'zero', extraArgs);

RTTRS.g = schemeData.grid;
RTTRS.data = data(:,:,:,end);
RTTRS.dynSys = dynSys;

% Save results
obj.RTTRS_filename = sprintf('RTTRS_%f.mat', now);
save(obj.RTTRS_filename, 'RTTRS', '-v7.3')

SPPP = obj;
save(obj.this_filename, 'SPPP', '-v7.3')
end