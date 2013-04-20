c={'2013_2_15_A' '2013_2_19_A' '2013_2_20_A'};

cd ..\calib_data
figure
colorz={'r','g','k'}
for i=1:length(c)
    nm=['knowles_calib_' c{i} '.mat'];
    load(nm)
    hold on; h(i)=scatter(KNOWLES.voltages,KNOWLES.spls,3,'o','MarkerFaceColor',colorz{i});
    leg{i}=nm;
end
legend(leg);