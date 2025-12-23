
function applyTableLabels(obj, axOut, tblIn, colsArg, varargin)
% applyTableLabels  Apply table variable names as tick labels to axes
%   obj.applyTableLabels(axOut, tblIn, colsArg)  % best-effort auto
%   obj.applyTableLabels(...,'Orientation','x')  % force XTickLabel
%   obj.applyTableLabels(...,'Orientation','y')  % force YTickLabel
%   colsArg can be: numeric indices, string/cell of names, or empty -> use all

    % Parse optional args
    p = inputParser;
    addParameter(p,'Orientation','auto',@(s) any(validatestring(s,{'auto','x','y'})));
    addParameter(p,'Rotate',45,@isnumeric);
    addParameter(p,'FontSize',[],@(x) isempty(x) || (isnumeric(x) && isscalar(x)));
    parse(p,varargin{:});
    orient = p.Results.Orientation;
    rot = p.Results.Rotate;
    fs = p.Results.FontSize;

    % Normalize axes handle
    if isempty(axOut)
        ax = gca;
    elseif ishghandle(axOut) && isa(axOut,'matlab.ui.Figure')
        ax = get(axOut,'CurrentAxes'); if isempty(ax), ax = gca; end
    elseif ishghandle(axOut) && isa(axOut,'matlab.graphics.axis.Axes')
        ax = axOut;
    else
        ax = gca;
    end

    % Resolve chosen names from colsArg / tblIn
    allNames = tblIn.Properties.VariableNames;
    if isempty(colsArg)
        chosen = allNames(:);
    elseif isnumeric(colsArg)
        if any(colsArg < 1) || any(colsArg > numel(allNames))
            error('FSDAAutopilot:BadCols','Mapping.Cols indices out of range.');
        end
        chosen = allNames(colsArg);
    else
        if isstring(colsArg), colsArg = cellstr(colsArg); end
        chosen = cellstr(colsArg(:));
    end

    N = numel(chosen);
    if N == 0
        return
    end

    % Get current ticks
    xt = get(ax,'XTick');
    yt = get(ax,'YTick');

    % Decide orientation
    useX = false; useY = false;
    if strcmp(orient,'x')
        useX = true;
    elseif strcmp(orient,'y')
        useY = true;
    else
        % auto: prefer axis where num ticks equals N, else prefer X
        if numel(xt) == N
            useX = true;
        elseif numel(yt) == N
            useY = true;
        else
            % If data plotted categorical-like horizontally, prefer X
            useX = true;
        end
    end

    % Apply labels: set tick positions to 1:N if mismatch, then labels
    if useX
        try
            set(ax,'XTick',1:N,'XTickLabel',chosen);
        catch
            % fallback: set string labels via xticklabels (newer MATLAB)
            try
                xticklabels(ax, chosen);
                ax.XTick = 1:N;
            catch
                % give up silently
            end
        end
        xtickangle(ax, rot);
        if ~isempty(fs), ax.FontSize = fs; end
    elseif useY
        try
            set(ax,'YTick',1:N,'YTickLabel',chosen);
        catch
            try
                yticklabels(ax, chosen);
                ax.YTick = 1:N;
            catch
            end
        end
        ytickangle(ax, rot);
        if ~isempty(fs), ax.FontSize = fs; end
    end
end