% This script produces the data for the purple curves in Fig. 8 (i.e., the proposed algorihtm)
% for given noise power (tau_N, e.g., -70dB-- -110dB);
%
% The results are NMSE_H_RB and NMSE_H_UR, which is also
% stored in DATA/VIB_Simulation.mat;
% To save the running time, here we can set the number of Monte Carlo
% trials as a small number.
% To fully recover the plots in Fig. 8, one shall change libopt.trials
% to 1500;

clear;
%clc;
warning('off');
%% add script path
basePath = [fileparts(mfilename('fullpath')) filesep];
addpath([basePath 'Replica_Library']);
addpath([basePath 'MP_Library']);
addpath([basePath 'Model_Generation_Library']);

%% libopt contains system parameter that will be passed into message passing functions
libopt=[];

% change to 1500 for smooth result
libopt.trials=1500;    % number of monte carlo trials

%.mat file location
libopt.pathstr=[basePath 'DATA/VIB_Simulation.mat'];

% allowable times for independent multiple trials, see below
multiple_intial=3;
%% System Parameter
libopt.M=60;        % number of antennas at BS
libopt.eta=2;       % 2x resolution of each sampling grid
libopt.M_prime=libopt.M*libopt.eta;  % dimension of sampling grid at BS
libopt.T=35;        % pliot length
libopt.K=20;        % # of users
libopt.L1=4;        % vertical dimension of the LIS
libopt.L2=4;        % horizontal dimension of the LIS
libopt.L1_prime=libopt.L1*libopt.eta;  % vertical dimension of sampling grid at RIS
libopt.L2_prime=libopt.L2*libopt.eta;  % horizontal dimension of sampling grid at RIS
libopt.L=libopt.L1*libopt.L2;          % # of antennas at the LIS
libopt.L_prime=libopt.L1_prime*libopt.L2_prime;  % total sampling dimension
libopt.kappa=9; %Rician factor in eq. (2)

%% Channel Parameter

% multipath channels are generated by multiple paths, angels of each forms
% scattering clusters with certain angular spread
libopt.C1=20;  %# of clusters in \hat H_RB
libopt.C2=1; % # of clusters in \tilde H_RB
libopt.C3=1; % # of cluster in h_{k,UR} \forall k
libopt.P_path=10; % # of paths per cluster
anglespread=10;


ref_pl=20; % reference path loss at d=1m
pleRB=2; %Path loss exponent for RIS-BS channe;
pleUR=2.6; %Path loss exponent for User-RIS channe;
dRB=50; % distance between BS and RIS
dUR=rand(libopt.K,1)*2+10; % distance between RIS and users uniformly drawn from U([10,12]);
% compute path gain \beta_0 and {\beta_k: 1\leq k leq K}
libopt.beta_0=dRB^(-pleRB)*10^(-0.1*ref_pl); % beta_0
libopt.beta_k=dUR.^(-pleUR)*10^(-0.1*ref_pl); %beta_k K\times 1

%% Algorithm Parameter

% These statistical quantites determine the prior distributions eqs.
% (12)--(13), which are input of Algorithm 1.
% Note that after changing the setting, one needs to well tune those parameters to achieve
% good performance for the message passing algorithm
libopt.lambdaG=0.1;                    % lambda_G defined in eq.(13), sparsity of G
libopt.lambdaS=0.01;                   % lambda_S defined in eq.(12), sparsity of S
libopt.tauS=1;                         % tau_S, nonzero variance
libopt.tauG=2;                         % tau_G, nonzero variance


libopt.optiter=2000; % I_max, maximum allowable number of algorithm 1
%
% input inverse noise power by user
% For example: the range in Fig. 8 is 70:5:110
Listinput=input('input the range of 1/tau_N in dB (in the form of list)\n');

% store NMSEs for each trial
NMSE_H_RB_trial=nan(length(Listinput),libopt.trials);
NMSE_H_UR_trial=nan(length(Listinput),libopt.trials);
% Run
for l=1:length(Listinput)
    % noise power
    libopt.tau_N_inverse=Listinput(l);
    fprintf('tau_N_inverse: %d\n',libopt.tau_N_inverse)
    libopt.nuw=10^(-libopt.tau_N_inverse/10);
    for j=1:libopt.trials
        fprintf('%d-th trial\n', j);
        % generate the channel/signal matrices for this realization
        % the overall model is: Y=H_RB*H_UR*X+N
        
        
        % Transmit Signal Matrix X: K\times T
        X=sqrt(1/2).*(randn(libopt.K,libopt.T)+1j*randn(libopt.K,libopt.T) );
        % AWGN N: M\times T
        N=sqrt(libopt.nuw/2).*(randn(libopt.M,libopt.T)+1i*randn(libopt.M,libopt.T));
        
        
        % Generate H_RB by eqs. (2)--(4)
        
        % RIS-BS slow-varying channel \bar H_RB, eq. (3)
        H_RB_bar=zeros(libopt.M,libopt.L);
        % paths are from 20 clusters, center angle of each cluster is
        % uniformly drawn, each path has a 10-degree angle spread with the
        % ceter angle
        for i=1:libopt.C1
            center_BS=180*(rand-0.5); % center azimuth AoA at BS
            center_RIS_azimuth=360*(rand-0.5);  % center azimuth AoD at RIS
            center_RIS_elevation=180*(rand-0.5); % center elevation AoD at RIS
            for i_p=1:libopt.P_path
                % angle of each path
                
                % azimuth AoA at BS
                n_ele_eff=center_BS+(rand-0.5)*anglespread;
                % azimuth AoD at RIS
                n_ele2_eff=center_RIS_azimuth+(rand-0.5)*anglespread;
                % elevation AoD at RIS
                n_ele3_eff=center_RIS_elevation+(rand-0.5)*anglespread;
                
                % steering vector a_B
                a1=exp(-1i*pi*(0:libopt.M-1)'*sind(n_ele_eff))/sqrt(libopt.M);
                
                % steering vecto a_R
                a4=exp(-1i*pi*(0:libopt.L1-1)'*cosd(n_ele3_eff)*sind(n_ele2_eff))/sqrt(libopt.L1);
                a3=exp(1i*pi*(0:libopt.L2-1)'*cosd(n_ele3_eff)*cosd(n_ele2_eff))/sqrt(libopt.L2);
                a2=kron(a4,a3);
                
                % coefficient \alpha_p
                alpha=sqrt(0.5)*(randn(1)+1i*randn(1));
                % sum up
                H_RB_bar=H_RB_bar+a1*a2'*alpha;
            end
        end
        % normalize the channel
        an=sqrt(mean(abs(H_RB_bar(:)).^2));
        H_RB_bar=H_RB_bar/an*sqrt(libopt.kappa/(libopt.kappa+1));
        H_RB_bar=sqrt(libopt.beta_0)*H_RB_bar;
        
        % RIS-BS fast-varying channel \tilde H_RB, eq. (3)
        H_RB_tilde=zeros(libopt.M,libopt.L);
        % paths are from one cluster, with center angle
        % uniformly drawn; each path has a 10-degree angle spread with the
        % ceter angle
        for i=1:libopt.C2
            center_BS=180*(rand-0.5);
            center_RIS_azimuth=360*(rand-0.5);
            center_RIS_elevation=180*(rand-0.5);
            for i_p=1:libopt.P_path
                n_ele_eff=center_BS+(rand-0.5)*anglespread;
                n_ele2_eff=center_RIS_azimuth+(rand-0.5)*anglespread;
                n_ele3_eff=center_RIS_elevation+(rand-0.5)*anglespread;
                a1=exp(-1i*pi*(0:libopt.M-1)'*sind(n_ele_eff))/sqrt(libopt.M);
                a4=exp(-1i*pi*(0:libopt.L1-1)'*cosd(n_ele3_eff)*sind(n_ele2_eff))/sqrt(libopt.L1);
                a3=exp(1i*pi*(0:libopt.L2-1)'*cosd(n_ele3_eff)*cosd(n_ele2_eff))/sqrt(libopt.L2);
                a2=kron(a4,a3);
                alpha=sqrt(0.5)*(randn(1)+1i*randn(1));
                H_RB_tilde=H_RB_tilde+a1*a2'*alpha;
            end
        end
        bn=sqrt(mean(abs(H_RB_tilde(:)).^2));
        H_RB_tilde=H_RB_tilde/bn*sqrt(1/(libopt.kappa+1));
        H_RB_tilde=sqrt(libopt.beta_0)*H_RB_tilde;
        % H_RB, eq. (2)
        H_RB=H_RB_bar+H_RB_tilde;
        
        % User-RIS channel  H_UR, L\times K, eq. (4)
        % paths are from one cluster, with center angle
        % uniformly drawn; each path has a 10-degree angle spread with the
        % ceter angle
        H_UR=zeros(libopt.L,libopt.K);
        for k=1:libopt.K
            for fj=1:libopt.C3
                center_RIS_azimuth=360*(rand-0.5);
                center_RIS_elevation=180*(rand-0.5);
                for i_p=1:libopt.P_path
                    n_ele2_eff=center_RIS_azimuth+(rand-0.5)*anglespread;
                    n_ele3_eff=center_RIS_elevation+(rand-0.5)*anglespread;
                    a4=exp(-1i*pi*(0:libopt.L1-1)'*cosd(n_ele3_eff)*sind(n_ele2_eff))/sqrt(libopt.L1);
                    a3=exp(1i*pi*(0:libopt.L2-1)'*cosd(n_ele3_eff)*cosd(n_ele2_eff))/sqrt(libopt.L2);
                    a2=kron(a4,a3);
                    alpha=sqrt(0.5)*(randn(1)+1i*randn(1));
                    H_UR(:,k)=H_UR(:,k)+a2*alpha;
                end
            end
        end
        cn=sqrt(mean(abs(H_UR(:)).^2));
        H_UR=H_UR/cn;
        H_UR=H_UR*diag(sqrt(libopt.beta_k));
        % receive signal Y
        Y=H_RB*H_UR*X+N;
        
        
        
        
        %% Run Message Passing Algorithm to Estimate Channels by eq. (10)
        % For the model Y=H_RB*H_UR*X+N, due to the existance of
        % large-scale fading, the magnitude of channel coefficients are
        % typically very small.
        
        % To avoid numerical errors in iteration and stablize the algorithm,
        % we first scale H_RB as H_RB*sqrt(\beta_0) and H_UR as
        % H_UR*mean(sqrt(\beta_k),k=1,2,...,K) by multiplying
        % sqrt(\beta_0)* mean(sqrt(\beta_k),k=1,2,...,K) at the both sides
        % of Y=H_RB*H_UR*X+N.
        
        % Roughly speaking, the variance of channel coefficients are around
        % 1 after the scaling.
        
        % After running the message passing algorithm, estimates are saled
        % back by multiplying 1/sqrt(\beta_0) and 1/mean(sqrt(\beta_k)).
        
        % Note that this normalization trick is commonly used in data
        % pre-processing.
        
        
        
        
        % structure that stores the known channels in eq. (10), which will pass into
        % the algorithm
        system=[];
        
        
        % BS angle basis A_B with an over-complete grid
        theta_0=-1+1/libopt.M_prime:2/libopt.M_prime:1-1/libopt.M_prime;
        system.A_B=exp(-1i*pi*(0:libopt.M-1)'*(theta_0))/sqrt(libopt.M);
        
        % RIS angle basis A_R with over-complete grids
        phi_01=-1+1/libopt.L1_prime:2/libopt.L1_prime:1-1/libopt.L1_prime;
        phi_02=-1+1/libopt.L2_prime:2/libopt.L2_prime:1-1/libopt.L2_prime;
        A_RIS_1= exp(-1i*pi*(0:libopt.L1-1)'*(phi_01))/sqrt(libopt.L1);
        A_RIS_2= exp(-1i*pi*(0:libopt.L2-1)'*(phi_02))/sqrt(libopt.L2);
        system.A_RIS=kron(A_RIS_2,A_RIS_1);
        
        
        
        
        % scaled receive signal
        system.X=X;
        system.Y=Y/sqrt(libopt.beta_0)/sqrt(mean(libopt.beta_k));
        
        % H_0 in eq. (10)
        system.H_0=H_RB_bar*system.A_RIS/sqrt(libopt.beta_0);
        
        % R in eq. (10)
        system.R=system.A_RIS'*system.A_RIS;
        
        % scaled noise power
        system.nuw=max(libopt.nuw/mean(libopt.beta_k)/libopt.beta_0,1e-10);
        
        
        % To stablize the result of matrix factorization, following [Ref
        % 1], we initalize the algorithm multiple times (=multiple_intial) independently. The
        % best result is selected as the final result. This is a common
        % metric in evaluting blinear matrix factorization performance.
        
        % Note that in Section VI-B, all algorithms, including baselines,
        % are invoked multiple times and only their best results are used for
        % comparisons.
        
        % [Ref 1]: J. T. Parker et al, "Bilinear Generalized Approximate Message 
        % Passing--Part II: Applications," in IEEE Transactions on Signal
        % Processing, 2014.
        
        
        
        temp=inf;
        for mm=1:multiple_intial
            % Run Algorithm 1
            Estimate_Output=MessagePassing(system,libopt);
            % Compute the estimates
            Estimate_Output.H_RB=H_RB_bar+...
                sqrt(libopt.beta_0)*system.A_B*Estimate_Output.shat*system.A_RIS';
            Estimate_Output.H_UR=sqrt(mean(libopt.beta_k))*system.A_RIS*Estimate_Output.ghat;
            
            
            % Compute NMSEs
            n1=NMSE_CAL(H_RB,Estimate_Output.H_RB);
            n2=NMSE_CAL2(H_UR,Estimate_Output.H_UR);
            
            % find the best result
            if n2<temp
                NMSE_H_RB_trial(l,j)=n1;
                NMSE_H_UR_trial(l,j)=n2;
                temp=n2;
            end
            
        end
        fprintf('Message passing NMSEs: %f, %f\n',...
            10*log10(NMSE_H_RB_trial(l,j)),10*log10(NMSE_H_UR_trial(l,j)));
    end
    
end
% Average NMSEs
NMSE_H_RB=10*log10(mean(NMSE_H_RB_trial,2))';
NMSE_H_UR=10*log10(mean(NMSE_H_UR_trial,2))';

% save the data
save(libopt.pathstr,'NMSE_H_RB','NMSE_H_UR','NMSE_H_RB_trial','NMSE_H_UR_trial','libopt');
