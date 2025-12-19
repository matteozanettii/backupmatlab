function lm = lollipopPlot(tbl, xVar, yVars, varargin)
% lollipopPlot  Interfaccia semplice per creare dumbbell (vertical) in OOP.
% lm = lollipopPlot(tbl)
% lm = lollipopPlot(tbl, xVar)
% lm = lollipopPlot(tbl, xVar, yVars)
% lm = lollipopPlot(..., Name,Value...)
%
% Default behavior:
% - se passi solo tbl: prima colonna -> X, le altre -> Y
% - se passi tbl e xVar: xVar -> X, tutte le altre -> Y
% - se passi 2 Y: disegna dumbbell verticale (linea che collega i due valori)
% - se passi 1 o >2 Y: disegna lollipop/stem per ciascuna serie

if nargin < 1 || ~istable(tbl)
    error('First input must be a table.');
end

% Determine xVar and yVars defaults
if nargin < 2 || isempty(xVar)
    xIdx = 1;
else
    if isnumeric(xVar)
        xIdx = xVar;
    else
        xIdx = find(strcmp(tbl.Properties.VariableNames, char(xVar)),1);
        if isempty(xIdx), xIdx = find(strcmpi(tbl.Properties.VariableNames, char(xVar)),1); end
        if isempty(xIdx), error('xVar not found in table variable names.'); end
    end
end

if nargin < 3 || isempty(yVars)
    allIdx = 1:width(tbl);
    yIdx = allIdx(allIdx ~= xIdx);
else
    if isnumeric(yVars)
        yIdx = yVars;
    else
        yVarsCell = cellstr(string(yVars));
        yIdx = zeros(1,numel(yVarsCell));
        for k = 1:numel(yVarsCell)
            ii = find(strcmp(tbl.Properties.VariableNames, yVarsCell{k}),1);
            if isempty(ii), ii = find(strcmpi(tbl.Properties.VariableNames, yVarsCell{k}),1); end
            if isempty(ii), error('yVars entry "%s" not found in table.', yVarsCell{k}); end
            yIdx(k) = ii;
        end
    end
end

xVarName = tbl.Properties.VariableNames{xIdx};
yVarNames = tbl.Properties.VariableNames(yIdx);
xVarName = string(xVarName);
yVarNames = string(yVarNames);

% parse optional name-value pairs (keeps unmatched for future use)
p = inputParser;
p.KeepUnmatched = true;
addParameter(p,'MarkerSize',80,@(v)isnumeric(v)&&isscalar(v)&&v>0);
addParameter(p,'Colors',[],@(v)isnumeric(v)&&size(v,2)==3);
addParameter(p,'OffsetFrac',0.02,@(v)isnumeric(v)&&isscalar(v)&&v>=0);
addParameter(p,'ShowDelta',true,@islogical);
addParameter(p,'Baseline',0,@isnumeric);
parse(p,varargin{:});
opts = p.Results;

% create manager and draw
lm = LollipopManager(tbl, xVarName, yVarNames, opts);
lm.draw();
end
