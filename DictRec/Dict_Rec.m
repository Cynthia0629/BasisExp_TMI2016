function [Count] = Dict_Rec(params,data,ch)
%% Function to implement Sparse KSVD
% Used in Denoising & Dictionary Recovery
% A is the sparse representation of the base dictionary D = B*A
% D_ = Dummy Dictionary
% D = Original Dictionary ; Ground Truth

%% Parameter Extraction
Tdict = params.Tdict;
D_base = params.D_base;
Dict = params.Dict;             % Ground Truth
alpha = params.alpha;   a1 = alpha(1); a2 = alpha(2);
iternum = params.iternum;
Count = zeros(1,iternum);

%% Dictionary Setup and Normalization
dictsize = size(Dict,2);
A = randn(size(D_base,2),dictsize);                 % Original Aini = Identity/random
for i = 1:dictsize
    A(:,i) = A(:,i)/norm(D_base*A(:,i));
end
D = D_base*A;   D = normc(D);
warning('off','MATLAB:nearlySingularMatrix');

%% Dictionary Learning stuff begins
for iter = 1:iternum
    G = D'*D;
    % Coding Mode
    if (isfield(params,'Tdata'))
        W = omp(D,data,G,params.Tdata);
    elseif (isfield(params,'Edata'))
        W = omp2(D,data,G,params.Edata);  % Sparse Coding Error Constraint
    end    
    p = randperm(dictsize); % randomize atom sparsify order
    
    replaced_atoms = zeros(1,dictsize);  % mark each atom replaced by optimize_atom  
    unused_sigs = 1:size(data,2);   % tracks the signals that were used to replace "dead" atoms.
                                    % makes sure the same signal is not selected twice
    for j = 1:dictsize
        switch lower(ch)
            case 'ksvds'
                [A(:,p(j)),W_j,data_indices,replaced_atoms,unused_sigs] = Optimize_KSVDs(data,D_base,A,p(j),W,Tdict,replaced_atoms,unused_sigs);
                W(p(j),data_indices) = W_j;            
            case 'algo-1'
                [A(:,p(j)),W_j,replaced_atoms,unused_sigs] = Optimize_A1(data,D_base,A,p(j),W,a1,replaced_atoms,unused_sigs);
                W(p(j),:)= W_j;
            case 'algo-2'
                [A(:,p(j)),W_j,replaced_atoms,unused_sigs] = Optimize_A2(data,D_base,A,p(j),W,a1,a2,replaced_atoms,unused_sigs);
                W(p(j),:)= W_j;
            otherwise
                error('Invalid Learning Method Specified');
        end        
    end    
        D = D_base*A;   D = normc(D);
    Count(1,iter) = NumAtomRec(D,Dict);               % To find # of atoms recovered
    disp([ch,' Iteration # ',num2str(iter),' Atoms recovered = ',num2str(Count(1,iter))])
end
end

function [a,W_j,ind,replaced_atoms,unused_sigs] = Optimize_KSVDs(data,D_base,A,j,W,Tdict,replaced_atoms,unused_sigs)
%     [g,ind] = sprow(W,j);
    ind = find(W(j,:)); g = W(j,ind);
    if length(ind) < 1
        maxsignals = 1000;
        perm = randperm(length(unused_sigs));  perm = perm(1:min(maxsignals,end)); 
        E = sum((data(:,unused_sigs(perm)) - D_base*A*W(:,unused_sigs(perm))).^2);
        [~,ind] = max(E);     X_I = data(:,unused_sigs(perm(ind)));
        a = omp(D_base,X_I,D_base'*D_base,Tdict);
        a = a/norm(D_base*a);       A(:,j) = a;
        W_j = 0;
        unused_sigs = unused_sigs([1:perm(ind)-1,perm(ind)+1:end]);
        replaced_atoms(j) = 1;
        return;
    end
    A(:,j) = 0;
    g = g';                 g = g/norm(g);
    X_I = data(:,ind);      W_I = W(:,ind);
    z = X_I*g - D_base*A*W_I*g;
    a = omp(D_base,z,D_base'*D_base,Tdict);     % Sparse atom coding
    a = a/norm(D_base*a);
    A(:,j) = a;
    W_j = (X_I'*D_base*a - (D_base*A*W_I)'*D_base*a)';
end

function [a,W_j,replaced_atoms,unused_sigs] = Optimize_A1(data,D_base,A,j,W,a1,replaced_atoms,unused_sigs)
    W_j = W(j,:);
    if nnz(W_j) < 1
        maxsignals = 1000;
        perm = randperm(length(unused_sigs));  perm = perm(1:min(maxsignals,end)); 
        E = sum((data(:,unused_sigs(perm)) - D_base*A*W(:,unused_sigs(perm))).^2);
        [~,ind] = max(E);     X_I = data(:,unused_sigs(perm(ind)));
        a = omp(D_base,X_I,D_base'*D_base,5);
        a = a/norm(D_base*a);       A(:,j) = a;
        W_j = 0;
        unused_sigs = unused_sigs([1:perm(ind)-1,perm(ind)+1:end]);
        replaced_atoms(j) = 1;
        return;
    end
    A(:,j) = 0;     
    E_k = data - D_base*A*W; 
    for i = 1:2
        a = (D_base'*D_base)\(D_base'*E_k*W_j');
        a = a/norm(D_base*a);   
        W_j = sign(a'*D_base'*E_k).*(abs(a'*D_base'*E_k)>a1/2).*(abs(a'*D_base'*E_k)-a1/2);
    end    
end

function [a,W_j,replaced_atoms,unused_sigs] = Optimize_A2(data,D_base,A,j,W,a1,a2,replaced_atoms,unused_sigs)
    W_j = W(j,:);
    if nnz(W_j) < 1
        maxsignals = 1000;
        perm = randperm(length(unused_sigs));  perm = perm(1:min(maxsignals,end)); 
        E = sum((data(:,unused_sigs(perm)) - D_base*A*W(:,unused_sigs(perm))).^2);
        [~,ind] = max(E);     X_I = data(:,unused_sigs(perm(ind)));
        a = omp(D_base,X_I,D_base'*D_base,5);
        a = a/norm(D_base*a);       A(:,j) = a;
        W_j = 0;
        unused_sigs = unused_sigs([1:perm(ind)-1,perm(ind)+1:end]);
        replaced_atoms(j) = 1;
        disp('olamba')
        return;
    end
    A(:,j) = 0;         
    E_k = data - D_base*A*W; 
    for i = 1:2
        XX = (sign(D_base'*E_k*W_j').*(abs(D_base'*E_k*W_j')>a2/2).*(abs(D_base'*E_k*W_j')-a2/2));
        if nnz(XX) == 0
            maxsignals = 1000;
            perm = randperm(length(unused_sigs));  perm = perm(1:min(maxsignals,end)); 
            E = sum((data(:,unused_sigs(perm)) - D_base*A*W(:,unused_sigs(perm))).^2);
            [~,ind] = max(E);     X_I = data(:,unused_sigs(perm(ind)));
            a = omp(D_base,X_I,D_base'*D_base,5);
            a = a/norm(D_base*a);       A(:,j) = a;
            W_j = 0;
            unused_sigs = unused_sigs([1:perm(ind)-1,perm(ind)+1:end]);
            replaced_atoms(j) = 1;
            disp('olamba')
            return;
        end
        a = ((D_base'*D_base)*norm(W_j)^2)\XX; 
        a = a/norm(D_base*a);
        W_j = sign(a'*D_base'*E_k).*(abs(a'*D_base'*E_k)>a1/2).*(abs(a'*D_base'*E_k)-a1/2);
    end
end

%% Function to Find # of Recovered Atoms
function Count = NumAtomRec(D_,D)   % Learnt and Original Dic
Count = 0;
% D_ = sign(D_).*D_;             % Making all atom values positive for safety
% D = sign(D).*D;
for i = 1:size(D_,2)
    D_(:,i) = sign(D_(1,i))*D_(:,i);
end

for i = 1:size(D,2)
    d = sign(D(1,i))*D(:,i);
    dist = sum((D_ - repmat(d,1,size(D_,2))).^2);
    [Value,Ind] = min (dist);
    Error = 1 - abs(D_(:,Ind)'*d);
    if Error < 0.01
        Count = Count + 1;
    end
end
Count = 100*Count/size(D_,2);
end