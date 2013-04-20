function [varargout] = lds_func(fcn,varargin)
global PDR passmein A

switch nargin
    case 4
        var1=varargin{1};
        var2=varargin{2};
        var3=varargin{3};
        feval(fcn,var1,var2,var3);
    otherwise
        feval(fcn);
end

function load_and_filter_data
    global PDR passmein A
    A.numpts=passmein.buf_pts/(2^passmein.decimateFactor);
    A.numbufs=passmein.nptsTotalPlay/(2^passmein.decimateFactor)/A.numpts;
    if exist([A.pname PDR.filename '_REC1.vrt'],'file')
        fid=fopen([A.pname PDR.filename '_REC1.vrt']); A.data1=fread(fid,'short'); fclose(fid);
    else
        fid=fopen([A.pname PDR.filename '_REC1.frf']); A.data1=fread(fid,'short'); fclose(fid);
    end
    keyboard
    A.trialtype=A.data1(1:A.numpts:size(A.data1));
    A.idx2trials=find(A.trialtype==1);
    A.idx2trials = A.idx2trials(1:end);
    A.PDRdata.trace=cell(length(A.idx2trials),1);
    h0 = waitbar(0,'Parsing Trial Data...');
    cnt=0;
    for t=1:length(A.idx2trials)
        cnt=cnt+1;
        q=1 + A.numpts*(A.idx2trials(t)-1);
        q=q - A.numpts*4; % include 4 buffers before trial buffer (AC 6/27/2012)
        if (q+(8*A.numpts))>size(A.data1,1)
            A.idx2trials=A.idx2trials(1:(end-1));
            A.PDRdata.tracen=cell(length(A.idx2trials),1);
            for r=1:length(A.idx2trials)
                A.PDRdata.tracen{r}=A.PDRdata.trace{r};
            end
            A.PDRdata.trace=[];
            A.PDRdata.trace=cell(length(A.idx2trials));
            A.PDRdata.trace=A.PDRdata.tracen;
            A.PDRdata.tracen=[];
            rmfield(A.PDRdata,'tracen')
        else
            for k=1:8
                startPt = 1+((k-1)*(A.numpts-A.infopts));
                stopPt = (k*(A.numpts-A.infopts));
                if (q+1) < 1 
                    % if this buffer does not exist fill with zeros
                    % this should only put zeros prior to the onset of the first sound
                    A.PDRdata.trace{t,1}(startPt:stopPt) = nan(A.numpts-A.infopts,1);
                else
                    A.PDRdata.trace{t,1}(startPt:stopPt) = A.data1(q+2:q+A.numpts-1);
                end
                q=q+A.numpts;
            end
            
            % sets values in "prior" buffers equal to first value in 1st
            % buffer (only for first stimulus trace):

            tmp = isnan(A.PDRdata.trace{t,1});
            tmp = find(tmp == 1);
            if ~isempty(tmp)
                A.PDRdata.trace{t,1}(tmp) = A.PDRdata.trace{t,1}(tmp(end)+1);
            end

            
            A.PDRdatA.numpts(t)=8*(A.numpts-A.infopts); % 8 buffer lengths
           % since now includes 4 buffers before trial buffer 
           % (AC 6/27/2012)
        end
        waitbar(cnt/(2*length(A.idx2trials)),h0);
    end
    A.P_data=NaN*ones(length(A.idx2trials),length(A.PDRdata.trace{1}));
    for n = 1:length(A.idx2trials)
        cnt=cnt+1;
        A.P_data(n,:) = A.PDRdata.trace{n};
        waitbar(cnt/(2*length(A.idx2trials)),h0);
    end
    close(h0)
    A.P_data =  A.P_data';
    A.ntrials = length(A.idx2trials);
    y = zeros(8*(A.dec_pts-A.infopts),A.ntrials)*NaN;
    A.meandata = zeros(8*(A.dec_pts-A.infopts),A.ntrials)*NaN;
    %filter AC noise out of trace; normalize all trial DC levels
    h0 = waitbar(0,'Hang on, filtering data...');
    for trial = 1:A.ntrials
        Fs = 1000;
        t = 0:1/Fs:1;
        b = ones (1,94)/94;
        y (:,trial)= filtfilt(b,1, A.P_data(:,trial));
        A.meandata (:, trial) = (y(:, trial))-((((y(round(4*(A.dec_pts-A.infopts)+A.sndStart*(A.dec_pts-A.infopts)), trial))))); % changed to zero at sound onset (A.sndStart)
        A.P_data (:, trial) = ( A.P_data(:, trial))-(((( A.P_data(4*(A.dec_pts-A.infopts)+round(A.sndStart*(A.dec_pts-A.infopts)), trial)))));
        waitbar(trial/A.ntrials,h0);
    end
    close(h0)
    if A.invertFlg{1}(1) == 'y'
        A.meandata = -1*A.meandata; %INVERTING ONLY!
    end
    
    
function remove_blinks
    global PDR passmein A
    %Plot fig to pick blink threshold levels
    hblink = figure('Name','Remove A.trials with Blinks','NumberTitle','off');
    set(gcf, 'Position', [0.1 0.1 0.5*A.scrn(3) 0.5*A.scrn(4)]);
    plot (A.meandata, 'k'); grid; zoom on; set (gcf, 'pointer', 'crosshair');
    
    % Added this to give a marker of sound onset (AC 6/27/2012):
    A.startInt = 4*(A.dec_pts-A.infopts)+round((A.dec_pts-A.infopts)*A.sndStart); % start integrating when sound starts in the buffer
    line([A.startInt A.startInt],[min(min(A.meandata)) max(max(A.meandata))]);
    axis tight
    A.lolimit = input ('Lower cutoff =  ');
    A.hilimit = input ('Upper cutoff =  ');
    close(hblink);

    %FILTER OUT ALL A.trials WITH BLINKS

    for trial = 1:A.ntrials
        loblinks = min(find((A.meandata(:,trial)) <= A.lolimit));
        hiblinks = min(find((A.meandata(:,trial)) >= A.hilimit));
        loblinks = isempty (loblinks);
        hiblinks = isempty (hiblinks);
        loblink (trial) = loblinks;
        hiblink (trial) = hiblinks;

    end

    lonay = find (loblink ==1);
    hinay = find (hiblink ==1);
    A.nay = intersect(lonay, hinay);
    A.nbltrials=(length(A.nay));

    %cull out blink-free A.trials

    A.mdata = zeros(8*(A.dec_pts-A.infopts),A.nbltrials)*NaN;

    for n = 1:A.nbltrials;
        A.mdata(:,n) = A.meandata(:,A.nay(n));
    end
    
    
function pdr_diagnostic_plots
    global PDR passmein A
    %PDR magnitude

    A.startInt = 4*(A.dec_pts-A.infopts)+round((A.dec_pts-A.infopts)*A.sndStart); % start integrating when sound starts in the buffer
    
    for m = 1:A.nbltrials;
            A.areas(m) = sum (A.mdata(round(A.startInt):round(A.startInt+A.time2integrate),m)) ;
    end
    
    %hscatt = figure('Name','PDR magnitude per trial','NumberTitle','off');
    %set(gcf, 'Position', [0.05 0.05 0.25*A.scrn(3) 0.25*A.scrn(4) ]);
    subplot(A.h(1));
    plot (A.areas, 'k.'); hold on; grid on;
    axis tight
    xlabel ('Trial number'); ylabel ('PDR magnitude mV.s');
    title(['PDR magnitude per trial',A.file]);

%     set(hscatt, 'InvertHardCopy', 'off');
%     if A.pflag
%         print(gcf,'-dpsc2');
%     end
    
    % was there a PDR response?
    %hbatav = figure ('Name','Batch Averages of PDR traces across session',...
    %    'NumberTitle','off');
    subplot(A.h(3));
    %set(gcf, 'Position', [0.3*A.scrn(3) 0.05 .25*A.scrn(3) .25*A.scrn(4) ]);
    hold on;
    batches = 5;
    names = cell(1,batches);

    minVal = 0;
    maxVal = 0;
    
    coloridx = -(0.5*batches):0.5*batches;
    for i =-(0.5*batches):0.5*batches
        redval = (-0.5*batches + i)/-batches;
        grnval = (batches - 2*abs(i))/batches;
        bluval = (0.5*batches + i)/batches;
        colorvals(find(coloridx==i),:) = [redval grnval bluval];
    end
    
    cnt = 1;
    for p = 1:batches
        if cnt > 4
            cnt = 1;
        end

        lo(p) = ((floor(A.nbltrials/batches))*(p-1))+1;
        hi(p) = floor(A.nbltrials/batches)*p;
        plot (mean(A.mdata(:,lo(p):hi(p))'),...
            'Color',colorvals(p,:),'LineWidth',2);
        
        
        minVal = min(minVal,min(mean(A.mdata(:,lo(p):hi(p))')));
        maxVal = max(maxVal,max(mean(A.mdata(:,lo(p):hi(p))')));
        
        names{p} = ['A.trials ' num2str(lo(p)) '-' num2str(hi(p))];
        cnt = cnt + 1;
    end
    set(gca,'Color',[.7 .7 .7]);

    % Added this to give a marker of sound onset (AC 6/27/2012)
    grid on;
    line([A.startInt A.startInt],[minVal maxVal],'Color','r');
    axis tight

    endtime = round((8*A.bufftime) - A.sndStart*A.bufftime - 4*A.bufftime);
    begintime = -round(4*A.bufftime + A.sndStart*A.bufftime);
    set (gca, 'xtick', [0:(A.dec_pts-A.infopts):8*(A.dec_pts-A.infopts)], 'xticklabel',[begintime:round(endtime/8):endtime]);
    
    xlabel ('Time after sound onset (ms)'); ylabel ('Pupil size (mV)');
    title (['Trace averaged across all A.trials of session ',A.file]);
    legend(names)
    
    drawnow;
    %set(hbatav, 'InvertHardCopy', 'off');
%     if A.pflag
%         print(gcf,'-dpsc2');
%     end
    
    if A.sflag
        saveas(hscatt,'PDR_magnitudes_scatter.fig')
        saveas(hscatt,'PDR_magnitudes_scatter.png')

        saveas(hbatav,'PDR_batch_avgs.fig')
        saveas(hbatav,'PDR_batch_avgs.png')
    end
    
function running_avg_habtrials(winnum,windur,subp)
    global PDR passmein A
    % winnum is the window (# of A.trials to average per window)
    % windur is the window length in minutes
    A.startInt = 4*(A.dec_pts-A.infopts)+round((A.dec_pts-A.infopts)*A.sndStart); % start integrating when sound starts in the buffer
    
    % calc initial windowed avg
    in = 0;
    area_list = ones(round(winnum),1)*NaN;
    for i = 1:round(winnum)
        in = in + sum(A.mdata(round(A.startInt):round(A.startInt+A.time2integrate),i));
        area_list(i) = sum(A.mdata(round(A.startInt):round(A.startInt+A.time2integrate),i));
    end
    
    % stdev and mean for first window
    begin_std = std(area_list);
    begin_avg = in/round(winnum);

    % running avg for all other windows
    in = 0;
    avg = ones(A.nbltrials,1)*NaN;
    stdevs = ones(A.nbltrials,1)*NaN;
    stdevs(1) = begin_std;
    avg(1) = begin_avg;
    for j = 2:round(A.nbltrials-winnum)
        area_list = zeros(round(winnum),1)*NaN;
        for k = 1:round(winnum)
            in = in + sum(A.mdata(round(A.startInt):round(A.startInt+A.time2integrate),j+k));
            area_list(k) = sum(A.mdata(round(A.startInt):round(A.startInt+A.time2integrate),k));
        end
        stdevs(j) = std(area_list);
        avg(j) = in/round(winnum);
        in = 0;
    end
%
    xes = ones(A.nbltrials,1)*NaN;
    for m = 1:A.nbltrials
        minute_cnt = floor(m*windur/winnum);
        xes(m) = minute_cnt + mod(m,winnum/windur)*windur/winnum;
    end

    %traceplot = figure('Name',['Running Avg.: ' num2str(windur) ' Min. Window'],'NumberTitle','off');
    %set(gcf, 'Position', [0.55*A.scrn(3) 0.05 0.25*A.scrn(3) 0.25*A.scrn(4) ]);
    subplot(subp);
    plot(xes,avg,'k-','LineWidth',4); hold on;
%     plot(xes,avg+stdevs,'k--','LineWidth',2);
%     plot(xes,avg-stdevs,'k--','LineWidth',2);
    xlabel ('Session Time (Min)'); ylabel ('Avg Response');
    title (['Running Average Hab Response (s.d. as dotted lines) with Window Length = ' num2str(windur) ' Minutes ',A.file]);
    
    %set(traceplot, 'InvertHardCopy', 'off');
%     if A.pflag
%         print(gcf,'-dpsc2');
%     end
%     
    plotname = ['RunningAvg_' num2str(windur) 'MinWindow'];
    drawnow;
    if A.sflag
        saveas(traceplot,plotname,'fig');
        saveas(traceplot,plotname,'png');
    end

function parse_trials
    global PDR passmein A
   
    
    % sort A.trials into hab, and each test sound type
    snd = PDR.trialID(1:end)';
    
    for n = 1:A.nbltrials;
        nblsnd(n) = snd(A.nay(n));
    end

    %get list of trial types (hab and other)
    A.trials.types = unique(nblsnd);
    A.trials.types = sort(A.trials.types);

    %get data for hab A.trials
    A.trials.hab.idx = find(nblsnd==A.habID);
    A.trials.hab.A.areas = A.areas(A.trials.hab.idx);
    A.trials.hab.traces = A.mdata(:,A.trials.hab.idx);

    %get overall mean and std deviation
    A.trials.stdev = std(A.areas);
    A.trials.mean = mean(A.areas);

    %get zscores for hab A.trials
    A.trials.hab.zscores = (A.trials.hab.A.areas - A.trials.mean)/A.trials.stdev;

    for i = 1:(length(A.trials.types)-1)
        A.trials.test{i}.corr = [num2str(A.trials.types(i)) '%'];
        A.trials.test{i}.idx = find(nblsnd==A.trials.types(i));
        A.trials.test{i}.A.areas = A.areas(A.trials.test{i}.idx);
        A.trials.test{i}.traces = A.mdata(:,A.trials.test{i}.idx);
        A.trials.test{i}.zscores = (A.trials.test{i}.A.areas - A.trials.mean)/A.trials.stdev;
    end
    drawnow;
    
function plot_average_traces
    global PDR passmein A
    
    A.startInt = 4*(A.dec_pts-A.infopts)+round((A.dec_pts-A.infopts)*A.sndStart); % start integrating when sound starts in the buffer
    
    %traceplot = figure('Name','Averaged Test and Hab A.trials','NumberTitle','off');
    %set(gcf, 'Position', [0.05 0.3*A.scrn(4) .25*A.scrn(3) .25*A.scrn(4) ]);
    %subplot(A.h(2));
    figure;
    plot(mean(A.trials.hab.traces'),'k:','LineWidth',1);
    minVal = min(min(mean(A.trials.hab.traces')));
    maxVal = max(max(mean(A.trials.hab.traces')));
    
    hold on
    leg = {'Hab A.trials'};

    plot(mean(A.trials.hab.traces(:,100:end)'),'k-','LineWidth',2);
    leg{2} = 'Hab A.trials (w/o 1st 100)';
    
    plot(mean(A.trials.hab.traces(:,ceil(end/2):end)'),'k--','LineWidth',3);
    leg{3} = 'Hab A.trials (Last Half)';

    tt_types = (length(A.trials.types)-1);
    
    for i = 1:tt_types
        
        plot(mean(A.trials.test{i}.traces'),'Color',[i/tt_types i/tt_types 1],'LineWidth',8-i);
        leg{i+3} = ['Test Trial = ' A.trials.test{i}.corr];
        minVal = min(minVal,min(min(mean(A.trials.test{i}.traces'))));
        maxVal = max(maxVal,max(max(mean(A.trials.test{i}.traces'))));
    end
    
    set(gca,'Color',[.7 .7 .7]);
    legend(leg);
    grid on;
    
    % Added this to give a marker of sound onset (AC 6/27/2012):
    len = size(A.trials.hab.traces,1);
    line([A.startInt A.startInt],[minVal maxVal],'Color','r');
    axis tight
    endtime = round((8*A.bufftime) - A.sndStart*A.bufftime - 4*A.bufftime);
    begintime = -round(4*A.bufftime + A.sndStart*A.bufftime);
    set (gca, 'xtick', [0:(A.dec_pts-A.infopts):8*(A.dec_pts-A.infopts)], 'xticklabel',[begintime:round(endtime/8):endtime]);
    
    xlabel ('Time after sound onset (ms)'); ylabel ('Pupil size (mV)');
    title (['Average traces of Habituating and Test A.trials ',A.file]);
    drawnow;
%     
%     set(traceplot, 'InvertHardCopy', 'off');
%     if A.pflag
%         print(gcf,'-dpsc2');
%     end
%     
    if A.sflag
        saveas(traceplot,'AvgTraces.fig');
        saveas(traceplot,'AvgTraces.png');
    end
    
function plot_trial_traces
    global PDR passmein A
    
    A.startInt = 4*(A.dec_pts-A.infopts)+round((A.dec_pts-A.infopts)*A.sndStart); % start integrating when sound starts in the buffer


    
    tt_types=(length(A.trials.types)-1);
    for i = 1:tt_types
        
        leg = cell(1,1);
        %traceplot = figure('Name',['Individual A.trials: ' A.trials.test{i}.corr ' Correlation'],'NumberTitle','off');
        %set(gcf, 'Position', [.3*A.scrn(3) 0.3*A.scrn(4) .25*A.scrn(3) .25*A.scrn(4) ]);
        subplot(A.h(1));
        set(gca,'Color',[.8 .8 .8]);
        plot(mean(A.trials.hab.traces'),'k:','LineWidth',2);
        
        minVal = min(min(mean(A.trials.hab.traces')));
        maxVal = max(max(mean(A.trials.hab.traces')));
        
        hold on
        leg{1} = 'Hab A.trials';
        plot(mean(A.trials.hab.traces(:,100:end)'),'k-','LineWidth',2);
        leg{2} = 'Hab A.trials (w/o 1st 100)';
        plot(mean(A.trials.hab.traces(:,ceil(end/2):end)'),'k--','LineWidth',2);
        leg{3} = 'Hab A.trials (Last Half)';
        
        
        num_trials = size(A.trials.test{i}.traces,2);
        prior_hab_trials_1MinWin_traces = [];
        prior_hab_trials_5MinWin_traces = [];

        
        for j = 1:num_trials
            
            ind = find(A.trials.hab.idx < A.trials.test{i}.idx(j));
            prior_hab_trials_1MinWin_idx = find(A.trials.hab.idx(ind) ...
                > (A.trials.test{i}.idx(j) - A.win1) ...
                ); % find hab A.trials during 1 minute window prior to this test trial
            prior_hab_trials_5MinWin_idx = find(A.trials.hab.idx(ind) ...
                > (A.trials.test{i}.idx(j) - A.win5) ...
                ); % find hab A.trials during 5 minute window prior to this test trial

            prior_hab_trials_1MinWin_traces = ...
                [prior_hab_trials_1MinWin_traces A.mdata(:,prior_hab_trials_1MinWin_idx)]; % get traces for hab A.trials 1 minute prior to this test trial
            prior_hab_trials_5MinWin_traces = ...
                [prior_hab_trials_5MinWin_traces A.mdata(:,prior_hab_trials_5MinWin_idx)]; % get traces for hab A.trials 5 minutes prior to this test trial
            
            plot(A.trials.test{i}.traces(:,j),'Color',[1 j/num_trials j/num_trials],'LineWidth',3);
            minVal = min(minVal,min(min(A.trials.test{i}.traces(:,j))));
            maxVal = max(maxVal,max(max(A.trials.test{i}.traces(:,j))));
            leg{j+3} = ['Trial #' num2str(j)];
            cnt = j+3;
        end
        
        leg{cnt+1} = 'Hab A.trials (1 Min Prior to Test Trial)';
        plot(mean(prior_hab_trials_1MinWin_traces'),'m-','LineWidth',2);
        leg{cnt+2} = 'Hab A.trials (5 Min Prior to Test Trial)';
        plot(mean(prior_hab_trials_5MinWin_traces'),'m--','LineWidth',2);
        
        set(gca,'Color',[.7 .7 .7]);
        legend(leg);
        grid on;
        
        % Added this to give a marker of sound onset (AC 6/27/2012):
        len = size(A.trials.hab.traces,1);
        line([A.startInt A.startInt],[minVal maxVal],'Color','r');
        axis tight
        endtime = round((8*A.bufftime) - A.sndStart*A.bufftime - 4*A.bufftime);
        begintime = -round(4*A.bufftime + A.sndStart*A.bufftime);
        set (gca, 'xtick', [0:(A.dec_pts-A.infopts):8*(A.dec_pts-A.infopts)], 'xticklabel',[begintime:round(endtime/8):endtime]);
        
        
        xlabel ('Time after sound onset (ms)'); ylabel ('Pupil size (mV)');
        title (['Individual ' A.trials.test{i}.corr ' Correlation Test A.trials: ',PDR.filename]);
        
        plotname = ['Traces_' A.trials.test{i}.corr(1:end-1) '_PercentCorr'];
        drawnow;
%         
%         set(traceplot, 'InvertHardCopy', 'off');
%         if A.pflag
%             print(gcf,'-dpsc2');
%         end
        
        if A.sflag
            saveas(traceplot,plotname,'fig');
            saveas(traceplot,plotname,'png');
        end
    end


        
        