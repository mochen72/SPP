function FBC = RS2Ctrl(BRS)
% FBC = RS2Ctrl(BRS)
% Computes the feedback control law from the backwards reachable set BRS
%
% Input:  BRS - backwards reachable set
%               .g    - grid structure
%               .data - time-dependent value function
%               .tau  - time stamps
%               .uMax - maximum turn rate
%
% Output: FBC - feedback control matrix
%               .U - feedback control at every state and time
%               .D - feedback disturbance at every state and time
%
% Mo Chen, 2016-02-02

%% Initialize
U = zeros(size(BRS.data));
D = cell(BRS.g.dim,1);
for j = 1:BRS.g.dim
  D{j} = zeros(size(BRS.data));
end

%% Loop over time to compute all feedback controls and disturbances
for i = 1:length(BRS.tau)
  switch BRS.g.dim
    case 3
      %% Get gradients
      P = extractCostates(BRS.g, BRS.data(:,:,:,i));
      U(:,:,:,i) = (P{3} >= 0) * (-BRS.uMax) + (P{3} < 0) * BRS.uMax;
      
      for j = 1:BRS.g.dim
        D{j}(:,:,:,i) = (P{j} >= 0) * BRS.dMax(j) + (P{j} < 0) * (-BRS.dMax(j));
      end
      
    otherwise
      error('This function has only been implemented for 3D systems!')
  end
end

%% Pack "Feedback Control"
FBC.U = U;
FBC.D = D;
FBC.g = BRS.g;
FBC.tau = BRS.tau;
FBC.v = BRS.v;
FBC.uMax = BRS.uMax;
FBC.dMax = BRS.dMax;

end