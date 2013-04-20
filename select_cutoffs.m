function [lo, hi] = select_cutoffs(xes,yes)
% Plots data in a scatter plot and asks user to input lo/hi cuttoffs
% for fitting linear portion of data range

hFig=figure;
scatter(xes,yes);
prompt = {'Enter Lower Cutoff','Enter Upper Cutoff'};
dlg_title = 'Input Cutoffs:';
num_lines = 1;
def = {'',''};
answer = inputdlg(prompt,dlg_title,num_lines,def);
lo=str2num(answer{1});
hi=str2num(answer{2});
close(hFig);
