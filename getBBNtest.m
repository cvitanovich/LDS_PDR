function [bbnoise] = getBBNtest(state,Fs,dur, minfreq, maxfreq)
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