function [RSQ, COEFFS] = regress_stats_exponential(xes,yes,alfa,xrange,col,beta0)
% plot data
hold on
n=length(yes);
df=length(yes)-3;
for j = 1:n
    plot(xes,yes,'*','Color',col);
end

% determine fit coefficients and R-squared
beta = nlinfit(xes,yes,@exponential_fxn,beta0);
yfit = exponential_fxn(beta,xrange);
ypred = exponential_fxn(beta,xes);
yresid = yes - ypred;
SSresid = sum(yresid.^2);
SStotal = (length(yes)-1) * var(yes);
RSQ = 1 - SSresid/SStotal;

COEFFS = zeros(1,3);
COEFFS = [beta(1) beta(2) beta(3)];

% set axis values
minX=min(xrange);
maxX=max(xrange);
minY=min(yes);
maxY=max(yes);
axis([minX maxX minY maxY]);

% plot info
eqn = ['Fit: y = ' num2str(beta(1)) 'e^{' num2str(beta(2)) '} + ' num2str(beta(3)) ];
text(minX+0.1*(maxX-minX),minY+0.9*(maxY-minY),eqn,'FontSize',8);
rsq = ['R^{2} = ' num2str(RSQ)];
text(minX+0.1*(maxX-minX),minY+0.75*(maxY-minY),rsq,'FontSize',8);

% plot fit
plot(xrange,yfit,'k');
hold off

% REGRESSION (EXPONENTIAL)
function y=exponential_fxn(beta,x)
    y=beta(1).*exp(x.*beta(2))+beta(3);