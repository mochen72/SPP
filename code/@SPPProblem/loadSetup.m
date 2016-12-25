function loadSetup(obj, setup_name, extraArgs)

switch setup_name
  case 'SF'
    if nargin < 3
      error('Must specify extraArgs for ''SF'' setup!')
    end
    
    %% Vehicle
    obj.vRangeA = [0.1 2.5];
    obj.wMaxA = 2;
    
    %% RTT
    obj.vReserved = [1 -1.2];
    obj.wReserved = -0.8;
    
    %% Initial states
    if isfield(extraArgs, 'number_of_vehicles')
      numVeh = extraArgs.number_of_vehicles;
    else
      error('Must specify the property ''number_of_vehicles''!')
    end
    
    obj.initStates = cell(numVeh, 1);
    initState = [475; 200; 220*pi/180];
    for i = 1:numVeh
      obj.initStates{i} = initState;
    end
    
    %% Sampling and collision radius
    obj.dt = 0.5;
    obj.Rc = 1;
    
    %% Initial targets
    obj.targetR = 10;
    
    targetCentersSet = { ...
      [300; 400]; ...
      [50; 175]; ...
      [75; 25]; ...
      [450; 25] ...
      };
    
    obj.targetCenters = cell(numVeh,1);
    for i = 1:numVeh
      target_ind = randi(length(targetCentersSet));
      obj.targetCenters{i} = targetCentersSet{target_ind};
    end
    
    %% Grid
    if strcmp(extraArgs.dstb_or_intr, 'dstb') && extraArgs.wind_speed == 6
      obj.gN = [201 201 15];
    else
      obj.gN = [101 101 15];
    end
    
    obj.gMin = [0 0 0];
    obj.gMax = [500 500 2*pi];
    
    obj.g = createGrid(obj.gMin, obj.gMax, obj.gN, 3);
    obj.g2D = createGrid(obj.gMin(1:2), obj.gMax(1:2), obj.gN(1:2));
    
    %% Obstacles
    temp_g2D = createGrid([-35 -35], [35 35], [101 101]);
    
    % Financial District
    Obs1 = shapeRectangleByCorners(obj.g2D, [300; 250], [350; 300]);
    
    % Union Square
    Obs2 = shapeRectangleByCorners(temp_g2D, [-25; -30], [25; 30]);
    Obs2_rot = rotateData(temp_g2D, Obs2, 7.5*pi/180, [1 2], []);
    Obs2_gShift = shiftGrid(temp_g2D, [325 185]);
    Obs2 = migrateGrid(Obs2_gShift, Obs2_rot, obs.g2D);
    Obs2b = shapeHyperplaneByPoints(obj.g2D, [170 0; 400 230], ...
      [0 500]);
    Obs2 = shapeDifference(Obs2, Obs2b);
    
    % City Hall
    Obs3 = shapeRectangleByCorners(obj.g2D, [-25; -5], [25; 5]);
    Obs3 = rotateData(obj.g2D, Obs3, 7.5*pi/180, [1 2], []);
    Obs3 = shiftData(obj.g2D, Obs3, [170 65], [1 2]);
    
    % Boundary
    Obs4 = -shapeRectangleByCorners(obj.g2D, obj.g2D.min+5, obj.g2D.max-5);
    
    obj.staticObs = min(Obs1, Obs2);
    obj.staticObs = min(obj.staticObs, Obs3);
    obj.staticObs = min(obj.staticObs, Obs4);
    
    obj.mapFile = 'map_streets.png';
    
    %% Wind speed
    if isfield(extraArgs, 'wind_speed')
      switch extraArgs.wind_speed
        case 6
          obj.dMaxA = [0.6 0];
          obj.RTT_tR = 0.5;
        case 11
          obj.dMaxA = [1.1 0];
          obj.RTT_tR = 3.5;
        otherwise
          error('Only 6 m/s and 11 m/s winds have been properly implemented!')
      end
    else
      error('Must specify property ''wind_speed'' in m/s in extraArgs!')
    end
    
    %% Target separation time
    if isfield(extraArgs, 'separation_time')
      % Scheduled times of arrival
      obj.tTarget = zeros(numVeh, 1);
      for i = 1:numVeh
        obj.tTarget(i) = -extraArgs.separation_time*(i-1);
      end
      
      % Adjust global time horizon
      obj.tMin = -500 - numVeh*extraArgs.separation_time;
      obj.tau = obj.tMin:obj.dt:max(obj.tTarget);
    else
      error('Must specify property ''separation time'' in s in extraArgs!')
    end
    
    %% Augment static obstacles
    if isfield(extraArgs, 'dstb_or_intr')
      switch extraArgs.dstb_or_intr
        case 'dstb'
          augStaticObs = addCRadius(obj.g2D, obj.staticObs, obj.RTT_tR);
          obj.augStaticObs = repmat(augStaticObs, ...
            [1 1 obj.gN(3) length(obj.tau)]);
          
        case 'intr'
          warning(['Static obstacles will be augmented after computing ' ...
            'bufferRegion and FRSBRS'])
          
        otherwise
          error('The property ''dstb_or_intr'' must be ''dstb'' or ''intr''!')
      end
    else
      error('Must specify property ''dstb_or_intr'' in extraArgs!')
    end
    
  otherwise
    error('Unknown setup_name!')
end

end