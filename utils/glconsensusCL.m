function glconsensusCL(adjmatpath,outpath,varargin)

%GLCONSENSUSCL Command-line wrapper for glconsensus.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  ☭  %
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
if size(A,1) == 1 || size(A,2) == 1
    A = squareform(A);
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Parse optional inputs
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for i=1:2:length(varargin)
    switch varargin{i}
        case 'nreps'
            nreps = varargin{i+1};
        case 'gamma'
            gamma = varargin{i+1};
        case 'pmat'
            pmat = varargin{i+1};
        case 'dnorm'
            ntype = varargin{i+1};
        case 'missing'
            missing = varargin{i+1};
        otherwise
            warning(['Unknown option: ' varargin{i} '\n']);
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Remove missing nodes.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if exist(missing,'file')
    missing_idx = dlmread(missing);
    N = size(A,1);
    aidx = 1:N;
    if length(missing_idx)==1
        aidx = (aidx~=missing_idx);
    else
        aidx = ~sum(bsxfun(@eq,aidx,missing_idx));
    end
    A = A(aidx,aidx);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Perform consensus community detection.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
[S,Q,ni,ag] = glconsensus(A,'nreps',nreps,'gamma',gamma,'pmat',pmat,'dnorm',ntype,'gprop',0);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Restore missing nodes as singletons.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if exist('missing_idx','var')
    S1 = zeros(N,1);
    S1(aidx) = S;
    ncom = max(S);
    for j = missing_idx'
        ncom = ncom + 1;
        S1(j) = ncom;
    end
    S = S1;
    ag1 = zeros(N,N,ni);
    ag1(aidx,aidx,:) = ag;
    ag = ag1;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Write outputs.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
dlmwrite([outpath '_partition.1D'],S,'delimiter',' ');
dlmwrite([outpath '_modularity.txt'],full(Q),'delimiter',' ');
%dlmwrite([outpath '_agreement.txt'],ni,'delimiter',' ');
%dlmwrite([outpath '_agreement.txt'],ag,'delimiter',' ','-append');

end
