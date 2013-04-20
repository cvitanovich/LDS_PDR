function simSPL()

global PDR
PDR.HRTF_directory='C:\andrew\pdr\HRTF_lib';
PDR.HRTF_fname='929AD.eq';
PDR.TEST_locs(1,:)=zeros(1,19);
PDR.TEST_locs(2,:)=-45:5:45;
PDR.TEST_nlocs=length(PDR.TEST_locs(2,:));


% HRTF SETUP:
% Setup HRTFs for calibration session:
MTLreadHDR0;
MTLreadDIR0;
keyboard
%convert coordinates to double polar, only if not using 929 or 930 or ones
if (~strcmp(PDR.HRTF_fname(1:3),'930') & ~strcmp(PDR.HRTF_fname(1:3),'929'))
    PDR.HRTF_dir_matrix = sphere2double(PDR.HRTF_dir_matrix);
end
HRTF.TestL = nan*ones(PDR.HRTF_nlines,PDR.TEST_nlocs);
HRTF.TestR = HRTF.TestL;
direc = PDR.HRTF_dir_matrix; % NOTE: first row = Elevation and 2nd row = Azimuth !!!
for i=1:PDR.TEST_nlocs
    idx{i}=find(direc(1,:)==PDR.TEST_locs(i,1) & direc(2,:)==PDR.TEST_locs(i,2));
    HRTF.TestL(:,i) = MTLreadCH0(idx{i}*2-1);
    HRTF.TestR(:,i) = MTLreadCH0(idx{i}*2);
end
keyboard

function MTLreadHDR0()
global PDR
% Adapted from MTLRH
% MTLreadHDR00 reads the header of a SIGMAP and MTLSIG file.
%
% filetype: 3 -> frq-domain
%           2 -> time-domain
% info_blocks: number of info blocks
% n_channels: number of channels in file
% n_lines: number of lines per channel
% sampling_rate: sampling rate in kHz
% first_line: value of first line ( in ms for time domain
%                                   in kHz for frq domain )
% last_line: value of last line
% n_directions: number of directions in file
% comment1: string with 80 characters
% comment2: string with 200 characters
%
% See also: MTLWH, MTLRCH, MTLWCH

% Author: Klaus Hartung [Lehrstuhl AEA, Ruhr-Universitaet Bochum]
% Date: 19.4.1995

%open file for reading
%disp(HRTFfile);
HRTFfile = [PDR.HRTF_directory PDR.HRTF_fname];
[fid,message] = fopen(HRTFfile,'r','ieee-le');
keyboard

if (fid==-1)         				% file can't be opened
    disp(message);
    filetype=-1;
    return;
end;
keyboard

fseek(fid,0,'bof');

%test if data are stored in PC-format (EOF=26) or Workstation format(EOF=XX)

fseek(fid,79,'bof');
eof = fread(fid,1,'char');
eof_int = abs(eof);
if (eof_int ~= 26);
    fclose(fid);
    error('chosen file isn''t readable');
    filetype=-1;
    return;
end;

%check filetype

fseek(fid,80,'bof');
filetype = fread(fid,1,'short');
if ( (filetype<2)|(filetype>11) )
    fclose(fid);
    error('choosen file includes unknown filetype');
end;

status=fseek(fid,82,'bof');
if (status<0) error('ERROR: MTLreadHDR0, fseek info_blocks'); filetype=-1;return, end;
PDR.HRTF_info_blocks = fread(fid,1,'short');

status=fseek(fid,84,'bof');
if (status<0) error('ERROR: MTLreadHDR0, fseek n_channels'); filetype=-1;return, end;
PDR.HRTF_nchannels = fread(fid,1,'short');

status=fseek(fid,128,'bof');
if (status<0) error('ERROR: MTLreadHDR0, fseek n_lines'); filetype=-1;return, end;
PDR.HRTF_nlines = fread(fid,1,'short');


%if the filetype is a linear signal (hrir or hrtf)
if (filetype<7)
    status=fseek(fid,132,'bof');
    if (status<0) error('ERROR: MTLreadHDR0, fseek sampling_rate'); filetype=-1;return, end;
    PDR.HRTF_sampling_rate = fread(fid,1,'float32');
    
    status= fseek(fid,136,'bof');
    if (status<0) error('ERROR: MTLreadHDR0, fseek first_line'); filetype=-1;return, end;
    PDR.HRTF_first_line = fread(fid,1,'float32');
    
    status=fseek(fid,140,'bof');
    if (status<0) error('ERROR: MTLreadHDR0, fseek last_lines'); filetype=-1;return, end;
    PDR.HRTF_last_line = fread(fid,1,'float32');
end;


% if the file is sigmap format it does not contain 'n_directions' field
% assume that it has one direction

status=fseek(fid,220,'bof');
if (status<0) error('ERROR: MTLreadHDR0, fseek n_directions'); filetype=-1;return, end;
PDR.HRTF_ndirections = fread(fid,1,'short');
if (PDR.HRTF_ndirections==0) PDR.HRTF_ndirections=1; end;

status=fseek(fid,0,'bof');
if (status<0) error('ERROR: MTLreadHDR0, fseek comment1'); filetype=-1;return, end;
comment1 = setstr(fread(fid,80,'uchar')) ;
PDR.HRTF_comment1=comment1';

status=fseek(fid,222,'bof');
if (status<0) error('ERROR: MTLreadHDR0, fseek comment2'); filetype=-1;return, end;
comment2 = setstr(fread(fid,200,'uchar'));
PDR.HRTF_comment2=comment2';

PDR.HRTF_filetype = filetype;
fclose(fid);
keyboard
return;

function MTLreadDIR0()
global PDR
% name changed from MTLRDIR to MTLreadDIR0

% direction_matrix=mtlrdir(filename,n_directions)
%
% MTLreadDIR0 reads direction matrix of a mtlsig file
%
% direction_matrix: matrix with n-directions columns
%                   first line: elevation
%                   second line: azimuth
%
% filename: name of the mtlsig file
%
% optional arguments:
%
% n_directions: number of directions
%
%
% See also: MTLWH, MTLRCH, MTLWCH

% Author: Klaus Hartung [Lehrstuhl AEA, Ruhr-Universitaet Bochum]
% Date: 19.4.1995
% Date: 21.4.1995



HRTFfile = [PDR.HRTF_directory PDR.HRTF_fname];

[fid,message] = fopen(HRTFfile,'r','ieee-le');
if fid==-1          % file can't be opened
    disp(message);
    direction_matrix=-1;
    return;
end;

if (nargin < 2)
    status=fseek(fid,220,'bof');
    if (status<0) error('ERROR: mtlrdir, fseek n_directions'); direction_matrix=-1;return, end;
    PDR.HRTF_ndirections = fread(fid,1,'short');
    if (PDR.HRTF_ndirections<=0) direction_matrix=-1;return, end;
end;


status=fseek(fid,512,'bof');
if (status<0) error('ERROR: mtlrdir, fseek n_directions'); direction_matrix=-1;return, end;

direction_matrix=fread(fid,2*PDR.HRTF_ndirections,'float32');

status=fclose(fid);
if (status<0) error('ERROR: mtlrdir, fseek n_directions'); direction_matrix=-1;return, end;

direction_matrix=reshape(direction_matrix,2,PDR.HRTF_ndirections);

PDR.HRTF_dir_matrix = direction_matrix;
keyboard


return;

function [dir1, dir2] = sphere2double(p1, p2)
% renamed sphere2double but functionality is the same.
%
% Original file: SPH2DBL.m	
% Description: 
% Converts spherical coordinates into double polar coordinates
%		[dir1, dir2] = sph2dbl(p1, p2):  (in degrees)
%		input arguments: saz, sel
%		output arguments: daz, del
%	or:	[dir1] = sph2dbl(p1):  (in degrees)
%		input argument: direction matrix (2 x n_dirs; el then az)
%		output argument: direction matrix (2 x n_dirs; del then daz)

if (nargin == 1)
    el = p1(1,:).*pi/180;
    az = p1(2,:).*pi/180;
    %  disp('SPH2DBL: calculating double polar direction matrix');
elseif (nargin ==2)
    el = p1*pi/180;
    az = p2*pi/180;
    %  disp('SPHDBL: calculating double polar azimuth and elevation');
else
    error('SPH2DBL: incorrect number of input arguments');
    return;
end;

% convert to cartesian coordinates:
x = cos(el) .* sin(az);
y = sin(el);
z = cos(el) .* cos(az);

%convert to double polar coordinates:
del = (el);
daz = (asin(x));

[value,index] = find(daz > pi/2);
daz(index) = pi - daz(index);

[value,index] = find(daz < -pi/2);
daz(index) = -pi - daz(index);

if (nargin == 1)
    dir1 = zeros(size(p1));
    dir1(1,:) = round(del*180/pi);
    dir1(2,:) = round(daz*180/pi);
else
    dir1 = round(del*180/pi);
    dir2 = round(daz*180/pi);
end;

%disp (['el : ' num2str(p1) ' del : ' num2str(dir1)]);
%disp (['az : ' num2str(p2) ' daz : ' num2str(dir2)]);

function [channel] = MTLreadCH0(index)
global PDR
% adapted from MTLRCH"

% MTLRCH reads one channel from a file (type 2 or 3)
%
% [channel]=MTLreadCH0(index);
%
% var_string = name of output variable
%
% See also: MTLWCH, MTLWH, MTLreadHDR0

% Author: Klaus Hartung [Lehrstuhl AEA, Ruhr-Universitaet Bochum]
% Date: 19.4.1995

% if no index available read first channel

if (nargin == 0) index=1; end

file_type = PDR.HRTF_filetype;
HRTFfile = [PDR.HRTF_directory PDR.HRTF_fname];

iscomplex=0;

if (file_type == 2) iscomplex=0; end
if (file_type == 3) iscomplex=1; end

[fid,message] = fopen(HRTFfile,'r','ieee-le');
if fid==-1          % file can't be opened
    disp(message);
    channel=-1;
    return
end

pos=PDR.HRTF_info_blocks*256+PDR.HRTF_nlines*4*(index-1)*(iscomplex+1);

% fseek to channel
status=fseek(fid,pos,'bof');
if (status<0) error('ERROR: MTLreadCH0,  fseek to channel not succesful' );channel=-1; return; end

%fread of channel
ichannel=fread(fid,PDR.HRTF_nlines*(iscomplex+1),'float32');
if (ichannel<0) error('ERROR: MTLreadCH0, reading of channel not succesful' );channel=-1; end

% creating a complex vector if necessary
if (iscomplex==1)
    channel(1:n_lines)=ichannel(1:2:PDR.HRTF_nlines*2)+i*ichannel(2:2:PDR.HRTF_nlines*2);
else
    channel=ichannel;
end

channel = channel(:);

status = fclose(fid);
if (status < 0) error('ERROR: MTLreadCH0, close file');channel=-1; return; end
var_string = channel; % sets global variable with name = var_string to value of channel
