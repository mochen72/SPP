function computeMinMinBRS(obj, save_png)
% computeMinMinBRS(obj, save_png)

if nargin < 2
  save_png = true;
end

fprintf('Executing %s...\n', mfilename)

if exist(obj.minMinBRS_filename, 'file')
  fprintf('The minMinBRS file %s already exists. Skipping computation.\n', ...
    obj.minMinBRS_filename)
  return
end

%% Load CARS
if exist(obj.CARS_filename, 'file')
  fprintf('Loading CARS...\n')
  load(obj.CARS_filename)
else
  error('CARS file not found!')
end

%% Solver parameters and initial condition
schemeData.dynSys = CARS.dynSys;
schemeData.grid = createGrid([-65; -70; -pi], [75; 70; pi], ...
  [101; 101; 21], 3);
schemeData.uMode = 'min';
schemeData.dMode = 'min';

data0 = shapeCylinder(schemeData.grid, 3, [0;0;0], obj.Rc);

%% Compute set
extraArgs.visualize = true;
extraArgs.deleteLastPlot = true;

if save_png
  if ispc
    folder = sprintf('%s\\%s', obj.folder, mfilename);
    system(sprintf('mkdir %s', folder));
  else
    folder = sprintf('%s/%s', obj.folder, mfilename);
    system(sprintf('mkdir -p %s', folder));
  end
  
  extraArgs.fig_filename = sprintf('%s/', folder);
end

minMinBRS.data = HJIPDE_solve(data0, CARS.tau, schemeData, 'zero', extraArgs);
minMinBRS.g = schemeData.grid;
minMinBRS.tau = CARS.tau;
minMinBRS.dynSys = CARS.dynSys;

% Update SPPP and save
obj.minMinBRS_filename = sprintf('%s/minMinBRS.mat', obj.folder);
save(obj.minMinBRS_filename, 'minMinBRS', '-v7.3')

SPPP = obj;
save(sprintf('%s/SPPP.mat', obj.folder), 'SPPP', '-v7.3')
end