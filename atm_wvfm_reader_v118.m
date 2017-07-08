function [atm_wvfm] = atm_wvfm_reader_v118(f_name_inp,varargin)
% ------------------------------------------------------------------------------------------------------------------------------------------------------------------
% SUMMARY:          The ATM_WVFM_READER function reads ATM waveform and QFIT data from an ATM HDF5 waveform file and imports the data into a 
%                   structured array (struct) in MATLAB. The function can be used to import entire files or extract only waveforms and qfit elevations that match 
%                   spatial and temporal search criteria, i.e., it can be used for subsetting.
%
% SYNTAX:           atm_wvfm = atm_wvfm_reader(f_name_inp);                                              % silent conversion of entire file   
%                   atm_wvfm = atm_wvfm_reader(f_name_inp, verbose);                                     % conversion of entire file with optional console output
%                   atm_wvfm = atm_wvfm_reader(f_name_inp, verbose, poly_lon, poly_lat);                 % spatial subsetting with optional console output
%                   atm_wvfm = atm_wvfm_reader(f_name_inp, verbose, t_start, t_end);                     % temporal subsetting with optional console output
%                   atm_wvfm = atm_wvfm_reader(f_name_inp, verbose, poly_lon, poly_lat, t_start, t_end); % spatial and temporal subsetting. optional console output
%
% EXAMPLE:          Example of a valid function call with combined spatial and temporal search parameters and command window/console output:
%                   atm_wvfm = atm_wvfm_reader('ILATM1B_20170510_132857.atm6AT6.h5',1,[310.21 310.27 310.23],[69.97 69.98 69.47],...
%                        '2017-05-10 13:28:00','2017-05-10 13:29:00');
%
%                   The accompanying ATM_WVFM_INFO function can create both spatial polygons and temporal search parameters that can be directly 
%                   used as input for ATM_WVFM_READER and will import all laser shots and waveform range gates of a specified file into MATLAB.
% ------------------------------------------------------------------------------------------------------------------------------------------------------------------
% INPUT PARAMETERS
% 
%   f_name_inp      File name of HDF5 ATM waveform file to be read including pathname.
% 
%   poly_lon        Longitude vertices of a polygon defining the area of interest for a spatial search.
%                   The polygon must contain at least 3 vertices and is automatically closed.
%                   Longitudes must be in decimal degrees east and between 0� and 360� longitude. 
%                   Crossing the prime meridian from 0� to 360� longitude has not been tested and can produce unexpected results. 
%   poly_lat        Latitude vertices of a polygon defining the area of interest for a spatial search.
%                   The polygon must contain at least 3 vertices and is automatically closed.
%                   Latiudes must be in decimal degrees and between �90� latitude.
%                   Crossing the poles at �90� has not been tested and can produce unexpected results.
%
%                   The number of latitude and longtitude vertices must be the same.
% 
%   t_start         start of time window for temporal serach in MATLAB's predefined date format #31: 'yyyy-mm-dd HH:MM:SS', e.g. 2017-05-10 15:45:17.
%   t_end           end   of time window for temporal serach in MATLAB's predefined date format #31: 'yyyy-mm-dd HH:MM:SS', e.g. 2017-05-10 16:53:56.
%                   t_start must be < t_end.
% 
%   verbose         Must be 0 or 1. 1 displays some basic parameters on the console. 0 is silent.
% ------------------------------------------------------------------------------------------------------------------------------------------------------------------
% OUTPUT PARAMETERS
%
%   atm_wvfm        Varible name of MATLAB structured array (struct) containing waveform and qfit data that fit the spatial and temporal search criteria.
%                   Metadata and processing information such as search criteria, instrument configuration and data format version as included as well.
%                   atm_wvfm must be a valid MATLAB variable name.  
% ------------------------------------------------------------------------------------------------------------------------------------------------------------------
% Author:           Michael Studinger, NASA Goddard Space Flight Center, Greenbelt MD, USA.
% Version:          1.18 - July 5, 2017
% See also:         atm_wvfm_info.m
% ------------------------------------------------------------------------------------------------------------------------------------------------------------------

%% diagram of the range gate and range bin pointer scheme
%
% <<waveform_pointer_scheme_v2c.jpg>>
% 

%% parse input parameters and do basic error checking

% profile on;

poly_search = 0; % will be set to 1 if parameters for a spatial search have been provided and are valid
time_search = 0; % will be set to 1 if parameters for a temporal search have been provided and are valid

% check number of input arguments
if ~any(nargin == [1 2 4 6])
    error('atm_wvfm_reader:nargin', ['\n\tERROR: The number of input arguments must be 1, 2, 4, or 6:\n\n', ...
        '\tSYNTAX: atm_wvfm = atm_wvfm_reader(f_name_inp);\n',...
        '\tSYNTAX: atm_wvfm = atm_wvfm_reader(f_name_inp, verbose);\n',...
        '\tSYNTAX: atm_wvfm = atm_wvfm_reader(f_name_inp, verbose, poly_lon, poly_lat);\n',...
        '\tSYNTAX: atm_wvfm = atm_wvfm_reader(f_name_inp, verbose, t_start, t_end);\n',...
        '\tSYNTAX: atm_wvfm = atm_wvfm_reader(f_name_inp, verbose, poly_lon, poly_lat, t_start, t_end);\n'])
end

% check number of output arguments
if (nargout ~= 1)
    error('atm_wvfm_reader:nargout', ['\n\tERROR: Number of output arguments must be 1:\n', ...
        '\tSYNTAX: atm_wvfm = atm_wvfm_reader(f_name_inp);\n',...
        '\tSYNTAX: atm_wvfm = atm_wvfm_reader(f_name_inp, verbose);\n',...
        '\tSYNTAX: atm_wvfm = atm_wvfm_reader(f_name_inp, verbose, poly_lon, poly_lat);\n',...
        '\tSYNTAX: atm_wvfm = atm_wvfm_reader(f_name_inp, verbose, t_start, t_end);\n',...
        '\tSYNTAX: atm_wvfm = atm_wvfm_reader(f_name_inp, verbose, poly_lon, poly_lat, t_start, t_end);\n'])
end

% check if input file exists
if (nargin >= 1 && ischar(f_name_inp))
    if (exist(f_name_inp) == 0)
        warndlg({'Input file not found!';'Script aborted.'},'!! Warning !!');
        error('atm_wvfm_reader:file_chk', '\n\tInput file not found. Script aborted.')
    end
end

% determine if console output is desired
if (length(varargin) >= 1)
    verbose = varargin{1};
    if (verbose ~= 0 && verbose ~= 1)
        error('atm_wvfm_info:verbose', '\n\tERROR: verbose must be either 0 or 1.')
    end
elseif(nargin == 1 || exist('verbose') == 0) % verbose has not been set due to nargin == 1
    verbose = 0;
end

% first populate poly_lon, poly_lat, t_start, t_end and set search flags from 0 to 1. do error checking later
% determine parameters for either spatial or temporal search 
if (nargin == 4)
    if (isnumeric(varargin{2}) &&  isnumeric(varargin{3})) % spatial search
        poly_lon = varargin{2};
        poly_lat = varargin{3};
        poly_search = 1; 
    elseif (ischar(varargin{2}) &&  ischar(varargin{3}))   % temporal search
        t_start = varargin{2};
        t_end = varargin{3};
        time_search = 1;         
    else
        error('atm_wvfm_reader:search_param', ['\n\tERROR: can''t determine search parameters. Check syntax. Examples for valid inputs are:\n',...
            '\tatm_wvfm = atm_wvfm_reader(''fname.h5'',1,[310.21 310.27 310.23],[69.97 69.98 69.47]);\n',...
            '\tatm_wvfm = atm_wvfm_reader(''fname.h5'',0,''2017-05-10 13:28:00'',''2017-05-10 13:29:00'');\n']);
    end
end

% determine parameters for combined spatial and temporal search
if (nargin == 6)
    if (all([isnumeric(varargin{2}) isnumeric(varargin{3}) ischar(varargin{4}) ischar(varargin{5})]))
        poly_lon = varargin{2};
        poly_lat = varargin{3};
        poly_search = 1; 
        t_start = varargin{4};
        t_end = varargin{5};
        time_search = 1; 
    else
        error('atm_wvfm_reader:search_param', ['\n\tERROR: can''t determine combined search parameters. Check syntax. Example for valid input:\n',...
            '\tatm_wvfm = atm_wvfm_reader(''fname.h5'',1,[310.21 310.27 310.23],[69.97 69.98 69.47],''2017-05-10 13:28:00'',''2017-05-10 13:29:00'');\n']);
    end
end

% check validity of parameters that define the spatial search

if (poly_search == 1) % input parameters include spatial search
    
    if (~isnumeric(poly_lat) || ~isvector(poly_lat))
        error('atm_wvfm_reader:poly_lat1', ['\n\tERROR: poly_lat must be a numeric vector.\n\tExample function call with valid search paramters:\n',...
            '\tatm_wvfm = atm_wvfm_reader(''fname.h5'',1,[310.21 310.27 310.23],[69.97 69.98 69.47]);\n']);
    end
    if any(abs(poly_lat) > 90)
        error('atm_wvfm_reader:poly_lat2', ['\n\tERROR: poly_lat values must be between �90�.\n\tExample function call with valid search paramters:\n',...
            '\tatm_wvfm = atm_wvfm_reader(''fname.h5'',1,[310.21 310.27 310.23],[69.97 69.98 69.47]);\n']);
    end
    if (any(poly_lon < 0) || any(poly_lon > 360))
        error('atm_wvfm_reader:poly_lon2', ['\n\tERROR: poly_lon values must be between 0� and 360�.\n\tExample function call with valid search paramters:\n',...
            '\tatm_wvfm = atm_wvfm_reader(''fname.h5'',1,[310.21 310.27 310.23],[69.97 69.98 69.47]);\n']);
    end
    if ~isequal(length(poly_lat), length(poly_lon))
        error('atm_wvfm_reader:lat_lon_length', '\n\tERROR: poly_lat and poly_lon must be the same length.')
    end
    if (length(poly_lat) < 3)
        error('atm_wvfm_reader:lat_lon_poly1', '\n\tERROR: poly_lat and poly_lon must contain at least 3 vertices.')
    end
    if ((length(poly_lat) >= 3) && ~isequal([poly_lat(1) poly_lon(1)], [poly_lat(end) poly_lon(end)]))
        warning('atm_wvfm_reader:lat_lon_poly2', ['\n\tWARNING: The first and last vertex of the search polygon are not identical.',...
            '\n\tThe polygon will be automatically closed for spatial search.'])
            poly_lon(end+1) = poly_lon(1);
            poly_lat(end+1) = poly_lat(1);
    end
    
    % check if vertices of the search polygon are arranged in clockwise order
    % and if not rearrange the vertices assuming a licence for the mapping toolbox is available. skip this check otherwise.
    
    if (license('test','map_toolbox') == 1)                      % check if user has a license for the mapping toolbox
        if (ispolycw(poly_lon, poly_lat) == 0)                   % check if vertex order of polygon is clockwise
            [poly_lon, poly_lat] = poly2cw(poly_lon, poly_lat);  % arrange vertices of the search polygon in clockwise order
            warning('atm_wvfm_reader:poly_cw', '\n\tWARNING: The vertices of the search polygon have been rearranged in clockwise order.')
        end
    else
        warning('atm_wvfm_reader:poly_cw', '\n\tWARNING: No license for mapping toolbox found. Skipping check for clockwise vertex order.')
    end
    
end % if (poly_search == 1)

% check integrity of temporal search parameters

if (time_search == 1) % note: MATLAB's datetime function exits with an error if the conversion is unsuccessful. no further error handling necessary.  
    
    % check for correct date and time input format
    if (isdatetime(datetime(t_start,'Inputformat','yyyy-MM-dd HH:mm:s')) == 1)
        t_start_num = datenum(t_start,31);
    end
    
    % check t_end
    if (isdatetime(datetime(t_start,'Inputformat','yyyy-MM-dd HH:mm:s')) == 1)
        t_end_num = datenum(t_end,31);
    end
    
    % verify t_start < t_end
    if (t_start_num > t_end_num)
        error('atm_wvfm_reader:t_start_t_end', '\n\tERROR: t_start must be < t_end.')
    end
    
    % verify the data file contains laser shots within the time window
    first_shot_str = h5read(f_name_inp,'/ancillary_data/time_first_shot'); % 2017-05-10T13:26:28-0000 in ISO-8601 standard
    first_shot_numdate = datenum(first_shot_str,'yyyy-mm-ddTHH:MM:SS-0000');
    % last_shot_str = h5read(f_name_inp,'/time/last_shot'); % not needed according to code analyzer
    % last_shot_numdate = datenum(last_shot_str,'yyyy-mm-ddTHH:MM:SS-0000'); % not needed according to code analyzer
    
    if (first_shot_numdate > t_end_num && t_end < first_shot_numdate)
        error('atm_wvfm_reader:time_search', '\n\tERROR: The HDF5 file contains no laser shots within the temporal search parameters.')
    end
    
end % if (time_search == 1)


%% determine version of ATM waveform data format

twv = h5read(f_name_inp,'/waveforms/twv/shot_number');
vld = h5read(f_name_inp,'/waveforms/vld/UniqID');

if(size(twv,1) > 0)
    data_fmt = 2; % current ATM waveform format stored in subgroup /waveforms/twv
    data_fmt_str = 'ATM Waveform Format Vers. 2.0';
elseif(size(vld,1) > 0)
    data_fmt = 1; % legacy  ATM waveform format stored in subgroup /waveforms/vld
    data_fmt_str = 'ATM Waveform Format Vers. 1.0';
else
    error('atm_wvfm_reader:wvfm_fmt_vers', '\n\tERROR: Cannot determine ATM waveform format version from HDF5 file.')
end


%% read data and set up MATLAB serial time tags for individual laser shots

% read qfit contents 
lon = h5read(f_name_inp,'/footprint/longitude'); % ATM longitudes are between 0� and 360�
lat = h5read(f_name_inp,'/footprint/latitude');
ele = h5read(f_name_inp,'/footprint/elevation');

% seconds_of_day = h5read(f_name_inp,'/time/seconds_of_day'); these time tags are for qfit elevations

% read time tags (seconds of day past midnight) of laser trigger time
shots_seconds_of_day = h5read(f_name_inp,'/waveforms/twv/shot_seconds_of_day');
epoch_seconds_of_day = h5read(f_name_inp,'/ancillary_data/epoch_seconds_of_day'); % number of seconds that have elapsed since January 1, 1970 (midnight UTC/GMT) not counting leap seconds

% convert epoch time to MATLAB serial date and create UTC laser trigger time in MATLAB serial date format 
day_first_shot_num = datenum('1970-01-01 00:00:00',31) + double(epoch_seconds_of_day)/86400;
shots_utc_num_date = day_first_shot_num + shots_seconds_of_day/86400; % time tags for laser shots as MATLAB serial date


%% identify laser shots that fit spatial and temporal search criteria

t1 = tic;
if (poly_search == 1)
    indx_polygon = inpolygon(lon,lat,poly_lon,poly_lat); % returns array with ones for shots inside the polyon or on the edge and zero outside
    shot_list_poly = find(indx_polygon == 1);
end
t_search_poly = toc(t1);

t2 = tic;
if (time_search == 1)
    shot_list_time = find(shots_utc_num_date >= t_start_num & shots_utc_num_date <= t_end_num);
end
t_search_time = toc(t2);

% now combine search results and check there are laser shots that fit both the spatial and temporal search criteria
if (poly_search == 1 && time_search == 0) % spatial search only
    shot_list_search = shot_list_poly;
    if (size(shot_list_poly,1) < 1)
        error('atm_wvfm_reader:search1', '\n\tERROR: The HDF5 file contains no laser shots within the spatial search parameters.')
    end
elseif (poly_search == 0 && time_search == 1) % temporal search only
    shot_list_search = shot_list_time;
    if(size(shot_list_time,1) < 1)
        error('atm_wvfm_reader:search2', '\n\tERROR: The HDF5 file contains no laser shots within the temporal search parameters.')
    end
elseif (poly_search == 1 && time_search == 1) % combined spatial and temporal search
    shot_list_search = intersect(shot_list_poly,shot_list_time); % returns the data common to both shot_list_poly and shot_list_time, with no repetitions. shot_list_search is in sorted order.
    if(size(shot_list_search,1) < 1)
        error('atm_wvfm_reader:search3', '\n\tERROR: The HDF5 file contains no laser shots that fit both, the spatial and temporal search parameters.')
    end
elseif (poly_search == 0 && time_search == 0) % no search. import entire HDF5 file
    shot_list_search = (1:1:size(lon,1))';
else
        error('atm_wvfm_reader:search4', '\n\tERROR: The HDF5 cannot be imported.')
end
    

%% determine the record/shot and range gate information necessary to reassemble the waveforms
% information is stored in different subgroups depending on data format type: 1 (ATM legacy) or 2 (current waveform)

if (data_fmt == 2)
    
    % sampling interval
    sample_int = h5read(f_name_inp,'/waveforms/twv/sample_interval'); % sampling interval in seconds
    sample_int_ns = sample_int*1E9; % sampling interval in nano seconds
    
    % laser shots
    shot_gate_count = h5read(f_name_inp,'/waveforms/twv/shot_gate_count');   % number of gates in shot
    shot_gate_start = h5read(f_name_inp,'/waveforms/twv/shot_gate_start');   % record number of waveform's first gate in shot (0, 3, 6,...)
    shot_identifier = h5read(f_name_inp,'/waveforms/twv/shot_number');       % unique shot identifier
    
    % gate information
    gate_wvfm_start  = h5read(f_name_inp,'/waveforms/twv/gate_wvfm_start');  % int32 pointer to first sample in waveform gate (0, 96, 192, ...)
    gate_wvfm_length = h5read(f_name_inp,'/waveforms/twv/gate_wvfm_length'); % int32
    gate_position   = h5read(f_name_inp,'/waveforms/twv/gate_position');   % int32 number of samples after laser trigger (n = 0 marks trigger)
    
    % range bins for faster import
    wvfm_amplitude = h5read(f_name_inp,'/waveforms/twv/wvfm_amplitude');     % uint8

    
elseif (data_fmt == 1)
    error('atm_wvfm_reader:data_fmt', '\n\tERROR: vld data format not yet supported.')
end
    

%% extract range gates and arrange them into a MATLAB structure array

% populate the waveform struct - this is for some reason not much faster than doing it inside the loop

atm_wvfm = struct('shot_id',shot_identifier(shot_list_search),...
    'lon',lon(shot_list_search),...
    'lat',lat(shot_list_search),...
    'ele',ele(shot_list_search),...
    'n_gates',shot_gate_count(shot_list_search),...
    'shot_gate_start', shot_gate_start(shot_list_search),...
    'laser_trigger_time_utc_serial',shots_utc_num_date(shot_list_search),...
    'laser_trigger_time_utc_seconds',shots_seconds_of_day(shot_list_search));    

tStart = tic;

for i = 1:size(shot_list_search,1)
    
    record_nr = shot_list_search(i);
    
    n_gates = shot_gate_count(record_nr); % determine the number or range gates
        
    for k = 1:n_gates
        
        % determine pointers/indices of desired shot/record number and accompanying range gates
        indx = shot_gate_start(record_nr) + k - 1;
        % this works very fast for a very small number of shots but very slow for a larger number of shots or entire files   
               % atm_wvfm.gates(i).wf(k).w = double(h5read(f_name_inp,'/waveforms/twv/wvfm_amplitude',double(gate_wvfm_start(indx)),double(gate_wvfm_length(indx)),1));
        % use this for large number of shots (> 1000) or entire files
        atm_wvfm.shots(i).wf(k).w = wvfm_amplitude(gate_wvfm_start(indx):gate_wvfm_start(indx) + gate_wvfm_length(indx) - 1); 

        % populate array of laser trigger time tags in units of nano seconds - convenient, but results in large data volume, when used for entire files
        tw_tmp = 0:sample_int_ns:double(gate_wvfm_length(indx))-1;
        tw_tmp1 = tw_tmp(1:gate_wvfm_length(indx));
        atm_wvfm.shots(i).wf(k).t = double(gate_position(indx))*sample_int_ns + tw_tmp1;
        
        % only export number of digitizer samples following laser trigger to save space
        % atm_wvfm.shots(i).wf(k).gate_position = gates_position(indx);
    end
    
    clear record_nr indx tw_*;
    
end

t_elapsed = toc(tStart);

%% create info field containing information about the subsetting/HDF5 ingest and basic metadata about the HDF5 input file

atm_wvfm.info.f_name                 = char(f_name_inp);
if poly_search == 1
    atm_wvfm.info.search_poly.lon    = poly_lon;
    atm_wvfm.info.search_poly.lat    = poly_lat;
else
    atm_wvfm.info.search_poly.lon    = 'No spatial search parameters provided.';
    atm_wvfm.info.search_poly.lat    = 'No spatial search parameters provided.';
end
if time_search == 1
    atm_wvfm.info.search_time.start      = t_start;
    atm_wvfm.info.search_time.end        = t_end;
else
    atm_wvfm.info.search_time.start      = 'No temporal search parameters provided.';
    atm_wvfm.info.search_time.end        = 'No temporal search parameters provided.';
end
atm_wvfm.info.data_fmt_str           = data_fmt_str;
atm_wvfm.info.sensor                 = upper(char(h5read(f_name_inp,'/ancillary_data/sensor')));
atm_wvfm.info.sampling_int_ns        = sample_int_ns; 
atm_wvfm.info.reference_frame        = upper(char(h5read(f_name_inp,'/ancillary_data/reference_frame')));
atm_wvfm.info.date_processed         = datestr(now);
atm_wvfm.info.m_file_used            = mfilename('fullpath');
atm_wvfm.info.user                   = getenv('UserName');
atm_wvfm.info.atm_processing_version = h5read(f_name_inp,'/ancillary_data/version');
atm_wvfm.info.atm_header_text        = h5read(f_name_inp,'/ancillary_data/header_text');
atm_wvfm.info.input_parameters       = varargin;

% add utc times of first and last shot in HDF5 and in search results
atm_wvfm.info.shot_times.utc_time_first_shot_HDF5 = datestr(shots_utc_num_date(1),'yyyy-mm-dd HH:MM:SS.FFF');
atm_wvfm.info.shot_times.utc_time_last_shot_HDF5  = datestr(shots_utc_num_date(end),'yyyy-mm-dd HH:MM:SS.FFF');
atm_wvfm.info.shot_times.utc_time_first_shot_search = datestr(shots_utc_num_date(shot_list_search(1)),'yyyy-mm-dd HH:MM:SS.FFF');
atm_wvfm.info.shot_times.utc_time_last_shot_search  = datestr(shots_utc_num_date(shot_list_search(end)),'yyyy-mm-dd HH:MM:SS.FFF');

% add closed polyong (clockwise order) of bounding box coordinates of both, the entire HDF5 file and the search results
atm_wvfm.info.bbox.lon_HDF5          = [min(lon) max(lon) max(lon) min(lon) min(lon)];
atm_wvfm.info.bbox.lat_HDF5          = [max(lat) max(lat) min(lat) min(lat) max(lat)];
atm_wvfm.info.bbox.lon_search        = ...
    [min(lon(shot_list_search)) max(lon(shot_list_search)) max(lon(shot_list_search)) min(lon(shot_list_search)) min(lon(shot_list_search))];
atm_wvfm.info.bbox.lat_search        = ...
    [max(lat(shot_list_search)) max(lat(shot_list_search)) min(lat(shot_list_search)) min(lat(shot_list_search)) max(lat(shot_list_search))];

% add number of shots/records and also indices of the shots that match the temporal and spatial search criteria
atm_wvfm.info.shots.n_shots_HDF5     = uint64(size(lon,1));
atm_wvfm.info.shots.n_shots_search   = uint64(size(shot_list_search,1));
atm_wvfm.info.shots.shot_indx_search = uint64(shot_list_search);

%% display processing information in MATLAB Command Window or Console if desired

if (verbose == 1)
    
    [~,name,ext] = fileparts(f_name_inp); 
    fprintf('\n-----------------------------------------------------------------------\n');
    fprintf('Imported file %s\n',[name ext]);
    fprintf('-----------------------------------------------------------------------\n');
    fprintf('Processing time (sec):                      %.2f\n',t_elapsed);
    fprintf('Time for spatial search (sec):              %.2f\n',t_search_poly);
    fprintf('Time for temporal search (sec):             %.2f\n',t_search_time);
    fprintf('Number of laser shots in ATM HDF5 file: %8d\n',size(lon,1));
    fprintf('Number of shots matching search params: %8d (%.1f%%)\n',size(shot_list_search,1),(size(shot_list_search,1)/size(lon,1))*100);
    fprintf('-----------------------------------------------------------------------\n');
    
end

%% clean up struct for output - MATLAB can only reorder top level fields

atm_wvfm = rmfield(atm_wvfm,'shot_gate_start'); % delete field since it it not needed
atm_wvfm = orderfields(atm_wvfm, {'info', 'lon', 'lat', 'ele', 'shot_id', 'laser_trigger_time_utc_seconds', 'laser_trigger_time_utc_serial',...
     'n_gates','shots'}); % orders the fields specified by the indices in permutation vector
 
% profile off
% profile viewer 

end