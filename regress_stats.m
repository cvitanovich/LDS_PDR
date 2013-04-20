function [RSQ, COEFFS] = regress_stats(xes,yes,alfa,xrange)
% plot data
n=length(yes);
df=length(yes)-2;
for j = 1:n
    plot(xes,yes,'m*');
end

% determine fit coefficients and CI
[p, S] = polyfit(xes,yes,1);
[Y,DELTA]=polyconf(p,xrange,S,alfa);
m=p(1);
b=p(2);
yfit =  m.* xrange + b;
ypred = (m.*xes + b);
yresid = yes - ypred;
SSresid = sum(yresid.^2);
SStotal = (length(yes)-1) * var(yes);
RSQ = 1 - SSresid/SStotal;

% plot fit with CI
hold on;
plot(xrange,Y,'c-');
plot(xrange,Y-DELTA,'r--');
plot(xrange,Y+DELTA,'r--');
hold off;

% standard error calculation
SSxx = sum(xes.^2)-n*mean(xes)^2;
SSyy = sum(yes.^2)-n*mean(yes)^2;
SSxy = sum(xes.*yes)-n*mean(xes)*mean(yes);
s=sqrt((SSyy-m*SSxy)/(n-2));
SE_m = s/sqrt(SSxx); % standard error for slope
SE_b = s*sqrt((1/n)+mean(xes)^2/SSxx); % standard error for intercept

% determine t statistic
step = 0.01;
t=step;
cum=0;
while cum < (1-alfa)
    tes=-t:step:t;
    tmp=tpdf(tes,df);
    cum=sum(tmp)*step;
    if cum > 0.95
        break;
    else
        t=t+step;
    end
end

% determine coefficient CIs
COEFFS = zeros(3,3);
COEFFS = [m m-SE_m*t m+SE_m*t; b b-SE_b*t b+SE_b*t];

% set axis values
minX=min(xrange);
maxX=max(xrange);
minY=min(Y-DELTA);
maxY=max(Y+DELTA);
axis([minX maxX minY maxY]);

% plot info
eqn = ['Fit: y = mx+b = ' num2str(m) 'x + ' num2str(b)];
text(minX+0.1*(maxX-minX),minY+0.9*(maxY-minY),eqn,'FontSize',8);
mcoeff=['m = ' num2str(m) ' [' num2str(COEFFS(1,2)) ',' num2str(COEFFS(1,3)) ']'];
text(minX+0.1*(maxX-minX),minY+0.75*(maxY-minY),mcoeff,'FontSize',8);
bcoeff=['b = ' num2str(b) ' [' num2str(COEFFS(2,2)) ',' num2str(COEFFS(2,3)) ']'];
text(minX+0.1*(maxX-minX),minY+0.6*(maxY-minY),bcoeff,'FontSize',8);