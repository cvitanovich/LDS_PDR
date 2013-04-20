% lds_switchyard.m (by Andrew Cvitanovich - 5/5/2012)
% script with functions to set up Lag Discrimination Suppression Exp't using free field
% PDR measurements

% Depends: playrecord_LDS (C program that interfaces with the TDT System II DSP)
% AlexMenu.m (menu script), AlexMenu.fig (figure)
% run_lds_pdr.m (script to "run" the experiment)

% Description of Variables:
% PDR - Structure containing parameters for the session
% including sounds used in the session ...
% and speaker filter coefficients!
% note: These parameters are set up by the setDefaults() function
% vars2pass - variables to pass on to playrecord_LDS

% Functions:
% lds_switchyard() - calls subfunctions in this file
% setDefaults() - sets up default values for all variables
% getBBN() - makes a BBN for sound production
% AMStim() - makes stimuli for the session 
% randPlusMinux() - randomly produces +/-1
% note: remember to check that "state" values are the ones you want for
% reproducible sounds!!!


function [varargout] = lds_switchyard(fcn,varargin)
global PDR
% Call as: lds_switchyard(fcn);

switch fcn
    case 'run_calibration'
        quit_flag = feval(fcn);
        varargout{1} = quit_flag;
    otherwise
        feval(fcn); % no special inputs or outputs
end

function setDefaults()
global PDR
PDR = struct(...                        % MAIN PARAMETERS:
    'bird_id',1073,...                  % bird's id #
    'info_pts',2,...                    % first 2 points in the (decimated) buffer reserved for trial info
    ...                                 % for example, if testing MAAs a comment should go here
    'maa_test_flag',0,...               % set to one if testing MAAs            
    'virtual',0,...                     % Freefield: virtual = 0, Headphones: virtual = 1
    'record',1,...                      % flag for recording pdr trace
    'jitter',2,...                      % jitter trial occurance (2 bufs = +/- 1.34 s)
    'ntrials',[],...                   % no. of trials in a session
    'npretrials',100,...                 % default # of habituating trials before the 1st test trial
    'n_test_trials',15,...              % default # of test trials in a session
    'buf_pts',32768,...                 % # points in a buffer - 32768 pts for a 0.671 second buffer (Fs = 48828 Hz)
    'buf_dur',[],...                    % buffer duration in ms
    'isi_buf',15,...                     % number of empty buffers between trials (10 buffers gives an ISI of ~6.71s (+/-1.34 s) using .671 sec sounds)
    'isi_time',[],...                   % time between trial buffers in seconds (calculated)
    'decimationfactor',5,...            % decimation factor for data collection (using 4 will give 1875Hz sampling rate)
    'stim_Fs',48828,...                 % sampling rate for sound production
    'npts_totalplay',[],...            % total no. pts in the session
    'len_session',[nan nan], ...               % length of session (in minutes)
    'starttime',[], ...                 % session start time
    'stoptime', [], ...                 % session stop time
    'code_path', 'C:\alex\code\',...    % path to code
    'data_path', 'C:\alex\data\',...     % flag indicates that AD recording (pupillometer) will be needed
    'base_atten',0,...                  % attenuation value to send to TDT
    'filename',[],...                   % file name for storing session data
    'exit_flag',0,...                   % exit session (quit) flag
    'plot_trials_handle',[],...                 % handles for the menu plots
    'plot_sounds_handle',[],...
    'outlier_separation',100,...        % defines angular separation considered to be "extreme outlier"
    'outlier_fraction',[],...          % fraction of test trials that are outliers (10% seems fine)
    'n_outlier_trials',0,...            % fraction of tests that are outliers
    'RPs',[],...                        % store response probabilities (From Nelson AM study)
    ...
    ...                                 % LEAD SOUND PARAMETERS:
    'LEAD_pos',-60,...                  % default azimuth (degrees) for lead sound
    'LEAD_sounds',[],...                 % LEAD_sounds sound (to be calculated)
    'LEAD_default_scale',0,...          % will be set to zero for MAA testing
    ...                                 % otherwise, lead/lag scales should be identical
    ...
    ...                                 % LAG SOUND PARAMETERS:
    'LAG_hab_pos',-50,...                % default azimuth for lag sound
    'LAG_sounds',[],...                  % lag sound (to be calculated)
    'LAG_default_scale',0,...       % lead and lag should have same scale (unless testing MAAs)
    ...
    ...                                 % TEST SOUND PARAMETERS:
    'TEST_azimuths',[-25 -5 5 15 30],... %45 60],... % SHOULD BE IN ORDER FROM SMALLEST TO GREATEST SEPARATION!!!!
    'TEST_trial_jitter',5,...           % jitter (test trials)
    'TEST_trial_freq',30,...             % default frequency of test trials (1 out of every X trials)
    ...
    ...                                 % SOUND PARAMETERS:
    'CARRIERS_SWITCHED',0,...           % if the delay is negative this flag will be set to one! (LEAD <-> LAG carriers switched if one)
    'SOUNDS_rms',0.5,...                % setting envelopes to 0.5 rms amplitude (equalizes sound envelope magnitudes)
    'SOUNDS_radius',152,...                % the distance from the speakers to the owl's head position (in cm)
    'SOUNDS_calib_fname',[],...         % filename for speaker calibration parameters
    'SOUNDS_SPL',60,...                  % target decibel level (intraural) for speaker
    'SOUNDS_num_speakers',7,...         % number of speakers (including lead speaker) available
    'SOUNDS_speaker_scales_lead',[],...      % list of calibrated scale values for lead speaker (matched to each lag)
    'SOUNDS_speaker_scales_lag',[],...      % list of calibrated scale values for lag speaker
    'SOUNDS_lead_attens',[],...             %attens for lead speaker
    'SOUNDS_elevations',[0 0 0 0 0 0 0],... %0 0],...
    'SOUNDS_speaker_numbers',1:7,...
    'SOUNDS_azimuths',[-60 -50 -25 -5 5 15 30],... % 45 60],...            % actual speaker azimuths (don't change unless moving speakers)
    'SOUNDS_length',100,...              % length of sounds in ms
    'SOUNDS_carrier_delay',-3,...                % ongoing CARRIER disparity between lead/LAG_sound sounds
    'SOUNDS_env_delay',0,...            % ongoing ENVELOPE disparity (lead/lag)
    'SOUNDS_mix',0,...                % mix fraction
    'SOUNDS_env_correlations',[],...     % calculated correlation coefficient (envelopes)
    'SOUNDS_states',[795 4932 4584],...% state values for random no generator (to ensure that sounds are reproducible)
    ...                                 % formatted as such: [env_state decorr_env_state1 decorr_env_state2]
    'SOUNDS_carrier_states',[],...            % carrier states (to rove the carrier)
    'SOUNDS_num_carriers',10,...        % number of carriers to rove (should be 10, don't change!)
    'SOUNDS_rand_states',[],...         % list of random state values (from Caitlin/Brian head saccade exp't)
    'SOUNDS_rove_sequence',[],...      % random ordering sequence to rove sounds
    'SOUNDS_carrier_bandwidth',[2000 11000],... % using 2 - 11 kHz bandwidth for carriers (same as Caitlin/Brian head saccade exp't)
    'SOUNDS_env_bandwidth',[1 150],...          % bandwidth of envelopes (should be 1 to 150 Hz to replicate Nelson/Baxter study)
    'SOUNDS_amplitude',60,...                   % Keep at 60 (this gives amplitudes suitable for the TDT)
    'SOUNDS_env_depth',100,...                  % depth of envelope modulation
    'SOUNDS_ramp',5,...                         % ramp length for sounds (ms)
    'SOUNDS_location_sequence',[]);           % sequence of locations for the session (1st row: lead, 2nd row: lag)

% Comments box:
PDR.comments = cell(3,1);
for j=1:length(PDR.comments)
    PDR.comments{j}='';
end
% These are the random SOUNDS_states from Baxter, et al.
RandStates = [...
        73 167 617 364 662 593 538 194 853 610 294 ...
        479 71 105 162 770 143 116 252 101 377 706 ...
        273 574 915 661 935 355 530 540 220 232 886 ...
        70 65 571 35 339 87 281 795 283 974 248 ...
        995 936 769 943 127 224];   
PDR.SOUNDS_rand_states=RandStates;

% check if testing MAAs
if PDR.maa_test_flag
    PDR.LEAD_default_scale = 0;
end

% setup cell array for lead/lag sounds
PDR.LEAD_sounds=cell(1,PDR.SOUNDS_num_carriers);
PDR.LAG_sounds=cell(1,PDR.SOUNDS_num_carriers);

q=clock;
y=num2str(q(1));y=y(3:4);
m=num2str(q(2));if size(m,2)<2;m=['0' m];end
d=num2str(q(3));if size(d,2)<2;d=['0' d];end
PDR.filename= [num2str(PDR.bird_id) '_LDS_' y m d '_a'];                    %930=m 929=l 882=d 883=e  (a is index to experiment number for that day)
calcSessionLen;

function calcSessionLen()
global PDR
% calculate length of session:
tmp = (PDR.npretrials + PDR.TEST_trial_freq*PDR.n_test_trials)...
    *(PDR.isi_buf+1)*(PDR.buf_pts/PDR.stim_Fs); % length in seconds
PDR.len_session(1)=floor(tmp/60); % Calculate length of session (in minutes)!
PDR.len_session(2)=round(tmp-floor(tmp/60)*60); % seconds

function setupTrials()
global PDR

%disp('Setting up Trial Sequence')
% SETUP randomized trial IDs
ntrials = PDR.npretrials + PDR.TEST_trial_freq*PDR.n_test_trials;
PDR.SOUNDS_location_sequence = NaN*ones(2,ntrials+1);
PDR.SOUNDS_location_sequence(1,:) = PDR.LEAD_pos*ones(1,ntrials + 1); % lead positions in first row
PDR.SOUNDS_location_sequence(2,:) = PDR.LAG_hab_pos*ones(1,ntrials + 1); % lag positions in second row

TEST_trial_jitter = PDR.TEST_trial_jitter;
no_angles = length(PDR.TEST_azimuths);

% create a trial sequence and convert to location sequence 
% (2 rows, 1st row= El, 2nd row = Az)
%PDR.n_outlier_trials = round(PDR.outlier_fraction*PDR.n_test_trials);
separations=PDR.TEST_azimuths - PDR.LAG_hab_pos;
outlier_IDs=find(abs(separations)>=PDR.outlier_separation);
not_outlier_IDs=find(abs(separations)<PDR.outlier_separation);
rep_freq=5; % don't repeat an outlier speaker location less than 7 test trials apart
rand_list = randomized_trials(not_outlier_IDs,outlier_IDs,PDR.n_outlier_trials,PDR.n_test_trials,rep_freq);

last_test=NaN;
if length(rand_list) == 0
    return;
end
% create list of locations with randomized test locs
cnt = PDR.npretrials; % skip pretrials
id = 0;
while cnt < ntrials
    cnt = cnt + PDR.TEST_trial_freq;
    id = id + 1;
    PDR.SOUNDS_location_sequence(2,cnt)=PDR.TEST_azimuths(rand_list(id));
    cnt = cnt + round(TEST_trial_jitter*rand); % jitter test trial occurances (if requested)
    if cnt >= (ntrials-PDR.TEST_trial_freq)
        break;
    end
end

% setup rove sequence:
num_snds=PDR.SOUNDS_num_carriers;
PDR.SOUNDS_rove_sequence = ceil(num_snds-num_snds*rand(1,ntrials+1));

function [trial_list] = randomized_trials(not_outlier_IDs,outlier_IDs,nOutliers,nTests,rep_limit)

outlier_list = [];
nOutlierTypes = length(outlier_IDs);
if nOutliers >0
    for i1=1:ceil(nOutliers/nOutlierTypes)
        outlier_list((i1-1)*nOutlierTypes+1:i1*nOutlierTypes)=outlier_IDs;
    end
    outlier_list = outlier_list(1:nOutliers);
end


not_outlier_list = [];
nNotOutlierTypes = length(not_outlier_IDs);
for i2=1:ceil((nTests-nOutliers)/nNotOutlierTypes)
    not_outlier_list((i2-1)*nNotOutlierTypes+1:i2*nNotOutlierTypes)=not_outlier_IDs;
end
not_outlier_list = not_outlier_list(1:(nTests-nOutliers));

total_list = [outlier_list not_outlier_list];

chk2=0;
cnt=0;
IDs = sort(unique(total_list));
while ~chk2
    chk2=1;
    trial_list = total_list(randperm(length(total_list)));
    for i2=outlier_IDs
        df_list = diff(find(trial_list==i2));
        if find(df_list < rep_limit)
            chk2=0;
        end
    end
    
    % check for repeated speakers
    for i2=IDs
        df_list = diff(find(trial_list==i2));
        if find(df_list == 1)
            chk2=0;
        end
    end
    cnt=cnt+1;
    if cnt>10000
        hWarn=warndlg('Cannot find a randomized trial list with these parameters!');
        uiwait(hWarn);
        trial_list=[];
        return;
    end
end

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

function AMStim()
% Note: Noise1 is lead and Noise2 is lag
% AMStim (Adapted from Caitlin/Brian's head turn exp't)
% Generate stimuli for LDS session

global PDR
PDR.RPs=[];
%//////////////////////////////////////////
% low pass filter design:
fc=150;
fs=PDR.stim_Fs;
order=2;
[Bs,As]=filt_butter(fc,fs,order);
% Make stimulus or stimuli
SR = PDR.stim_Fs;
% Increase duration by delay
% so that the stimuli can be gated/windowed (see below)
StimDur = PDR.SOUNDS_length + PDR.SOUNDS_carrier_delay; % should be in ms, add delay

%for sound generation (creates extended BBN that is then curtailed to
%the desired duration)
% Use PAD = 10 for sounds with less than 250ms total duration!
% Otherwise use PAD = 1
if StimDur <= 250
    PAD = 10;
else
    PAD = 1;
end

StimPnts = round((StimDur/1000)*SR);
DelayPnts = round((PDR.SOUNDS_carrier_delay/1000)*SR);
DelayPnts = max(1,DelayPnts);

numsnds=length(PDR.SOUNDS_rand_states);

% create a family of sounds the same envelope parameters, but with
% different carriers
hWait = waitbar(0,'Generating Sounds');
for i0=1:numsnds
    % Make Noise #1
    Noise1 = getBBN(PDR.SOUNDS_rand_states(i0), SR, StimDur, PDR.SOUNDS_carrier_bandwidth(1), PDR.SOUNDS_carrier_bandwidth(2));
    Noise1 = Noise1(1:StimPnts);
    % Scale to desired amplitude
    Noise1 = Noise1 * 50; % scale by 50 so that speaker scaling factors aren't too big (well, small)!
    Noise1 = Noise1 * 10^(PDR.SOUNDS_amplitude/20)*0.00002; % amplitude re: 20 uPa   
    % copy Noise #1 to make Noise #2
    Noise2 = Noise1;
    % Make Envelope #1
    Env1 = getBBN(PDR.SOUNDS_states(1), SR, PAD*StimDur, PDR.SOUNDS_env_bandwidth(1), PDR.SOUNDS_env_bandwidth(2));
    Env1 = Env1(1:StimPnts);
    Env1 = Env1 - min(Env1); Env1 =  Env1 / max(Env1);  % normalize
    Env1 = Env1 .* (PDR.SOUNDS_env_depth/100); % AM depth (as a percent)
    Env1 = Env1 + 1 - (PDR.SOUNDS_env_depth/100);
    % copy Envelope #1 to make Envelope #2
    Env2 = Env1;
    % get de-correlateing envelope #1
    DCEnv1 = getBBN(PDR.SOUNDS_states(2), SR, PAD*StimDur, PDR.SOUNDS_env_bandwidth(1), PDR.SOUNDS_env_bandwidth(2));
    DCEnv1 = DCEnv1(1:StimPnts);
    DCEnv1 = DCEnv1 - min(DCEnv1); DCEnv1 =  DCEnv1 / max(DCEnv1);  % normalize
    DCEnv1 = DCEnv1 .* (PDR.SOUNDS_env_depth/100); % AM depth (as a percent)
    DCEnv1 = DCEnv1 + 1 - (PDR.SOUNDS_env_depth/100);
    % get de-correlateing envelope #2
    DCEnv2 = getBBN(PDR.SOUNDS_states(3), SR, PAD*StimDur, PDR.SOUNDS_env_bandwidth(1), PDR.SOUNDS_env_bandwidth(2));
    DCEnv2 = DCEnv2(1:StimPnts);
    DCEnv2 = DCEnv2 - min(DCEnv2); DCEnv2 =  DCEnv2 / max(DCEnv2);  % normalize
    DCEnv2 = DCEnv2 .* (PDR.SOUNDS_env_depth/100); % AM depth (as a percent)
    DCEnv2 = DCEnv2 + 1 - (PDR.SOUNDS_env_depth/100);
    % ** mix de-correlateing envelopes in with original envelopes **
    Env1DC = ((1-PDR.SOUNDS_mix).*DCEnv1) + ((PDR.SOUNDS_mix).*Env1);
    Env2DC = ((1-PDR.SOUNDS_mix).*DCEnv2) + ((PDR.SOUNDS_mix).*Env2);
    % !!! re-normalize the envelopes
    Env1DC = Env1DC - min(Env1DC); Env1DC =  Env1DC / max(Env1DC);  % normalize
    Env1DC = Env1DC .* (PDR.SOUNDS_env_depth/100); % AM depth (as a percent)
    Env1DC = Env1DC + 1 - (PDR.SOUNDS_env_depth/100);
    Env2DC = Env2DC - min(Env2DC); Env2DC =  Env2DC / max(Env2DC);  % normalize
    Env2DC = Env2DC .* (PDR.SOUNDS_env_depth/100); % AM depth (as a percent)
    Env2DC = Env2DC + 1 - (PDR.SOUNDS_env_depth/100);
    
    % Delay to make "lead" and "lag"
    % DO NOT SHIFT ENVELOPES!!! (only carriers have a delay)
    Noise1 = [Noise1 zeros(1,DelayPnts)];
    Noise2 = [zeros(1,DelayPnts) Noise2];
    
    % window (i.e., gate) out onset/offset time disparity
    % DO NOT SHIFT ENVELOPES!!! (only carriers have a delay)
    if(PDR.SOUNDS_carrier_delay>=0)
        Noise1 = Noise1(DelayPnts:StimPnts);
        Noise2 = Noise2(DelayPnts:StimPnts);
    else
        PDR.CARRIERS_SWITCHED=1;
        Noise2 = Noise1(DelayPnts:StimPnts);
        Noise1 = Noise2(DelayPnts:StimPnts);
    end
        
    % Fix envelope points to match carriers!
    Env1DC = Env1DC(1:length(Noise1));
    Env2DC = Env2DC(1:length(Noise2));
    
    % ramp envelopes on/off
    Env1DC = rampSounds(Env1DC, SR, PDR.SOUNDS_ramp); % stim envelope
    Env2DC = rampSounds(Env2DC, SR, PDR.SOUNDS_ramp); % stim envelope
    
    % set rms amplitude for envelopes:
    % calculate multiplier to equalize rms with min rms
    r=sqrt((length(Env1DC)*PDR.SOUNDS_rms^2)/sum(Env1DC.^2));
    Env1DC=r.*Env1DC;
    r=sqrt((length(Env2DC)*PDR.SOUNDS_rms^2)/sum(Env2DC.^2));
    Env2DC=r.*Env2DC;
    
    
    % CALCULATE CORRELATION COEFFICIENTS (Final LEAD/LAG Envelopes)
    % get hilbert envelope (lead):           
    env1(i0,:)=abs(hilbert(Noise1 .* Env1DC));
    % butterworth lowpass filter (lead):
    for y0=1:size(Bs,1); env1(i0,:)=filter(Bs(y0,:),As(y0,:),env1(i0,:)); end
    
    % get hilbert envelope (lag);
    env2(i0,:)=abs(hilbert(Noise2 .* Env2DC));
    % butterworth lowpass filter (lag):
    for y1=1:size(Bs,1); env2(i0,:)=filter(Bs(y1,:),As(y1,:),env2(i0,:)); end
    
    % calculate correlation coefficient (lead/lag) for filtered hilbert
    % envelopes (this is the true envelope after convolving with
    % carrier)
    
    R=corrcoef(env1(i0,:),env2(i0,:));
    Res(i0)=R(2,1);
    PDR.SOUNDS_env_correlations{i0} = R(2,1); % correlation coefficients

    % CALCULATE RP:
    [leadP, lagP] = SpikeProbAM(env1(i0,:),env2(i0,:),PDR.stim_Fs);
    PDR.RPs(i0)= leadP/(leadP+lagP);
    
    % multiply with envelopes
    Noise1 = Noise1 .* Env1DC;
    Noise2 = Noise2 .* Env2DC;
    
    LEAD_sounds{i0} = Noise1;
    LAG_sounds{i0} = Noise2;
    
    waitbar(i0/numsnds,hWait);
end

close(hWait);
if(PDR.SOUNDS_carrier_delay<0)
    h=warndlg('Lead/Lag Carriers Switched!!!');
    uiwait(h);
end
% find the most highly correlated sounds (low pass filtered hilbert
% envelopes)
clims=[-1 1];

R0=corrcoef(env1');
for q0=1:numsnds
    R0(q0,q0)=-inf;
end
tmp=reshape(R0,1,size(R0,1)*size(R0,2));
tmp=sort(tmp);
tmp=fliplr(tmp);
chk=0; cnt=0;
while chk==0
    cnt=cnt+1;
    [i,j]=find(R0>=tmp(cnt));
    if length(unique(i)) >= PDR.SOUNDS_num_carriers
        snds=unique(i);
        snds=snds(1:PDR.SOUNDS_num_carriers);
        PDR.SOUNDS_carrier_states=PDR.SOUNDS_rand_states(snds);
        env_new1=env1(snds,:);
        env_new2=env2(snds,:);
        chk=1;
        break;
    end
end

for q1=1:length(snds)
    % zero out LEAD sounds if testing MAAs
    if PDR.maa_test_flag
        PDR.LEAD_sounds{q1}=zeros(size(LEAD_sounds{snds(q1)}));
    else
        PDR.LEAD_sounds{q1}=LEAD_sounds{snds(q1)};
    end
    PDR.LAG_sounds{q1}=LAG_sounds{snds(q1)};
end

scrn=get(0,'ScreenSize');
hTemp=figure('name','hist','Position',[0.1*scrn(3) 0.1*scrn(4) 0.8*scrn(3) 0.8*scrn(4)]); hold on;

if PDR.SOUNDS_num_carriers > 1
    % correlations of sound tokens
    subplot(3,2,1);
    Rnew1=corrcoef(env_new1');
    Rnew2=corrcoef(env_new2');
    Ravg=(Rnew1+Rnew2)./2;
    
    imagesc(Ravg,[min(min(Ravg)) max(max(Ravg))]); colormap bone; colorbar
    axis square
    title('Avg. Correlations Between Sound Tokens');
end
if PDR.SOUNDS_num_carriers > 1
    if ~PDR.maa_test_flag
        % plot histogram of calculated lead/lag correlations
        % (Just the ones that will be used)
        subplot(3,2,3);
        hold on;
        binz=(min(Res(snds))-0.05):0.01:(max(Res(snds))+0.05);
        out=hist(Res(snds),binz);
        bar(binz,out);
        xlabel('Correlation Coefficient')
        ylabel('Frequency')
        title('Histogram of Lead/Lag Correlations (low pass filtered envelopes)')
        h = findobj(gca,'Type','patch');
        set(h,'FaceColor','w','EdgeColor','none')
        axis([-1 1 0 ceil(1.1*max(out))]);
        %axis([(min(Res(snds))-0.05) (max(Res(snds))+0.05) 0 ceil(1.1*max(out))])
        set(gca,'Color',[0 0 0]);
        % hist of RPs
        subplot(3,2,5);
        hold on;
        binz=0:0.01:1;
        out=hist(PDR.RPs,binz);
        bar(binz,out);
        xlabel('RP');
        ylabel('Frequency');
        title('Histogram of Response Probabilities (low pass filtered envelopes)');
        h = findobj(gca,'Type','patch');
        set(h,'FaceColor','r','EdgeColor','none')
        axis([0 1 0 ceil(1.1*max(out))])
        set(gca,'Color',[0 0 0]);
    else
        subplot(3,2,3);
        axis off
        text(0.15,0.35,'MAA EXPERIMENT','FontSize',30,'Color',[1 0 0])
    end
end
% lead and lag envelopes
subplot(3,2,2); hold on;
for q2=1:length(snds)
    % do not plot leads if just testing MAAs
    if ~PDR.maa_test_flag
        A=PDR.LEAD_sounds{q2};
        A_env=abs(hilbert(A));
        for y0=1:size(Bs,1); A_env=filter(Bs(y0,:),As(y0,:),A_env); end
        plot(A_env,'Color',[q2/length(snds) 0 1-q2/length(snds)],'LineWidth',2);
    end
    % plot low pass filtered lag envelopes:
    B=PDR.LAG_sounds{q2};
    B_env=abs(hilbert(B));
    for y0=1:size(Bs,1); B_env=filter(Bs(y0,:),As(y0,:),B_env); end
    plot(B_env,'Color',[q2/length(snds) 0 1-q2/length(snds)],'LineWidth',1,'LineStyle',':');
end
title('Low Pass Filtered Envelopes (lead/lag)');
set(gca,'Color',[0 0 0]);


% wait for user
uicontrol('Style', 'pushbutton', 'String', 'Close and Continue',...
    'Units','Normalized','Position', [0.6 0.1 0.25 0.1],...
    'BackgroundColor','g','Callback', 'close(''hist'')');
uiwait(hTemp)


function [Bs,As]=filt_butter(fc,fs,order)
% creates a low pass butterworth filter
[B,A] = butter(order,2*fc/fs); % [0:pi] maps to [0:1] here
[sos,g] = tf2sos(B,A);
% sos =
%  1.00000  2.00080   1.00080  1.00000  -0.92223  0.28087
%  1.00000  1.99791   0.99791  1.00000  -1.18573  0.64684
%  1.00000  1.00129  -0.00000  1.00000  -0.42504  0.00000
% 
% g = 0.0029714
% 
Bs = sos(:,1:3); % Section numerator polynomials
As = sos(:,4:6); % Section denominator polynomials

function [stim] = rampSounds(stim, SR, SOUNDS_ramp)
% SOUNDS_ramp should be in ms
ramp_pts = ceil(SR*(SOUNDS_ramp/1000));
npts = length(stim) - 2*ramp_pts - 2;
rampenv = [0:(1/ramp_pts):1 ones(1,npts) 1:-(1/ramp_pts):0];
stim = stim .* rampenv;

function soundBufferSetup
global PDR

for i0=1:PDR.SOUNDS_num_carriers
    len_buf = PDR.buf_pts;
    len_stim = length(PDR.LEAD_sounds{i0});
    lead_stim=zeros(1,len_buf);
    lag_stim=lead_stim;
    pad = PDR.buf_pts-len_stim; %ceil(len_buf-len_stim);
    lead_stim = [zeros(1,2) PDR.LEAD_sounds{i0} zeros(1,pad)];
    lag_stim = [zeros(1,2) PDR.LAG_sounds{i0} zeros(1,pad)];
    PDR.LEAD_sounds{i0} = lead_stim(1:PDR.buf_pts);
    PDR.LAG_sounds{i0} = lag_stim(1:PDR.buf_pts);
end

function [leadP, lagP] = SpikeProbAM(Env1, Env2,Fs)
% Adapted from B.S. Nelson's AM study
% leadP = lead spike probability (cummulative)
% lagP = lag spike probability (cummulative)

% Env1 = lead envelope
% Env2 = lag envelope

SR = Fs; % may need to adjust derivative function if SR is changed
% set separately in function filteredstimuliAM !!!

% get amplitude difference
Env1(find(Env1==0)) = 0.00000000001;
Env1_dB = 20*log10(Env1);
Env2(find(Env2==0)) = 0.00000000001;
Env2_dB = 20*log10(Env2);
Env1_dBDiff = Env1_dB - Env2_dB;
Env2_dBDiff = Env2_dB - Env1_dB;%-Env1_dBDiff;
Env1_dBDiff_wt = 3.0207 ./(1 + exp(-(Env1_dBDiff(:) - 3.2497) ./ 2.3835));
Env2_dBDiff_wt = 3.0207 ./(1 + exp(-(Env2_dBDiff(:) - 3.2497) ./ 2.3835));

%Env1_dBDiff = max(-24, Env1_dBDiff); % limit range
%Env2_dBDiff = min(24, Env2_dBDiff); % limit range

% derivative
if 1 % use average envelope to measure d/dt -- as in Nelson & Takahashi 2010
    % calculate average envlope
    Env1_dt = diff((Env1 + Env2)/2) * (SR/1000); % units are per ms... from AM paper
    Env2_dt = diff((Env1 + Env2)/2) * (SR/1000);
   
    Env1_dt_wt = 2.2082 ./(1 + exp(-(Env1_dt(:) - 0.014001) ./ 0.065264));
    Env2_dt_wt = 2.2082 ./(1 + exp(-(Env2_dt(:) - 0.014001) ./ 0.065264));
   
    spikeProb_1 = (Env1_dt_wt) .* (Env1_dBDiff_wt(2:end));
    spikeProb_2 = (Env2_dt_wt) .* (Env2_dBDiff_wt(2:end));
   
else % calulate d/dt separately for each sound -- as in human model
    % This doesn't work (here) unless we get signals spatialized in
    % each ear. The derivavite would then be calulated from the
    % signals in each ear.
    % Also cannot use functions from Nelson & Takahashi 2010
    Env1_dt = diff((Env1)/2) * (SR/1000); % units are per ms... from AM paper
    Env2_dt = diff((Env2)/2) * (SR/1000);
    Env1_dt_wt = 2.2082 ./(1 + exp(-(Env1_dt(:) - 0.014001) ./ 0.065264));
    Env2_dt_wt = 2.2082 ./(1 + exp(-(Env2_dt(:) - 0.014001) ./ 0.065264));
    Env_dt_wt = Env1_dt_wt .* Env2_dt_wt; % multiply weights
    Env1_dt_wt = Env_dt_wt;
    Env2_dt_wt = Env_dt_wt;
    spikeProb_1 = (Env_dt_wt) .* (Env1_dBDiff_wt(2:end));
    spikeProb_2 = (Env_dt_wt) .* (Env2_dBDiff_wt(2:end));
end

if 1 % entire stimulus
    leadP = sum(spikeProb_1) / (SR/1000) / 34; % 34=duration of stimuli used to estimate sensitivity functions?
    lagP = sum(spikeProb_2) / (SR/1000) / 34;
else % skip onset and offset
    firstpnt = round(0.003*SR);
    lastpnt = round(length(spikeProb_1)-(0.003*SR));
    leadP = sum(spikeProb_1(firstpnt:lastpnt)) / (SR/1000) / 34;
    lagP = sum(spikeProb_2(firstpnt:lastpnt)) / (SR/1000) / 34;
end

function readCalibFiles
global PDR
% function to read calibration data and select appropriate scales and
% atten values for each speaker

% calibration data file selection:
pth = 'C:\alex\calib_data\';
PDR.SOUNDS_calib_pname = pth;
switch PDR.bird_id
    case 925
        nfiles = 1;
        PDR.SOUNDS_calib_fnames = cell(nfiles,1);
        PDR.SOUNDS_calib_fnames{1} = ['intraural_calib_130322_925D.mat'];
        %PDR.SOUNDS_calib_fnames = {'intraural_calib_130309_925A.mat';...
        %       'intraural_calib_130318_925F.mat'};
        %PDR.SOUNDS_calib_fnames = ['intraural_calib_130222_925B.mat'];
    case 924
        nfiles = 1;
        PDR.SOUNDS_calib_fnames = cell(nfiles,1);
        PDR.SOUNDS_calib_fnames{1} = 'intraural_calib_130309_924B.mat';
        %PDR.SOUNDS_calib_fnames = ['intraural_calib_130221_924A.mat'];
    case 1073
        nfiles = 1;
        PDR.SOUNDS_calib_fnames = cell(nfiles,1);
        PDR.SOUNDS_calib_fnames{1} = ['intraural_calib_130322_1073A.mat'];
        %PDR.SOUNDS_calib_fnames{1} = ['intraural_calib_130309_1073A.mat'];
        %PDR.SOUNDS_calib_fnames = ['intraural_calib_130219_1073A.mat'];
    otherwise
        PDR.SOUNDS_calib_fnames = cell(1,1);
        PDR.SOUNDS_calib_fnames{1}='ERROR';
        warndlg('No calibration data for this bird!!!','!! Warning !!');
        return;
end

tmp = NaN*ones(1,PDR.SOUNDS_num_speakers-1);
PDR.SOUNDS_lead_attens = tmp;
PDR.SOUNDS_speaker_scales_lead = tmp;
PDR.SOUNDS_speaker_scales_lag = tmp;

expt_locs = [PDR.SOUNDS_elevations; PDR.SOUNDS_azimuths];
spkr_list = PDR.SOUNDS_speaker_numbers;
spkr_list = spkr_list(find(spkr_list ~= 1)); % remove lead speaker
% go through each calibration file and grab speaker calibration data
for j = 1:size(PDR.SOUNDS_calib_fnames,1)
    
    % load calibration data
    load([pth PDR.SOUNDS_calib_fnames{j}]);
    
    calib_locs = CALIB_PDR.locations(:,2:end); % get all locations except lead
    
    % get speaker attenuations & scales
    spkr_IDs = CALIB_PDR.equalized_lead_attens{1,2};
    attens = CALIB_PDR.equalized_lead_attens{2,2};
    speaker_data = CALIB_PDR.speaker_data;
    
    for i0 = spkr_list
        % check if calibration file has calibration data for this speaker
        idx=find(spkr_IDs == i0);
        if length(idx)
            % check if calib data is for same location
            el = expt_locs(1,i0); az = expt_locs(2,i0);
            if el == calib_locs(1,idx) && az == calib_locs(2,idx)
                % store attenuation for this speaker
                PDR.SOUNDS_lead_attens(i0-1) = attens(idx);
                % store scales for this speaker
                lead_coeffs=speaker_data(idx).coeffs_both_fit_lead_scales;
                m_lead=lead_coeffs(1,1);
                b_lead=lead_coeffs(2,1);
                PDR.SOUNDS_speaker_scales_lead(i0-1) = round(10^((PDR.SOUNDS_SPL-b_lead)/m_lead));
                lag_coeffs=speaker_data(idx).coeffs_both_fit_lag_scales; 
                m_lag=lag_coeffs(1,1);
                b_lag=lag_coeffs(2,1);
                PDR.SOUNDS_speaker_scales_lag(i0-1) = round(10^((PDR.SOUNDS_SPL-b_lag)/m_lag));
                spkr_list = spkr_list(find(spkr_list ~= i0)); % done with this speaker!
            end
        end
    end
    
end

if length(spkr_list)
    warndlg(['Could not find calib data for speaker numbers: ' num2str(spkr_list)],'!! Warning !!');
    PDR.SOUNDS_calib_fname='ERROR';
end

% check speaker scales to be in range for TDT
scales=[PDR.SOUNDS_speaker_scales_lead PDR.SOUNDS_speaker_scales_lag];
if ~isempty(find((scales>32760)==1))
    warndlg('Some of the scales are too LARGE for the TDT!!!','!! Warning !!');
    PDR.SOUNDS_calib_fname='ERROR';
end
if ~isempty(find((scales<=0)==1))
    warndlg('Some of the scales are too SMALL for the TDT!!!','!! Warning !!');
    PDR.SOUNDS_calib_fname='ERROR';
end

function speakerTestSetup
global PDR
% PARAMS

PDR.filename = 'speaker_test';
cd(PDR.data_path);
if exist([PDR.filename '.mat'])
    delete([PDR.filename '.mat']);
end
PDR.comments = 'Testing Equipment!';
PDR.record = 1;
PDR.isi_buf = 5;
% ORDERED LIST OF SPEAKER LOCATIONS
PDR.npretrials = 1;
PDR.TEST_trial_freq = 1;
PDR.n_test_trials = 2*length(PDR.TEST_azimuths);
ntrials = PDR.npretrials + PDR.TEST_trial_freq*PDR.n_test_trials;
PDR.SOUNDS_location_sequence = NaN*ones(2,ntrials+1);
PDR.SOUNDS_location_sequence(1,:) = PDR.LEAD_pos*ones(1,ntrials + 1); % lead positions in first row
PDR.SOUNDS_location_sequence(2,:) = PDR.LAG_hab_pos*ones(1,ntrials + 1); % lag positions in second row

PDR.TEST_trial_jitter=0;
TEST_trial_jitter = PDR.TEST_trial_jitter;
no_angles = length(PDR.TEST_azimuths);

% create a trial sequence and convert to location sequence 
% (2 rows, 1st row= El, 2nd row = Az)
last_test=NaN;

% create list of locations with randomized test locs
cnt = PDR.npretrials; % skip pretrials
id = 0;
while cnt < ntrials
    cnt = cnt + PDR.TEST_trial_freq;
    id = id + 1;
    PDR.SOUNDS_location_sequence(2,cnt)=PDR.TEST_azimuths(mod(id,length(PDR.TEST_azimuths))+1);
    cnt = cnt + round(TEST_trial_jitter*rand); % jitter test trial occurances (if requested)
    if cnt >= (ntrials-PDR.TEST_trial_freq)
        break;
    end
end

% setup rove sequence:
num_snds=PDR.SOUNDS_num_carriers;
PDR.SOUNDS_rove_sequence = ceil(num_snds-num_snds*rand(1,ntrials+1));
lds_switchyard('calcSessionLen');
sec=num2str(PDR.len_session(2));
if length(sec)==1
    sec=['0' sec];
end
minutes=num2str(PDR.len_session(1));
if length(minutes)==1
    minutes=['0' minutes];
end
% TELL USER HOW LONG EQUIPMENT TESTING WILL TAKE!
h=msgbox(['Testing equipment will take: ' minutes ' minutes & ' sec ' seconds']);
uiwait(h);
% MAKE SOUND TOKENS:
lds_switchyard('AMStim'); % calculate lead lag sounds using correlation and state values (for reproducible sounds)
lds_switchyard('soundBufferSetup');
% SETUP CALIBRATED SCALES & ATTENS:
lds_switchyard('readCalibFiles');