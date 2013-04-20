function [stim] = rampSoundstest(stim, SR, SOUNDS_ramp)
% SOUNDS_ramp should be in ms
    ramp_pts = ceil(SR*(SOUNDS_ramp/1000));
    npts = length(stim) - 2*ramp_pts - 2;
    rampenv = [0:(1/ramp_pts):1 ones(1,npts) 1:-(1/ramp_pts):0];
    stim = stim .* rampenv;