% run_lds_pdr.m
% created by A. Cvitanovich (5/06/2012)
% This simply calls functions in lds_switchyard and then opens AlexMenu to
% allow user to select options for the Lag Discrimination Suppression PDR
% Exp't ... After all that, it calls a C program to run the TDT
% 

% NOTE: (10/22/2012) I've set this up to rove carriers... There should be
% <= 50 sounds (because the matlab mex functions don't handle
% dynamic memory allocation very well, and I'm not sure how many sounds the AP2 card can store... 
% this will depend on buffer length, AP2 card memory, etc. 
% 50 as a max seems safe for now)



button = questdlg('What do you wish to do?','LDS PDR Experiment','TEST EQUIPMENT','RUN EXPERIMENT','DO NOTHING AND QUIT','TEST EQUIPMENT');

save tmp button
if strcmp(button,'DO NOTHING AND QUIT')
    delete tmp.mat
    return
else
    clear all; close all;
    load tmp;
end

cd c:\alex\code\LDS_PDR

global session % session plotting info
global PDR % variables used in the experiment must be global so that all the functions can use them.

% INITIAL SETUP OF DEFAULTS AND TRIAL SEQUENCE:
lds_switchyard('setDefaults'); % sets default values for running a session

if strcmp(button,'RUN EXPERIMENT')
    % NOTE: sounds and trial sequence setup taken care of in AlexMenu.m
    H = AlexMenu;
    uiwait(H)
elseif strcmp(button,'TEST EQUIPMENT')
    lds_switchyard('speakerTestSetup');
    PDR.exit_flag == 0;
end


if PDR.exit_flag == -1
    disp('Starting experiment...')
elseif PDR.exit_flag == 1
    disp('Goodbye!')
    return
elseif PDR.exit_flag == 0
    disp('Testing Speakers...')
else
    warndlg('Something is not right???')
    return
end

% Make sure the session gets a unique filename
cd(PDR.data_path);
if strcmp(button,'RUN EXPERIMENT')
    
    cnt = double('a'+0);
    while exist ([PDR.filename '.mat'],'file');
        cnt = cnt + 1;
        if cnt > 122
            disp(['Attempted to use filename: ' PDR.filename '.mat' ' but failed!']);
            disp('There are already several files with similar names!');
            PDR.filename = input('Enter a unique filename for this session: ', 's');
            break;
        else
            PDR.filename(end) = char(cnt);
        end
    end
    if exist ([PDR.filename '_REC1.frf'],'file');
        disp('you are trying to overwrite a free field recording! try again.')
        return
    end
end
button1 = questdlg(['Check that the correct speakers are wired up and positioned correctly.' ...
        'Is it okay to continue with this session?'],'','YES','NO','YES');

if strcmp(button1,'NO')
    return
end

% calculate no of trials, no pts total play, etc:
PDR.ntrials = PDR.npretrials+PDR.n_test_trials*PDR.TEST_trial_freq;
PDR.npts_totalplay=PDR.buf_pts*(PDR.ntrials)*(PDR.isi_buf+1);

if PDR.virtual
    type='vrt';
else
    type='frf';
end
passmein.FN1=[PDR.filename '_REC1.' type];
passmein.FN2=[PDR.filename '_REC2.' type];
passmein.record = PDR.record;
passmein.n_trials = uint16(PDR.ntrials);
passmein.latten = 0; % not using a base attenuation
passmein.ratten = 0; % not using a base attenuation
passmein.decimateFactor = PDR.decimationfactor;
passmein.buf_pts = PDR.buf_pts;
passmein.nptsTotalPlay = PDR.npts_totalplay;
passmein.ISI = PDR.isi_buf;
passmein.max_signal_jitter = PDR.jitter; % jitter trial presentation (+/- 1 trial usually)
passmein.num_carriers = PDR.SOUNDS_num_carriers; % number of carriers to rove
passmein.n_speakers = PDR.SOUNDS_num_speakers; % no. of speakers available (including lead speaker)
tmp=find(PDR.LAG_sounds{1}~=0);
passmein.sound_onset=tmp(1);
passmein.trials_to_show=3;
passmein.hab_loc=find(PDR.SOUNDS_azimuths==PDR.LAG_hab_pos);
passmein.test_trial_freq=PDR.TEST_trial_freq;

p = pwd;
p = [p '\'];
if strcmp(PDR.data_path(3:end),p(3:end))
else
    warndlg('Something could be wrong with the path setup!')
    pwd
    return
end


%*********************************%
%**LOCATION SEQUENCE FOR TDT******%
%*********************************%
% Convert trial sequence to a sequence of speaker #'s

tmp = PDR.SOUNDS_location_sequence(2,:); % lag location sequence (azimuths)
locations = NaN*ones(1,length(tmp));

for i=1:length(locations)
    locations(i) = find(PDR.SOUNDS_azimuths == tmp(i));
end

%*********************************%
%**PLOT TRIAL SEQUENCE ETC *******%
%*********************************%

locs = PDR.SOUNDS_location_sequence(2,:); % lag location sequence (azimuths)
hab = PDR.LAG_hab_pos; % habituating location (lag)
session.hab_xes = find(locs == hab);
session.hab_yes = hab*ones(1,length(session.hab_xes));
session.trial_xes = find(locs ~= hab);
session.trial_yes = locs(session.trial_xes);
session.trial_param = 'Azimuth (Deg.)';
session.ntrials = PDR.ntrials;
session.min_yes = min(PDR.SOUNDS_azimuths)-10;
session.max_yes = max(PDR.SOUNDS_azimuths)+10;
session.bufpts = PDR.buf_pts;
session.dec_fact = PDR.decimationfactor;
session.isi = PDR.isi_buf;
session.trials_to_show = passmein.trials_to_show;
tmp=find(PDR.LAG_sounds{1}~=0);
session.sound_onset=tmp(1); % how many points until sound onset?
session.npts_totalplay=PDR.npts_totalplay;
session.srate=(10^6)*(1/PDR.stim_Fs); % sampling period in usec
session.stim_fs=PDR.stim_Fs;
session.zoomval=0.4;
% requires session to be declared a global
sessionPlots('Initialize');
hold on;
uicontrol(gcf,'Style', 'pushbutton','Tag','ZoomOut','String','Zoom -',...
    'Units','normalized','FontSize',8,'Position',[0.02 0.6 0.05 0.05],...
    'Callback', 'if session.zoomval<2.1; session.zoomval=session.zoomval+0.1; end;');
uicontrol(gcf,'Style', 'pushbutton','Tag','ZoomIn','String','Zoom +',...
    'Units','normalized','FontSize',8,'Position',[0.02 0.8 0.05 0.05],...
    'Callback', 'if session.zoomval>0.1; session.zoomval=session.zoomval-0.1; end;');
% required to initialize sessionPlots:
% structure with these parameters:
% hab_xes, hab_yes, trial_xes, trial_yes
% ntrials, min_yes, max_yes
% bufpts, decpts, isi, trials_to_show

%*********************************************************************
%*********************************************************************
%       Start Main Loop Here
%*********************************************************************
%*********************************************************************
%from here on, this will be run in a .dll and you can't jump out.

lengthOFtrials=(round(passmein.nptsTotalPlay/PDR.stim_Fs/60*10))/10;  %should be in approximate minutes
b=clock;
PDR.starttime(1:2)=b(4:5);
disp(['Now the program will just have to run its course.'])
disp(['It should be done in ~' num2str(lengthOFtrials) ' min from now (' num2str(b(4:5)) ')']);

% convert sound data to single precision & organize into a matrix
LEAD_sounds=NaN*ones(PDR.buf_pts,PDR.SOUNDS_num_carriers);
LAG_sounds=NaN*ones(PDR.buf_pts,PDR.SOUNDS_num_carriers);
for i=1:length(PDR.LEAD_sounds); LEAD_sounds(:,i)=single(PDR.LEAD_sounds{i})'; end;
for i=1:length(PDR.LAG_sounds); LAG_sounds(:,i)=single(PDR.LAG_sounds{i})'; end;

%write header information to file... saving global variables
save ([PDR.data_path PDR.filename '.mat'], 'passmein','PDR');

% save a diary of PDR variables
diary('C:\Documents and Settings\alex\Desktop\lds_pdr_diary.txt');
diary on;
disp('PDR SESSION:')
disp(date)
disp(PDR)
diary off;


% run session!
play2_record2D2_alex7(passmein, single(LEAD_sounds), single(LAG_sounds),...
    single(locations), single(PDR.SOUNDS_azimuths), single(PDR.SOUNDS_rove_sequence),...
    single(PDR.SOUNDS_speaker_scales_lead),single(PDR.SOUNDS_speaker_scales_lag),single(PDR.SOUNDS_lead_attens));
b=clock;
PDR.stoptime(1:2)=b(4:5);
%write header information to file... saving global variables
save ([PDR.data_path PDR.filename '.mat'], 'passmein','PDR');
cd ..\code
button = questdlg('What do you want to do now?','Session Complete',...
    'Close Windows','Run a New Session','Do Nothing','Close Windows');
if strcmp(button,'Close Windows')
    close all;
elseif strcmp(button,'Run a New Session')
    run_lds_pdr
elseif strcmp(button,'Do Nothing')
    % doing nothing
end