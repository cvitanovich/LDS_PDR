function varargout = AlexMenu(varargin)
global PDR trials_handle sounds_handle

% Begin GUI initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @AlexMenu_OpeningFcn, ...
                   'gui_OutputFcn',  @AlexMenu_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin & isstr(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end

function AlexMenu_OpeningFcn(hObject, eventdata, handles, varargin)
global PDR
handles.output = hObject;
% Update handles structure
guidata(hObject, handles);
% UIWAIT makes AlexMenu wait for user response (see UIRESUME)

function varargout = AlexMenu_OutputFcn(hObject, eventdata, handles)
varargout{1} = handles.output;

% LEAD POSITION:
function lead_pos_CreateFcn(hObject, eventdata, handles)
global PDR
if ~PDR.maa_test_flag
    set(hObject,'String',num2str(PDR.LEAD_pos));
else
    set(hObject,'String','N/A');
end
colorBackground(hObject);

function lead_pos_Callback(hObject, eventdata, handles)
global PDR
PDR.LEAD_pos = str2double(get(hObject,'String'));
set(hObject,'String',num2str(PDR.LEAD_pos));
clear PDR
refreshTrials;

% LAG HABITUATING POSITION:
function lag_hab_pos_CreateFcn(hObject, eventdata, handles)
global PDR
set(hObject,'String',num2str(PDR.LAG_hab_pos));
colorBackground(hObject);

function lag_hab_pos_Callback(hObject, eventdata, handles)
global PDR
PDR.LAG_hab_pos = str2double(get(hObject,'String'));
set(hObject,'String',num2str(PDR.LAG_hab_pos));
clear PDR
refreshTrials;

% TEST TRIAL SHIFT ANGLES:
function lag_test_azimuths_CreateFcn(hObject, eventdata, handles)
global PDR
set(hObject,'String',['[' num2str(PDR.TEST_azimuths) ']']);
colorBackground(hObject);

function lag_test_azimuths_Callback(hObject, eventdata, handles)
global PDR
tmp0=get(hObject,'String');
tmp0=tmp0(2:end-1);
tmp1=str2num(tmp0);
% check that these azimuths are appropriate choices
tmp2=PDR.SOUNDS_azimuths(find(PDR.SOUNDS_azimuths==PDR.LEAD_pos & PDR.SOUNDS_azimuths==PDR.LAG_hab_pos));
% WARN USER
if ~isempty(tmp2)
    h=warndlg('Some of these azimuths are not available! (Check hab lag and lead positions)');
    uiwait(h)
    return;
end
% okay to use these azumuths
PDR.TEST_azimuths=tmp1
set(hObject,'String',['[' num2str(PDR.TEST_azimuths) ']']);
PDR.SOUNDS_azimuths=[PDR.LEAD_pos PDR.LAG_hab_pos PDR.TEST_azimuths];
PDR.SOUNDS_azimuths=sort(PDR.SOUNDS_azimuths);
clear PDR
refreshTrials;

% MIX PERCENT:
function mix_CreateFcn(hObject, eventdata, handles)
global PDR
set(hObject,'String',num2str(PDR.SOUNDS_mix));
colorBackground(hObject);

function mix_Callback(hObject, eventdata, handles)
global PDR
PDR.SOUNDS_mix=str2double(get(hObject,'String'));
set(hObject,'String',num2str(PDR.SOUNDS_mix));
clear PDR
refreshSounds;

% RANDOM NUMBER GENERATOR STATES:
function env_state_CreateFcn(hObject, eventdata, handles)
global PDR
set(hObject,'String',num2str(PDR.SOUNDS_states(1)));
colorBackground(hObject);

function env_state_Callback(hObject, eventdata, handles)
global PDR
PDR.SOUNDS_states(1) = str2double(get(hObject,'String'));
set(hObject,'String',num2str(PDR.SOUNDS_states(1)));
clear PDR
refreshSounds;

function decorr1_state_CreateFcn(hObject, eventdata, handles)
global PDR
set(hObject,'String',num2str(PDR.SOUNDS_states(2)));
colorBackground(hObject);

function decorr1_state_Callback(hObject, eventdata, handles)
global PDR
PDR.SOUNDS_states(2) = str2double(get(hObject,'String'));
set(hObject,'String',num2str(PDR.SOUNDS_states(2)));
clear PDR
refreshSounds;

function decorr2_state_CreateFcn(hObject, eventdata, handles)
global PDR
set(hObject,'String',num2str(PDR.SOUNDS_states(3)));
colorBackground(hObject);

function decorr2_state_Callback(hObject, eventdata, handles)
global PDR
PDR.SOUNDS_states(3) = str2double(get(hObject,'String'));
set(hObject,'String',num2str(PDR.SOUNDS_states(3)));
clear PDR
refreshSounds;

% SOUND LENGTH IN MS:
function len_sounds_CreateFcn(hObject, eventdata, handles)
global PDR
set(hObject,'String',num2str(PDR.SOUNDS_length));
colorBackground(hObject);

function len_sounds_Callback(hObject, eventdata, handles)
global PDR
PDR.SOUNDS_length = str2double(get(hObject,'String'));
set(hObject,'String',num2str(PDR.SOUNDS_length));
clear PDR
refreshSounds;

% DELAY (ONGOING ENVELOPE DISPARITY):
function delay_CreateFcn(hObject, eventdata, handles)
global PDR
set(hObject,'String',num2str(PDR.SOUNDS_carrier_delay));
colorBackground(hObject);

function delay_Callback(hObject, eventdata, handles)
global PDR
PDR.SOUNDS_carrier_delay = str2double(get(hObject,'String'))
set(hObject,'String',num2str(PDR.SOUNDS_carrier_delay));
clear PDR
refreshSounds;

% RECORD TRACE CHECKBOX:
function record_CreateFcn(hObject, eventdata, handles)
global PDR
set(hObject,'Value',PDR.record);

function record_Callback(hObject, eventdata, handles)
global PDR
PDR.record = get(hObject,'Value');
clear PDR

% TEST MAA FLAG:
function test_maa_CreateFcn(hObject, eventdata, handles)
global PDR
set(hObject,'Value',PDR.maa_test_flag);
clear PDR

function test_maa_Callback(hObject, eventdata, handles)
global PDR
handles = guihandles(gcf);
PDR.maa_test_flag = get(hObject,'Value');
if PDR.maa_test_flag
    tmp=find(PDR.filename=='_');
    PDR.filename=[PDR.filename(1:tmp(1)) 'MAAs' PDR.filename(tmp(2):end)];
    set(handles.session_fname,'String',PDR.filename);
end
clear PDR
refreshTrials;
refreshSounds;

% JITTER TEST TRIALS:
function jitter_CreateFcn(hObject, eventdata, handles)
global PDR
set(hObject,'String',num2str(PDR.TEST_trial_jitter));
colorBackground(hObject);

function jitter_Callback(hObject, eventdata, handles)
global PDR
PDR.TEST_trial_jitter = str2double(get(hObject,'String'));
set(hObject,'String',num2str(PDR.TEST_trial_jitter));
clear PDR
refreshTrials;

% NO. TEST TRIALS:
function n_test_trials_CreateFcn(hObject, eventdata, handles)
global PDR
set(hObject,'String',num2str(PDR.n_test_trials));
colorBackground(hObject);

function n_test_trials_Callback(hObject, eventdata, handles)
global PDR
PDR.n_test_trials = str2double(get(hObject,'String'));
set(hObject,'String',num2str(PDR.n_test_trials));
clear PDR
refreshTrials;

% FREQ. TEST TRIALS:
function freq_test_trials_CreateFcn(hObject, eventdata, handles)
global PDR
set(hObject,'String',num2str(PDR.TEST_trial_freq));
colorBackground(hObject);

function freq_test_trials_Callback(hObject, eventdata, handles)
global PDR
PDR.TEST_trial_freq = str2double(get(hObject,'String'));
set(hObject,'String',num2str(PDR.TEST_trial_freq));
clear PDR
refreshTrials;

% INTER-STIMULUS INTERVAL (Buffers):
function isi_CreateFcn(hObject, eventdata, handles)
global PDR
handles=guihandles(gcf);
PDR.isi_time = (PDR.isi_buf*PDR.buf_pts - (PDR.SOUNDS_length/1000)*PDR.buf_pts)/PDR.stim_Fs;
set(handles.isi_time,'String',num2str(PDR.isi_time,'%2.4f'));
set(hObject,'String',num2str(PDR.isi_buf));
colorBackground(hObject);

function isi_Callback(hObject, eventdata, handles)
global PDR
handles=guihandles(gcf);
PDR.isi_buf = str2double(get(hObject,'String'));
PDR.isi_time = (PDR.isi_buf*PDR.buf_pts - (PDR.SOUNDS_length/1000)*PDR.buf_pts)/PDR.stim_Fs;
set(handles.isi_time,'String',num2str(PDR.isi_time,'%2.4f'));
set(hObject,'String',num2str(PDR.isi_buf));
refreshTrials;

% NO. HAB TRIALS BEFORE FIRST TEST TRIAL:
function prehab_CreateFcn(hObject, eventdata, handles)
global PDR
set(hObject,'String',num2str(PDR.npretrials));
colorBackground(hObject);

function prehab_Callback(hObject, eventdata, handles)
global PDR
PDR.npretrials = str2double(get(hObject,'String'));
set(hObject,'String',num2str(PDR.npretrials));
clear PDR
refreshTrials;

% LENGTH OF SESSION:
function len_session_CreateFxn(hObject, eventdata, handles)
global PDR
lds_switchyard('calcSessionLen');
set(hObject,'String',num2str(PDR.len_session));

% SPL SELECTION:
function spl_CreateFcn(hObject, eventdata, handles)
global PDR
set(hObject,'String',num2str(PDR.SOUNDS_SPL));
colorBackground(hObject);

function spl_Callback(hObject, eventdata, handles)
global PDR
PDR.SOUNDS_SPL = str2double(get(hObject,'String'));
set(hObject,'String',num2str(PDR.SOUNDS_SPL));
% reload calib data and determine scales/attens
% then update display
calibSetup;
clear PDR

% SESSION FILENAME:
function session_fname_CreateFcn(hObject, eventdata, handles)
global PDR
set(hObject,'String',PDR.filename);
colorBackground(hObject);

function session_fname_Callback(hObject, eventdata, handles)
global PDR
PDR.filename = get(hObject,'String');
set(hObject,'String',PDR.filename);
clear PDR

% BIRD ID:
function bird_id_CreateFcn(hObject, eventdata, handles)
global PDR
set(hObject,'String',num2str(PDR.bird_id));
colorBackground(hObject);

function bird_id_Callback(hObject, eventdata, handles)
global PDR
handles = guihandles(gcf);
PDR.bird_id = str2num(get(hObject,'String'));
set(hObject,'String',num2str(PDR.bird_id));
tmp=find(PDR.filename=='_');
PDR.filename=[num2str(PDR.bird_id) PDR.filename(tmp(1):end)];
set(handles.session_fname,'String',num2str(PDR.filename));
% reload calib data and determine scales/attens
% then update display
calibSetup;
clear PDR

% COMMENTS:
function comments_CreateFcn(hObject, eventdata, handles)
global PDR
set(hObject,'String',PDR.comments);
colorBackground(hObject);

function comments_Callback(hObject, eventdata, handles)
global PDR
PDR.comments = get(hObject,'String');
set(hObject, 'String',PDR.comments);
clear PDR

% PLOT TRIALS:
function plot_trials_CreateFcn(hObject, eventdata, handles)
global trials_handle
trials_handle=hObject;

% PLOT SOUNDS:
function plot_sounds_CreateFcn(hObject, eventdata, handles)
global sounds_handle
sounds_handle=hObject;

% REMIX BUTTON CALLBACK:
function remix_Callback(hObject, eventdata, handles)
global PDR
clear PDR
refreshTrials;

% REFRESH TRIAL SEQUENCE:
function refreshTrials
global PDR trials_handle
lds_switchyard('setupTrials');
lds_switchyard('calcSessionLen');
handles = guihandles(gcf);
sec=num2str(PDR.len_session(2));
if length(sec)==1
    sec=['0' sec];
end
minutes=num2str(PDR.len_session(1));
if length(minutes)==1
    minutes=['0' minutes];
end
set(handles.len_session_disp,'String',[minutes ':' sec]);
axes(trials_handle);
set(gca,'FontSize',8);
hold off;
plot(0,0); % clear plot
lead_trialIDs = PDR.SOUNDS_location_sequence(1,:);
lag_trialIDs = PDR.SOUNDS_location_sequence(2,:);
% do not plot lead sounds if testing MAAs
if ~PDR.maa_test_flag
    plot(lead_trialIDs,'wx');
end
hold on;
temp = find(lag_trialIDs == PDR.LAG_hab_pos);
plot(temp,lag_trialIDs(temp),'d','MarkerFaceColor',[0 0 1],'MarkerEdgeColor','none');
%temp = find(lag_trialIDs ~= PDR.LAG_hab_pos);
%for i=1:length(temp)
%    delta = lag_trialIDs(temp(i)) - PDR.LAG_hab_pos;
%    plot(temp(i),lag_trialIDs(temp(i)),'d','MarkerFaceColor',[abs(delta/25) 0 1-abs(delta/25)],'MarkerEdgeColor','none');
%end
temp=find(lag_trialIDs ~= PDR.LAG_hab_pos);
plot(temp,lag_trialIDs(temp),'d','MarkerFaceColor',[0 1 0],'MarkerEdgeColor','none');
title('Trial Sequence')
xlabel('Trial #','FontSize',8); ylabel('Azimuth (deg.)','FontSize',8);
set(gca,'Color',[0 0 0]);
clear PDR trials_handle


% REFRESH SOUNDS:
function refreshSounds
global PDR sounds_handle 
lds_switchyard('AMStim'); % calculate lead lag sounds using correlation and state values (for reproducible sounds)
handles=guihandles(gcf);
for i0=1:PDR.SOUNDS_num_carriers
    temp(i0)=PDR.SOUNDS_env_correlations{i0};
end
set(handles.correlation_display_box,'String',num2str(mean(temp)));
axes(sounds_handle);
set(gca,'FontSize',8);
lds_switchyard('soundBufferSetup');
hold off;
tmp = find(PDR.LAG_sounds{1}~=0);
start = tmp(1); stop=tmp(end);
xes = 0:(1/1000):2*PDR.SOUNDS_length;
xes = 1000*xes;

% plot each sound
hold on;
for i1=1:PDR.SOUNDS_num_carriers
    if ~PDR.maa_test_flag
        yes = PDR.LEAD_sounds{i1}(start:stop);
        plot(xes(1:length(yes)),yes+2*i1+1,'r');
    end
    yes = PDR.LAG_sounds{i1}(start:stop);
    plot(xes(1:length(yes)),yes+2*i1,'k');
    
end
xlabel('Time (ms)','FontSize',8);
title('LEAD/LAG SOUNDS (red/black)','FontSize',8)
set(gca,'Color',[.7 .7 .7]);
axis tight
clear PDR trials_handle



% INITIALIZE:
function init_Callback(hObject, eventdata, handles)
refreshTrials;
refreshSounds;
calibSetup;



% START:
function start_Callback(hObject, eventdata, handles)
global PDR
PDR.exit_flag = -1;
clear PDR
close(gcf)


% EXIT:
function exit_Callback(hObject, eventdata, handles)
global PDR
PDR.exit_flag = 1;
clear PDR
close(gcf)


% FIRE PROTON CANNON (Just a harmless bit of fun):
function proton_cannon_Callback(hObject, eventdata, handles)
global PDR
for i=1:10
    set(handles.menu_background,'Color',[rand rand rand]);
    pause(0.1)
    set(handles.menu_background,'Color',[0.75 0.75 0.75]);
    pause(0.1)
end
clear PDR


% colors object backgrounds appropriately:
function colorBackground(hObject)
if ispc
    set(hObject,'BackgroundColor','white');
else
    set(hObject,'BackgroundColor',get(0,'defaultUicontrolBackgroundColor'));
end

function calibSetup
global PDR
handles=guihandles(gcf);
% load and read calibration data... set scales/attens
lds_switchyard('readCalibFiles');
if ~strcmp(PDR.SOUNDS_calib_fnames{1},'ERROR')
    % set display info
    set(handles.speaker_scales_lead,'String',['[' num2str(PDR.SOUNDS_speaker_scales_lead) ']']);
    set(handles.speaker_scales_lag,'String',['[' num2str(PDR.SOUNDS_speaker_scales_lag) ']']);
    set(handles.lead_atten_values,'String',['[' num2str(PDR.SOUNDS_lead_attens) ']']);
    set(handles.calib_fname,'String',PDR.SOUNDS_calib_fnames);
end