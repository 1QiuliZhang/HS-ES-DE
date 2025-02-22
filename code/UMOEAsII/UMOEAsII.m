%% ============United Multi-Operator Evolutionary AlgorithmsII ============
% Should you have any queries, please contact
% Dr. Saber Elsayed. University of New South Wales at Canberra
% s.elsayed@adfa.edu.au
% www.saberelsayd.net or
% https://sites.google.com/site/saberelsayed3/home
% =========================================================================
function [outcome,com_time,SR,avgFE,res_det,seed_run,bestx]= UMOEAsII(run,I_fno)

Par= Introd_Par(I_fno);
iter=0;             %% current generation

%% =================== Define a random seed ===============================
%%------use the seeds we used in the initial submission (Saved Read the seeds saved in Results_Record\seeds), 
%% if you have MATLAB R2015a with the following computer specifications: 
%%� Processor: Intel(R) Core(TM) i7-3770 CPU @ 3.40GHz (8 CPUs), ~3.4GHz 
%%� Memory: 16384MB RAM
%%� Windows: 7
%%� MATLAB 8.5.0.197613 (R2015a)

%% ======== else use a new set of seed
%% == use it if your computer's specifications are different from tthose mentioned above=======
%%-----Becase we ran experiments in parallel, we used "*run" to differentiate
%%-----among runs which started at the same time

stream = RandStream('mt19937ar','Seed',sum(100*clock)*run);
RandStream.setGlobalStream(stream);

%% to record seeds for further validation, if needed
seed_run=stream.Seed; 

%% define variables
current_eval=0;             %% current fitness evaluations
PS1=Par.PopSize;            %% define PS1
PS2=4+floor(3*log(Par.n));  %% define PS2
Par.PopSize=PS1+PS2;        %% PS = PS1+PS2

%% ====================== Initalize x ==================================
x=repmat(Par.xmin,Par.PopSize,1)+repmat((Par.xmax-Par.xmin),Par.PopSize,1).*rand(Par.PopSize,Par.n);

%% calc. fit. and update FES
tic;
fitx = cec14_func(x',I_fno);
current_eval =current_eval+Par.PopSize;
res_det= min(repmat(min(fitx),1,Par.PopSize), fitx); %% used to record the convergence

%% ====================== store the best ==================
[bestold, bes_l]=min(fitx);     bestx= x(bes_l,:);
%% ================== fill in each MOEA ===================================
%% DE
EA_1= x(1:PS1,:);    EA_obj1= fitx(1:PS1);
%% ES
EA_2= x(PS1+1:size(x,1),:);    EA_obj2= fitx(PS1+1:size(x,1));
%% ================ define CMA-ES parameters ==============================
setting=[];fitness=[];bnd=[];
[setting,fitness,bnd]= init_cmaes_par(setting,fitness,bnd,EA_obj2,EA_2, Par.n, PS2, Par.xmin, Par.xmax);

%% ===== prob. of each DE variant
probDE1=1./Par.n_opr .* ones(1,Par.n_opr);
%% ===================== archive data ====================================
arch_rate=2.6;
archive.NP = arch_rate * PS1; % the maximum size of the archive
archive.pop = zeros(0, Par.n); % the solutions stored in te archive
archive.funvalues = zeros(0, 1); % the function value of the archived solutions
%% ==================== to adapt CR and F =================================
hist_pos=1;
memory_size=6;
archive_f= ones(1,memory_size).*0.5;
archive_Cr= ones(1,memory_size).*0.5;
%%
stop_con=0; avgFE=Par.Max_FES; InitPop=PS1; thrshold=1e-08;

cy=0;indx = 0; Probs=ones(1,2);

%% main loop
while stop_con==0;
    
    iter=iter+1;
    cy=cy+1; % to control CS
    %  ================ determine the best MOEA ===========================
    if(cy==ceil(Par.CS+1))
        
        %%calc normalized qualit -- NQual
        qual(1) = EA_obj1(1);qual(2) = EA_obj2(1);
        norm_qual = qual./sum(qual);
        norm_qual=1-norm_qual; %% to satisfy the bigger is the better
        
        %%Normalized diversity
        D(1) = mean(pdist2(EA_1(2:PS1,:),EA_1(1,:)));
        D(2) = mean(pdist2(EA_2(2:PS2,:),EA_2(1,:)));
        norm_div= D./sum(D);
        
        %%Total Imp
        Probs=norm_qual+norm_div;
        %%Update Prob_MODE and Prob_CMAES
        Probs = max(0.1, min(0.9,Probs./sum(Probs)));
        
        [~,indx]=max(Probs);
        if Probs(1)==Probs(2)
            indx=0;%% no sharing of information
        end
        
    elseif cy==2*ceil(Par.CS)
        
        %% share information
        if indx==1
            list_ind = randperm(PS1);
            list_ind= list_ind(1:(min(PS2,PS1)));
            EA_2(1:size(list_ind,2),:)= EA_1(list_ind,:);
            EA_obj2(1:size(list_ind,2))= EA_obj1(list_ind);
            [setting,fitness,bnd]= init_cmaes_par(setting,fitness,bnd,EA_obj2,EA_2, Par.n, PS2, Par.xmin, Par.xmax);
            setting.sigma= setting.sigma*(1- (current_eval/Par.Max_FES));
        else
            if (min (EA_2(1,:)))> -100 && (max(EA_2(1,:)))<100 %% share best sol. in EA_2 if it is feasible
                EA_1(PS1,:)= EA_2(1,:);
                EA_obj1(PS1)= EA_obj2(1);
                [EA_obj1, ind]=sort(EA_obj1);
                EA_1=EA_1(ind,:);
            end
            
        end
        %% reset cy and Probs
        cy=1;   Probs=ones(1,2);
    end
    %% ====================== MOEA1 <-- SAMODE ============================
    if (current_eval<Par.Max_FES)
        if rand<Probs(1)
            
            %% =============================== LR of PS ===================================================
            UpdPopSize = round((((Par.MinPopSize - InitPop) / Par.Max_FES) * current_eval) + InitPop);
            if PS1 > UpdPopSize
                reduction_ind_num = PS1 - UpdPopSize;
                if PS1 - reduction_ind_num <  Par.MinPopSize;
                    reduction_ind_num = PS1 - Par.MinPopSize;
                end
                %% remove the worst ind.
                for r = 1 : reduction_ind_num
                    vv=PS1;
                    EA_1(vv,:)=[];
                    EA_obj1(vv)=[];
                    PS1 = PS1 - 1;
                end
                archive.NP = round(arch_rate * PS1);
                if size(archive.pop, 1) > archive.NP
                    rndpos = randperm(size(archive.pop, 1));
                    rndpos = rndpos(1 : archive.NP);
                    archive.pop = archive.pop(rndpos, :);
                end
            end
            
            %% apply MODE
            [EA_1, EA_obj1,probDE1,bestold,bestx,archive,hist_pos,memory_size, archive_f,archive_Cr,current_eval,res_det] = ...
                SAMO_DE( EA_1, EA_obj1,probDE1,bestold,bestx,archive,hist_pos,memory_size, archive_f,archive_Cr,...
                Par.xmin, Par.xmax,  Par.n,  PS1,  current_eval, I_fno,res_det,Par.Printing,Par.Max_FES);
        end
    end
    %% ====================== MOEA2 <-- SAMO-ES ======================
    if (current_eval<Par.Max_FES)
        if   rand<Probs(2)
            [ EA_2, EA_obj2, setting,bestold,bestx,bnd,fitness,current_eval,res_det] = ...
                SAMO_ES( EA_2, EA_obj2, setting, iter,bestold,bestx,fitness,bnd,...
                Par.xmin,Par.xmax,Par.n,PS2,current_eval,I_fno,res_det,Par.Printing,Par.Max_FES);
            
        end
    end
    %% ============================ LS ====================================
    if current_eval>0.75*Par.Max_FES
        if rand<Par.prob_ls
            old_fit_eva=current_eval;
            [bestx,bestold,current_eval,succ] = LS (bestx,bestold,Par,current_eval,I_fno,Par.Max_FES,Par.xmin,Par.xmax);
            if succ==1 %% if LS was successful
                EA_1(PS1,:)=bestx';
                EA_obj1(PS1)=bestold;
                [EA_obj1, sort_indx]=sort(EA_obj1);
                EA_1= EA_1(sort_indx,:);
                
                EA_2=repmat(EA_1(1,:), PS2, 1);
                [setting,fitness,bnd]= init_cmaes_par(setting,fitness,bnd,EA_obj2,EA_2, Par.n, PS2, Par.xmin, Par.xmax);
                setting.sigma=1e-05;
                EA_obj2(1:PS2)= EA_obj1(1);
                Par.prob_ls=0.1;
            else
                Par.prob_ls=0.01; %% set p_LS to a small value it  LS was not successful
            end
            %% record best fitness -- set Par.Printing==0 if not
            if Par.Printing==1
                res_det= [res_det repmat(bestold,1,(current_eval-old_fit_eva))];
            end
            
        end
    end
    
    %% ====================== stopping criterion check ====================
    if (current_eval>=Par.Max_FES)
        stop_con=1;
    end
    if ( (abs (Par.f_optimal - bestold)<= thrshold))
        stop_con=1;
        bestold=Par.f_optimal;
        avgFE=current_eval;
    end
    
    %% =============================== Print ==============================
    %          fprintf('current_eval\t %d fitness\t %d \n', current_eval, abs(Par.f_optimal-bestold));
    if stop_con
        com_time= toc;%cputime-start_time;
        fprintf('run\t %d, fitness\t %d, avg.FFE\t %d\t %d\n', run, abs(Par.f_optimal-bestold),avgFE,indx(1));
        outcome= abs(Par.f_optimal-bestold);
        if (min (bestx))< -100 || (max(bestx))>100 %% make sure  that the best solution is feasible
            fprintf('in problem: %d, there is  a violation',I_fno);
        end
        SR= (outcome==0);
    end
end
end
