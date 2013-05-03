function sessionPlots(options)
% plots information about a PDR session in real time 
% session=structure with data for the session, 
% options=tells sessionPlots what action to take
% required to initialize:
% structure with these parameters:
% hab_xes, hab_yes, trial_xes, trial_yes
% ntrials, min_yes, max_yes
% bufpts, decpts, isi, trials_to_show
% zoomval

% other required parameters:
% sound_onset, npts_totalplay, srate
% last_buffer
% stim_fs
global session
switch options
    
    case 'Initialize'
        
        % INIT PLOTS
        % handles
        
        session.hTxt=zeros(1,10); % text handles
        session.hSub=zeros(1,10); % subplot handles
        session.hMark=zeros(1,100);
        session.hMark2=zeros(1,100);
        session.hBox=0; % box marker handle
        session.ymax=32768; session.ymin=-32768; % for plotting trace
        screen_size = get(0, 'ScreenSize');% get scrn size
        
        close all; % close all figures
        session.hFig=figure; whitebg(gcf,'k');
        set(session.hFig,'renderer','OpenGL'); %use OpenGL for renderer
        set(session.hFig, 'Position', [0.17*screen_size(3) 0.04*screen_size(4) 0.8*screen_size(3) 0.90*screen_size(4)] );
        
        session.hSub(1)=subplot(3,7,[17:21]); hold on; % trial plot
        plot(session.hab_xes,session.hab_yes,'g*','MarkerSize',1);
        plot(session.trial_xes,session.trial_yes,'r+');
        xlabel('Trial #'); ylabel(session.trial_param);
        title('Trial Sequence');
        %legend({'Habituating Stimulus','Test Stimuli'},-1);
        xlim([0 session.ntrials]); ylim([session.min_yes session.max_yes]);
        session.hBox=scatter(-1,10^6,30,'w','s');
        session.trialcnt=0; session.trialval=0;
        
        % session text info
        session.hSub(2)=subplot(3,7,15:16); axis off; hold on;
        session.txt{1}='ELAPSED TIME:    ??? minutes   ??? seconds';
        session.hTxt(1) = text(.01,.9,session.txt(1),'FontSize',8);
        session.txt{2}='REMAINING TIME:  ??? minutes   ??? seconds';
        session.hTxt(2) = text(.01,.7,session.txt(2),'FontSize',8); 
        session.txt{3}='NEXT TEST TRIAL: ??? minutes   ??? seconds';
        session.hTxt(3) = text(.01,.5,session.txt(3),'FontSize',8);
        session.txt{4}='Processing Time: ???? seconds';
        session.hTxt(4) = text(.01,.3,session.txt(4),'FontSize',8);
        session.elapsed_time=[0 0];
        tmp=session.npts_totalplay*(session.srate/1E6);
        session.rem_time=[floor(tmp/60) tmp-(60*floor(tmp/60))];
        session.next_test_trial=[0 0];
        session.proc_time=[];
        
        session.hSub(3)=subplot(3,7,[1:14]); cla; hold on; % trace plot
        set(session.hSub(3),'XtickLabel','');
        title('PDR Trace');
        session.decpts=ceil(session.bufpts/2^session.dec_fact);
        session.trace_pts=session.decpts*session.isi*session.trials_to_show;
        session.trace_xes=1:session.trace_pts;
        % circular buffered trace
        session.trace_yes=zeros(1,session.trace_pts);
        session.trace_xes(end+1)=session.trace_pts; 
        session.trace_yes(end+1)=session.ymax;
        session.trace_xes(end+1)=0;
        session.trace_yes(end+1)=session.ymax;
        session.dec_fs = ceil(session.stim_fs/2^session.dec_fact); % decimated sample rate
        %session.dec_xes=session.trace_xes./session.dec_fs; % convert to time values
        session.hLine=line([session.trace_xes session.trace_xes],...
            [session.trace_yes session.trace_yes],'LineWidth',1,'Color','w');
        xlim([0 session.trace_pts]); ylim([session.ymin session.ymax]);
        % initialize variable for latest buffer
        session.last_buffer=zeros(1,session.decpts);
        session.test_flag=0;
        session.flag_list=[];
        session.test_flag_list=[];
        drawnow;
        
    case 'Update Trial Plot'
        % draw a marker to indicate next trial
        figure(session.hFig);
        subplot(session.hSub(1)); hold on;
        set(session.hBox,'xdata',session.trialcnt,'ydata',session.trialval);
        drawnow;
        
    case 'Update Session Info'
        % clear previous text
        figure(session.hFig);
        subplot(session.hSub(2)); hold on;
        delete(session.hTxt(1)); session.hTxt(1)=0;
        delete(session.hTxt(2)); session.hTxt(2)=0;
        delete(session.hTxt(3)); session.hTxt(3)=0;
        if session.hTxt(4)~=0
            delete(session.hTxt(4)); session.hTxt(4)=0;
        end

        % write new text
        session.txt{1}=sprintf('ELAPSED TIME:    %1.0f minutes   %4.2f seconds',...
            session.elapsed_time(1),session.elapsed_time(2));
        session.hTxt(1) = text(.01,.9,session.txt(1),'FontSize',8);
        session.txt{2}=sprintf('REMAINING TIME:  %1.0f minutes   %4.2f seconds',...
            session.rem_time(1),session.rem_time(2));
        session.hTxt(2) = text(.01,.7,session.txt(2),'FontSize',8); 
        session.txt{3}=sprintf('NEXT TEST TRIAL: %1.0f minutes   %4.2f seconds',...
            session.next_test_trial(1),session.next_test_trial(2));
        if session.next_test_trial(1)==0 && session.next_test_trial(2)<2
            col='r';
        else
            col='w';
        end
        session.hTxt(3) = text(.01,.5,session.txt(3),'FontSize',8,'Color',col);
        if length(session.proc_time)>0
            session.txt{4}=sprintf('Processing Time: %5.3f seconds',session.proc_time(end));
            session.hTxt(4) = text(.01,.3,session.txt(4),'FontSize',8);
        end
        drawnow;
        
        
    case 'Finish Session'
        session.txt{1}=sprintf('ELAPSED TIME:    %1.0f minutes   %4.2f seconds',...
            session.elapsed_time(1),session.elapsed_time(2));
        session.hTxt(1) = text(.01,.9,session.txt(1),'FontSize',8);
        delete(session.hTxt(2)); session.hTxt(2)=0;
        session.txt{2} = sprintf('SESSION COMPLETE!');
        session.hTxt(2) = text(.01,.7,session.txt(2),'FontSize',8,'Color',[1 0 0]);
        drawnow;
        
    case 'Update Trace Plot'
        figure(session.hFig);
        subplot(session.hSub(3)); hold on;
        % circular buffer update
        session.trace_yes(1:(session.trace_pts-session.decpts))=session.trace_yes((session.decpts+1):end-2);
        session.trace_yes((end-session.decpts-1):(end-2))=session.last_buffer;
        
        % update xes
        %session.dec_xes(1:end-2)=session.dec_xes(1:end-2)+session.decpts;
        %session.dec_xes(end-1)=session.dec_xes(end-2);
        %session.dec_xes=session.trace_xes./session.dec_fs; % convert to time values
        session.flag_list=session.flag_list-session.decpts;
        tmp=find(session.flag_list>=0); session.flag_list=session.flag_list(tmp);
        session.test_flag_list=session.test_flag_list-session.decpts;
        tmp=find(session.test_flag_list>=0); session.test_flag_list=session.test_flag_list(tmp);
        if session.test_flag==1
            session.flag_list=[session.trace_xes(end-2-session.decpts+ceil(session.sound_onset/2^session.dec_fact)) session.flag_list]; %[session.dec_xes(end-2-session.decpts+1+ceil(session.sound_onset/2^session.dec_fact)) session.flag_list];
        elseif session.test_flag==Inf
            session.test_flag_list=[session.trace_xes(end-2-session.decpts+ceil(session.sound_onset/2^session.dec_fact)) session.test_flag_list];%[session.dec_xes(end-2-session.decpts+1+ceil(session.sound_onset/2^session.dec_fact)) session.test_flag_list];
        end
        % update trace plot
        if session.ymax>session.zoomval*max(session.trace_yes(1:end-2)) || session.ymin<session.zoomval*min(session.trace_yes(1:end-2))
            session.ymax=max(session.trace_yes(1:end-2))+session.zoomval*abs(max(session.trace_yes(1:end-2))); session.ymin=min(session.trace_yes(1:end-2))-session.zoomval*abs(min(session.trace_yes(1:end-2)));
            ylim([session.ymin session.ymax]);
            session.trace_yes(end-1:end)=session.ymax*ones(1,2);
        end
            
        set(session.hLine,'xdata',[session.trace_xes session.trace_xes],'ydata',...
            [session.trace_yes session.trace_yes]);
        % plot sound onset indicators
        %start=session.dec_xes(1);
        %stop=session.dec_xes(end-2);
        start=session.trace_xes(1);
        stop=session.trace_xes(end-2);
        
        % marker lines
        chk=1; hTemp=0;
        while chk
            
            hTemp=findobj(gca,'Tag','marker');
            if hTemp>0
                delete(hTemp(1)); hTemp=0;
            else
                break;
            end
        end
        
        temp=find(session.flag_list>=start);
        for i=1:length(temp)
            session.hMark(i)=line([session.flag_list(temp(i)) session.flag_list(temp(i))],...
                [session.ymin session.ymax],'LineWidth',1,'Color','g','LineStyle','-','Tag','marker');
        end
        temp2=find(session.test_flag_list>=start);
        for i=1:length(temp2)
            session.hMark2(i)=line([session.test_flag_list(temp2(i)) session.test_flag_list(temp2(i))],...
                [session.ymin session.ymax],'LineWidth',1,'Color','r','LineStyle','-','Tag','marker');
        end

        drawnow; % only redraw plot when stimuli are played


end

return;