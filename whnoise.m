function [X,Xtime] = whnoise(minfreq,maxfreq,Fs,duration)
%A script to produce noise with a flat spectrum between specified frequencies.
%Usage: [freq domain, time domain] = whnoise(min frequency, max frequency,Fs,durationor)
%durationor is used to determine length; len = duration * Fs;
%Borrowed from Kip Keller w_rnd.m

if (nargin < 3) Fs = 30000; end
if (nargin < 4) duration = .1; end

len = duration*Fs;

minfreq = round(((minfreq+1)/Fs) * len);
maxfreq = round(((maxfreq+1)/Fs) * len);
range = maxfreq-minfreq+1;

% mag spectrum = 1 between set frequencies:
mag = zeros(len,1);
mag(minfreq:maxfreq) = ones(range,1);

% random phase spectrum between set frequencies:
phase = (rand(len,1) - 0.5) * (2*pi);            %-0.5 moves phases from 0to1 range to -0.5to0.5 range, then have to multiply by 2pi instead of pi
% combine phase and magnitude:
X = mag .* ( (cos(phase)) + (i .* sin(phase)) );


% convert to time domain:
Xtime = real(ifft(X));
Xtime=Xtime/max(abs(Xtime));                        %have to normalize so that max and mins are between -1 and 1 otherwise will saturate = bad

return;