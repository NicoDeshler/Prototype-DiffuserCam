function [r] = ZemaxSimPSFSegments()

% Initialize the OpticStudio connection
TheApplication = InitConnection();
if isempty(TheApplication)
    % failed to initialize a connection
    r = [];
else
    try
        r = BeginApplication(TheApplication);
        CleanupConnection(TheApplication);
    catch err
        CleanupConnection(TheApplication);
        rethrow(err);
    end
end
end

function app = InitConnection()

import System.Reflection.*;

% Find the installed version of OpticStudio.

% This method assumes the helper dll is in the .m file directory.
% p = mfilename('fullpath');
% [path] = fileparts(p);
% p = strcat(path, '\', 'ZOSAPI_NetHelper.dll' );
% NET.addAssembly(p);

% This uses a hard-coded path to OpticStudio
NET.addAssembly('\ZOSAPI_NetHelper.dll'); 
success = ZOSAPI_NetHelper.ZOSAPI_Initializer.Initialize();
% Note -- uncomment the following line to use a custom initialization path
% success = ZOSAPI_NetHelper.ZOSAPI_Initializer.Initialize('C:\Program Files\OpticStudio\');
if success == 1
    LogMessage(strcat('Found OpticStudio at: ', char(ZOSAPI_NetHelper.ZOSAPI_Initializer.GetZemaxDirectory())));
else
    app = [];
    return;
end

% Now load the ZOS-API assemblies
NET.addAssembly(AssemblyName('ZOSAPI_Interfaces'));
NET.addAssembly(AssemblyName('ZOSAPI'));

% Create the initial connection class
TheConnection = ZOSAPI.ZOSAPI_Connection();

% Attempt to create a Standalone connection

% NOTE - if this fails with a message like 'Unable to load one or more of
% the requested types', it is usually caused by try to connect to a 32-bit
% version of OpticStudio from a 64-bit version of MATLAB (or vice-versa).
% This is an issue with how MATLAB interfaces with .NET, and the only
% current workaround is to use 32- or 64-bit versions of both applications.
app = TheConnection.CreateNewApplication();
if isempty(app)
   HandleError('An unknown connection error occurred!');
end
if ~app.IsValidLicenseForAPI
    HandleError('License check failed!');
    app = [];
end
end


%% Boilerplate Code
% NOTE: The abreviation ILU stands for "In Lens Units" and refers to the
% units of measurement used in the .zmx lens file.
function r = BeginApplication(TheApplication)
import ZOSAPI.*;
r = [];

% OpticStudio session variables
TheSystem = TheApplication.PrimarySystem;
TheAnalyses = TheApplication.PrimarySystem.Analyses;
TheLDE = TheSystem.LDE;
SysData = TheSystem.SystemData.Fields;

% Load in .zmx lens file from provided filepath
lensFile = '';
loaded = TheSystem.LoadFile(lensFile, false);
if loaded == 0 
    HandleError('A problem occurred loading the lens file. Check the provided filepath')
end

% Surfaces
s1 = TheLDE.GetSurfaceAt(1);    % Point Source to Diffuser spacing
s6 = TheLDE.GetSurfaceAt(6);    % Aperture

% Fields
f1 = SysData.GetField(1);

% Zemax analysis
geom = TheAnalyses.New_Analysis_SettingsFirst(ZOSAPI.Analysis.AnalysisIDM.GeometricImageAnalysis);

d_dim = 2;  %diffuser dimension length (ILU)
s_dim = 1;  %sensor dimension length (ILU)
f = 1.45;   %diffuser focal length (i.e. caustic plane) (ILU)
t = 0.1;    %diffuser thickness (ILU)
z = 10;     %point source depth (ILU)
pix = 1000;

%% Getting True PSF with a Large Sensor
s1.Thickness = z;

% Run the Geometric Image Analysis
geom.ApplyAndWaitForCompletion();
geom_results = geom.GetResults();
geom_grid = geom_results.GetDataGrid(0);
geom_data = geom_grid.Values.double;

% Save the standard PSF
standard_PSF = geom_data;
imwrite(standard_PSF, fullfile('Demo','PSFs','standard_PSF.tif'))

%% Get PSF segments using a small sensor (laterally shifting point source)

% Reduce image plane aperture -- Effectively sets up a small sensor
Rect_Aper = s6.ApertureData.CreateApertureTypeSettings(ZOSAPI.Editors.LDE.SurfaceApertureTypes.RectangularAperture);
Rect_Aper.S_RectangularAperture_.XHalfWidth = s_dim/2;
Rect_Aper.S_RectangularAperture_.YHalfWidth = s_dim/2;
s6.ApertureData.ChangeApertureTypeSettings(Rect_Aper);

% Set constants for calculating source translation positions.
% Point source positions based on simple geometric derivation.
p = (z + t) / (z + t + f) * s_dim;  % portion of diffuser captured in sensor
n = ceil(d_dim / p);                % number of segments along diffuser

p_lat = linspace((-p * (n - 1)) / 2, (p * (n - 1)) / 2, (n*2)); %lateral position of captured diffuser portion
source_lat = p_lat * (z + t + f) / (t + f);                     %lateral position of point source

sensor_pix = round(pix*s_dim/d_dim);
n = 1;
for j = 1:size(source_lat,2)
    for i = 1:size(source_lat,2)
        x = source_lat(i);
        y = source_lat(j);
        
        % Set source's lateral position
        f1.X = x;
        f1.Y = y;

        % Run the Geometric Image Analysis
        geom.ApplyAndWaitForCompletion();
        geom_results = geom.GetResults();
        geom_grid = geom_results.GetDataGrid(0);
        geom_data = geom_grid.Values.double;    
                
        % Isolate PSF segment from small sensor reading
        xymin = round((pix-sensor_pix)/2);
        whdim = sensor_pix-1;
        sensorCrop = imcrop(geom_data, [xymin, xymin, whdim, whdim]);
        
        imwrite(sensorCrop, fullfile('Demo','PSFSegments - 2x2cm Diffuser', sprintf('img%d.tif',n)))
        n = n+1;
    end
end

end

function LogMessage(msg)
disp(msg);
end

function HandleError(error)
ME = MXException(error);
throw(ME);
end

function  CleanupConnection(TheApplication)
% Note - this will close down the connection.
% If you want to keep the application open, you should skip this step
% and store the instance somewhere instead.
TheApplication.CloseApplication();
end




