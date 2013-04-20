function beta=fit_powerlaw(X,Y,beta0)
beta = nlinfit(X,Y,@powerlaw,beta0);

function y=powerlaw(beta,x)
    y=beta(1).*(x+beta(2)).^beta(3)+beta(4);