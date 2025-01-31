function FaSTrack()
% FaSTrack

%% Setup
gMin = [0 0];
gMax = [50 50];
gN = [20 20];

g = createGrid(gMin, gMax, gN);
%temp_g = createGrid([-20 -20], [20 20], [15 15]);  
%obs = shapeRectangleByCorners(g, [30; 25], [35; 30]);
obs = shapeRectangleByCorners(g, [30; 20], [40; 30]);

vxmax = 1;
vymax = 1;
P = Plane2D([47; 20], vxmax, vymax);
wmax = 2*pi;
aRange = [-1.5, 1.5];
dMax = [0.8, 0.8]; %%%%% making 2 disturbances
dims = 1:4;
Q = Plane4D([47; 20; 0; 0], wmax, aRange, dMax, dims);

target = [20; 45];
targetLength = 6.5;
vehicleSize = 0.8;

%% Computing Tracking Error Bound (TEB)
TEBgN = [65; 65; 25; 25];
TEBgMin = [-3; -3; -pi; -2];
TEBgMax = [ 3;  3;  pi; 2];
sD.grid = createGrid(TEBgMin, TEBgMax, TEBgN, 3);
data0 = sD.grid.xs{1}.^2 + sD.grid.xs{2}.^2;
%extraArgs.obstacles = -data0; 

% Visualization
[TEBg2D, data02D] = proj(sD.grid,data0,[0 0 1 1],[0 0]);
figure(1)
clf
subplot(1,2,1)
surf(TEBg2D.xs{1}, TEBg2D.xs{2}, sqrt(data02D))
hold on

sD.dynSys = P4D_Q2D_Rel([0; 0; 0; 0], -wmax, wmax, vxmax, vymax, ...
   -dMax, dMax, aRange(1), aRange(2), [1 2 3 4]);
%sD.dynSys = P4D_Q2D_Rel([0; 0; 0; 0], -2, 2, vxmax, vymax, ...
%    -dMax, dMax, aRange(1), aRange(2), [1 2 3 4]);
sD.uMode = 'min';
sD.dMode = 'max';
sD.accuracy = 'medium';

f = figure(2);
%set(f, 'Position', [400 400 450 400]); %%%%% removing this for debugging
extraArgs.visualize = true;
extraArgs.RS_level = 2; 
extraArgs.fig_num = 2;
extraArgs.plotData.plotDims = [1 1 0 0];
extraArgs.plotData.projpt = [0 0];
extraArgs.deleteLastPlot = false;

dt = 0.1;
tMax = 1;
tau = 0:dt:tMax;
extraArgs.stopConverge = true;
extraArgs.convergeThreshold = dt;
extraArgs.keepLast = true;

% solve backwards reachable set
% instead of none, do max_data0 - no obstacles or max over time
[data, tau] = HJIPDE_solve(data0, tau, sD, 'maxWithTarget', extraArgs); 

% largest cost along all time (along the entire 5th dimension which is
% time)
data = max(data,[],5); 

figure(1)
subplot(1,2,2)
[TEBg2D, data2D] = proj(sD.grid, data, [0 0 1 1], [0 0]);
s = surf(TEBg2D.xs{1}, TEBg2D.xs{2}, sqrt(data2D));
  
%Level set for tracking error bound
lev = min(min(s.ZData));


% More visualization
f = figure(3);
clf
%set(f, 'Position', [360 278 560 420]); %%%%% removing for debugging
alpha = .2;
small = .05;
 
levels = [lev, lev + .2, lev + .4];
%levels = [.5, .75, 1];  
%levels = [2.6, 3, 3.3];
  
[g3D, data3D] = proj(sD.grid,data,[0 0 0 1], .5);
[~, data03D] = proj(sD.grid,data0,[0 0 0 1], .5);
%plotlevel = min(data3D(:));  


for i = 1:3
    subplot(2,3,i)
    h0 = visSetIm(g3D, sqrt(data03D), 'blue', levels(i)+small);
    h0.FaceAlpha = alpha;
    hold on
    h = visSetIm(g3D, sqrt(data3D), 'red', levels(i));
    axis([-levels(3)-3*small levels(3)+3*small ...
      -levels(3)-3*small levels(3)+3*small -pi pi])
  if i == 2
    title(['t = ' num2str(tau(end)) ' s'])
  end
    axis square
end
  
for i = 4:6
    subplot(2,3,i)
    h0 = visSetIm(TEBg2D, sqrt(data02D), 'blue', levels(i-3)+small);
    hold on
    h = visSetIm(TEBg2D, sqrt(data2D), 'red', levels(i-3));
    axis([-levels(3)-small levels(3)+small ...
      -levels(3)-small levels(3)+small])
    title(['R = ' num2str(levels(i-3))])
    axis square
          
set(gcf,'Color','white')
end


teb = sqrt(min(data(:))) + 0.03;
lev = lev + 0.03;
trackingRadius = lev;

figure(4)
clf
h0 = visSetIm(TEBg2D, sqrt(data02D), 'blue', lev+small);
hold on
h = visSetIm(TEBg2D, sqrt(data2D), 'red', lev);
title(['Tracking Error Bound R = ' num2str(lev)])
axis square

%% Planning
% Augment obstacles
augObs = addCRadius(g, obs, trackingRadius + vehicleSize);
obs_bdry = -shapeRectangleByCorners(g, gMin + [0.1, 0.1], ...
       gMax - [0.1, 0.1]); 
augObs = min(augObs, obs_bdry);
targetLsmall = targetLength - trackingRadius - vehicleSize;
targetsm = shapeRectangleByCorners(g, target - [targetLsmall; targetLsmall], ...
    target + [targetLsmall; targetLsmall]);

% Solve for BRS
schemeData.grid = g;
schemeData.uMode = 'min';
schemeData.dynSys = P;
extraArgs = [];
extraArgs.visualize = true;
extraArgs.deleteLastPlot = true;
extraArgs.plotData.plotDims = [1, 1];
extraArgs.plotData.projpt = [];
extraArgs.targets = targetsm;
extraArgs.obstacles = augObs;
extraArgs.stopInit = [47; 20];
BRS_tau = -55:0;
[BRS, tau] = HJIPDE_solve(targetsm, BRS_tau, schemeData, 'none', ...
  extraArgs);
BRS_tau = BRS_tau(end-length(tau)+1:end);

% Compute nominal trajectory
tauLength = length(BRS_tau);
iter = 1;
subSamples = 32;
dtSmall = (BRS_tau(2) - BRS_tau(1))/subSamples;
traj = nan(g.dim, tauLength);
traj(:,1) = P.x;
clns = repmat({':'}, 1, g.dim);
uMode = 'min';
projDim = [1 1];
showDims = find(projDim);
hideDims = ~projDim;
while iter <= tauLength
    BRS_at_t = BRS(clns{:}, tauLength-iter + 1);
    
    plot(traj(1, iter), traj(2, iter), 'ko')
    hold on

    %    [g2D, data2D] = proj(g, BRS_at_t, hideDims, traj(hideDims, iter));
    %visSetIm(g2D, data2D);
    visSetIm(g,BRS_at_t);
    tStr = sprintf('t = %.3f\', BRS_tau(iter));
    title(tStr)
    drawnow
    hold off
    
    Deriv = computeGradients(g, BRS_at_t);
    for j = 1:subSamples
        deriv = eval_u(g, Deriv, P.x);
        u = P.optCtrl(BRS_tau(iter), P.x, deriv, uMode);
        P.updateState(u, dtSmall, P.x);
    end
    
    iter = iter + 1;
    traj(:,iter) = P.x;
end

%extraArgs = [];
%extraArgs.uMode = 'min';
%extraArgs.visualize = true;
%extraArgs.projDim = [1 1];
%extraArgs.subSamples = 32;
%[nomTraj, nomTraj_tau] = ...
%  computeOptTraj(g, BRS, BRS_tau, P, extraArgs);

%% Simulation
Deriv = computeGradients(sD.grid, data0);
tStart = inf;
tEnd = -inf;
Q.x = Q.xhist(:,1);  
Q.xhist = Q.x;     
Q.u = [];            
Q.uhist = [];    
nomTraj_tau = BRS_tau(1:iter-1);
%tStart = min(tStart, min(nomTraj_tau)); 
%tEnd = max(tEnd, max(nomTraj_tau));
%tau = tStart:dtSmall:tEnd;

f = figure;
visSetIm(g, augObs, 'r');
hold on;
visSetIm(g, obs, 'k');
hold on;
rectangle('Position', [target(1)-targetLsmall target(2)-targetLsmall ...
    2*targetLsmall 2*targetLsmall]); 

for i = 1:length(nomTraj_tau)
    for s = 1:subSamples
        w = s/subSamples;
        prev_tInd = max(1, i-1);
        nomTraj_pt = (1-w)*traj(:,prev_tInd) + ...
          w*traj(:,i);
        rel_x = nomTraj_pt - Q.x(1:2); 
        rel_x(1:2) = rotate2D(rel_x(1:2), -Q.x(3));   
        rel_x(3:4) = [Q.x(3); Q.x(4)];

        deriv = eval_u(sD.grid, Deriv, rel_x);
        u = sD.dynSys.optCtrl([], rel_x, deriv, 'max');
        d = sD.dynSys.optDstb([], rel_x, deriv, 'min');
        d = [d(1) d(3)];
        Q.updateState(u, dtSmall/subSamples, Q.x, d);
    end
    Q.uhist(:, end-subSamples+1:end-1) = [];   
    Q.xhist(:, end-subSamples+1:end-1) = [];
    
    plot(Q.x(1), Q.x(2), 'b*');
    plot(traj(1, i), traj(2, i), 'ko');
    title(sprintf('t = %.0f', i));
    drawnow;
end






end