%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% 
% Copyright (C): Chen HUANG
% Date: 19 August 2019
% Affiliation: Dept of Civil, Environmental and Geomatic Engeering at 
% University College London
% Email: chen.huang.14@ucl.ac.uk
% 
% Contributor: Deyu MING
% Affiliation: Dept of Statistical Science at University College London
% Email: deyu.ming.16@ucl.ac.uk
% 
% Reference: 
% Huang, C., and Galasso, C. (2019). Ground-motion intensity measure 
% correlations observed in Italian data, Earthquake Engineering and 
% Structural Dynamics (Accepted/in press)
% 
% Ming, D., Huang, C., Peters, G.W., and Galasso, C. (2019)
% An advanced estimation algorithm for ground-motion models with 
% spatial correlation. Bulletin of the Seismological Society of America, 
% 109(2): 541-566.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function Output=scoring_update(y,x,w,id,f1,f2,gamma0,theta0,tol,cl,cf,strike)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This function computes the estimates of user-defined GM model
% with stationary and isotropic correlation functions by the method of Scoring
% with dimension reduction. See https://github.com/mingdeyu/GMPE-estimation
% for examples on how to specify the inputs. 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% INPUTS:
% y: the logarithmic intensity measures;
%
% x: the covariates in the mean function f(X_ij);
%
% w: the covariates (i.e., the station coordinates) in the correlation function;
%
% id: a vector containing the IDs of earthquakes;
%
% f1: a function handle that uses x and nonlinear coefficients gamma as input and
% outputs the design matrix B of linear coefficients;
%
% f2: a function handle that uses x and nonlinear coefficients gamma as input and
% ouputs a cell, each element of which contains the grident of the design
% matrix B wrt to one nonlinear coefficient in gamma;
%
% gamma0: initial values for nonlinear coefficients in the GM prediction function;
%
% theta0=(\tau^2; \sigma^2; h): initial values for inter- and intraevent variances 
% \tau^2 and \sigma^2, and range paramter h in the correlation function;
%
% tol: the tolerance level set by the user;
%
% cl: the confidence level (in %) for outputing the confidence intervals of
% model parameters;
%
% cf: the type of the covariance function: currently support 'No spatial'
% type (No), 'exponential' type (Exp), Matern type with v=1.5 (Matern1.5)
% and 'squared exponential' type (SExp);
%
% strike: the strike angle of finite-fault model in degree measured from
% North for the calculation of distance along the fault-parallel and
% fault-normal direction.
% 
% OUTPUTS:
% An output structure which contains:
%
% LogLikelihood: the maximum log-likelihood value;
%
% ParameterEstimates: the maximum likelihood estimates of model paramters
% beta, gamma and theta;
%
% StandardError: the asympototic standard error estimates of the maximum likelihood
% estimators;
%
% ConfidenceInterval: the cl% confidence intervals for model parameters;
%
% InformationCriteria: a structure array containing the AIC and BIC.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%initialisation
stopping=1;
it=0;
gamma=gamma0;
%Transform the theta by theta=exp(theta_trans) so convert constraint to
%unconstraint problem
theta_trans=log(theta0);
%Compute the initial design matrix of \beta
B=f1(x,gamma);
%Compute the initial covariance matrix and its determinant
[c,c_par,c_nor]=sepdis(w,id,strike); %compute the matrix of separation distances for each event

switch cf
    case 'No'
        Omega=CovNo(theta_trans,c);
        D=deterNo(theta_trans,c);
    case 'Exp'
        Omega=CovExp(theta_trans,c);
        D=deterExp(theta_trans,c);
    case 'SExp'
        Omega=CovSExp(theta_trans,c);
        D=deterSExp(theta_trans,c);
    case 'Matern1.5'
        Omega=CovMatern15(theta_trans,c);
        D=deterMatern15(theta_trans,c);
    case 'ExpAni'
        Omega=CovExpAni(theta_trans,c_par,c_nor);
        D=deterExpAni(theta_trans,c_par,c_nor);
end

%Compute the initial value for \beta
beta=(B'/Omega*B)\(B'/Omega*y);
%Compute the initial value of the log-likelihood function
ll=-0.5*length(y)*log(2*pi)-0.5*D-0.5*(y-B*beta)'/Omega...
    *(y-B*beta);

%update
while stopping>tol
formatSpec = 'Iteration %i Loglikelihood %10.4f\n';
fprintf(formatSpec,it,ll);
it=it+1;
theta_trans_old=theta_trans;
gamma_old=gamma;
ll_old=ll;
%Compute additional elements in the gradients and information matrix
A1=f2(x,gamma); %B_\gamma

switch cf
    case 'No'
        A2=CtNo(theta_trans,c);
    case 'Exp'
        A2=CtExp(theta_trans,c); %C_\theta
    case 'SExp'
        A2=CtSExp(theta_trans,c);
    case 'Matern1.5'
        A2=CtMatern15(theta_trans,c);
    case 'ExpAni'
        A2=CtExpAni(theta_trans,c_par,c_nor);
end

A3=(y-B*beta);
%Compute gradients
St=Stheta(Omega,A2,A3);
Sg=Sgamma(Omega,A1,A3,beta);

%Compute information matrices
Igg=Igamma(Omega,A1,beta);
Igb=Igammabeta(Omega,A1,B,beta);
Ibb=B'/Omega*B;
Itt=Itheta(Omega,A2);
%Step halving to gurantee the increase if the log-likelihood function
ll=ll_old-1; %temporarily decrease the log-likelihood to enter the step-halving
delta=1;
while ll<ll_old
%Update gamma
gamma=gamma_old+delta*((Igg-Igb/Ibb*Igb')\Sg);
B=f1(x,gamma);
%Update theta
theta_trans=theta_trans_old+delta.*modify(St,Itt);

switch cf
    case 'No'
Omega=CovNo(theta_trans,c);
D=deterNo(theta_trans,c);
    case 'Exp'
Omega=CovExp(theta_trans,c);
D=deterExp(theta_trans,c);
    case 'SExp'
Omega=CovSExp(theta_trans,c);
D=deterSExp(theta_trans,c);
    case 'Matern1.5'
Omega=CovMatern15(theta_trans,c);
D=deterMatern15(theta_trans,c);
end

%Update beta
beta=(B'/Omega*B)\(B'/Omega*y);
ll=-0.5*length(y)*log(2*pi)-0.5*D-0.5*(y-B*beta)'/Omega...
    *(y-B*beta);
delta=delta/2;
end

%Stopping rule
diffg=abs(gamma-gamma_old);
difft=abs(theta_trans-theta_trans_old);
diff=[diffg,difft']';
mag=[abs(gamma);abs(theta_trans)];
stopping=max(diff./max([mag,10*ones(size(mag))],2));
end
disp('Converged!')
%Arrange the results to obtain estimates of of estimators of (beta, gamma and theta_trans)
%(first cell) and (beta, gamma and theta) (second cell).
estimates_all=est(beta, gamma, theta_trans);
estimates(1).beta=estimates_all{2}(1:length(beta));
estimates(1).gamma=estimates_all{2}(length(beta)+1:length(beta)+length(gamma));
% estimates(1).theta=estimates_all{2}(end-2:end);
estimates(1).theta=estimates_all{2}(length(beta)+length(gamma)+1:end);
%Compute asymptotic standard error estimates of estimators of (beta, gamma and
%theta_trans) (first cell) and (beta, gamma and theta) (second cell)
se_all=sefct(Igg,Igb,Ibb,Itt,theta_trans);
se(1).beta=se_all{2}(1:length(beta));
se(1).gamma=se_all{2}(length(beta)+1:length(beta)+length(gamma));
% se(1).theta=se_all{2}(end-2:end);
se(1).theta=se_all{2}(length(beta)+length(gamma)+1:end);

%Compute the cl% confidence interval for (beta, gamma and theta_trans)
%(first cell) and (beta, gamma and theta) (second cell)
ci_all=CI(estimates_all{1},se_all{1},cl,cf);
ci(1).beta=ci_all{2}(1:length(beta),:);
ci(1).gamma=ci_all{2}(length(beta)+1:length(beta)+length(gamma),:);
% ci(1).theta=ci_all{2}(end-2:end,:);
ci(1).theta=ci_all{2}(length(beta)+length(gamma)+1:end,:);
%Compute AIC and BIC
AIC=-2*ll+2*length(estimates_all{2});
BIC=-2*ll+length(estimates_all{2})*log(length(y));
info.AIC=AIC;
info.BIC=BIC;
%Final output
Output(1).LogLikelihood=ll;
Output(1).ParameterEstimates=estimates;
Output(1).StandardError=se;
Output(1).ConfidenceInterval=ci;
Output(1).InformationCriteria=info;

end

function [c,c_par,c_nor]=sepdis(position,id,strike)
%This function computes the speration distances between stations for each
%earthquake.
%Inputs: id is the index labelling the event; position is the coordinates of
%stations
%Output: c is a cell containing the separation distance mateices for each
%event.
[g,event]=findgroups(id);
c=cell(1,length(event));
c_par=cell(1,length(event));
c_nor=cell(1,length(event));
for j=1:length(event)
    subpos=position(g==j,:);
    m=size(subpos,1);
    [K,L]=ndgrid(1:m);
    K=K(:);
    L=L(:);
    pairs=[L,K];
    
    set1=subpos(pairs(:,1),:);
    set2=subpos(pairs(:,2),:);
    vector_originalcoord=set2-set1;
    
    set1_rotate=zeros(size(set1));
    set2_rotate=zeros(size(set2));
    
    theta=(90-strike)/180*pi;
    set1_rotate(:,1)=cos(theta).*set1(:,1)-sin(theta).*set1(:,2);
    set1_rotate(:,2)=sin(theta).*set1(:,1)+cos(theta).*set1(:,2);
    set2_rotate(:,1)=cos(theta).*set2(:,1)-sin(theta).*set2(:,2);
    set2_rotate(:,2)=sin(theta).*set2(:,1)+cos(theta).*set2(:,2);
    vector_Rotatecoord=set2_rotate-set1_rotate;

pairdis=sqrt(vector_originalcoord(:,1).^2+vector_originalcoord(:,2).^2);
pairdis_par=abs(vector_Rotatecoord(:,1));
pairdis_nor=abs(vector_Rotatecoord(:,2));

subdis=vec2mat(pairdis, m);
subdis_par=vec2mat(pairdis_par, m);
subdis_nor=vec2mat(pairdis_nor, m);

c{1,j}=subdis;
c_par{1,j}=subdis_par;
c_nor{1,j}=subdis_nor;
end
end

function Omega=CovNo(theta_trans,c)
%This function computes the covariance matrix \Omega with no
%spatial correlation.
n=length(c);
Omega_i=cell(1,n);
for i=1:n
Omega_i{1,i}=exp(theta_trans(1)).*ones(size(c{i}))+exp(theta_trans(2)).*eye(size(c{i}));
end
Omega=blkdiag(Omega_i{:});
end

function Omega=CovExp(theta_trans,c)
%This function computes the covariance matrix \Omega with exponential
%correlation function.
n=length(c);
Omega_i=cell(1,n);
for i=1:n
Omega_i{1,i}=exp(theta_trans(1))+exp(theta_trans(2)-c{i}.*exp(-theta_trans(3)));
end
Omega=blkdiag(Omega_i{:});
end

function Omega=CovSExp(theta_trans,c)
%This function computes the covariance matrix \Omega with squared exponential
%correlation function.
n=length(c);
Omega_i=cell(1,n);
for i=1:n
Omega_i{1,i}=exp(theta_trans(1))+exp(theta_trans(2)-0.5.*(c{i}.^2).*exp(-2*theta_trans(3)));
end
Omega=blkdiag(Omega_i{:});
end

function Omega=CovMatern15(theta_trans,c)
%This function computes the covariance matrix \Omega with Matern
%correlation function with v=1.5.
n=length(c);
Omega_i=cell(1,n);
for i=1:n
Omega_i{1,i}=exp(theta_trans(1))+exp(theta_trans(2)-sqrt(3).*c{i}.*exp(-theta_trans(3)))...
    .*(1.+sqrt(3).*c{i}.*exp(-theta_trans(3)));
end
Omega=blkdiag(Omega_i{:});
end

function Omega=CovExpAni(theta_trans,c_lat,c_lon)
%This function computes the covariance matrix \Omega with anisotropic exponential
%correlation function.
n=length(c_lat);
Omega_i=cell(1,n);
for i=1:n
Omega_i{1,i}=exp(theta_trans(1))+exp(theta_trans(2)-((c_lat{i}.^2+exp(theta_trans(4)).*c_lon{i}.^2).^0.5).*exp(-theta_trans(3)));
end
Omega=blkdiag(Omega_i{:});
end

function d=deterNo(theta_trans,c)
%This function computes the log-determinant of the covariance matrix with
%no spatial correlation.
n=length(c);
d=0;
for i=1:n
d=d+logdet(exp(theta_trans(1)).*ones(size(c{i}))+exp(theta_trans(2)).*eye(size(c{i})),'chol');
end
end

function d=deterExp(theta_trans,c)
%This function computes the log-determinant of the covariance matrix with
%exponential correlation function.
n=length(c);
d=0;
for i=1:n
d=d+logdet(exp(theta_trans(1))+exp(theta_trans(2)-c{i}.*exp(-theta_trans(3))),'chol');
end
end

function d=deterSExp(theta_trans,c)
%This function computes the log-determinant of the covariance matrix with
%squared exponential correlation function.
n=length(c);
d=0;
for i=1:n
d=d+logdet(exp(theta_trans(1))+exp(theta_trans(2)-0.5.*(c{i}.^2).*exp(-2*theta_trans(3))),'chol');
end
end

function d=deterMatern15(theta_trans,c)
%This function computes the log-determinant of the covariance matrix with Matern
%correlation function with v=1.5.
n=length(c);
d=0;
for i=1:n
d=d+logdet(exp(theta_trans(1))+exp(theta_trans(2)-sqrt(3).*c{i}.*exp(-theta_trans(3)))...
    .*(1.+sqrt(3).*c{i}.*exp(-theta_trans(3))),'chol');
end
end

function d=deterExpAni(theta_trans,c_lat,c_lon)
%This function computes the log-determinant of the covariance matrix with
%anisotropic exponential correlation function.
n=length(c_lat);
d=0;
for i=1:n
d=d+logdet(exp(theta_trans(1))+exp(theta_trans(2)-((c_lat{i}.^2+exp(theta_trans(4)).*c_lon{i}.^2).^0.5).*exp(-theta_trans(3))));

end
end

function A=CtNo(theta_trans,c)
n=length(c);
A=cell(1,2);
%compute the derivative wrt \tau^2
C1_i=cell(1,n);
for i=1:n
C1_i{1,i}=exp(theta_trans(1)).*ones(size(c{i}));
end
C1=blkdiag(C1_i{:});

%compute the derivative wrt \sigma^2
C2_i=cell(1,n);
for i=1:n
C2_i{1,i}=exp(theta_trans(2)).*eye(size(c{i}));
end
C2=blkdiag(C2_i{:});


A{1}=C1;
A{2}=C2;
end

function A=CtExp(theta_trans,c)
n=length(c);
A=cell(1,3);
%compute the derivative wrt \tau^2
C1_i=cell(1,n);
for i=1:n
C1_i{1,i}=exp(theta_trans(1)).*ones(size(c{i},1));
end
C1=blkdiag(C1_i{:});

%compute the derivative wrt \sigma^2
C2_i=cell(1,n);
for i=1:n
C2_i{1,i}=exp(theta_trans(2)-c{i}.*exp(-theta_trans(3)));
end
C2=blkdiag(C2_i{:});

%compute the derivative wrt h
C3_i=cell(1,n);
for i=1:n
C3_i{1,i}=c{i}.*exp(theta_trans(2)-c{i}.*exp(-theta_trans(3))...
    -theta_trans(3));
end
C3=blkdiag(C3_i{:});

A{1}=C1;
A{2}=C2;
A{3}=C3;
end

function A=CtSExp(theta_trans,c)
n=length(c);
A=cell(1,3);
%compute the derivative wrt \tau^2
C1_i=cell(1,n);
for i=1:n
C1_i{1,i}=exp(theta_trans(1)).*ones(size(c{i},1));
end
C1=blkdiag(C1_i{:});

%compute the derivative wrt \sigma^2
C2_i=cell(1,n);
for i=1:n
C2_i{1,i}=exp(theta_trans(2)-0.5.*(c{i}.^2).*exp(-2*theta_trans(3)));
end
C2=blkdiag(C2_i{:});

%compute the derivative wrt h
C3_i=cell(1,n);
for i=1:n
C3_i{1,i}=(c{i}.^2).*exp(theta_trans(2)-0.5*(c{i}.^2).*exp(-2*theta_trans(3))...
    -2*theta_trans(3));
end
C3=blkdiag(C3_i{:});

A{1}=C1;
A{2}=C2;
A{3}=C3;
end

function A=CtMatern15(theta_trans,c)
n=length(c);
A=cell(1,3);
%compute the derivative wrt \tau^2
C1_i=cell(1,n);
for i=1:n
C1_i{1,i}=exp(theta_trans(1)).*ones(size(c{i},1));
end
C1=blkdiag(C1_i{:});

%compute the derivative wrt \sigma^2
C2_i=cell(1,n);
for i=1:n
C2_i{1,i}=exp(theta_trans(2)-sqrt(3).*c{i}.*exp(-theta_trans(3)))...
    .*(1.+sqrt(3).*c{i}.*exp(-theta_trans(3)));
end
C2=blkdiag(C2_i{:});

%compute the derivative wrt h
C3_i=cell(1,n);
for i=1:n
C3_i{1,i}=3.*(c{i}.^2).*exp(theta_trans(2)-sqrt(3).*c{i}...
    .*exp(-theta_trans(3))-2.*theta_trans(3));
end
C3=blkdiag(C3_i{:});

A{1}=C1;
A{2}=C2;
A{3}=C3;
end

function A=CtExpAni(theta_trans,c_lat,c_lon)
n=length(c_lat);
A=cell(1,4);
%compute the derivative wrt \tau^2
C1_i=cell(1,n);
for i=1:n
C1_i{1,i}=exp(theta_trans(1)).*ones(size(c_lat{i},1));
end
C1=blkdiag(C1_i{:});

%compute the derivative wrt \sigma^2
C2_i=cell(1,n);
for i=1:n
C2_i{1,i}=exp(theta_trans(2)-((c_lat{i}.^2+exp(theta_trans(4)).*c_lon{i}.^2).^0.5).*exp(-theta_trans(3)));
end
C2=blkdiag(C2_i{:});

%compute the derivative wrt h
C3_i=cell(1,n);
for i=1:n
C3_i{1,i}=((c_lat{i}.^2+exp(theta_trans(4)).*c_lon{i}.^2).^0.5).*exp(theta_trans(2)-((c_lat{i}.^2+exp(theta_trans(4)).*c_lon{i}.^2).^0.5).*exp(-theta_trans(3))...
    -theta_trans(3));
end
C3=blkdiag(C3_i{:});

%compute the derivative wrt \theta4
C4_i=cell(1,n);
for i=1:n
C4_i{1,i}=-0.5.*c_lon{i}.^2.*((c_lat{i}.^2+exp(theta_trans(4)).*c_lon{i}.^2).^(-0.5))...
    .*exp(theta_trans(2)-((c_lat{i}.^2+exp(theta_trans(4)).*c_lon{i}.^2).^0.5).*exp(-theta_trans(3))-theta_trans(3)+theta_trans(4));
C4_i{1,i}(isnan(C4_i{1,i}))=0;
end
C4=blkdiag(C4_i{:});

A{1}=C1;
A{2}=C2;
A{3}=C3;
A{4}=C4;
end

function s=Sgamma(Omega,A1,A3,beta)
%This function computes the gradients of log-likelihood function wrt
%gamma.
n=length(A1);
s=zeros(n,1);
for i=1:n
s(i,1)=(A1{i}*beta)'/Omega*A3;
end
end

function s=Stheta(Omega,A2,A3)
%This function computes the gradients of log-likelihood function wrt
%theta.
n=length(A2);
s=zeros(n,1);
for i=1:n
s(i,1)=-0.5*trace(Omega\A2{1,i}*(eye(size(Omega,1))-Omega\(A3*A3')));
end
end

function I=Igamma(Omega,A1,beta)
%This function computes the expected information matrix of log-likelihood
%function wrt gamma
n=length(A1);
I=zeros(n,n);

for i=1:n
    for j=1:n
I(i,j)=(A1{i}*beta)'/Omega*(A1{j}*beta);
    end
end

end

function I=Igammabeta(Omega,A1,B,beta)
%This function computes the expected information matrix of log-likelihood
%function wrt gamma and beta
n1=length(A1);
n2=length(beta);
I=zeros(n1,n2);

for i=1:n1
I(i,:)=(A1{i}*beta)'/Omega*B;
end

end

function I=Itheta(Omega,A2)
%This function computes the expected information matrix of log-likelihood
%function wrt theta
n=length(A2);
I=zeros(n,n);

for i=1:n
    for j=1:n
I(i,j)=0.5*trace((Omega\A2{i})*(Omega\A2{j}));
    end
end

end

function p=modify(A,I)
%This function compute the solution of p to Ip=A using modified Cholesky which
%modifies the expected information matrix I so that it is sufficiently
%positive definite.
  L=cholmid(I);
  p=cholinv(A,L);
end

function L=cholmid(I)
%This function uses the modified Cholesky decpmposition to prevent from
%ill-conditioned problem (see Section 4.4.2.2. in Practical Optimization of
%Gill, Murray and Wright (1995)
n=length(I);
delta=1e-16;
eta=max(abs(diag(I)));
idx=eye(n,n);
xi=max(abs(I(~idx)));
a2=max([eta,xi/sqrt(n^2-1),delta]);
c=zeros(n,n);
l=eye(n);
d=zeros(1,n);
for j=1:n
c(j,j)=I(j,j)-(j>1)*d(1:j-1)*(l(j,1:j-1).^2)';
if j==n
     d(j)=max([abs(c(j,j)),delta]);
else
   for i=j+1:n
    c(i,j)=I(i,j)-(j>1)*d(1:j-1)*(l(i,1:j-1).*l(j,1:j-1))';
   end
     theta=max(abs(c(j+1:n,j)));
     d(j)=max([abs(c(j,j)),theta^2/a2,delta]);
     l(j+1:n,j)=c(j+1:n,j)/d(j);
end
end
L=l*diag(sqrt(d));
end

function z=forward(L,A)
%This function computes the forward substitution to solve Lz=A using the
%results of the modified Cholesky decpmposition
m=length(L);
z=zeros(1,m);
z(1,1)=A(1)./L(1,1);
for k=2:m
  z1=1/L(k,k).*(A(k)-sum(L(k,k-1:-1:1).*z(k-1:-1:1)));
  z(1,k)=z1;
end
z=z';
end

function p=backward(L,z)
%This function computes the backward substitution to solve L'p=z using the
%results of the modified Cholesky decpmposition and forward substitution
U=L';
m=length(U);
p=zeros(1,m);
p(1,m)=z(end)./U(m,m);
for k=m-1:-1:1
    p1=1/U(k,k).*(z(k)-sum(U(k,k+1:end).*p(k+1:end)));
    p(k)=p1;
end
p=p';
end

function p=cholinv(A,L)
%This function solves LL'p=A for p
z=forward(L,A);
p=backward(L,z);
end

function estimates=est(beta, gamma, theta_trans)

estimates{1}=[beta',gamma',theta_trans']';
theta=exp(theta_trans);
estimates{2}=[beta',gamma',theta']';


end

function se=sefct(Igg,Igb,Ibb,Itt,trans_theta)
%This function computes the asymptotic standard error estimates of the
%ML estimators of (beta, gamma, theta_trans) and (beta, gamma, theta) by
%Delta method
IBB=Igg-Igb/Ibb*Igb';
SEg=sqrt(1/IBB);
SEb=sqrt(diag(inv(Ibb)+1/IBB*Ibb\Igb'*Igb/Ibb));
if rcond(Itt) < eps
    SEt=zeros(size(Itt,1),1);
else
    SEt=sqrt(diag(inv(Itt)));
end
%asymptotic standard error estimates of (beta, gamma, theta_trans)
se{1}=[SEb;SEg;SEt];
%asymptotic standard error estimates of (beta, gamma, theta) by Delta
%method
se{2}=[SEb;SEg;SEt.*exp(trans_theta)];
end

function ci=CI(estimates,se,cl,cf)
%This function computes the cl% confidence intervals for (beta, gamma, theta_trans)
%and (beta, gamma, theta)
interval=se.*norminv(1-(1-cl/100)/2);
left=estimates-interval;
right=estimates+interval;
ci{1}=[left,right];
ci{2}=ci{1};
% ci{2}(end-2:end,:)=exp(ci{2}(end-2:end,:));
switch cf
    case 'No'
        ci{2}(end-1:end,:)=exp(ci{2}(end-1:end,:));
    otherwise
        ci{2}(end-2:end,:)=exp(ci{2}(end-2:end,:));
end
end

function v = logdet(A, op)
%LOGDET Computation of logarithm of determinant of a matrix
%
%   v = logdet(A);
%       computes the logarithm of determinant of A. 
%
%       Here, A should be a square matrix of double or single class.
%       If A is singular, it will returns -inf.
%
%       Theoretically, this function should be functionally 
%       equivalent to log(det(A)). However, it avoids the 
%       overflow/underflow problems that are likely to 
%       happen when applying det to large matrices.
%
%       The key idea is based on the mathematical fact that
%       the determinant of a triangular matrix equals the
%       product of its diagonal elements. Hence, the matrix's
%       log-determinant is equal to the sum of their logarithm
%       values. By keeping all computations in log-scale, the
%       problem of underflow/overflow caused by product of 
%       many numbers can be effectively circumvented.
%
%       The implementation is based on LU factorization.
%
%   v = logdet(A, 'chol');
%       If A is positive definite, you can tell the function 
%       to use Cholesky factorization to accomplish the task 
%       using this syntax, which is substantially more efficient
%       for positive definite matrix. 
%
%   Remarks
%   -------
%       logarithm of determinant of a matrix widely occurs in the 
%       context of multivariate statistics. The log-pdf, entropy, 
%       and divergence of Gaussian distribution typically comprises 
%       a term in form of log-determinant. This function might be 
%       useful there, especially in a high-dimensional space.       
%
%       Theoretially, LU, QR can both do the job. However, LU 
%       factorization is substantially faster. So, for generic
%       matrix, LU factorization is adopted. 
%
%       For positive definite matrices, such as covariance matrices,
%       Cholesky factorization is typically more efficient. And it
%       is STRONGLY RECOMMENDED that you use the chol (2nd syntax above) 
%       when you are sure that you are dealing with a positive definite
%       matrix.
%
%   Examples
%   --------
%       % compute the log-determinant of a generic matrix
%       A = rand(1000);
%       v = logdet(A);
%
%       % compute the log-determinant of a positive-definite matrix
%       A = rand(1000);
%       C = A * A';     % this makes C positive definite
%       v = logdet(C, 'chol');
%

%   Copyright 2008, Dahua Lin, MIT
%   Email: dhlin@mit.edu
%
%   This file can be freely modified or distributed for any kind of 
%   purposes.
%

%% argument checking

assert(isfloat(A) && ndims(A) == 2 && size(A,1) == size(A,2), ...
    'logdet:invalidarg', ...
    'A should be a square matrix of double or single class.');

if nargin < 2
    use_chol = 0;
else
    assert(strcmpi(op, 'chol'), ...
        'logdet:invalidarg', ...
        'The second argument can only be a string ''chol'' if it is specified.');
    use_chol = 1;
end

%% computation

if use_chol
    v = 2 * sum(log(diag(chol(A))));
else
    [L, U, P] = lu(A);
    du = diag(U);
    c = det(P) * prod(sign(du));
    v = log(c) + sum(log(abs(du)));
end
end
