pname = 'c:\alex\calib_data\';
cd(pname)
fnameL = '120925calib_testD_vleft.rec';
fnameR = '120925calib_testD_vright.rec';
header = '120925calib_testD.mat';
load(header);


fid=fopen(fnameL)
vleft=fread(fid,PDR.buf_pts,'short');
pos = ftell(fid)
keyboard
fclose(fid);
keyboard

fid=fopen(fnameR)
vright=fread(fid,PDR.buf_pts,'short');
pos = ftell(fid)
fclose(fid);

keyboard
return

left_tmp = left_tmp(begin_pts:end_pts);
right_tmp = right_tmp(begin_pts:end_pts);
left_tmp = left_tmp - mean(left_tmp);
right_tmp = right_tmp - mean(right_tmp);
% calculate rms voltage
PDR.CALIB_left_rms_voltage(i) = sqrt(sum(left_tmp.^2)./length(left_tmp));
PDR.CALIB_right_rms_voltage(i) = sqrt(sum(right_tmp.^2)./length(right_tmp));


%write header information to file... saving global variables
save ([PDR.data_path PDR.filename '.mat'],'PDR');