function computeRawAugObs(obj, RTTRS)
% computeRawAugObs(obj)
%     Augments the raw obstacles (for translation on nominal trajectory)

if exist(obj.rawAugObs_filename, 'file')
  fprintf(['The rawObs file %s already exists. Skipping rawObs' ...
  'computation.\n'], obj.rawAugObs_filename)
  return
end

%% Load and migrate RTTRS
fprintf('Loading RTTRS...\n')
load(obj.RTTRS_filename)

g = createGrid([-0.4; -0.5; -3*pi/2], [0.6; 0.5; pi/2], [51; 51; 51], 3);
schemeData.grid = g;

RTTRSdata = migrateGrid(RTTRS.g, -RTTRS.data, schemeData.grid);

%% Load CARS
fprintf('Loading CARS...\n')
load(obj.CARS_filename)

% Initialize dynamical system based on RTTRS parameters
schemeData.dynSys = Plane([0; 0; 0], ...
  RTTRS.dynSys.wMaxA, RTTRS.dynSys.vRangeA, RTTRS.dynSys.dMaxA);

% Compute the sets
fprintf('Computing FRS of raw obstacle...\n')
rawObsFRS = computeRawObs_FRS(RTTRSdata, schemeData, CARS.tau);

fprintf('Computing cylObs3D of raw obstacle FRS...\n')
tR = RTTRS.trackingRadius;
[obs3D, g2D, obs2D] = computeRawObs_cylObs(rawObsFRS, g, CARS.Rc, tR);
rawAugObs.g2D = g2D;
rawAugObs.data2D = obs2D;

fprintf('Computing BRS of cylObs3D...\n')
rawAugObs.data = computeRawObs_BRS(obs3D(:,:,:,end), schemeData, CARS.tau);
rawAugObs.g = g;

obj.rawAugObs_filename = sprintf('rawObs_%f.mat', now);
save(obj.rawAugObs_filename, 'rawAugObs', '-v7.3')

end

function rawObsFRS = computeRawObs_FRS(RTTRSdata, schemeData, tauIAT)
% Computes FRS of RTTRS
schemeData.uMode = 'max';
schemeData.dMode = 'max';
schemeData.tMode = 'forward';

extraArgs.visualize = true;
extraArgs.deleteLastPlot = true;

rawObsFRS = HJIPDE_solve(RTTRSdata, tauIAT, schemeData, 'none', extraArgs);

end

function [obs3D, g2D, obs2D] = computeRawObs_cylObs(augObsFRS, g, Rc, tR)
% Makes 3D cylindrical obstacles from FRS of RTTRS
obs3D = zeros(size(augObsFRS));
[g2D, obs2D] = proj(g, augObsFRS, [0 0 1]);

for i = 1:size(augObsFRS,4)
  obs2D(:,:,i) = addCRadius(g2D, obs2D(:,:,i), Rc+tR);
  obs3D(:,:,:,i) = repmat(obs2D(:,:,i), [1 1 g.N(3)]);
end
end

function cylObsBRS = computeRawObs_BRS(cylObs3D_last, schemeData, tauIAT)
% Computes BRS or cylindrical obstacles
schemeData.uMode = 'min';
schemeData.dMode = 'min';
schemeData.tMode = 'backward';

extraArgs.visualize = true;
extraArgs.deleteLastPlot = true;

cylObsBRS = HJIPDE_solve(cylObs3D_last, tauIAT, schemeData, 'zero', extraArgs);
end

