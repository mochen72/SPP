function simulateNIFaSTrack(obj, save_png, save_fig, NI_RS_filename, CPP_RTTRS_file, CPP_NIRS_file, separatedNIRS)
% simulateNI(obj, save_png, save_fig)
%     Simulates SPP with disturbances with the RTT method

if nargin < 2
  save_png = true;
end

if nargin < 3
  save_fig = false;
end

if nargin < 4
  NI_RS_filename = obj.NI_RS_filename;
end

if nargin < 5
  CPP_RTTRS_file = false;
end

if nargin < 6
  CPP_NIRS_file = false;
end

if nargin < 7
    separatedNIRS = false;
end

%% Load files
% Load robust tracking reachable set
if exist(obj.RTTRS_filename, 'file')
  fprintf('Loading RTTRS...\n')
  if (CPP_RTTRS_file == 1)
    RTTRS = loadRTTRS(obj.RTTRS_filename);
  else
    load(obj.RTTRS_filename);
  end
else
  error('RTTRS file not found!')
end

% Load path planning reachable set
fprintf('Loading RS data...\n')
if (CPP_NIRS_file == 1)    %%%%%%%%%%%%%%%%%all this block
    if separatedNIRS
        numVeh = length(obj.tTarget);
        for vehicle=1:numVeh
            Plane_filename = sprintf('%s%d.mat', obj.NI_RS_filename, vehicle-1);
            if ~exist(Plane_filename, 'file')
                % last file may not be completed file.
                fprintf('Simulate NI for %d vehicles which have computed traj...\n', vehicle-2)
                numVeh = vehicle-2;
                break;
            end
        end
        Q = cell(numVeh, 1);
        for vehicle=1:numVeh
            Plane_filename = sprintf('%s%d.mat', obj.NI_RS_filename, vehicle-1);
            if exist(Plane_filename, 'file')
                fprintf('Loading %dth vehicle...\n', vehicle-1)
                load(Plane_filename);
                Q{vehicle} = cpp2matSPPPlane(Qthis, obj.gN);
                clear Qthis;
                % remove large unused data.
                Q{vehicle}.BRS1 = [];
                if exist('obstacles', 'var')
                    clear obstacles;
                end
                if ~isempty(Q{vehicle}.BRS1)
                    [g2D, data2D] = proj(obj.g, Q{vehicle}.BRS1, [0 0 1], Qthis.x(3));
                    figure;
                    visSetIm(g2D, data2D);
                    close;
                end
            else
                break;
            end
        end %end for
    else
      Q = loadNIRS(obj.NI_RS_filename, obj.gN, false);
    end
else
   load(obj.NI_RS_filename);
   Q = initTracker(obj, RTTRS);
end


for veh = 1:length(obj.P)
    %Q{veh}.BRS1 = obj.P{veh}.BRS1;
    %Q{veh}.BRS1_tau = obj.P{veh}.BRS1_tau;
    Q{veh}.nomTraj = obj.P{veh}.nomTraj;
    Q{veh}.nomTraj_tau = obj.P{veh}.nomTraj_tau;
    %Q{veh}.obsForRTT = obj.P{veh}.obsForRTT;
    %Q{veh}.obsForRTT_tau = obj.P{veh}.obsForRTT_tau;
    %Q{veh}.obs2D = obj.P{veh}.obs2D;
    %Q{veh}.obs2D_tau = obj.P{veh}.obs2D_tau;
    %Q{veh}.target = obj.P{veh}.target;
    %Q{veh}.targetsm = obj.P{veh}.targetsm;
    %Q{veh}.targetCenter = obj.P{veh}.targetCenter;
    %{veh}.targetR = obj.P{veh}.targetR;
    %Q{veh}.targetRsmall = obj.P{veh}.targetRsmall;
end

if exist('obstacles', 'var')
  figure;
  for t=1:length(obstacles.data)
      obs = reshape(obstacles.data{t}, obj.gN);   
      surf(obs(:,:,1)) 
      drawnow
  end
end

%% Post process loaded data
% Compute gradients used for optimal control
fprintf('Computing gradients...\n')
RTTRS.Deriv = computeGradients(RTTRS.g, RTTRS.data);

% Determine time of simulation
tStart = inf;
tEnd = -inf;
for veh = 1:length(Q)
  Q{veh}.x = Q{veh}.xhist(:,1);   %%%%%%%%%%%%%%%%
  Q{veh}.xhist = Q{veh}.x;      %%%%%%%%%%%%%%%%%%
  Q{veh}.u = [];            
  Q{veh}.uhist = [];         
  tStart = min(tStart, min(Q{veh}.nomTraj_tau)); %find min/max times over all trajectories
  tEnd = max(tEnd, max(Q{veh}.nomTraj_tau));
end
tau = tStart:obj.dt:tEnd;

% Add cylindrical obstacles for visualization
if save_png || save_fig
  % For saving graphics
  if ispc
    system(sprintf('mkdir %s\\%s', obj.folder, mfilename));
  else
    system(sprintf('mkdir -p %s/%s', obj.folder, mfilename));
  end  
  
  % Initialize figure
  f = figure;
  
  % Map
  if strcmp(obj.setupName, 'room') == 0
     I = imread(obj.mapFile);
    if strcmp(obj.mapFile, 'map_streets.png')
        I = I(1:800, 701:1500, :);
        I = flip(I, 1);   %%%%%%%%%%%%%%%%%%%%%%
        imshow(I, 'InitialMagnification', 75, 'XData', [0 500], 'YData', [0 500]);
    elseif strcmp(obj.mapFile, 'bay_area_streets.png')
        I = I(155:915, 1120:1770, :);
        I = flip(I, 1);
        imshow(I, 'InitialMagnification', 100, 'XData', [-125 1500], 'YData', [0 1900]);
    end 
  end
  
  axis xy
  axis on
  grid on
  
  hold on
  
  colors = lines(length(Q));
  
  % Targets
  plotTargetSets(Q, colors);
  
  % Static obstacles
  if ~isempty(obj.staticObs)
    h = visSetIm(obj.g2D, obj.staticObs, 'k');
    h.LineWidth = 3;
  end
  hc = cell(length(Q), 1); % Capture radius
  ho = cell(length(Q), 1); % Obstacle
  hn = cell(length(Q), 1); % Nominal trajectory
  ht = cell(length(Q), 1); % Vehicle label
end

small = 1e-4;
tInds = cell(length(Q), 1);
taumin = inf(length(Q), 1);
taumax = -inf(length(Q), 1);

subSamples = 32;  

for i = 1:length(tau)
  fprintf('t = %f\n', tau(i))
  for veh = 1:length(Q)
    % Check if nominal trajectory has this t
    tInds{veh} = find(Q{veh}.nomTraj_tau > tau(i) - small & ...    %%%%%%%%%%%%%%%%%%
      Q{veh}.nomTraj_tau < tau(i) + small, 1);
    
    if ~isempty(tInds{veh})
      taumin(veh) = min(taumin(veh), tau(i));
      taumax(veh) = max(taumax(veh), tau(i));
      
      %% Get optimal control
      % Our plane is vehicle A, trying to stay out of reachable set, and the
      % reference virtual plane is vehicle B, trying to get into reachable set
      for s = 1:subSamples;
        % Obtain intermediate nominal trajectory points
        this_tInd = tInds{veh};         %%%%%%%%%%%%%%%%%%%%%
        prev_tInd = max(1, tInds{veh}-1);
%         nomTraj_pt = zeros(3,1);
        w = s/subSamples; % weight that goes from 0 to 1   
        nomTraj_pt = (1-w)*Q{veh}.nomTraj(:,prev_tInd) + ...
          w*Q{veh}.nomTraj(:,this_tInd);
        rel_x = nomTraj_pt - Q{veh}.x(1:2);   
        
%         rel_x = Q{veh}.nomTraj(:,tInds{veh}) - Q{veh}.x;
        rel_x(1:2) = rotate2D(rel_x(1:2), -Q{veh}.x(3));   
        rel_x(3:4) = [Q{veh}.x(3); Q{veh}.x(4)];

        deriv = eval_u(RTTRS.g, RTTRS.Deriv, rel_x);
        u = RTTRS.dynSys.optCtrl([], rel_x, deriv, 'max');

        %% Get disturbance
%       d = Q{veh}.uniformDstb();
%       d = [RTTRS.dynSys.dMaxA(1); 0; 0];
        d = RTTRS.dynSys.optDstb([], rel_x, deriv, 'min');
        
        %d = d(3:4);
        
        % Update state
        Q{veh}.updateState(u, obj.dt/subSamples, Q{veh}.x, d);
      end
      % Remove sub-samples
      Q{veh}.uhist(:, end-subSamples+1:end-1) = [];   
      Q{veh}.xhist(:, end-subSamples+1:end-1) = [];
    end
  end
  
  %% Visualize
  if save_png || save_fig
    [hc, ho, hn, ht] = plotVehicles(Q, tInds, obj.g2D, hc, ho, hn, ht, ...
      colors, obj.Rc);
    
    title(sprintf('t = %.0f', tau(i)))
    drawnow;
  end
  
  if save_png
    export_fig(sprintf('%s/%s/%d', obj.folder, mfilename, i), '-png', '-m2')
  end
  
  if save_fig
    savefig(f, sprintf('%s/%s/%d', obj.folder, mfilename, i), 'compact')
  end
end

%% Save data
obj.tau = tau;
for veh = 1:length(Q)
  Q{veh}.tau = taumin(veh):obj.dt:taumax(veh);
end

obj.Q = Q;

obj.NI_sim_filename = sprintf('%s/%s.mat', obj.folder, mfilename);
save(obj.NI_sim_filename, 'Q', '-v7.3')

SPPP = obj;
save(sprintf('%s/SPPP.mat', obj.folder), 'SPPP', '-v7.3')
end