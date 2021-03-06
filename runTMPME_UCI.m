clc; clear; close all;
format compact;
addpath('data')


% Parameter Settings
Trial = 20; % Number of trials
Rho_set = [10.^(4:-1:-4),1e-10];  % Regaularization coefficient 
Lambda_set = [10.^(2:-1:-2)]; % Weight coefficient for unlabeled data

Set = 1;

for split = 1:Trial

    [Xl,Yl,Xu,Yu,Xv,Yv,Xt,Yt,p]  =  LoadSet_ssl(Set,split,[],0);
    
    L = length(Yl);
    U = length(Yu);
       
    % Obtain  initial predictions using MPM
    mu1 = mean(Xl(Yl == 1,:));
    mu2 = mean(Xl(Yl == -1,:));
    covX = cov(Xl(Yl == 1,:),1);
    covY = cov(Xl(Yl == -1,:),1);
    acc = -Inf;
    for i = 1:length(Rho_set)
        [alfa,a,b] = mpm_lin(mu1',mu2',covX,covY,0,Rho_set(i),Rho_set(i),0,1e-6,1e-6,50);
        acc_tmp = 100*mean(Yv == sign(Xv*a-b));
        if acc_tmp(1)>acc
            acc = acc_tmp(1);
            a_best = a;
            b_best = b;
        end
    end
    out = Xu*a_best-b_best;
    disp(['Supervised learning accuracy using MPM: ',num2str(100*mean(Yu == sign(out))),'%'])
    err_mpm_u(split) = 100*mean(sign(out)~= Yu);

     
    % Incorporate the prior of propotion
    [~,idx]  =  sort(out);
    Yup = zeros(size(Yu));
    Yup(idx(1:ceil((1-p)*U))) = -1;
    Yup(idx(ceil((1-p)*U)+1:end)) = 1;
    disp(['Supervised learning accuracy using MPM (reweighted): ',num2str( 100*mean(Yup == Yu)),'%'])

    % Train TMPM
    err_cv_best = Inf;
    err_cv = [];
    err_cv_u = [];
    
    paras.verbose = 1;
    paras.Yu = Yu;

    for i = 1:length(Rho_set)
        paras.rho1 = Rho_set(i)*diag(var([Xl;Xu]));
        paras.rho2 = paras.rho1;
      
        for j = 1:length(Lambda_set)
            paras.lambda = Lambda_set(j);
            model_tmp = tmpm_lin_extend(Xl,Yl,Xu,Yup,paras);
            
            [~,~,~,auc_v(i,j)]  =  perfcurve(Yv,Xv*model_tmp.a-model_tmp.b,1);
            err_cv(i,j) = 100-100*auc_v(i,j);
            
            if err_cv(i,j)<err_cv_best
                err_cv_best = err_cv(i,j);
                model = model_tmp;
                model.rho = Rho_set(i);
            end
        end
    end

    err_u(split) = 100*mean(model.yu~= Yu)
end
Result = [err_u;err_mpm_u]
Result_Summary = [mean(err_u),std(err_u);
    mean(err_mpm_u),std(err_mpm_u)]
