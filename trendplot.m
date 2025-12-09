function h = trendplot(tt, varargin)
% trendplot  Plot trends of variables in a timetable
%
% Usage:
%   h = trendplot(tt)                         % plot all numeric vars
%   h = trendplot(tt, 'Variables', V)        % V = string, char, or cellstr of var names
%   h = trendplot(tt, 'Smooth', span)        % span = moving average window (integer) or false (default)
%   h = trendplot(tt, 'Stacked', true)       % stacked subplots per variable (default false)
%   h = trendplot(tt, 'LineWidth', 1.5, 'Colors', cmap)
%
% Returns:
%   h = array of Line handles (if stacked, returns handles grouped by axes)

% Input validation
if ~istimetable(tt)
    error('Input must be a timetable.');
end

p = inputParser;
addParameter(p,'Variables',tt.Properties.VariableNames,@(x) ischar(x)||isstring(x)||iscellstr(x)||isstring(x));
addParameter(p,'Smooth',false,@(x) (isnumeric(x) && isscalar(x) && x>=1) || isequal(x,false));
addParameter(p,'Stacked',false,@islogical);
addParameter(p,'LineWidth',1.5,@(x)isnumeric(x)&&isscalar(x)&&x>0);
addParameter(p,'Colors',[],@(x)isnumeric(x) && (size(x,2)==3 || isempty(x)));
addParameter(p,'Marker','none',@(x)ischar(x)||isstring(x));
parse(p,varargin{:});
vars = p.Results.Variables;
span = p.Results.Smooth;
stacked = p.Results.Stacked;
lw = p.Results.LineWidth;
cmap = p.Results.Colors;
marker = char(p.Results.Marker);

% Resolve variables
if isempty(vars)
    vars = tt.Properties.VariableNames;
else
    if ischar(vars) || isstring(vars)
        vars = cellstr(vars);
    else
        vars = cellstr(vars);
    end
end

% Keep only variables that exist and are numeric/duration-compatible for plotting
valid = ismember(vars, tt.Properties.VariableNames);
vars = vars(valid);
if isempty(vars)
    error('No valid variables found to plot.');
end

% Extract data
t = tt.Properties.RowTimes;
Y = tt{:,vars};

% If some columns are non-numeric (e.g. categorical), try to convert
for k = 1:size(Y,2)
    if ~isnumeric(Y(:,k))
        try
            Y(:,k) = double(Y(:,k));
        catch
            error('Variable %s is not numeric and cannot be plotted.', vars{k});
        end
    end
end

% Apply smoothing if requested (simple moving average)
if ~isequal(span,false) && span>1
    for k = 1:size(Y,2)
        Y(:,k) = movmean(Y(:,k), round(span), 'Endpoints','shrink');
    end
end

% Prepare colors
nvars = size(Y,2);
if isempty(cmap)
    cmap = lines(nvars);
else
    if size(cmap,1) < nvars
        cmap = repmat(cmap(1,:), nvars, 1);
    end
end

% Plot
if stacked
    % one subplot per variable, shared x-axis
    clf;
    tlo = tiledlayout(nvars,1);
    h = gobjects(nvars,1);
    for k = 1:nvars
        ax = nexttile;
        h(k) = plot(t, Y(:,k), 'Color', cmap(k,:), 'LineWidth', lw, 'Marker', marker);
        ylabel(vars{k}, 'Interpreter','none');
        grid on;
        if k==1
            title('Trend Plot');
        end
        if k < nvars
            ax.XTickLabel = [];
        else
            xlabel('Time');
        end
    end
    xlabel(tlo, 'Time');
else
    clf;
    ax = axes;
    hold on;
    h = gobjects(nvars,1);
    for k = 1:nvars
        h(k) = plot(t, Y(:,k), 'Color', cmap(k,:), 'LineWidth', lw, 'Marker', marker);
    end
    hold off;
    legend(vars, 'Interpreter','none', 'Location','best');
    xlabel('Time'); ylabel('Value'); title('Trend Plot');
    grid on;
end

% Return handles
if nargout==0
    clear h
end

end
