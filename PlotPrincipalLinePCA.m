function out = PlotPrincipalLinePCA(T, cols, varargin)
% PlotPrincipalLinePCA  Calcola e plotta la retta principale 3D usando PCA.
% USAGE
%   out = PlotPrincipalLinePCA(T)
%   out = PlotPrincipalLinePCA(T,'select')
%   out = PlotPrincipalLinePCA(T,[1 2 3])
%   out = PlotPrincipalLinePCA(T,{'Var1','Var2','Var3'})
%   out = PlotPrincipalLinePCA(...,'Nline',200,'Scale',3)
%
% OUTPUT (struct out)
%   out.mu        - 1x3 mean of selected variables
%   out.v1        - 3x1 first principal direction (unit)
%   out.Xproj     - Nx3 projections of X on the principal line
%   out.tproj     - Nx1 scores along v1 (parametric coordinates)
%   out.coeff     - 3x3 PCA loadings (coeff)
%   out.score     - Nx3 PCA scores
%   out.explained - variance explained by components
%   out.cols      - indices of selected columns in T
%   out.X         - Nx3 data used
%   out.linePts   - Nline x 3 points used to draw the line
%   out.options   - parsed options (Nline, Scale, etc.)

% default cols
if nargin < 2
    cols = [];
end

% parse name-value and validate basic types
p = inputParser;
addRequired(p,'T', @(x) istable(x));
addOptional(p,'cols', [], @(x) (isempty(x) || isnumeric(x) || iscellstr(x) || isstring(x) || ischar(x)));
addParameter(p,'Nline',200,@(x) isnumeric(x)&&isscalar(x)&&x>1);
addParameter(p,'Scale',3,@(x) isnumeric(x)&&isscalar(x));
parse(p,T,cols,varargin{:});
opts = p.Results;
cols = opts.cols;

% GUI selection if requested or empty
if isempty(cols) || (ischar(cols) && strcmpi(cols,'select')) || (isstring(cols) && isscalar(cols) && strcmpi(cols,"select"))
    names = T.Properties.VariableNames;
    numMask = varfun(@isnumeric, T, 'OutputFormat','uniform');
    preselect = find(numMask,3);
    if isempty(preselect)
        preselect = 1:min(3,numel(names));
    end
    [sel, ok] = listdlg('ListString', names, ...
                        'SelectionMode', 'multiple', ...
                        'InitialValue', preselect, ...
                        'PromptString', 'Seleziona esattamente 3 variabili per le coordinate 3D:', ...
                        'Name', 'Seleziona variabili', ...
                        'ListSize', [300 300]);
    if ok && numel(sel) == 3
        cols = sel;
    else
        idx = find(numMask,3);
        if numel(idx) < 3
            error('La table deve avere almeno 3 variabili numeriche.');
        end
        cols = idx;
    end
end

% --- Normalizza e valida l'input cols (accetta indici o nomi) ---
names = T.Properties.VariableNames;
if isnumeric(cols)
    if numel(cols) ~= 3
        error('Specificare esattamente 3 indici di colonna.');
    end
    colIdx = cols(:).'; % row vector
else
    % unify textual inputs into cellstr
    if ischar(cols)
        colsCell = {cols};
    else
        try
            colsCell = cellstr(string(cols));
        catch
            error('Formato di ''cols'' non valido.');
        end
    end

    % map each requested name to its index (preserve user order)
    nameToIdx = containers.Map(names, 1:numel(names));
    colIdx = zeros(1, numel(colsCell));
    for k = 1:numel(colsCell)
        nm = colsCell{k};
        if isKey(nameToIdx, nm)
            colIdx(k) = nameToIdx(nm);
        else
            error('Nome di variabile non trovato: %s', nm);
        end
    end

    if numel(colIdx) ~= 3
        error('Specificare esattamente 3 nomi di variabile presenti in T.');
    end
end

% final cols (indices)
cols = colIdx;

% extract Nx3 data
X = T{:, cols};
if size(X,2) ~= 3 || ~isnumeric(X)
    error('Le colonne selezionate devono essere 3 e numeriche.');
end

% PCA (pca returns mu and score consistent with internal centering)
[coeff, score, ~, ~, explained, mu_pca] = pca(X);

mu = mu_pca;              % 1x3 mean
v1 = coeff(:,1);          % 3x1 first principal direction
tproj = score(:,1);       % Nx1 scores along v1
Xproj = mu + tproj * v1.';% Nx3 projections

% construct line points using spread of scores and Scale
tmin = min(tproj); tmax = max(tproj);
if tmax == tmin
    span = max(1, abs(tmin));
    tspan = linspace(-opts.Scale*span, opts.Scale*span, opts.Nline).';
else
    tspan = linspace(tmin - opts.Scale*(tmax-tmin)/2, tmax + opts.Scale*(tmax-tmin)/2, opts.Nline).';
end
linePts = mu + tspan * v1.';

% plot
figure;
scatter3(X(:,1),X(:,2),X(:,3),36,'b','filled'); hold on;
plot3(linePts(:,1),linePts(:,2),linePts(:,3),'r-','LineWidth',2);
plot3(Xproj(:,1),Xproj(:,2),Xproj(:,3),'ko','MarkerSize',4);
for i = 1:size(X,1)
    plot3([X(i,1),Xproj(i,1)], [X(i,2),Xproj(i,2)], [X(i,3),Xproj(i,3)], '-', 'Color', [0.6 0.6 0.6]);
end
axis equal; grid on; view(3);
xlabel(names{cols(1)});
ylabel(names{cols(2)});
zlabel(names{cols(3)});
legend('Dati','Retta principale (PCA)','Proiezioni','Location','best');
hold off;

% prepare output struct
out = struct();
out.mu        = mu;
out.v1        = v1;
out.Xproj     = Xproj;
out.tproj     = tproj;
out.coeff     = coeff;
out.score     = score;
out.explained = explained;
out.cols      = cols;
out.X         = X;
out.linePts   = linePts;
out.options   = opts;

end
