function LDS_PDR_double_buffered
% A FUNCTION TO RUN A SPATIAL PDR EXPERIMENT WITH AN ADAPTOR
global PDR TDT session

%% INITIATE TDT PARAMETERS HERE
TDT.nPlayChannels=2;
TDT.playpts = {[PDR.buf_pts PDR.buf_pts],[PDR.buf_pts PDR.buf_pts]};
if(PDR.record>0)
    TDT.nRecChannels=2;
    TDT.recpts=TDT.playpts;
else
    TDT.nRecChannels=0;
end
TDT.dec_factor=PDR.decimationfactor;
TDT.din = 1;
TDT.Fs = PDR.stim_Fs;
TDT.npts_total_play=PDR.npts_totalplay;
TDT.outFN{1}=[PDR.filename '_REC1.vrt'];
TDT.outFN{2}=[PDR.filename '_REC2.vrt'];
TDT.ntrials=PDR.ntrials;
TDT.srate=1e6 / TDT.Fs;
TDT.display_flag=1; % flag to display trace during session
TDT.max_signal_jitter=PDR.TEST_trial_jitter;
TDT.disp_proc_time=1; % flag to display processing time for each buffer segment


%% CHECK PARAMETERS
out=check_params;
if(out==-1)
    return;
end

%% INITIALIZE DOUBLE BUFFER PROGRESS VARIABLES
signalScale=0;
readflag=0;
Signalcnt=1; % should be 1 (initialized to 0 in the original C code)
signalScale=0;
record=(TDT.nRecChannels>0);
cnt=1; % ISI counter


%% ADAPTOR FILTERING PARAMS
% recording adaptor sequence:
PDR.ADAPT_state_seq=[];
% initial state (picked randomly from list of adaptor states)
rand_idx=round((length(PDR.ADAPT_state_list)-1)*rand+1);
adapt_state = PDR.ADAPT_state_list(rand_idx);
PDR.ADAPT_state_seq(end+1)=rand_idx;
% circular buffer for continuous filtered adaptor:
CIRC_BUFS.adaptor=zeros(1,(length(PDR.ADAPT_coefs)+PDR.buf_pts));
% circular buffers for HRTF filtering (left/right):
CIRC_BUFS.left=CIRC_BUFS.adaptor; CIRC_BUFS.right=CIRC_BUFS.adaptor;

if(true) % for debugging without the TDT
    %% INITIALIZE TDT
    out=TDT_init;
    if(out==-1); return; end;
    
    %% INITIALIZE BUFFERS
    TDT=TDT_buffers(TDT);
    LEFT_PLAY = [TDT.stim_buffers{1}(1) TDT.stim_buffers{1}(2)];
    RIGHT_PLAY = [TDT.stim_buffers{2}(1) TDT.stim_buffers{2}(2)];
    REC_A = [TDT.rec_buffers{1}(1) TDT.rec_buffers{1}(2)];
    REC_B = [TDT.rec_buffers{2}(1) TDT.rec_buffers{2}(2)];
    DEC_A = [TDT.dec_buffers{1}(1) TDT.dec_buffers{1}(2)];
    DEC_B = [TDT.dec_buffers{2}(1) TDT.dec_buffers{2}(2)];
    
    %% INITIALIZE PD1
    PD1_init(TDT);
    
    %% FILTER TEST SOUNDS WITH HRTFS
    % buffer assignments for TDT
    TESTLEFT=zeros(PDR.TEST_nlocs,PDR.buf_pts);
    TESTRIGHT=TESTLEFT;
    filtered_test_left=zeros(1,PDR.buf_pts);
    filtered_test_right=filtered_test_left;
    % loop through test sounds
    for(j=1:PDR.TEST_nlocs)
        % filter each test sound with HRTFS & Store on AP2 Card
        filtered_test_left=filter(HRTF.TestL(:,j),1,PDR.TEST_sound);
        filtered_test_right=filter(HRTF.TestR(:,j),1,PDR.TEST_sound);
        rms_val=(sqrt(mean(filtered_test_left.^2))+sqrt(mean(filtered_test_left.^2)))/2;
        filtered_test_left = (PDR.TEST_target_rms/rms_val).*filtered_test_left;
        filtered_test_right = (PDR.TEST_target_rms/rms_val).*filtered_test_right;
        TESTLEFT(j,:)=filtered_test_left;
        TESTRIGHT(j,:)=filtered_test_right;
    end
    clear filtered_test_left filtered_test_right
    
    %% SET ATTENS
    TDT.attens=[PDR.base_atten PDR.base_atten];
    TDT_attens(TDT);
    
    %% SIGNAL RAMP BUFFER
    TDT.ramp_buffer=TDT.n_total_buffers+1;
    S232('allotf',TDT.ramp_buffer,PDR.buf_pts);
    S232('pushf',PDR.ADAPT_ramp,PDR.buf_pts);
    S232('qpopf',TDT.ramp_buffer);
    TDT.n_total_buffers=TDT.n_total_buffers+1;
    
    %% ZERO PLAY BUFFERS
    zero_play_buffers(TDT);
    
    %% START SEQUENCED PLAY
    init_sequenced_play(TDT);
    
    
end

%% MAIN LOOP
seekpos=0;
while(seekpos < TDT.npts_total_play)
    % WAIT FOR LAST BUFFER TO FINISH
    while(check_play(TDT.nPlayChannels,[LEFT_PLAY(1) RIGHT_PLAY(1)])); end;
    
    tic;
    
    % SET FLAGS
    SignalPlayFlag=0;
    if(signalScale>0)
        readflag=1;
    elseif(readflag>0)
        readflag=0;
        SignalPlayFlag=1;
    end
    % COUNTDOWN (in seconds) TO NEXT TEST TRIAL
    cntdown=update_countdown(cnt,Signalcnt);
    % DISPLAY SESSION INFO
    disp_session_info(cntdown,seekpos);
    % PREPARE ADAPTOR
    if(PDR.flag_adapt>0)
        [adapt_state, adapt_left, adapt_right, CIRC_BUFS]=adaptor_filter(adapt_state,CIRC_BUFS);
    end
    % TEST TRIAL SCALE
    test_left=zeros(1,PDR.buf_pts);
    test_right=zeros(1,PDR.buf_pts);
    if(cnt==PDR.isi_buf)
        loc=PDR.TEST_loc_sequence(Signalcnt);
        if(loc~=0)
            signalScale=PDR.TEST_scale_sequence(Signalcnt);
            test_left=TESTLEFT(loc,:);
            test_right=TESTRIGHT(loc,:);
        else % not playing test sound in this trial!
            signalScale=0;
        end
    end
    % SETUP ADAPTOR FOR TRIAL BUFFER
    if(cnt==PDR.isi_buf && PDR.flag_adapt>0)
        % clear circular buffers & set new seed value
        rand_idx=round((length(PDR.ADAPT_state_list)-1)*rand+1);
        adapt_state = PDR.ADAPT_state_list(rand_idx);
        PDR.ADAPT_state_seq(end+1)=rand_idx; % save state sequence
        CIRC_BUFS.adaptor=zeros(1,(length(PDR.ADAPT_coefs)+PDR.buf_pts));
        CIRC_BUFS.left=CIRC_BUFS.adaptor; CIRC_BUFS.right=CIRC_BUFS.adaptor;
        % paste prior/new buffers together (the trial ramp will remove any
        % possible discontinuities in the adaptor)
        [adapt_state, aleft_new, aright_new, CIRC_BUFS]=adaptor_filter(adapt_state,CIRC_BUFS);
        adapt_left=[adapt_left(1:PDR.TEST_on_delay_pts) zeros(1,length(PDR.TEST_sound)) ...
            aleft_new((end-(PDR.TEST_on_delay_pts+length(PDR.TEST_sound))+1):end)];
        adapt_right=[adapt_left(1:PDR.TEST_on_delay_pts) zeros(1,length(PDR.TEST_sound)) ...
            aright_new((end-(PDR.TEST_on_delay_pts+length(PDR.TEST_sound))+1):end)];
    end
    
    % LEFT CHANNEL BUFFER
    update_buffer(LEFT_PLAY(1),adapt_left,test_left,cnt,Signalcnt,signalScale);
    % RIGHT CHANNEL BUFFER
    update_buffer(RIGHT_PLAY(1),adapt_right,test_right,cnt,Signalcnt,signalScale);
    % UPDATE ISI COUNTER AND SIGNAL COUNT
    if(cnt==PDR.isi_buf)
        cnt=round(TDT.max_signal_jitter.*rand);
        Signalcnt=Signalcnt+1;
    else
        cnt=cnt+1;
    end
    % RECORD PDR TRACE
    if(record)
        % First Record Channel:
        ch=1; buf=1;
        session.last_buffer=record_buffer(REC_A(buf),DEC_A(buf),SignalPlayFlag,TDT.display_flag);
        session.test_flag=SignalPlayFlag;
        sessionPlots2('Update Trace Plot');
        % Second Record Channel:
        ch=2; buf=1;
        record_buffer(REC_B(buf),DEC_B(buf),SignalPlayFlag,0);
    end
    % PROCESSING TIME
    if(TDT.disp_proc_time)
        t1=toc;
        figure(h1); delete(session.txt(4)); axis off;
        session.txt(4)= text(.01,.3,sprintf('Processing Time: %.3f seconds',t1),'FontSize',10);
        drawnow;
    end
    
    % UPDATE SEEK POSITION
    seekpos = seekpos + PDR.buf_pts;
    
    if(seekpos<TDT.npts_total_play)
        
        % WAIT FOR LAST BUFFER TO FINISH
        while(check_play(TDT.nPlayChannels,[LEFT_PLAY(2) RIGHT_PLAY(2)])); end;
        
        tic;
        
        % SET FLAGS
        SignalPlayFlag=0;
        if(signalScale>0)
            readflag=1;
        elseif(readflag>0)
            readflag=0;
            SignalPlayFlag=1;
        end
        % COUNTDOWN (in seconds) TO NEXT TEST TRIAL
        cntdown=update_countdown(cnt,Signalcnt);
        % DISPLAY SESSION INFO
        disp_session_info(cntdown,seekpos);
        % PREPARE ADAPTOR
        if(PDR.flag_adapt>0)
            [adapt_state, adapt_left, adapt_right, CIRC_BUFS]=adaptor_filter(adapt_state,CIRC_BUFS);
        end
        % TEST TRIAL SCALE
        test_left=zeros(1,PDR.buf_pts);
        test_right=zeros(1,PDR.buf_pts);
        if(cnt==PDR.isi_buf)
            loc=PDR.TEST_loc_sequence(Signalcnt);
            if(loc~=0)
                signalScale=PDR.TEST_scale_sequence(Signalcnt);
                test_left=TESTLEFT(loc,:);
                test_right=TESTRIGHT(loc,:);
            else % not playing test sound in this trial!
                signalScale=0;
            end
        end
        % SETUP ADAPTOR FOR TRIAL BUFFER
        if(cnt==PDR.isi_buf && PDR.flag_adapt>0)
            % initialize circular buffers & set new seed value
            rand_idx=round((length(PDR.ADAPT_state_list)-1)*rand+1);
            adapt_state = PDR.ADAPT_state_list(rand_idx);
            PDR.ADAPT_state_seq(end+1)=rand_idx; % save state sequence
            CIRC_BUFS.adaptor=zeros(1,(length(PDR.ADAPT_coefs)+PDR.buf_pts));
            CIRC_BUFS.left=CIRC_BUFS.adaptor; CIRC_BUFS.right=CIRC_BUFS.adaptor;
            % paste prior/new buffers together (the trial ramp will remove any
            % possible discontinuities in the adaptor)
            [adapt_state, aleft_new, aright_new, CIRC_BUFS]=adaptor_filter(adapt_state,CIRC_BUFS);
            adapt_left=[adapt_left(1:PDR.TEST_on_delay_pts) zeros(1,length(PDR.TEST_sound)) ...
                aleft_new((end-(PDR.TEST_on_delay_pts+length(PDR.TEST_sound))+1):end)];
            adapt_right=[adapt_left(1:PDR.TEST_on_delay_pts) zeros(1,length(PDR.TEST_sound)) ...
                aright_new((end-(PDR.TEST_on_delay_pts+length(PDR.TEST_sound))+1):end)];
        end
        % LEFT CHANNEL BUFFER
        update_buffer(LEFT_PLAY(2),adapt_left,test_left,cnt,Signalcnt,signalScale);
        % RIGHT CHANNEL BUFFER
        update_buffer(RIGHT_PLAY(2),adapt_right,test_right,cnt,Signalcnt,signalScale);
        % RECORD PDR TRACE
        if(record)
            % First Record Channel:
            ch=1; buf=2;
            session.last_buffer=record_buffer(REC_A(buf),DEC_A(buf),SignalPlayFlag,TDT.display_flag);
            session.test_flag=SignalPlayFlag;
            sessionPlots2('Update Trace Plot');
            % Second Record Channel:
            ch=2; buf=2;
            record_buffer(REC_B(buf),DEC_B(buf),SignalPlayFlag,0);
        end
        % UPDATE ISI COUNTER AND SIGNAL COUNT
        if(cnt==PDR.isi_buf)
            cnt=round(TDT.max_signal_jitter.*rand);
            Signalcnt=Signalcnt+1;
        else
            cnt=cnt+1;
        end
        % UPDATE SEEK POSITION
        seekpos = seekpos + PDR.buf_pts;
        % CHECK IF CORRECT BUFFERS ARE PLAYING
        if(~check_play(TDT.nPlayChannels,[LEFT_PLAY(1) RIGHT_PLAY(1)]))
            disp(sprintf('Got %.2f percentof the way',seekpos/TDT.npts_total_play));
            disp('APcard too slow? or outFNs incorrect?');
            break;
        end
        % PROCESSING TIME
        if(TDT.disp_proc_time)
            t1=toc;
            figure(h1); delete(session.txt(4)); axis off;
            session.txt(4)= text(.01,.3,sprintf('Processing Time: %.3f seconds',t1),'FontSize',10);
            drawnow;
        end
    end
    
    if(Signalcnt>TDT.ntrials); break; end;
    
end

%% WAIT FOR LAST BUFFERS TO FINISH
while(S232('playseg',TDT.din)==RIGHT_PLAY(2) || S232('playseg',TDT.din)==LEFT_PLAY(2)); end;
TDT_flush;

%% SUBROUTINES

function disp_session_info(cntdown,seekpos)
global TDT session
figure(session.hFig);
subplot(session.hInfo);
delete(session.txt(1)); delete(session.txt(2)); delete(session.txt(3)); axis off;
elapsed_time=seekpos*(TDT.srate/1e6);
min=floor(elapsed_time/60); sec=elapsed_time-(60*min);
session.txt(1)=text(.01,.9,sprintf('ELAPSED TIME:    %i minutes   %.2f seconds',min,sec),'FontSize',12);
rem_time = TDT.npts_total_play*(TDT.srate/1E6) - elapsed_time;
min=floor(rem_time/60); sec=rem_time-(60*min);
session.txt(2)=text(.01,.7,sprintf('REMAINING TIME:  %i minutes   %.2f seconds',min,sec),'FontSize',12);
min=floor(cntdown/60); sec=cntdown-(60*min);
session.txt(3)=text(.01,.5,sprintf('NEXT TEST TRIAL: %i minutes   %.2f seconds',min,sec),'FontSize',12);
drawnow;

function cntdown=update_countdown(cnt,Signalcnt)
global PDR TDT
cntdown=(PDR.isi_buf-cnt)*(PDR.buf_pts*(TDT.srate/1e6));
if(PDR.TEST_scale_sequence(Signalcnt)==0)
    for(j=1:(PDR.ntrials-Signalcnt))
        cntdown=cntdown+(PDR.isi_buf+1)*(PDR.buf_pts*TDT.srate/1e6);
        if(PDR.TEST_scale_sequence(j+Signalcnt)>0)
            break;
        end
    end
end

function [adapt_state, adapt_left, adapt_right, CIRC_BUFS]=adaptor_filter(adapt_state,CIRC_BUFS)
global PDR HRTF
% get new set of pseudorandomly generated numbers and run through a FIR filter
rand('state',adapt_state);
new_buffer=rand(1,PDR.buf_pts);
adapt_state=rand('state');

[filtered_buffer, CIRC_BUFS.adaptor] = circ_fir(CIRC_BUFS.adaptor,new_buffer,PDR.ADAPT_coefs);
% filter adaptor with left/right HRTF coefficients
[adapt_left, CIRC_BUFS.left] = circ_fir(CIRC_BUFS.left,filtered_buffer,HRTF.AdaptL);
[adapt_right, CIRC_BUFS.right] = circ_fir(CIRC_BUFS.right,filtered_buffer,HRTF.AdaptR);

function update_buffer(BUF_ID,adaptor,test,cnt,Signalcnt,signalScale)
global PDR session
S232('dropall');
if(PDR.flag_adapt)
    S232('pushf',adaptor,PDR.buf_pts); S232('scale',PDR.ADAPT_scale);
    if(cnt==PDR.isi_buf)
        S232('qpushf',PDR.ADAPT_ramp); S232('mult');
    end
else
    S232('dpush',PDR.buf_pts); S232('value',0);
end
if(cnt==PDR.isi_buf)
    loc=PDR.TEST_loc_sequence(Signalcnt);
    if(loc~=0)
        % plot a marker on trial sequence plot
        x=Signalcnt+1; y=loc;
        figure(session.hTrialPlot);
        if exist('hMark')
            delete(hMark);
        end
        hMark=plot(x,y,'MarkerSize',12,'Marker','s',...
            'MarkerFaceColor','none','MarkerEdgeColor','w');
        % push test onto stack and add to the ramped adaptor buffer:
        S232('qpushf',test);
        S232('scale',signalScale);
        S232('add'); % add to adaptor buffer
    end
end
S232('qpop16',BUF_ID);

function out=check_play(nPlayChannels,BUFFERS)
out=true;
for ch=1:nPlayChannels
    if(S232('playseg',ch)~=BUFFERS(ch))
        out=false; % error
    end
end

function out=check_params
global TDT PDR HRTF
out=1;
% check decimation factor
div=PDR.buf_pts/2^PDR.decimationfactor;
if(round(div)~=div)
    h = warndlg('buf_pts and decimationfactor incompatible');
    uiwait(h);
    out=-1;
end

% check npts total play
div=PDR.npts_totalplay/PDR.buf_pts;
if(round(div)~=div)
    h = warndlg('buf_pts and npts total play incompatible');
    uiwait(h);
    out=-1;
end

% check HRTF arrays
if(size(HRTF.AdaptL,1)~=1 && size(HRTF.AdaptL,2)~=PDR.HRTF_nlines)
    h = warndlg('Adaptor HRTF arrays must be 1 x HRTF_nlines');
    uiwait(h);
    out=-1;
end
if(size(HRTF.AdaptR,1)~=1 && size(HRTF.AdaptR,2)~=PDR.HRTF_nlines)
    h = warndlg('Adaptor HRTF arrays must be 1 x HRTF_nlines');
    uiwait(h);
    out=-1;
end

if(size(HRTF.TestL,2)~=PDR.TEST_nlocs && size(HRTF.TestL,1)~=PDR.HRTF_nlines)
    h = warndlg('Test HRTF arrays must be HRTF_nlines x # Test Locs');
    uiwait(h);
    out=-1;
end
if(size(HRTF.TestR,2)~=PDR.TEST_nlocs && size(HRTF.TestR,1)~=PDR.HRTF_nlines)
    h = warndlg('Test HRTF arrays must be HRTF_nlines x # Test Locs');
    uiwait(h);
    out=-1;
end

% check ramp vector
if(size(PDR.ADAPT_ramp,1)~=1 && size(PDR.ADAPT_ramp,2)~=PDR.buf_pts)
    h = warndlg('Ramp must be 1 x buf_pts');
    uiwait(h);
    out=-1;
end

% check test sound
if(size(PDR.TEST_sound,1)~=1 && size(PDR.TEST_sound,2)~=PDR.buf_pts)
    h = warndlg('Test sound must be 1 x buf_pts');
    uiwait(h);
    out=-1;
end

% check scale sequence
if(size(PDR.TEST_scale_sequence,1)~=1 && size(PDR.TEST_scale_sequence,2)<PDR.n_trials)
    h = warndlg('Scale sequence must be a 1 x n (n>=ntrials), row vector');
    uiwait(h);
    out=-1;
end

% check location sequence
if(size(PDR.TEST_loc_sequence,1)~=1 && size(PDR.TEST_loc_sequence,2)<PDR.n_trials)
    h = warndlg('Location sequence must be a 1 x n (n>=ntrials), row vector');
    uiwait(h);
    out=-1;
end


