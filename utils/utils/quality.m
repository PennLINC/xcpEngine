function quality(adjmatpath,compath,outpath,varargin)

%GLCONSENSUSCL Command-line wrapper for glconsensus.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  ⊗  %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Flag indicates that algorithm has not yet converged
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
consensus = 0;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Define defaults
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
nreps = 1;
gamma = 1;
pmat = 0;
ntype = 'signed';
missing = '';

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Read in the adjacency matrix or edge timeseries
% TODO
% The 'type' field is currently not used; however, it will indicate
% the type of input matrix, e.g. FA, correlation, etc., so that
% the most appropriate objective function can be applied. As of
% now, only the Newman-Girvan is implemented.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
A = dlmread(adjmatpath);
S = dlmread(compath);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Parse optional inputs
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for i=1:2:length(varargin)
    switch varargin{i}
        case 'pmat'
            pmat = varargin{i+1};
            pmat = dlmread(pmat);
        case 'dnorm'
            ntype = varargin{i+1};
        case 'gamma'
            gamma = varargin{i+1};
        case 'dnorm'
            ntype = varargin{i+1};
        otherwise
            warning(['Unknown option: ' varargin{i} '\n']);
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Prepare a preliminary matrix of predicted edge weights P
% expected under an appropriate null model.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if length(gamma) == 1
    gpos = gamma(1);
    gneg = gamma(1);
elseif length(gamma)==2
    gpos = gamma(1);
    gneg = gamma(2);
else
    Q=NaN;
    return
end
if propgamma
    gprop = gpos;
else
    gprop = 1;
end
kpos=sum(Apos)';
kneg=sum(Aneg)';
twompos = sum(kpos);
twomneg = sum(kneg);
if size(pmat) == size(A)
    P = pmat;
else
    P = gpos*kpos*kpos'/twompos-gneg*kneg*kneg'/twomneg;
end
V = repmat(0:(nreps - 1),[N,1]);
niter = 0;
adjmat = A;
pmat = P;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Compute the partition quality.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

B = adjmat - pmat;
H = dummyvar(S);
delta = H*H';
if strcmp(ntype,'none')
    degnorm = 1;
else
    degnorm = twompos + twomneg;
end
Q = sum(sum(B.*delta)) ./ degnorm;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Write output.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
dlmwrite(outpath,full(Q),'delimiter',' ');

end
