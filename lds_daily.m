% lds daily analysis
clear all;
global A
A.pflag = 0; %print flag (set to 1 to print figures)
A.sflag = 0; %save flag (set to 1 to save figures)


% SELECT HEADER FILE FOR ANALYSIS


dt='C:\alex\code';
cd ('C:\alex\data');
path(path,dt);
[A.fname, A.pname] = uigetfile('*.mat', 'Select header file for daily analysis');
global PDR passmein

if A.fname==0
    disp('Couldn''t find file!')
    return
end

A.analysis_dir = ['c:\alex\data\analysis' A.fname(1:end-4) '_analysis'];

if A.sflag
    if ~exist(A.analysis_dir)
        status = mkdir(A.analysis_dir);
        if status ~= 1
            disp('Couldn''t create analysis directory!!!');
            return
        end
    else
        disp('Analysis directory already exists!!!');
        return
    end
end

cd (A.pname)
load(A.fname)

if ~isempty(dt)
    A.DATApath = dt;
end
A.infopts=2; % first 2 points used for trial info (trial marker=1, location=1,2,3...,8,9,etc)
A.PDRfile=passmein.FN1;
tmp = find(PDR.LAG_sounds{1}~=0);
A.sndStart = tmp(1)/size(PDR.LAG_sounds{1},2); % how far through the buffer (fractional) does the sound start
A.dec_Fs = PDR.stim_Fs/2^PDR.decimationfactor; % decimated samp. rate
A.dec_pts = PDR.buf_pts/2^PDR.decimationfactor; % num buf pts (decimated)
A.time2integrate = A.dec_Fs*2; % using integration time of 2 sec
A.bufftime = (PDR.buf_pts/A.dec_Fs)*1000; % actual timelength of buffer in ms
A.defaultFlg = {'n'};
A.invertFlg=inputdlg('Invert traces? (y/n)','Invert Trace Dlg',1,A.defaultFlg);

A.scrn = get(0, 'ScreenSize');
A.file='';
for i=1:length(A.PDRfile)
    if A.PDRfile(i)~='_'
        A.file=[A.file A.PDRfile(i)];
    else
        A.file=[A.file '\' A.PDRfile(i)];
    end
end

%***************************************************
%*******LOAD AND FILTER DATA ***********************
%***************************************************

lds_func('load_and_filter_data');

%***************************************************
%*******REMOVE BLINKS ******************************
%***************************************************
lds_func('remove_blinks');

if A.sflag
    cd (A.analysis_dir) % move to analysis dir to save figs, data, etc.
end


% MAIN FIGURE SETUP

A.hFig=figure;
set(gcf,'Position',[.15 .15 .75*A.scrn(3) .75*A.scrn(4)]);
for i=1:5
    A.h(i)=subplot(5,1,i);
end

%***************************************************
%*******DIAGNOSTIC PLOTS ***************************
%***************************************************

% Plot PDR magnitudes for all trials
% Plot Batch averages of hab trials

lds_func('pdr_diagnostic_plots');

%***************************************************
% Plot running average of hab trial areas
%***************************************************

winnum = 60*(A.dec_pts*(PDR.isi_buf+1)/A.dec_Fs)^-1; % 2 minute window to calculate running average (trials per window)
windur=1;
lds_func('running_avg_habtrials',winnum,windur,A.h(4));

winnum = 5*winnum; % 5 minute window to calculate running average (trials per window)
windur=5;
lds_func('running_avg_habtrials',winnum,windur,A.h(5));

%*****************************************************
% parse trials (and sort zscores, areas, traces, etc.)
%*****************************************************
for i0=1:length(PDR.SOUNDS_location_sequence)
    PDR.trialID(i0)=find(PDR.SOUNDS_location_sequence(2,i0)==PDR.SOUNDS_azimuths);
end
A.habID=find(PDR.SOUNDS_azimuths==PDR.LAG_hab_pos);
lds_func('parse_trials');

%***************************************************
% plot average traces
%***************************************************
lds_func('plot_average_traces');

if length(A.trials.types) == 1 % there were only habit trials
    
% do no more analysis

else % there were test trials
end
