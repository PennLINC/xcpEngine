function [S,Q,niter,agmats] = glconsensus(A,varargin)

%GLCONSENSUS Consensus community detection using the Louvain-like
% modularity-maximisation procedure, as implemented in genlouvain.m
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% glconsensus reads in:
%   (1) a square symmetric adjacency matrix
%   (2) [optional] number of repetitions of community detection
%       per agreement cycle [default 1]. One repetition performs
%       elementary community detection without any consensus
%       approach.
%   (3) [optional] Louvain community resolution parameter (or
%       parameter vector [+γ,-γ] for signed) [default 1]
%   (4) [optional] The predicted matrix P under an appropriate
%       objective function. If this is not provided, glconsensus
%       defaults to a signed generalisation of the Newman-Girvan
%       model.
%   (5) [optional] The type of degree normalisation to apply
%       when computing quality. Accepted options include 'signed'
%       [default] or 'none'.
%
% glconsensus outputs:
%   (1) A community affiliation vector numerically indicating
%       each node's community assignment
%   (2) The modularity value Q, representing the quality of the
%       consensus partition on the original adjacency matrix
%       under the Newman-Girvan objective function
%   (3) The number of iterations that the algorithm needs prior
%       to convergence.
%   (4) An array of agreement matrices from each stage of
%       community detection.
%
% glconsensus repeats genlouvain-based clustering nreps times per
% agreement cycle and continues agreement cycles until a consensus
% partition is obtained, similar to the approach of Lancichinetti
% and Fortunato as implemented/modified by Richard Betzel for BCT
%
% For a given adjacency matrix A, community detection is
% performed on the modularity matrix A using a generalisation of
% the Louvain approach:
%
%   B = A - P
%
% where the expectation matrix P follows the Newman-Girvan
% objective function for community detection on the adjacency
% matrix, but follows a constant model for community detection
% on the agreement matrix, with the constant defined via
% permutation of the community affiliation vector as in
% Bassett et al.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

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
nrepsnull = 100;
gamma = 1;
propgamma = 0;
pmat = 0;
ntype = 'signed';
agmats = [];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Parse optional inputs
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for i=1:2:length(varargin)
    switch varargin{i}
        case 'nreps'
            nreps = varargin{i+1};
        case 'nnull'
            nrepsnull = varargin{i+1};
        case 'gamma'
            gamma = varargin{i+1};
        case 'gprop'
            propgamma = varargin{i+1};
        case 'pmat'
            pmat = varargin{i+1};
        case 'dnorm'
            ntype = varargin{i+1};
        otherwise
            warning(['Unknown option: ' varargin{i} '\n'])
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Obtain the number of nodes in the input adjacency matrix.
%
% Write the original adjacency matrix into the variable 'adjmat'
% so that the quality of the consensus partition may be computed
% on the original adjacency matrix rather than the most recent
% agreement matrix.
%
% If the network has one or fewer nodes, abort. The problem is
% trivial and the result uninformative.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
N = size(A,1);
if N <= 1
    S = 1;
    Q = NaN;
    return
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% TEMPORARY WORKAROUND:
% Use the signed generalisation of the Newman-Girvan null.
%
% TODO
% Read papers regarding expected/null edge weight models for
% correlation matrices. The Newman-Girvan objective function may
% not be the most appropriate in this case.
% (1) Bazzi, Porter, et al. Community detection in temporal
%     multilayer networks, and its application to correlation networks
%     http://arxiv.org/pdf/1501.00040v2.pdf
% (2) McMahon and Garlaschelli 2014 Community detection for
%     correlation matrices
%     http://arxiv.org/pdf/1311.1924v3.pdf
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Apos = A;
Aneg = -A;
Apos(A<0) = 0;
Aneg(A>0) = 0;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Prepare a preliminary matrix of predicted edge weights P
% expected under an appropriate null model.
%
% The "modularity" matrix B that genlouvain receives as input
% should be the difference between the observed graph A and the
% predicted graph P.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if length(gamma) == 1
    gpos = gamma(1);
    gneg = gamma(1);
elseif length(gamma)==2
    gpos = gamma(1);
    gneg = gamma(2);
else
    S = 1;
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
% Continue until there is a consensus
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
while consensus ~= 1
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Iterate for nreps
    % Preallocate for a set of community affiliation vectors
    % (preagreement) and a set of association matrices (agreement)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    preagreement = zeros(N,nreps);
    agreement = zeros(N,N,nreps);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Define the modularity matrix as the difference between the
    % observed edge weights and the predicted edge weights.
    %
    % Allocate memory for a sparse matrix based on the input
    % adjacency matrix or edge timeseries
    %
    % This is more generalisable but slower for the case of a
    % single-slice matrix
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    B = A - P;
    for r = 1:nreps
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Compute the community partition. The solution space
        % of possible community partitions should be sampled
        % nreps times.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        S = genlouvain(B,10000,0);
        S = reshape(S,[N,1]);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Write the nodewise community affiliation vector into
        % the pre-agreement matrix
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        preagreement(:,r) = S;
    end
    niter = niter + 1;
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Convert pre-agreement vector array to agreement matrix.
    % Update the matrix being operated upon so that it is the
    % probabilistic agreement matrix. The weight of each edge is
    % equal to the probability that the nodes it connects are
    % assigned to the same community over the sample of the
    % solution space.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    H = dummyvar(preagreement);
    A = H*H'./nreps;
    agmats = cat(3,agmats,A);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Determine whether consensus has been reached: if it has, the
    % sampled solution space will be deterministic, so only binary
    % values will exist in the agreement matrix.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if isempty(setdiff_fp(unique(A).',[0,1]))
        consensus = 1;
        break
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Generate a null model of agreement matrices via nodewise
    % permutation of community assignments. This null model
    % provides the expected weights of edges in the agreement
    % matrix.
    %
    % Some code for this section contributed by Dr. Richard Betzel
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    Pmat = zeros(N,N,nreps);
    for r = 1:nrepsnull
        [~,R] = sort(rand(size(preagreement)));
        I = V + R;
        H = dummyvar(preagreement(I));
        P = H*H';
        P = P - diag(diag(P));
        Pmat(:,:,r) = P;
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % This null model effectively results in a constant expected
    % weight for all edges; it is independent of "degree" (mean
    % community size of a node).
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    pcon = gprop .* mean(mean(mean(Pmat)))./nrepsnull;
    P = repmat(pcon,size(P));
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Compute Newman-Girvan modularity (quality function) for
% the consensus.
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

end





%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Helper function to obtain set difference of floating point
% numbers, as publicly contributed by Divakar
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [C,IA] = setdiff_fp(A,B)
%//SETDIFF_FP Set difference for floating point numbers.
%//   C = SETDIFF_FP(A,B) for vectors A and B, returns the values 
%//   in A that are not in B with no repetitions. C will be sorted.
%//
%//   [C,IA] = SETDIFF_FP(A,B) also returns an index vector IA
%//   such that C = A(IA). If there are repeated values in A that
%//   are not in B, then the index of the first occurrence of each
%//   repeated value is returned.

%//   Get 2D matrix of absolute difference between each element
%//   of A against  each element of B
      abs_diff_mat = abs(bsxfun(@minus,A,B.')); %//'

%//   Compare each element against eps to "negate" the floating
%//   point precision issues. Thus, we have a binary array of
%//   true comparisons.
      abs_diff_mat_epscmp = abs_diff_mat<=eps;

%//   Find indices of A that are exclusive to it
      A_ind = ~any(abs_diff_mat_epscmp,1);

%//   Get unique(to account for no repetitions and being sorted)
%//   exclusive  A elements for the final output alongwith the
%//   indices
      [C,IA] = intersect(A,unique(A(A_ind)));
      return;
end
