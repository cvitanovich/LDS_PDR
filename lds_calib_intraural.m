function lds_calib_intraural()
% lds calib intraural (Knowles in Owl Ears)
global CALIB_PDR H TDT KNOWLES

% SCREEN DIMENSIONS IN PIXELS
screen = get(0,'ScreenSize'); % screen = [left bottom width height]
left = screen(1); 
bottom = screen(2);
width = screen(3)-screen(1);
height = screen(4)-screen(2);

% CREATE NEW FIGURE
fig_left = left + .4*width; % left edge shifted 55% across screen
fig_bottom = bottom + .05*height; % bottom edge shifted 5% up screen
fig_width = .5*width; % fig width = 40% of screen width
fig_height = .8*height; % fig height = 80% of screen height

H.fig = figure('Units','pixels',...
    'Position',[fig_left fig_bottom fig_width fig_height],...
    'Name','Interaural Calibrations (LDS Study)',...
    'NumberTitle','off',...
    'Toolbar','none');
set(gcf,'Menubar','none')

% buttons
H.opt = uicontrol('Parent',H.fig,...
    'Style','text',...
    'Units','normalized',...
    'Position',[.05 .9 .3 .1],...
    'ForegroundColor','Black',...
    'BackgroundColor',[.7 .7 1],...
    'String','Options');

% calib knowles button
H.calib_knowles_btn = uicontrol('Parent',H.fig,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[.05 .80 .3 .1],...
    'BackgroundColor','white',...
    'ForegroundColor','blue',...
    'String','Calib Knowles',...
    'Enable','on',...
    'Callback',@run_knowles_calibration);

% load a knowles file
H.load_knowles_data_btn = uicontrol('Parent',H.fig,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[.05 .70 .3 .1],...
    'BackgroundColor','white',...
    'ForegroundColor','blue',...
    'String','Load Knowles Data',...
    'Enable','off',...
    'Callback',@load_knowles);

% init setup button
H.init_btn = uicontrol('Parent',H.fig,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[.05 .60 .3 .1],...
    'BackgroundColor','white',...
    'ForegroundColor','blue',...
    'String','Init Setup',...
    'Callback',@init_setup);

% equalize attens button
H.equal_attens_btn = uicontrol('Parent',H.fig,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[.05 .50 .3 .1],...
    'BackgroundColor','white',...
    'ForegroundColor','blue',...
    'String','Equalize Attens',...
    'Enable','off',...
    'Callback',@equalize_speaker_attens);

% equalize scales button
H.equal_scales_btn = uicontrol('Parent',H.fig,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[.05 .40 .3 .1],...
    'BackgroundColor','white',...
    'ForegroundColor','blue',...
    'String','Equalize Scales',...
    'Enable','off',...
    'Callback',@equalize_speaker_scales);

% quit button
H.quit = uicontrol('Parent',H.fig,...
    'Style','pushbutton',...
    'Units','normalized',...
    'Position',[.05 .30 .3 .1],...
    'BackgroundColor','red',...
    'ForegroundColor','yellow',...
    'String','QUIT',...
    'Callback','close(gcf)');

% owl ID entry
H.owl_id1 = uicontrol('Parent',H.fig,...
    'Style','text',...
    'Units','normalized',...
    'Position',[.05 .2 .15 .05],...
    'BackgroundColor','w',...
    'ForegroundColor','m',...
    'HorizontalAlignment','left',...
    'String','OWL ID#: ');

H.owl_id2 = uicontrol('Parent',H.fig,...
    'Style','text',...
    'Units','normalized',...
    'Position',[.2 .2 .1 .05],...
    'BackgroundColor','k',...
    'ForegroundColor','k',...
    'String','',...
    'HorizontalAlignment','left');

% display calib files
H.knowles1 = uicontrol('Parent',H.fig,...
    'Style','text',...
    'Units','normalized',...
    'Position',[.05 .15 .15 .05],...
    'BackgroundColor',[.9 .9 .9],...
    'ForegroundColor','k',...
    'HorizontalAlignment','left',...
    'String','Knowles Calib FN: ');

H.knowles2 = uicontrol('Parent',H.fig,...
    'Style','text',...
    'Units','normalized',...
    'Position',[.2 .15 .4 .05],...
    'BackgroundColor',[.9 .9 .9],...
    'ForegroundColor','k',...
    'HorizontalAlignment','left',...
    'String','...');

H.intraural1 = uicontrol('Parent',H.fig,...
    'Style','text',...
    'Units','normalized',...
    'Position',[.05 .1 .15 .05],...
    'BackgroundColor',[.9 .9 .9],...
    'ForegroundColor','k',...
    'HorizontalAlignment','left',...
    'String','Intraural Calib FN: ');

H.intraural2 = uicontrol('Parent',H.fig,...
    'Style','text',...
    'Units','normalized',...
    'Position',[.2 .1 .4 .05],...
    'BackgroundColor',[.9 .9 .9],...
    'ForegroundColor','k',...
    'HorizontalAlignment','left',...
    'String','...');

function set_owl_id(hObject,eventdata)
global CALIB_PDR H
CALIB_PDR.owl_id = str2num(get(H.owl_id2,'String'));

% broadband noise
function [bbnoise] = getBBN(state,Fs,dur, minfreq, maxfreq)
global PDR
%GetNoise_BB:	Create a BroadBand Noise (2-11 kHz)
%state:  rand state
%Fs:	Sampling rate (Hz)
%dur:	Stimulus duration (ms)
dur = dur/1000;
len = round(dur*Fs);
minfreq = round(((minfreq + 1)/Fs) * len);
maxfreq = round(((maxfreq + 1)/Fs) * len);
range = maxfreq-minfreq+1;
% mag spectrum = 1 between set frequencies:
mag = zeros(len,1);
mag(minfreq:maxfreq) = ones(range,1);
% random phase spectrum between set frequencies:
% rand('state',sum(100*clock));
rand('state',state); % use state
phi = (rand(len,1) - 0.5) * (2*pi);
% combine phase and magnitude:
X = mag .* ( (cos(phi)) + (i .* sin(phi)) );
% convert to time domain:
bbnoise = real(ifft(X));
% scale to RMS = 0.23591 !!!!!!!!
rms = norm(bbnoise)/sqrt(length(bbnoise))';
bbnoise = bbnoise * (0.23591/rms);
bbnoise = bbnoise';
%bbnoise = (bbnoise/max(abs(bbnoise)))';

% ramping sounds
function [stim] = rampSounds(stim, SR, SOUNDS_ramp)
% SOUNDS_ramp should be in ms
ramp_pts = ceil(SR*(SOUNDS_ramp/1000));
npts = length(stim) - 2*ramp_pts - 2;
rampenv = [0:(1/ramp_pts):1 ones(1,npts) 1:-(1/ramp_pts):0];
stim = stim .* rampenv;

% AMstim -- for making sounds
function AMStim_calib()
% Note: Noise1 is lead and Noise2 is lag
% AMStim (Adapted from Caitlin/Brian's head turn exp't)
% Generate stimuli for LDS session
global CALIB_PDR

%//////////////////////////////////////////
% Make stimulus or stimuli
SR = CALIB_PDR.stim_Fs;
% Increase duration by delay
% so that the stimuli can be gated/windowed (see below)
StimDur = CALIB_PDR.SOUNDS_length + CALIB_PDR.SOUNDS_delay; % should be in ms, add delay

% for sound generation
if StimDur < 500
    PAD = 10;
else
    PAD = 1;
end

StimPnts = round((StimDur/1000)*SR);
DelayPnts = round((CALIB_PDR.SOUNDS_delay/1000)*SR);
DelayPnts = max(1,DelayPnts);
% Make Noise #1
Noise1 = getBBN(CALIB_PDR.SOUNDS_states(1), SR, PAD*StimDur, CALIB_PDR.SOUNDS_carrier_bandwidth(1), CALIB_PDR.SOUNDS_carrier_bandwidth(2));
Noise1 = Noise1(1:StimPnts);
% scale to desired amplitude
Noise1 = Noise1 * 50; % scale by 50 so that speaker scaling factors aren't too big (well, small)!
Noise1 = Noise1 * 10^(CALIB_PDR.SOUNDS_amplitude/20)*0.00002; % amplitude re: 20 uPa   
% copy Noise #1 to make Noise #2
Noise2 = Noise1;  
% Make Envelope #1
Env1 = getBBN(CALIB_PDR.SOUNDS_states(2), SR, PAD*StimDur, CALIB_PDR.SOUNDS_env_bandwidth(1), CALIB_PDR.SOUNDS_env_bandwidth(2));
Env1 = Env1(1:StimPnts);
Env1 = Env1 - min(Env1); Env1 =  Env1 / max(Env1);  % normalize
Env1 = Env1 .* (CALIB_PDR.SOUNDS_env_depth/100); % AM depth (as a percent)
Env1 = Env1 + 1 - (CALIB_PDR.SOUNDS_env_depth/100);
% copy Envelope #1 to make Envelope #2
Env2 = Env1;
% get de-correlateing envelope #1
DCEnv1 = getBBN(CALIB_PDR.SOUNDS_states(3), SR, PAD*StimDur, CALIB_PDR.SOUNDS_env_bandwidth(1), CALIB_PDR.SOUNDS_env_bandwidth(2));
DCEnv1 = DCEnv1(1:StimPnts);
DCEnv1 = DCEnv1 - min(DCEnv1); DCEnv1 =  DCEnv1 / max(DCEnv1);  % normalize
DCEnv1 = DCEnv1 .* (CALIB_PDR.SOUNDS_env_depth/100); % AM depth (as a percent)
DCEnv1 = DCEnv1 + 1 - (CALIB_PDR.SOUNDS_env_depth/100);
% get de-correlateing envelope #2
DCEnv2 = getBBN(CALIB_PDR.SOUNDS_states(4), SR, PAD*StimDur, CALIB_PDR.SOUNDS_env_bandwidth(1), CALIB_PDR.SOUNDS_env_bandwidth(2));
DCEnv2 = DCEnv2(1:StimPnts);
DCEnv2 = DCEnv2 - min(DCEnv2); DCEnv2 =  DCEnv2 / max(DCEnv2);  % normalize
DCEnv2 = DCEnv2 .* (CALIB_PDR.SOUNDS_env_depth/100); % AM depth (as a percent)
DCEnv2 = DCEnv2 + 1 - (CALIB_PDR.SOUNDS_env_depth/100);
% ** mix de-correlateing envelopes in with original envelopes **
Env1DC = ((1-CALIB_PDR.SOUNDS_mix).*DCEnv1) + ((CALIB_PDR.SOUNDS_mix).*Env1);
Env2DC = ((1-CALIB_PDR.SOUNDS_mix).*DCEnv2) + ((CALIB_PDR.SOUNDS_mix).*Env2);
% !!! re-normalize the envelopes
Env1DC = Env1DC - min(Env1DC); Env1DC =  Env1DC / max(Env1DC);  % normalize
Env1DC = Env1DC .* (CALIB_PDR.SOUNDS_env_depth/100); % AM depth (as a percent)
Env1DC = Env1DC + 1 - (CALIB_PDR.SOUNDS_env_depth/100);
Env2DC = Env2DC - min(Env2DC); Env2DC =  Env2DC / max(Env2DC);  % normalize
Env2DC = Env2DC .* (CALIB_PDR.SOUNDS_env_depth/100); % AM depth (as a percent)
Env2DC = Env2DC + 1 - (CALIB_PDR.SOUNDS_env_depth/100);

% set rms amplitude for envelopes:
% calculate multiplier to equalize rms with min rms
r=sqrt((length(Env1DC)*CALIB_PDR.SOUNDS_rms^2)/sum(Env1DC.^2));
Env1DC=r.*Env1DC;
r=sqrt((length(Env2DC)*CALIB_PDR.SOUNDS_rms^2)/sum(Env2DC.^2));
Env2DC=r.*Env2DC;

% get correlation coefficient (envelopes)
R=corrcoef(Env1DC,Env2DC);
CALIB_PDR.SOUNDS_env_correlation = R(2,1); % correlation coefficient

% Delay to make "lead" and "lag" carriers
Env1DC = [Env1DC zeros(1,DelayPnts)];
Env2DC = [zeros(1,DelayPnts) Env2DC];
Noise1 = [Noise1 zeros(1,DelayPnts)];
Noise2 = [zeros(1,DelayPnts) Noise2];

% window (i.e., gate) out onset/offset time disparity
Env1DC = Env1DC(DelayPnts:StimPnts);
Env2DC = Env2DC(DelayPnts:StimPnts);
Noise1 = Noise1(DelayPnts:StimPnts);
Noise2 = Noise2(DelayPnts:StimPnts);

% ramp envelopes on/off
Env1DC = rampSounds(Env1DC, SR, CALIB_PDR.SOUNDS_ramp); % stim envelope
Env2DC = rampSounds(Env2DC, SR, CALIB_PDR.SOUNDS_ramp); % stim envelope

% multiply with envelopes
Noise1 = Noise1 .* Env1DC;
Noise2 = Noise2 .* Env2DC;

CALIB_PDR.LEAD_sound = Noise1;
CALIB_PDR.LAG_sound = Noise2;

% sound buffer setup
function soundBufferSetup_calib()
global CALIB_PDR

len_buf = CALIB_PDR.buf_pts;
len_stim = length(CALIB_PDR.LEAD_sound);
lead_stim=zeros(1,len_buf);
lag_stim=lead_stim;
pad = ceil((len_buf-len_stim)/2);
lead_stim = [zeros(1,pad) CALIB_PDR.LEAD_sound zeros(1,pad+1)];
lag_stim = [zeros(1,pad) CALIB_PDR.LAG_sound zeros(1,pad+1)];
CALIB_PDR.LEAD_sound = lead_stim(1:CALIB_PDR.buf_pts);
CALIB_PDR.LAG_sound = lag_stim(1:CALIB_PDR.buf_pts);

% initialize TDT and set up for calibrations
function init_setup(hObject,eventdata)

% CHECK IF IT'S OKAY TO CONTINUE
button = questdlg('You need to reset the TDT before continuing. Click OKAY when you''ve done this, or CANCEL otherwise.',...
'Continue Operation','OKAY','CANCEL','OKAY');
if strcmp(button,'OKAY')
elseif strcmp(button,'CANCEL')
   return;
end
% SETUP PARAMETERS
global CALIB_PDR H TDT
CALIB_PDR = struct(...                        % MAIN PARAMETERS:
    'calib',1,...                       % flag for calibrations
    'owl_id',0,...                      % for owl ID #
    'virtual',0,...                     % Freefield: virtual = 0, Headphones: virtual = 1
    'record',1,...                      % flag for recording CALIB_PDR trace
    'ntrials',[],...                   % no. of trials in a session
    'buf_pts',51269,...              
    'stim_Fs',48828,...                 % sampling rate for sound production
    'npts_totalplay',[],...            % total no. pts in the session
    'len_session',[], ...               % length of session (in minutes)
    'starttime',[], ...                 % session start time
    'stoptime', [], ...                 % session stop time
    'code_path', 'c:\alex\code\',...    % path to code
    'data_path', 'c:\alex\calib_data\',...     % flag indicates that AD recording (pupillometer) will be needed
    'base_atten',0,...                  % attenuation value to send to TDT (combining scale_val and atten gives a certain SPL in dB -- This needs to be calibrated!!!)
    'filename',[],...                   % file name for storing session data
    ...
    ...                                 % CALIBRATION PARAMETERS:
    'calibtype',[],...            % What are we calibrating? (Knowles alone, Knowles in owl's ears)
    'knowles_file',[],...              % equals 1 if calibrating Knowles voltage output
    'comments','lag discrimination suppression study (freefield). Intraural Calibrations with Knowles mics.',...             % extra info about sounds
    'speaker_numbers',1:9,...     % speaker identification numbers (LAG speakers = 2...9, speaker 1 is reserved for the LEAD!!!!)
    'speaker_sequence',[],...     % sequence of speakers to use
    'locations',[],...            % a 2xnlocs vector of location coordinates (El,Az) ...
    'coord_sequence',[],...       % sequence of location coordinates (El,Az) ... should be selected from locations
    'locID_sequence',[],...       % sequence of location IDs (for speaker selection)
    'nlocs',8,...                 % calibrate for x locations (usually 8 ... one lead location {not counted} and 8 lag choices)
    'nscales',80,...              % number of scales used for equalizing
    'scales_2_try_for_cutoffs',10.^([0:.09:4.5 log10(32760)]),... % these are the scales to try to avoid nonlinearities due to speaker limitations and noise floor, etc.
    ...
    ...
    'LEAD_pos',-60,...                  % default azimuth (degrees) for lead sound
    'LEAD_sound',[],...                 % LEAD sound (to be calculated)
    ...
    ...                                 % LAG SOUND PARAMETERS:
    'LAG_hab_pos',-50,...                % default azimuth for lag sound
    'LAG_sound',[],...                  % lag sound (to be calculated)             .
    ...
    ...                                 % SOUND PARAMETERS:
    'SOUNDS_rms',0.5,...                % rms amplitude setting for envelopes
    'SOUNDS_length',1000,...              % 1000 ms sounds for tdt calibrations
    'SOUNDS_delay',3,...                % ongoing envelope disparity between lead/LAG_sound sounds
    'SOUNDS_mix',1,...                  % percent mix (100% for calibrations)
    'SOUNDS_env_correlation',[],...     % calculated correlation coefficient (envelopes)
    'SOUNDS_states',[73 167 617 364],...% state values for random no generator (to ensure that sounds are reproducible)
    ...                                 % formatted as such: [carrier_state env_state decorr_env_state1 decorr_env_state2]
    'SOUNDS_carrier_bandwidth',[2000 11000],... % using 2 - 11 kHz bandwidth for carriers (same as Caitlin/Brian head saccade exp't)
    'SOUNDS_env_bandwidth',[1 150],...          % bandwidth of envelopes (should be 1 to 150 Hz to replicate Nelson/Baxter study)
    'SOUNDS_amplitude',60,...                   % Keep at 60 (this gives amplitudes suitable for the TDT)
    'SOUNDS_env_depth',100,...                  % depth of envelope modulation
    'SOUNDS_ramp',5,...                         % ramp length for sounds (ms)
    'SOUNDS_azimuths',[-60 -50 -25 -5 5 15 30 45 60],...            % actual speaker azimuths (don't change unless moving speakers) ... 1st azimuth is LEAD!!!!
    'SOUNDS_location_sequence',[]);           % sequence of locations for the session (1st row: lead, 2nd row: lag)

CALIB_PDR.calibtype = 'Knowles in owl''s ears'; % calibrating scales vs. voltage using Knowles in owls ears
CALIB_PDR.left_rms_voltage = [];
snd_type = menu('Type of sound?','100% Envelope Depth','Flat Envelope');
if snd_type == 2
    CALIB_PDR.SOUNDS_type = 'Flat Envelope';
    CALIB_PDR.SOUNDS_env_depth = 1E-8; % make envelope depth really small
else
    CALIB_PDR.SOUNDS_type = '100% Envelope Depth';
end

% % estimate session duration
% % est_time = CALIB_PDR.nlocs*length(CALIB_PDR.scales)*(CALIB_PDR.buf_pts/CALIB_PDR.stim_Fs);
% % est_time = (est_time/60);
% % min = floor(est_time);
% % sec = (est_time - floor(est_time))*60;
% % CALIB_PDR.len_session = [min sec];
% % msgbox(['Estimated session duration = ' num2str(min) ' minutes and ' num2str(sec) ' seconds']);
CALIB_PDR = orderfields(CALIB_PDR); % order fields by ASCII dictionary order

% locations
CALIB_PDR.locations(1,:) = zeros(1,CALIB_PDR.nlocs+1); % zero elevation throughout
CALIB_PDR.locations(2,:) = CALIB_PDR.SOUNDS_azimuths;


figure(H.fig);
axis off;
txt(1)=text(.55,.9,'Speakers:'); txt(2)=text(.70,.9,'Elevations:'); txt(3)=text(.85,.9,'Azimuths:');
cnt=3;
for i=1:length(CALIB_PDR.speaker_numbers); 
    cnt=cnt+1; txt(cnt)=text(.55,.9-.05*i,num2str(CALIB_PDR.speaker_numbers(i))); 
end
for i=1:length(CALIB_PDR.locations(1,:)); 
    cnt=cnt+1; txt(cnt)=text(.7,.9-.05*i,num2str(CALIB_PDR.locations(1,i))); 
end
for i=1:length(CALIB_PDR.locations(2,:)); 
    cnt=cnt+1; txt(cnt)=text(.85,.9-.05*i,num2str(CALIB_PDR.locations(2,i))); 
end
set(txt,'HorizontalAlignment','right');
H.abort=uicontrol('Parent',H.fig,'Style','pushbutton',...
    'Units','normalized','Position',[.4 .9 .2 .1],...
    'Callback','uiresume(gcbf)',...
    'String','ABORT','Tag','ABORT');
H.continue=uicontrol('Parent',H.fig,'Style','pushbutton',...
    'Units','normalized','Position',[.65 .9 .2 .1],...
    'Callback','uiresume(gcbf)',...
    'String','CONTINUE','Tag','CONTINUE');
uiwait(gcf);
delete(txt); delete(H.abort); delete(H.continue);
if strcmp(get(gco,'Tag'),'ABORT')
    error('CALIB:SpkChk','Something wrong with the speaker locs!');
end

% make sounds for calibration (relies on the 'AMStim' function)
AMStim_calib;
% NOTE: BUFFER SETUP MAKES BOTH LEAD AND LAG THE SAME (USING LEAD SOUND
% FROM AMStim_calib) ... SO, the rms amplitude is the same for both!
soundBufferSetup_calib;

CALIB_PDR = orderfields(CALIB_PDR); % order fields by ASCII dictionary order

q=clock;
y=num2str(q(1));y=y(3:4);
m=num2str(q(2));if size(m,2)<2;m=['0' m];end
d=num2str(q(3));if size(d,2)<2;d=['0' d];end

cd(CALIB_PDR.code_path);
tmp = pwd;
if tmp(end-3:end) == 'code'
    CALIB_PDR.data_path = [tmp(1:end-4) 'calib_data\'];
else
    error('CALIB:PathSetup','Something could be wrong with the path setup!')
end


cd(CALIB_PDR.data_path);
Prompt='Enter OWL ID # for this calibration session';
Title='Owl ID';
Answer = INPUTDLG(Prompt,Title);
CALIB_PDR.owl_id=str2num(Answer{1});
set(H.owl_id2,'String',Answer{1},'BackgroundColor','w');
CALIB_PDR.filename = ['intraural_calib_' y m d '_' num2str(CALIB_PDR.owl_id) 'A'];
count = double('A'+0);
while exist ([CALIB_PDR.filename '.mat'],'file');
    count = count + 1;
    if count > 90
        disp('There are already several files with similar names!');
        CALIB_PDR.filename = input('Enter a unique filename for this session: ', 's');
        break;
    else
        CALIB_PDR.filename(end) = char(count);
    end
end
set(H.intraural2,'String',[CALIB_PDR.data_path CALIB_PDR.filename '.mat']);

% determine begin/end of stimulus
tmp=find(CALIB_PDR.LEAD_sound~=0);
if isempty(tmp)
    tmp = find(CALIB_PDR.LAG_sound);
end
CALIB_PDR.begin_pts = tmp(1);
CALIB_PDR.end_pts = tmp(end);

% INITIALIZE TDT
h=warndlg('CHANNEL 0 = LEFT EAR, CHANNEL 1 = RIGHT EAR ... OKAY???','warning');
uiwait(h);

% initialize all SystemII hardware
if(S232('S2init',0,'INIT_PRIMARY',1000)==0)
    warndlg('FAILED to initialize a primary process','warning');
    return;
else
    disp('Initialized primary process');
end

if(S232('APlock',100, 0)==0)
    warndlg('FAILED to get AP lock for initialization','warning');
    return;
else
    disp('AP lock in initiation');
end
if(S232('XBlock',100, 0)==0)
    warndlg('FAILED to get XB lock for initialization','warning');
    S232('APunlock',0);
    warndlg('AP unlock in initiation','warning');
    return;
else
    disp('XB lock in initiation');
end

err = S232('getS2err');
switch err
    case 0
    case 1: warndlg('APOS error in initiation','warning'); return;
    case 2: warndlg('XBUS error in initiation','warning'); return;
end


SRATE =  (1/CALIB_PDR.stim_Fs)*10^6; % sampling rate for TDT

% PREPARE PD1 FOR CONVERSION:
s232('PD1clear',1);
s232('PD1fixbug',1);
s232('PD1nstrms',1, 2, 2);
s232('PD1srate',1,SRATE);
s232('PD1npts',1, CALIB_PDR.buf_pts);
s232('PD1clrsched',1);
s232('PD1addsimp',1, s232('IREG',0), s232('DAC',0));
s232('PD1specIB',1, s232('IB',0), s232('IREG',0));
s232('PD1addsimp',1, s232('IREG',1), s232('DAC',1));
s232('PD1specIB',1, s232('IB',1), s232('IREG',1));
s232('PD1setIO',1,.01,9.99,.01,9.99);
s232('PD1specOB',1,s232('OB',0), s232('ADC',0));
s232('PD1specOB',1,s232('OB',1), s232('ADC',1));
% SET PA4 ATTENUATION:
s232('PA4atten',1,0); % NO ATTEN YET (SET LATER)
s232('PA4atten',2,0); % NO ATTEN YET (SET LATER)

start_cnt = 0;
step = CALIB_PDR.ntrials;

% allot buffers for lead and lag sounds & store sounds on AP2 card!
% allot buffers for voltage trace record

if s232('APlock',100,0)==1
    TDT.NPTS = CALIB_PDR.buf_pts;
    
    % play spec list
    TDT.CHA_SEQ = s232('_allot16', 10);
    TDT.CHB_SEQ = s232('_allot16', 10);
    TDT.PLAY_SPEC = s232('_allot16',10);
    s232('dpush',10);
    s232('value',0);
    s232('make',0,TDT.CHA_SEQ);
    s232('make',1,TDT.CHB_SEQ);
    s232('make',2,0);
    s232('qpop16',TDT.PLAY_SPEC);
    
    TDT.BUF_A1 = s232('_allot16', TDT.NPTS);
    TDT.BUF_B1 = s232('_allot16', TDT.NPTS);
    
    TDT.BUF_LEAD = s232('_allotf', TDT.NPTS);
    TDT.BUF_LAG = s232('_allotf', TDT.NPTS);
    lead = CALIB_PDR.LEAD_sound;
    s232('pushf',lead, TDT.NPTS);
    s232('qpopf',TDT.BUF_LEAD);
    lag = CALIB_PDR.LAG_sound;
    s232('pushf',lag, TDT.NPTS);
    s232('qpopf',TDT.BUF_LAG)
    
    % NULL buffer setup
    TDT.BUF_NULL = s232('_allotf', TDT.NPTS);
    s232('pushf',zeros(1,TDT.NPTS),TDT.NPTS);
    s232('qpopf',TDT.BUF_NULL);
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % play sequences
    s232('dpush', 10);
    s232('value', 0);
    s232('make', 0, TDT.BUF_A1);
    s232('make', 1, 1);
    s232('make', 2, 0);
    s232('qpop16', TDT.CHA_SEQ);
    
    s232('dpush', 10);
    s232('value', 0);
    s232('make', 0, TDT.BUF_B1);
    s232('make', 1, 1);
    s232('make', 2, 0);
    s232('qpop16', TDT.CHB_SEQ);
    
    
    % for recording Knowles mic voltage trace
    TDT.RECBUF_L1 = s232('_allot16', TDT.NPTS);
    TDT.RECBUF_R1 = s232('_allot16', TDT.NPTS);
    TDT.TMPBUF = s232('_allot16',TDT.NPTS);
    
    % record spec list
    TDT.REC_SPEC = s232('_allot16', 10);
    TDT.REC_LEFT_SEQ = s232('_allot16', 10);
    TDT.REC_RIGHT_SEQ = s232('_allot16', 10);
    s232('dpush',10);
    s232('value',0);
    s232('make',0,TDT.REC_LEFT_SEQ);
    s232('make',1,TDT.REC_RIGHT_SEQ);
    s232('make',2,0);
    s232('qpop16', TDT.REC_SPEC);
    
    % record sequences
    s232('dpush',10);
    s232('value',0);
    s232('make',0, TDT.RECBUF_L1);
    s232('make',1,1);
    s232('make',2,0);
    s232('qpop16', TDT.REC_LEFT_SEQ);
    
    s232('dpush',10);
    s232('value',0);
    s232('make',0, TDT.RECBUF_R1);
    s232('make',1,1);
    s232('make',2,0);
    s232('qpop16', TDT.REC_RIGHT_SEQ);
    
    s232('APunlock', 0);
else
    disp('Cannot allocate buffers... quitting!')
    return;
end

%write header information to file... saving global variables
set(H.equal_attens_btn,'Enable','on');
set(H.owl_id2,'Enable','on','BackgroundColor','w','String',num2str(CALIB_PDR.owl_id));
set(H.load_knowles_data_btn,'Enable','on');
save ([CALIB_PDR.data_path CALIB_PDR.filename '.mat'],'CALIB_PDR');
str{1} = 'Variables saved in: ';
str{2} = [CALIB_PDR.data_path CALIB_PDR.filename '.mat'];
hMsg=msgbox(str); uiwait(hMsg);

% LOAD PREVIOUSLY GATHERED KNOWLES CALIBRATION DATA
function load_knowles(hObject,eventdata)
global KNOWLES CALIB_PDR H
cd(CALIB_PDR.data_path);
uiopen('knowles*.mat');
CALIB_PDR.knowles_file = [KNOWLES.data_path KNOWLES.filename];
set(H.knowles2,'String',[KNOWLES.data_path KNOWLES.filename '.mat']);

% PERFORM CALIBRATION OF KNOWLES MICS
function run_knowles_calibration(hObject,eventdata)
global KNOWLES CALIB_PDR H
% CHECK IF IT'S OKAY TO CONTINUE
button = questdlg('You need to reset the TDT before continuing. Click OKAY when you''ve done this, or CANCEL otherwise.',...
'Continue Operation','OKAY','CANCEL','OKAY');
if strcmp(button,'OKAY')
elseif strcmp(button,'CANCEL')
   return;
end
KNOWLES=calib_knowles;
CALIB_PDR.knowles_file = [KNOWLES.data_path KNOWLES.filename];
set(H.knowles2,'String',[KNOWLES.data_path KNOWLES.filename '.mat']);

% EQUALIZE SPEAKERS WITH LEAD USING ATTEN VALUES
function equalize_speaker_attens(hObject,eventdata)
% lag speakers always at atten = 0, but lead atten varies
global CALIB_PDR H TDT KNOWLES

cd(CALIB_PDR.data_path);

% MEASURE VOLTAGE OUTPUTS OF EACH SPEAKER
% get lead speaker voltage
hWait=waitbar(0,'Hold on. Testing speaker levels...');

% FIRST, GET RMS VOLTAGE FOR LEAD SPEAKER
s232('PA4atten',1,CALIB_PDR.base_atten);
s232('PA4atten',2,0);
s232('dropall'); % clear the stack
scale = 16000; % middle scale value
loc = 1; % lead speaker
% clear SS1 modules
s232('SS1clear',1);
s232('SS1clear',2);
% playing only lead sound
s232('qpushf',TDT.BUF_LEAD);
s232('scale',scale);
s232('qpop16',TDT.BUF_A1);
s232('qpushf',TDT.BUF_NULL);
s232('scale',0);
s232('qpop16',TDT.BUF_B1);
s232('seqplay',TDT.PLAY_SPEC);
% recording voltage
s232('seqrecord',TDT.REC_SPEC);
s232('PD1arm',1);
s232('PD1go',1);
while(s232('PD1status',1))
    % wait for TDT to finish
end
% pop recorded voltage traces into matlab
if exist('left_tmp')
    clear left_tmp;
end
if exist('right_tmp')
    clear right_tmp;
end

% RECORDING PROCESS:
[left_tmp, right_tmp] = rec_proc([1 0],[1 0],[scale 0],[CALIB_PDR.base_atten 0]);

% calculate rms voltages and average across both ears
left_tmp = left_tmp(CALIB_PDR.begin_pts:CALIB_PDR.end_pts);
right_tmp = right_tmp(CALIB_PDR.begin_pts:CALIB_PDR.end_pts);
left_tmp = left_tmp - mean(left_tmp);
right_tmp = right_tmp - mean(right_tmp);
% calculate rms voltages
left_rms = sqrt(sum(left_tmp.^2)./length(left_tmp));
right_rms = sqrt(sum(right_tmp.^2)./length(right_tmp));
avg_rms = (left_rms + right_rms)/2;
CALIB_PDR.rms_speakers(1) = avg_rms; % lead rms

% GET RMS VOLTAGES FOR THE OTHER SPEAKERS (LAGS)
% loop through speakers
cnt=0;
for loc=CALIB_PDR.speaker_numbers(2:end)
    %loc = ii; %ii+1;
    cnt=cnt+1;
    % SET PA4 ATTENUATION:
    s232('PA4atten',1,0);
    s232('PA4atten',2,CALIB_PDR.base_atten);
    s232('dropall'); % clear the stack
    % clear SS1 modules & switch to correct channel
    s232('SS1clear',1);
    s232('SS1clear',2);
    s232('qpushf',TDT.BUF_NULL); % nothing to lead
    s232('scale',0);
    s232('qpop16',TDT.BUF_A1);
    s232('qpushf',TDT.BUF_LAG); % lag sound
    s232('scale',scale);
    s232('qpop16',TDT.BUF_B1);
    % using SS1 modules
    if loc < 6
        ss_id = 1;
        out_port = loc - 2;
    else
        ss_id = 2;
        out_port = loc - 6;
    end
    s232('SS1mode',ss_id,0); % "QUAD_2_1" == 0
    s232('SS1select',ss_id,out_port,1);
    s232('seqplay',TDT.PLAY_SPEC);
    s232('seqrecord',TDT.REC_SPEC);
    
    s232('PD1arm',1);
    s232('PD1go',1);
    
    while(s232('PD1status',1))
        % wait for TDT to finish
    end
    % pop recorded voltage traces into matlab
    if exist('left_tmp')
        clear left_tmp;
    end
    if exist('right_tmp')
        clear right_tmp;
    end

    % RECORDING PROCESS:
    [left_tmp, right_tmp] = rec_proc([0 1],[0 loc],[0 scale],[0 CALIB_PDR.base_atten]);
    
    % calculate rms voltages and average across both ears
    left_tmp = left_tmp(CALIB_PDR.begin_pts:CALIB_PDR.end_pts);
    right_tmp = right_tmp(CALIB_PDR.begin_pts:CALIB_PDR.end_pts);
    left_tmp = left_tmp - mean(left_tmp);
    right_tmp = right_tmp - mean(right_tmp);
    % calculate rms voltages
    left_rms = sqrt(sum(left_tmp.^2)./length(left_tmp));
    right_rms = sqrt(sum(right_tmp.^2)./length(right_tmp));
    avg_rms = (left_rms + right_rms)/2;
    CALIB_PDR.rms_speakers(cnt+1) = avg_rms; % save avg rms voltage
    waitbar(cnt/length(CALIB_PDR.speaker_numbers(2:end)),hWait);
end
close(hWait);

hWait=waitbar(0,'Hold on. Equalizing each speaker with the lead using attenuation settings.');
% cell array of lead attens
cnt=0;
CALIB_PDR.equalized_lead_attens = {'Speaker IDs',CALIB_PDR.speaker_numbers(2:end);'Lead Attens',NaN*ones(1,length(CALIB_PDR.speaker_numbers(2:end)))};
for jj=CALIB_PDR.speaker_numbers(2:end)
    cnt=cnt+1;
    max_atten=40; min_atten=0;
    spkr_id = jj;
    lead_atten=round((max_atten-min_atten)/2); % start by trying lead_atten=min_atten (zero?)
    s232('dropall'); % clear the stack
    % clear SS1 modules
    s232('SS1clear',1);
    s232('SS1clear',2);
    % using SS1 modules
    loc = spkr_id;
    if loc < 6
        ss_id = 1;
        out_port = loc - 2;
    else
        ss_id = 2;
        out_port = loc - 6;
    end
    s232('SS1mode',ss_id,0); % "QUAD_2_1" == 0
    s232('SS1select',ss_id,out_port,1);
    
    % only playing lead
    s232('qpushf',TDT.BUF_LEAD); % lead
    s232('scale',scale);
    s232('qpop16',TDT.BUF_A1);
    s232('qpushf',TDT.BUF_NULL); % no lag
    s232('scale',0);
    s232('qpop16',TDT.BUF_B1);
    
    % difference between rms of lead and lag at atten=0
    del_rms = CALIB_PDR.rms_speakers(1) - CALIB_PDR.rms_speakers(cnt+1);
    last_atten=Inf;
    while last_atten ~= lead_atten
        drawnow;
        % SET PA4 ATTENUATION:
        s232('PA4atten',1,lead_atten+CALIB_PDR.base_atten);
        s232('PA4atten',2,0);
        s232('seqplay',TDT.PLAY_SPEC);
        s232('seqrecord',TDT.REC_SPEC);
        s232('PD1arm',1);
        s232('PD1go',1);
        while(s232('PD1status',1))
            % wait for TDT to finish
        end
        % RECALCULATION OF DEL_RMS FOR THIS ATTEN
        % pop recorded voltage traces into matlab
        if exist('left_tmp')
            clear left_tmp;
        end
        if exist('right_tmp')
            clear right_tmp;
        end
        
        % RECORDING PROCESS:
        [left_tmp, right_tmp] = rec_proc([1 0],[1 0],[scale 0],[(lead_atten+CALIB_PDR.base_atten) 0]);
        
        % calculate rms voltages and average across both ears
        left_tmp = left_tmp(CALIB_PDR.begin_pts:CALIB_PDR.end_pts);
        right_tmp = right_tmp(CALIB_PDR.begin_pts:CALIB_PDR.end_pts);
        left_tmp = left_tmp - mean(left_tmp);
        right_tmp = right_tmp - mean(right_tmp);
        % calculate rms voltages
        left_rms = sqrt(sum(left_tmp.^2)./length(left_tmp));
        right_rms = sqrt(sum(right_tmp.^2)./length(right_tmp));
        avg_rms = (left_rms + right_rms)/2;
        last_del_rms = del_rms;
        del_rms = avg_rms - CALIB_PDR.rms_speakers(cnt+1);
        last_atten=lead_atten;
        if del_rms > 0
            min_atten=lead_atten;
            lead_atten=min_atten+round((max_atten-min_atten)/2);
        elseif del_rms < 0
            max_atten=lead_atten;
            lead_atten=min_atten+round((max_atten-min_atten)/2);
        end
    end
    % save the BEST lead_atten for this speaker
    idx = find(CALIB_PDR.equalized_lead_attens{1,2}==spkr_id);
    CALIB_PDR.equalized_lead_attens{2,2}(idx) = lead_atten;
    waitbar(cnt/length(CALIB_PDR.speaker_numbers(2:end)),hWait);
    
end % loop for equalizing lead_attens
close(hWait);
% plot these lead_attens
hBar = figure; bar(CALIB_PDR.equalized_lead_attens{2,2});
xlabel('Speaker IDs'); ylabel('Attenuation Value of Lead');
set(gca,'XTickLabel',CALIB_PDR.equalized_lead_attens{1,2});
h = warndlg('Click Okay to Continue...');
uiwait(h);
close(hBar)
set(H.equal_scales_btn,'Enable','on');
%write header information to file... saving global variables
save ([CALIB_PDR.data_path CALIB_PDR.filename '.mat'],'CALIB_PDR');
str{1} = 'Variables saved in: ';
str{2} = [CALIB_PDR.data_path CALIB_PDR.filename '.mat'];
hMsg=msgbox(str); uiwait(hMsg);

cd(CALIB_PDR.code_path);


% EQUALIZE LEAD/LAG WITH SCALE VALUES
function equalize_speaker_scales(hObject,eventdata)
global CALIB_PDR H TDT KNOWLES

cd(CALIB_PDR.data_path);

% for storing speaker scale calibration data
CALIB_PDR.speaker_data = struct('lag_loc',[],'scales_lead',[],'avg_rms_lead',[],'coeffs_lead_fit',...
    [],'rsq_lead_fit',[],'scales_lag',[],'avg_rms_lag',[],'coeffs_lag_fit',[],'rsq_lag_fit',[],...
    'scales_both',[],'avg_rms_both',[],'coeffs_both_fit_lead_scales',[],'rsq_both_fit_lead_scales',[],...
    'coeffs_both_fit_lag_scales',[],'rsq_both_fit_lag_scales',[]);
CALIB_PDR.speaker_data(1:length(CALIB_PDR.speaker_numbers(2:end)),1)=CALIB_PDR.speaker_data;
for i0=1:length(CALIB_PDR.speaker_numbers(2:end))
    CALIB_PDR.speaker_data(i0).lag_loc=CALIB_PDR.speaker_numbers(i0+1);
end

%regression plot setup
screen_size = get(0, 'ScreenSize');
hSpk=figure; % figure for lead and lag regression fits
set(hSpk, 'Position', [0.02*screen_size(3) 0.05*screen_size(4) 0.45*screen_size(3) 0.9*screen_size(4)] );
hBoth=figure;
set(hBoth, 'Position', [0.48*screen_size(3) 0.05*screen_size(4) 0.45*screen_size(3) 0.9*screen_size(4)] );
dim=ceil(sqrt(length(CALIB_PDR.speaker_numbers(2:end))));
a=0.05; %alpha
scales2try=CALIB_PDR.scales_2_try_for_cutoffs;
ntests=CALIB_PDR.nscales;
hWait=waitbar(0,'Hold on. Equalizing scale values for each speaker...');
i1=0;
cnt=0;
while i1 <= length(CALIB_PDR.speaker_numbers(2:end)) % loop through all the lag speakers
    if i1~=0
        button = questdlg('Do you want to redo the last location?',...
            'REDO','Yes','NO','NO');
    else
        button='NO';
    end
    if strcmp(button,'Yes')
        % do not increment
        figure(hSpk); subplot(dim,dim,i1); cla;
        figure(hBoth); subplot(dim,dim,i1); cla;
        figure(hWait);
    elseif strcmp(button,'NO')
        i1=i1+1;
        if i1 <= length(CALIB_PDR.speaker_numbers(2:end))
            loc=CALIB_PDR.speaker_numbers(i1+1); % increment to get speaker location
            cnt=cnt+1;
        end
    end
    % exit while loop if done with all speakers
    if i1 > length(CALIB_PDR.speaker_numbers(2:end))
        break;
    end
    drawnow;
    
    % SET CUTOFFS FOR LEAD: play scales throughout TDT range and let user
    % select cutoffs to avoid noise floor and speaker limits in regression
    % fits
    avg_rms=[];
    scales=scales2try; % gives a range of scales spread across TDT limits (0...32760)
    % clear SS1 modules & switch to correct channel
    s232('dropall'); % clear stack
    % SET PA4 ATTENUATION:
    idx = find(CALIB_PDR.equalized_lead_attens{1,2}==loc);
    lead_atten = CALIB_PDR.equalized_lead_attens{2,2}(idx);
    s232('PA4atten',1,lead_atten+CALIB_PDR.base_atten);
    s232('PA4atten',2,0);
    s232('SS1clear',1);
    s232('SS1clear',2);
    for i2=1:length(scales) % loop through all the scale values
        s232('dropall'); % clear stack
        % just playing lead sound
        s232('qpushf',TDT.BUF_LEAD);
        s232('scale',scales(i2));
        s232('qpop16',TDT.BUF_A1);
        s232('qpushf',TDT.BUF_NULL);
        s232('scale',0);
        s232('qpop16',TDT.BUF_B1);
        s232('seqplay',TDT.PLAY_SPEC);
        % recording voltage
        s232('seqrecord',TDT.REC_SPEC);
        s232('PD1arm',1);
        s232('PD1go',1);
        while(s232('PD1status',1))
            % wait for TDT to finish
        end
        % pop recorded voltage traces into matlab
        if exist('left_tmp')
            clear left_tmp;
        end
        if exist('right_tmp')
            clear right_tmp;
        end
        % RECORDING PROCESS:
        [left_tmp, right_tmp] = rec_proc([1 0],[1 0],[scales(i2) 0],[(lead_atten+CALIB_PDR.base_atten) 0]);
        % calculate rms voltages and average across both ears
        left_tmp = left_tmp(CALIB_PDR.begin_pts:CALIB_PDR.end_pts);
        right_tmp = right_tmp(CALIB_PDR.begin_pts:CALIB_PDR.end_pts);
        left_tmp = left_tmp - mean(left_tmp);
        right_tmp = right_tmp - mean(right_tmp);
        % calculate rms voltages
        left_rms = sqrt(sum(left_tmp.^2)./length(left_tmp));
        right_rms = sqrt(sum(right_tmp.^2)./length(right_tmp));
        avg_rms(i2) = (left_rms + right_rms)/2;
    end % lead cutoff loop
    % select cutoffs
    lead_dbs = (1/KNOWLES.coeffs(2))*log( (avg_rms - KNOWLES.coeffs(3)) ./ KNOWLES.coeffs(1) );
    [lo hi] = select_cutoffs(log10(scales),lead_dbs);
    
    % LEAD ALONE: play scales from LEAD at equalized atten and do a regression fit
    avg_rms=[];
    if hi>log10(32760)
        hi=log10(32760);
    end
    if lo<0
        lo=0;
    end
    scales_lead=10.^(lo:(hi-lo)/ntests:hi); % range of scales inside cutoff limits
    % clear SS1 modules & switch to correct channel
    s232('dropall'); % clear stack
    % SET PA4 ATTENUATION:
    idx = find(CALIB_PDR.equalized_lead_attens{1,2}==loc);
    lead_atten = CALIB_PDR.equalized_lead_attens{2,2}(idx);
    s232('PA4atten',1,lead_atten+CALIB_PDR.base_atten);
    s232('PA4atten',2,0);
    s232('SS1clear',1);
    s232('SS1clear',2);
    for i3=1:length(scales_lead) % loop through all the scale values
        s232('dropall'); % clear stack
        % just playing lead sound
        s232('qpushf',TDT.BUF_LEAD);
        s232('scale',scales_lead(i3));
        s232('qpop16',TDT.BUF_A1);
        s232('qpushf',TDT.BUF_NULL);
        s232('scale',0);
        s232('qpop16',TDT.BUF_B1);
        s232('seqplay',TDT.PLAY_SPEC);
        % recording voltage
        s232('seqrecord',TDT.REC_SPEC);
        s232('PD1arm',1);
        s232('PD1go',1);
        while(s232('PD1status',1))
            % wait for TDT to finish
        end
        % pop recorded voltage traces into matlab
        if exist('left_tmp')
            clear left_tmp;
        end
        if exist('right_tmp')
            clear right_tmp;
        end
        % RECORDING PROCESS:
        [left_tmp, right_tmp] = rec_proc([1 0],[1 0],[scales_lead(i3) 0],[(lead_atten+CALIB_PDR.base_atten) 0]);
        % calculate rms voltages and average across both ears
        left_tmp = left_tmp(CALIB_PDR.begin_pts:CALIB_PDR.end_pts);
        right_tmp = right_tmp(CALIB_PDR.begin_pts:CALIB_PDR.end_pts);
        left_tmp = left_tmp - mean(left_tmp);
        right_tmp = right_tmp - mean(right_tmp);
        % calculate rms voltages
        left_rms = sqrt(sum(left_tmp.^2)./length(left_tmp));
        right_rms = sqrt(sum(right_tmp.^2)./length(right_tmp));
        avg_rms(i3) = (left_rms + right_rms)/2;
    end % lead loop
    CALIB_PDR.speaker_data(i1).scales_lead = scales_lead;
    CALIB_PDR.speaker_data(i1).avg_rms_lead = avg_rms;
    
    waitbar((1/3)*cnt/length(CALIB_PDR.speaker_numbers(2:end)),hWait);
    
    % regression fits (log10(scale) vs. dB) for lead and lag speakers
    figure(hSpk); 
    info_flg=0; % no fit data on plots
    h(i1)=subplot(dim,dim,i1);
    hold on;
    xrange = log10(1:1:35000);
    % regression of avg rms for lead
    colr = [1 0 0];
    lead_xes = log10(CALIB_PDR.speaker_data(i1).scales_lead); % log10(scales) for lead speaker
    lead_yes = (1/KNOWLES.coeffs(2))*log( (CALIB_PDR.speaker_data(i1).avg_rms_lead - KNOWLES.coeffs(3)) ./ KNOWLES.coeffs(1) ); % decibels (calibrated for knowles) lead speaker
    hold on;
    [CALIB_PDR.speaker_data(i1).rsq_lead_fit, CALIB_PDR.speaker_data(i1).coeffs_lead_fit] = regress_stats(lead_xes,lead_yes,a,xrange,colr,info_flg);
    lead_el=CALIB_PDR.locations(1,1); lead_az=CALIB_PDR.locations(2,1);
    
    % title string
    title_string=[];
    title_string{1} = ['Lag = Speaker #' num2str(loc) ' Lead Atten = ' num2str(lead_atten)];
    title_string{2} = ['Locs (Lead): (' num2str(lead_el) ',' num2str(lead_az) ')'];
    title_string{3} = ['RSQs Lead = ' num2str(CALIB_PDR.speaker_data(i1).rsq_lead_fit)];
    title(title_string,'FontSize',8);
    % axes labels
    xlabel('log10(scales)','FontSize',8);
    ylabel('SPL (dB, ABL)','FontSize',8);
    drawnow;
    
    % SET CUTOFFS FOR LAG: play scales throughout TDT range and let user
    % select cutoffs to avoid noise floor and speaker limits in regression
    % fits
    avg_rms=[];
    scales=scales2try; % gives a range of scales spread across TDT limits (0...32760)
    % clear SS1 modules & switch to correct channel
    s232('dropall'); % clear stack
    % SET PA4 ATTENUATION:
    idx = find(CALIB_PDR.equalized_lead_attens{1,2}==loc);
    lead_atten = CALIB_PDR.equalized_lead_attens{2,2}(idx);
    s232('PA4atten',1,0);
    s232('PA4atten',2,CALIB_PDR.base_atten);
    s232('SS1clear',1);
    s232('SS1clear',2);
    % using SS1 modules
    if loc < 6
        ss_id = 1;
        out_port = loc - 2;
    else
        ss_id = 2;
        out_port = loc - 6;
    end
    s232('SS1mode',ss_id,0); % "QUAD_2_1" == 0
    s232('SS1select',ss_id,out_port,1);
    for i4=1:length(scales) % loop through all the scale values
        s232('dropall'); % clear stack
        % just playing lag sound
        s232('qpushf',TDT.BUF_NULL);
        s232('scale',0);
        s232('qpop16',TDT.BUF_A1);
        s232('qpushf',TDT.BUF_LAG);
        s232('scale',scales(i4));
        s232('qpop16',TDT.BUF_B1);
        s232('seqplay',TDT.PLAY_SPEC);
        % recording voltage
        s232('seqrecord',TDT.REC_SPEC);
        s232('PD1arm',1);
        s232('PD1go',1);
        while(s232('PD1status',1))
            % wait for TDT to finish
        end
        % pop recorded voltage traces into matlab
        if exist('left_tmp')
            clear left_tmp;
        end
        if exist('right_tmp')
            clear right_tmp;
        end
        % RECORDING PROCESS:
        [left_tmp, right_tmp] = rec_proc([0 loc],[1 0],[0 scales(i4)],[0 CALIB_PDR.base_atten]);
        % calculate rms voltages and average across both ears
        left_tmp = left_tmp(CALIB_PDR.begin_pts:CALIB_PDR.end_pts);
        right_tmp = right_tmp(CALIB_PDR.begin_pts:CALIB_PDR.end_pts);
        left_tmp = left_tmp - mean(left_tmp);
        right_tmp = right_tmp - mean(right_tmp);
        % calculate rms voltages
        left_rms = sqrt(sum(left_tmp.^2)./length(left_tmp));
        right_rms = sqrt(sum(right_tmp.^2)./length(right_tmp));
        avg_rms(i4) = (left_rms + right_rms)/2;
    end % lag cutoff loop
    % select cutoffs
    lag_dbs = (1/KNOWLES.coeffs(2))*log( (avg_rms - KNOWLES.coeffs(3)) ./ KNOWLES.coeffs(1) );
    [lo hi] = select_cutoffs(log10(scales),lag_dbs);
    if hi>log10(32760)
        hi=log10(32760);
    end
    if lo<0
        lo=0;
    end
    % LAG ALONE: play scales from LAG and do a regression fit
    avg_rms=[];
    scales_lag=10.^(lo:(hi-lo)/ntests:hi); % choose a range of scales inside cutoff range
    % clear SS1 modules & switch to correct channel
    s232('dropall'); % clear stack
    % SET PA4 ATTENUATION:
    idx = find(CALIB_PDR.equalized_lead_attens{1,2}==loc);
    lead_atten = CALIB_PDR.equalized_lead_attens{2,2}(idx);
    s232('PA4atten',1,0);
    s232('PA4atten',2,CALIB_PDR.base_atten);
    s232('SS1clear',1);
    s232('SS1clear',2);
    % using SS1 modules
    if loc < 6
        ss_id = 1;
        out_port = loc - 2;
    else
        ss_id = 2;
        out_port = loc - 6;
    end
    s232('SS1mode',ss_id,0); % "QUAD_2_1" == 0
    s232('SS1select',ss_id,out_port,1);
    for i5=1:length(scales_lag) % loop through all the scale values
        s232('dropall'); % clear stack
        % just playing lag sound
        s232('qpushf',TDT.BUF_NULL);
        s232('scale',0);
        s232('qpop16',TDT.BUF_A1);
        s232('qpushf',TDT.BUF_LAG);
        s232('scale',scales_lag(i5));
        s232('qpop16',TDT.BUF_B1);
        s232('seqplay',TDT.PLAY_SPEC);
        % recording voltage
        s232('seqrecord',TDT.REC_SPEC);
        s232('PD1arm',1);
        s232('PD1go',1);
        while(s232('PD1status',1))
            % wait for TDT to finish
        end
        % pop recorded voltage traces into matlab
        if exist('left_tmp')
            clear left_tmp;
        end
        if exist('right_tmp')
            clear right_tmp;
        end
        % RECORDING PROCESS:
        [left_tmp, right_tmp] = rec_proc([0 1],[0 loc],[0 scales_lag(i5)],[0 CALIB_PDR.base_atten]);
        % calculate rms voltages and average across both ears
        left_tmp = left_tmp(CALIB_PDR.begin_pts:CALIB_PDR.end_pts);
        right_tmp = right_tmp(CALIB_PDR.begin_pts:CALIB_PDR.end_pts);
        left_tmp = left_tmp - mean(left_tmp);
        right_tmp = right_tmp - mean(right_tmp);
        % calculate rms voltages
        left_rms = sqrt(sum(left_tmp.^2)./length(left_tmp));
        right_rms = sqrt(sum(right_tmp.^2)./length(right_tmp));
        avg_rms(i5) = (left_rms + right_rms)/2;
    end % lag loop
    CALIB_PDR.speaker_data(i1).scales_lag = scales_lag;
    CALIB_PDR.speaker_data(i1).avg_rms_lag = avg_rms;
    
    % regression fits (log10(scale) vs. dB) for lead and lag speakers
    figure(hSpk); 
    info_flg=0; % no fit data on plots
    h(i1)=subplot(dim,dim,i1);
    hold on;
    xrange = log10(1:1:35000);
    lead_xes = log10(CALIB_PDR.speaker_data(i1).scales_lead); % log10(scales) for lead speaker
    lead_yes = (1/KNOWLES.coeffs(2))*log( (CALIB_PDR.speaker_data(i1).avg_rms_lead - KNOWLES.coeffs(3)) ./ KNOWLES.coeffs(1) ); % decibels (calibrated for knowles) lead speaker
    lead_el=CALIB_PDR.locations(1,1); lead_az=CALIB_PDR.locations(2,1);
    % regression of avg rms for lag
    colr = [0 0 1];
    lag_xes = log10(CALIB_PDR.speaker_data(i1).scales_lag); % log10(scales) for lag speaker
    lag_yes = (1/KNOWLES.coeffs(2))*log( (CALIB_PDR.speaker_data(i1).avg_rms_lag - KNOWLES.coeffs(3)) ./ KNOWLES.coeffs(1) ); % decibels (calibrated for knowles) for lag speaker
    hold on;
    [CALIB_PDR.speaker_data(i1).rsq_lag_fit, CALIB_PDR.speaker_data(i1).coeffs_lag_fit] = regress_stats(lag_xes,lag_yes,a,xrange,colr,info_flg);
    tmp_xes = [lead_xes lag_xes]; tmp_yes = [lead_yes lag_yes];
    axis([min(tmp_xes) max(tmp_xes) min(tmp_yes) max(tmp_yes)]);
    lag_el=CALIB_PDR.locations(1,i1+1); lag_az=CALIB_PDR.locations(2,i1+1);
    
    % title string
    title_string=[];
    title_string{1} = ['Lag = Speaker #' num2str(loc) ' Lead Atten = ' num2str(lead_atten)];
    title_string{2} = ['Locs (Lead/Lag): (' num2str(lead_el) ',' num2str(lead_az) ')' ' (' num2str(lag_el) ',' num2str(lag_az) ')'];
    title_string{3} = ['RSQs Lag = ' num2str(CALIB_PDR.speaker_data(i1).rsq_lag_fit) 'Lead = ' num2str(CALIB_PDR.speaker_data(i1).rsq_lead_fit)];
    title(title_string,'FontSize',8);
    % axes labels
    xlabel('log10(scales)','FontSize',8);
    ylabel('SPL (dB, ABL)','FontSize',8);

    waitbar((2/3)*cnt/length(CALIB_PDR.speaker_numbers(2:end)),hWait);
    
    drawnow;
    %% DETERMINE CUTOFFS for both speakers together
    avg_rms=[];
    scales_lead=scales2try; % gives a range of scales spread across TDT limits (0...32760)
    % determine matched scales for lag speaker using fits to data
    log10_scales_lead=log10(scales_lead);
    m_lead=CALIB_PDR.speaker_data(i1).coeffs_lead_fit(1,1); b_lead=CALIB_PDR.speaker_data(i1).coeffs_lead_fit(2,1);
    m_lag=CALIB_PDR.speaker_data(i1).coeffs_lag_fit(1,1); b_lag=CALIB_PDR.speaker_data(i1).coeffs_lag_fit(2,1);
    
    % get matched lag scales and only store valid ones
    log10_scales_lag=(m_lead.*log10_scales_lead+b_lead-b_lag)./m_lag; % calculate matched scales for lag speaker using regression fits
    scales_lag = 10.^(log10_scales_lag);
    idx=find(scales_lag >= 0 & scales_lag <= 32760);
    scales_lag=scales_lag(idx); scales_lead=scales_lead(idx);
    % clear SS1 modules & switch to correct channel
    s232('dropall'); % clear stack
    % SET PA4 ATTENUATION:
    idx = find(CALIB_PDR.equalized_lead_attens{1,2}==loc);
    lead_atten = CALIB_PDR.equalized_lead_attens{2,2}(idx);
    s232('PA4atten',1,lead_atten+CALIB_PDR.base_atten);
    s232('PA4atten',2,CALIB_PDR.base_atten);
    s232('SS1clear',1);
    s232('SS1clear',2);
    % using SS1 modules
    if loc < 6
        ss_id = 1;
        out_port = loc - 2;
    else
        ss_id = 2;
        out_port = loc - 6;
    end
    s232('SS1mode',ss_id,0); % "QUAD_2_1" == 0
    s232('SS1select',ss_id,out_port,1);
    for i6=1:length(scales_lead) % loop through all the scale values
        lead_scale = scales_lead(i6);
        lag_scale = scales_lag(i6);
        s232('dropall'); % clear stack
        % just playing lag sound
        s232('qpushf',TDT.BUF_LEAD);
        s232('scale',lead_scale);
        s232('qpop16',TDT.BUF_A1);
        s232('qpushf',TDT.BUF_LAG);
        s232('scale',lag_scale);
        s232('qpop16',TDT.BUF_B1);
        s232('seqplay',TDT.PLAY_SPEC);
        % recording voltage
        s232('seqrecord',TDT.REC_SPEC);
        s232('PD1arm',1);
        s232('PD1go',1);
        while(s232('PD1status',1))
            % wait for TDT to finish
        end
        % pop recorded voltage traces into matlab
        if exist('left_tmp')
            clear left_tmp;
        end
        if exist('right_tmp')
            clear right_tmp;
        end
        % RECORDING PROCESS:
        [left_tmp, right_tmp] = rec_proc([1 1],[1 loc],[lead_scale lag_scale],[(lead_atten+CALIB_PDR.base_atten) CALIB_PDR.base_atten]);
        % calculate rms voltages and average across both ears
        left_tmp = left_tmp(CALIB_PDR.begin_pts:CALIB_PDR.end_pts);
        right_tmp = right_tmp(CALIB_PDR.begin_pts:CALIB_PDR.end_pts);
        left_tmp = left_tmp - mean(left_tmp);
        right_tmp = right_tmp - mean(right_tmp);
        % calculate rms voltages
        left_rms = sqrt(sum(left_tmp.^2)./length(left_tmp));
        right_rms = sqrt(sum(right_tmp.^2)./length(right_tmp));
        avg_rms(i6) = (left_rms + right_rms)/2;
    end % lead loop
    % select cutoffs
    both_dbs = (1/KNOWLES.coeffs(2))*log( (avg_rms - KNOWLES.coeffs(3)) ./ KNOWLES.coeffs(1) );
    [lo hi] = select_cutoffs(log10(scales_lead),both_dbs);
    if hi>log10(32760)
        hi=log10(32760);
    end
    if lo<0
        lo=0;
    end
    scales_lead=10.^(lo:(hi-lo)/ntests:hi); % choose a range of scales inside cutoff range
    % determine matched scales for lag speaker using fits to data
    log10_scales_lead=log10(scales_lead);
    m_lead=CALIB_PDR.speaker_data(i1).coeffs_lead_fit(1,1); b_lead=CALIB_PDR.speaker_data(i1).coeffs_lead_fit(2,1);
    m_lag=CALIB_PDR.speaker_data(i1).coeffs_lag_fit(1,1); b_lag=CALIB_PDR.speaker_data(i1).coeffs_lag_fit(2,1);
    
    % get matched lag scales and only store valid ones
    log10_scales_lag=(m_lead.*log10_scales_lead+b_lead-b_lag)./m_lag; % calculate matched scales for lag speaker using regression fits
    scales_lag = 10.^(log10_scales_lag);
    % make extra sure scales are within TDT limits
    idx=find(scales_lag >= 0 & scales_lag <= 32760);
    CALIB_PDR.speaker_data(i1).scales_both=NaN*ones(2,length(idx));
    CALIB_PDR.speaker_data(i1).scales_both(2,:)=scales_lag(idx); % store lag scales
    CALIB_PDR.speaker_data(i1).scales_both(1,:)=scales_lead(idx); % store lead scales

    % Play LEAD+LAG (equalized)
    avg_rms=[];
    % clear SS1 modules & switch to correct channel
    s232('dropall'); % clear stack
    % SET PA4 ATTENUATION:
    idx = find(CALIB_PDR.equalized_lead_attens{1,2}==loc);
    lead_atten = CALIB_PDR.equalized_lead_attens{2,2}(idx);
    s232('PA4atten',1,lead_atten+CALIB_PDR.base_atten);
    s232('PA4atten',2,CALIB_PDR.base_atten);
    s232('SS1clear',1);
    s232('SS1clear',2);
    % using SS1 modules
    if loc < 6
        ss_id = 1;
        out_port = loc - 2;
    else
        ss_id = 2;
        out_port = loc - 6;
    end
    s232('SS1mode',ss_id,0); % "QUAD_2_1" == 0
    s232('SS1select',ss_id,out_port,1);
    for i7=1:size(CALIB_PDR.speaker_data(i1).scales_both,2) % loop through all the lead scale values
        lead_scale = CALIB_PDR.speaker_data(i1).scales_both(1,i7);
        lag_scale = CALIB_PDR.speaker_data(i1).scales_both(2,i7);
        s232('dropall'); % clear stack
        % just playing lag sound
        s232('qpushf',TDT.BUF_LEAD);
        s232('scale',lead_scale);
        s232('qpop16',TDT.BUF_A1);
        s232('qpushf',TDT.BUF_LAG);
        s232('scale',lag_scale);
        s232('qpop16',TDT.BUF_B1);
        s232('seqplay',TDT.PLAY_SPEC);
        % recording voltage
        s232('seqrecord',TDT.REC_SPEC);
        s232('PD1arm',1);
        s232('PD1go',1);
        while(s232('PD1status',1))
            % wait for TDT to finish
        end
        % pop recorded voltage traces into matlab
        if exist('left_tmp')
            clear left_tmp;
        end
        if exist('right_tmp')
            clear right_tmp;
        end
        % RECORDING PROCESS:
        [left_tmp, right_tmp] = rec_proc([1 1],[1 loc],[lead_scale lag_scale],[(lead_atten+CALIB_PDR.base_atten) CALIB_PDR.base_atten]);
        % calculate rms voltages and average across both ears
        left_tmp = left_tmp(CALIB_PDR.begin_pts:CALIB_PDR.end_pts);
        right_tmp = right_tmp(CALIB_PDR.begin_pts:CALIB_PDR.end_pts);
        left_tmp = left_tmp - mean(left_tmp);
        right_tmp = right_tmp - mean(right_tmp);
        % calculate rms voltages
        left_rms = sqrt(sum(left_tmp.^2)./length(left_tmp));
        right_rms = sqrt(sum(right_tmp.^2)./length(right_tmp));
        avg_rms(i7) = (left_rms + right_rms)/2;
    end % lead+lag loop
    CALIB_PDR.speaker_data(i1).avg_rms_both = avg_rms;
    
    % regression fit for lead+lag together
    figure(hBoth);
    h_both(i1)=subplot(dim,dim,i1);
    hold on;
    info_flg=0;
    xrange = log10(1:1:32760);
    % regression of avg rms for both speakers together (lead scales)
    
    lag_xes = log10(CALIB_PDR.speaker_data(i1).scales_both(2,:)); % log10(scales) for lag speaker
    lead_xes = log10(CALIB_PDR.speaker_data(i1).scales_both(1,:)); % log10(scales) for lead speaker
    both_yes = (1/KNOWLES.coeffs(2))*log( (CALIB_PDR.speaker_data(i1).avg_rms_both - KNOWLES.coeffs(3)) ./ KNOWLES.coeffs(1) );
    
    hold on;
    % plot/regression for each set of scales (lead/lag)
    colr = [1 0 0];
    [CALIB_PDR.speaker_data(i1).rsq_both_fit_lead_scales, CALIB_PDR.speaker_data(i1).coeffs_both_fit_lead_scales] = regress_stats(lead_xes,both_yes,a,xrange,colr,info_flg);
    colr = [0 0 1];
    hold on;
    [CALIB_PDR.speaker_data(i1).rsq_both_fit_lag_scales, CALIB_PDR.speaker_data(i1).coeffs_both_fit_lag_scales] = regress_stats(lag_xes,both_yes,a,xrange,colr,info_flg);
    lead_el=CALIB_PDR.locations(1,1); lead_az=CALIB_PDR.locations(2,1);
    lag_el=CALIB_PDR.locations(1,i1+1); lag_az=CALIB_PDR.locations(2,i1+1);
    idx = find(CALIB_PDR.equalized_lead_attens{1,2}==loc);
    lead_atten = CALIB_PDR.equalized_lead_attens{2,2}(idx);
    min_xes=min([lag_xes lead_xes]); max_xes=max([lag_xes lead_xes]);
    min_yes=min(both_yes); max_yes=max(both_yes);
    axis([min_xes max_xes min_yes max_yes]);
    % title string
    title_string=[];
    title_string{1} = ['Lag = Speaker #' num2str(loc) ' Lead Atten = ' num2str(lead_atten)];
    title_string{2} = ['Locs (Lead/Lag): (' num2str(lead_el) ',' num2str(lead_az) ')' ' (' num2str(lag_el) ',' num2str(lag_az) ')'];
    title_string{3} = ['RSQ = ' num2str(CALIB_PDR.speaker_data(i1).rsq_both_fit_lead_scales)];
    title(title_string,'FontSize',8);
    % axes labels
    xlabel('log10(scales)','FontSize',8);
    ylabel('SPL (dB, ABL)','FontSize',8);
    hold off;
    
    waitbar(cnt/length(CALIB_PDR.speaker_numbers(2:end)),hWait);
    
    drawnow;
    figure(hWait)
    
end % speaker loop
close(hWait);

% save figures
set(hSpk,'InvertHardcopy','off');
fname = [CALIB_PDR.data_path CALIB_PDR.filename '_speaker_fits'];
saveas(hSpk,fname,'fig');
set(hBoth,'InvertHardcopy','off');
fname = [CALIB_PDR.data_path CALIB_PDR.filename '_dualspeaker_fits'];
saveas(hBoth,fname,'fig');

%write header information to file... saving global variables
save ([CALIB_PDR.data_path CALIB_PDR.filename '.mat'],'CALIB_PDR');
str{1} = 'Variables saved in: ';
str{2} = [CALIB_PDR.data_path CALIB_PDR.filename '.mat'];
hMsg=msgbox(str); uiwait(hMsg);

cd(CALIB_PDR.code_path);

% REGRESSION STATS
function [RSQ, COEFFS] = regress_stats(xes,yes,alfa,xrange,col,info_flg)
% plot data
n=length(yes);
df=length(yes)-2;
for j = 1:n
    plot(xes,yes,'.','Color',col);
end

% determine fit coefficients and CI
[p, S] = polyfit(xes,yes,1);
[Y,DELTA]=polyconf(p,xrange,S,alfa);
m=p(1);
b=p(2);
yfit =  m.* xrange + b;
ypred = (m.*xes + b);
yresid = yes - ypred;
SSresid = sum(yresid.^2);
SStotal = (length(yes)-1) * var(yes);
RSQ = 1 - SSresid/SStotal;

% plot fit with CI
hold on;
plot(xrange,Y,'c-','Color',col);
plot(xrange,Y-DELTA,'r--','Color',col);
plot(xrange,Y+DELTA,'r--','Color',col);
hold off;

% standard error calculation
SSxx = sum(xes.^2)-n*mean(xes)^2;
SSyy = sum(yes.^2)-n*mean(yes)^2;
SSxy = sum(xes.*yes)-n*mean(xes)*mean(yes);
s=sqrt((SSyy-m*SSxy)/(n-2));
SE_m = s/sqrt(SSxx); % standard error for slope
SE_b = s*sqrt((1/n)+mean(xes)^2/SSxx); % standard error for intercept

% determine t statistic
step = 0.01;
t=step;
cum=0;
while cum < (1-alfa)
    tes=-t:step:t;
    tmp=tpdf(tes,df);
    cum=sum(tmp)*step;
    if cum > 0.95
        break;
    else
        t=t+step;
    end
end

% determine coefficient CIs
COEFFS = zeros(3,3);
COEFFS = [m m-SE_m*t m+SE_m*t; b b-SE_b*t b+SE_b*t];

% set axis values
minX=min(xrange);
maxX=max(xrange);
minY=min(Y-DELTA);
maxY=max(Y+DELTA);
axis([minX maxX minY maxY]);

if info_flg
    % plot info
    eqn = ['Fit: y = mx+b = ' num2str(m) 'x + ' num2str(b)];
    text(minX+0.1*(maxX-minX),minY+0.9*(maxY-minY),eqn,'FontSize',8);
    mcoeff=['m = ' num2str(m) ' [' num2str(COEFFS(1,2)) ',' num2str(COEFFS(1,3)) ']'];
    text(minX+0.1*(maxX-minX),minY+0.75*(maxY-minY),mcoeff,'FontSize',8);
    bcoeff=['b = ' num2str(b) ' [' num2str(COEFFS(2,2)) ',' num2str(COEFFS(2,3)) ']'];
    text(minX+0.1*(maxX-minX),minY+0.6*(maxY-minY),bcoeff,'FontSize',8);
end

function [RSQ, COEFFS] = regress_stats_exponential(xes,yes,alfa,xrange,col,beta0)
% plot data
hold on
n=length(yes);
df=length(yes)-3;
for j = 1:n
    plot(xes,yes,'.','Color',col);
end

% determine fit coefficients and R-squared
beta = nlinfit(xes,yes,@exponential_fxn,beta0);
yfit = exponential_fxn(beta,xrange);
ypred = exponential_fxn(beta,xes);
yresid = yes - ypred;
SSresid = sum(yresid.^2);
SStotal = (length(yes)-1) * var(yes);
RSQ = 1 - SSresid/SStotal;

COEFFS = zeros(1,3);
COEFFS = [beta(1) beta(2) beta(3)];

% set axis values
minX=min(xrange);
maxX=max(xrange);
minY=min(yes);
maxY=max(yes);
axis([minX maxX minY maxY]);

% plot info
eqn = ['Fit: y = ' num2str(beta(1)) 'e^{' num2str(beta(2)) 'x} + ' num2str(beta(3)) ];
text(minX+0.1*(maxX-minX),minY+0.9*(maxY-minY),eqn,'FontSize',8);
rsq = ['R^{2} = ' num2str(RSQ)];
text(minX+0.1*(maxX-minX),minY+0.75*(maxY-minY),rsq,'FontSize',8);

% plot fit
plot(xrange,yfit,'k');
hold off

% REGRESSION (EXPONENTIAL)
function y=exponential_fxn(beta,x)
    y=beta(1).*exp(x.*beta(2))+beta(3);
    
function [lo, hi] = select_cutoffs(xes,yes)
% Plots data in a scatter plot and asks user to input lo/hi cuttoffs
% for fitting linear portion of data range
screen_size = get(0, 'ScreenSize');
hFig=figure;
set(hFig, 'Position', [0.02*screen_size(3) 0.05*screen_size(4) 0.8*screen_size(3) 0.8*screen_size(4)] );

scatter(xes,yes,'.');
prompt = {'Enter Lower Cutoff','Enter Upper Cutoff'};
dlg_title = 'Input Cutoffs:';
num_lines = 1;
def = {'',''};
answer = inputdlg(prompt,dlg_title,num_lines,def);
lo=str2num(answer{1});
hi=str2num(answer{2});
close(hFig);
drawnow;

function [left_tmp, right_tmp] = rec_proc(flags,locs,scales,attens);
global TDT CALIB_PDR
% saves mic output to "LEFT" and "RIGHT" files
% Points 0-2 of each buffer = lead location, lead scale, lead atten
% Points 3-5 = lag location, lag scale, lag atten

% LEFT EAR:
s232('qpush16', TDT.RECBUF_L1);
s232('qdup');

% LEAD SOUND PARAMS
if flags(1)
    s232('make',0,locs(1));
    s232('make',1,scales(1));
    s232('make',2,attens(1));
else
    s232('make',0,0);
    s232('make',1,0);
    s232('make',2,0);
end
% LAG SOUND PARAMS
if flags(2)
    s232('make',3,locs(2));
    s232('make',4,locs(2));
    s232('make',5,attens(2));
else
    s232('make',3,0);
    s232('make',4,0);
    s232('make',5,0);
end
% STORE TO FILE:
s232('qpop16', TDT.TMPBUF);
s232('dama2disk16', TDT.TMPBUF, [CALIB_PDR.filename '_LEFT.rec'], 1);
% pop to matlab:
left_tmp = s232('pop16');

% RIGHT EAR:
s232('qpush16', TDT.RECBUF_R1);
s232('qdup');
% LEAD SOUND PARAMS
if flags(1)
    s232('make',0,locs(1));
    s232('make',1,scales(1));
    s232('make',2,attens(1));
else
    s232('make',0,0);
    s232('make',1,0);
    s232('make',2,0);
end
% LAG SOUND PARAMS
if flags(2)
    s232('make',3,locs(2));
    s232('make',4,locs(2));
    s232('make',5,attens(2));
else
    s232('make',3,0);
    s232('make',4,0);
    s232('make',5,0);
end
% STORE TO FILE:
s232('qpop16', TDT.TMPBUF);
s232('dama2disk16', TDT.TMPBUF, [CALIB_PDR.filename '_RIGHT.rec'], 1);
% pop to matlab:
right_tmp=s232('pop16');