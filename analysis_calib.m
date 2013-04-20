clear all;
bird_ids=[1053 1034];
h=msgbox('Analysis of Calibration data for LDS PDR Expt');
uiwait(h)
for i=1:length(bird_ids)
    h=msgbox('Select Interaural Microphone Calibration Data, Bird' num2str(bird_ids(1)));
    uiwait(h)
    cd C:\alex\calib_data
    uiopen('load');
end