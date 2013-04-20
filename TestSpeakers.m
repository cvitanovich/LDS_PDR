% TEST SPEAKERS
% andrew 10/17/2012
% depends: powerSpec() and whnoise()

% PARAMETER SETUP

% get number of speakers
numSpeakers = input('number of speakers to test? ');
% frequencies and sampling rate
minfreq = input('min freq (Hz)? ');
maxfreq = input('max freq (Hz)? ');
Fs = input('sampling rate (samples/sec) (>30kHz)? ');
% duration
duration = input('duration (seconds)? ');
% attenuation
atten = input('attenuation (dB)? ');
% test scale
scale = input('test scale? (0-32000) ');
% number of sounds per speaker
numsnds = input('number of sounds? ');

% FOR TDT
SRATE =  (1/Fs)*10^6; % sampling rate for TDT
NPTS = length(Xtime); % buffer points

% INIT HARDWARE

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



% PREPARE PD1 FOR CONVERSION:
s232('PD1clear',1);
s232('PD1fixbug',1);
s232('PD1nstrms',1, 1, 1);
s232('PD1srate',1,SRATE);
s232('PD1npts',1, NPTS);
s232('PD1clrsched',1);
s232('PD1addsimp',1, s232('IREG',0), s232('DAC',0));
s232('PD1specIB',1, s232('IB',0), s232('IREG',0));
s232('PD1setIO',1,.01,9.99,.01,9.99);
s232('PD1specOB',1,s232('OB',0), s232('ADC',0));

% SET PA4 ATTENUATION:
s232('PA4atten',1,0);
s232('PA4atten',2,0);

% BUILD SOUND BUFFER
BUF_PLAY=s232('_allot16', NPTS);
BUF_TEST=s232('_allotf', NPTS);


% BUILD RECORD BUFFER
BUF_REC=s232('_allot16', NPTS);

% INIT AP2 DATA HANDLER
s232('play',BUF_PLAY);
s232('record',BUF_REC);

% play and record sounds
% then run power spectrum analysis
hSpect = figure;
hold on;
title(['Speaker Diagnostics: '  'Bandwidth=' num2str(minfreq) '-' num2str(maxfreq) 'Hz, sampling=' ...
        num2str(Fs) 'Hz, Dur=' num2str(duration) 's, Atten=' num2str(atten) 'dB, scale=' num2str(scale) ', # sounds=' num2str(numsnds)]);
speakerID=cell(numSpeakers,1);
traces=cell(numSpeakers,numsnds);
colorz = ones(numSpeakers,3);
leg=cell(numSpeakers,1);
for j0 = 1:numSpeakers
    colorz(j0,:) = [1-(j0/numSpeakers) 0.5*(j0/numSpeakers) 0.5*(j0/numSpeakers)];
end
f=cell(numSpeakers,1);
mx=cell(numSpeakers,numsnds);
avg=cell(numSpeakers,1);

for i0=1:numSpeakers
    hWarn = WARNDLG(['Is speaker #' num2str(i0) ' ready to test?'],'speaker setup');
    uiwait(hWarn);
    tmp = input('Name of this speaker? ','s');
    speakerID{i0}=tmp;
    for k0=1:numsnds
        % make a white noise with desired specs
        [X,Xtime] = whnoise(minfreq,maxfreq,Fs,duration);
        s232('pushf',Xtime',NPTS);
        s232('qpopf',BUF_TEST);
        % SCALE SOUND FOR OUTPUT
        s232('qpushf',BUF_TEST);
        s232('scale',scale);
        s232('qpop16',BUF_PLAY);
        s232('PD1arm',1);
        s232('PD1go',1);
        while(s232('PD1status',1))
            % wait for TDT to finish
        end
        s232('qpush16',BUF_REC);
        traces{i0,k0}=s232('pop16');
        % power spectrum analysis
        [f{i0} mx{i0,k0}]=powerSpec(traces{i0,k0},Fs,512);
    end
    
    % averaging power spectrum across sounds
    tmp = mx{i0,1};
    for k1=1:numsnds-1
        tmp=tmp+mx{i0,k1+1};
    end
    avg{i0}=tmp./numsnds;

    endpt=find(f{i0}>=15000);
    % only plot 1-15000Hz
    plot(f{i0}(2:endpt(1)),avg{i0}(2:endpt(1)),'Color',colorz(i0,:));
    set(gca,'FontSize',8);
    xlabel('Frequency (Hz)','FontSize',8);
    ylabel('dB','FontSize',8);
end
legend(speakerID);

S232('APunlock', 0);
S232('XBunlock', 0);