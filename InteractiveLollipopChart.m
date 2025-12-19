classdef InteractiveLollipopChart < handle
    properties (SetAccess = private)
        T table
        TeamVar
        TopNameVar
        TopValueVar
        SecondNameVar
        SecondValueVar

        Fig
        Ax
        ScatterTop
        ScatterSecond
        Lines

        % shared color properties (single source of truth)
        TopColor
        SecondColor
        FadedColor
    end

    methods
        function obj = InteractiveLollipopChart(T, varargin)
            % Constructor: expects a table T and optional name-value pairs.
            if nargin < 1 || ~istable(T)
                error('InteractiveLollipopChart:InvalidInput', 'First input must be a table.');
            end
            obj.T = T;

            % Parse name-value pairs
            p = inputParser;
            addParameter(p, 'TeamVar', []);
            addParameter(p, 'TopNameVar', []);
            addParameter(p, 'TopValueVar', []);
            addParameter(p, 'SecondNameVar', []);
            addParameter(p, 'SecondValueVar', []);
            parse(p, varargin{:});
            nv = p.Results;

            % Auto-detect columns if not provided
            [teamIdx, nameIdxs, numIdxs] = detectColumns(obj);

            obj.TeamVar = resolveColumnSpecifier(obj, nv.TeamVar, teamIdx);
            obj.TopNameVar = resolveColumnSpecifier(obj, nv.TopNameVar, nameIdxs(1));
            obj.SecondNameVar = resolveColumnSpecifier(obj, nv.SecondNameVar, nameIdxs(2));

            if isempty(nv.TopValueVar) || isempty(nv.SecondValueVar)
                % pick two most significant numeric columns (sum)
                numSums = varfun(@(x) sum(double(x)), T(:, numIdxs), 'OutputFormat','uniform');
                [~, ord] = sort(numSums, 'descend');
                defaultTop = numIdxs(ord(1));
                defaultSecond = numIdxs(ord(2));
            else
                defaultTop = numIdxs(1);
                defaultSecond = numIdxs(2);
            end
            obj.TopValueVar = resolveColumnSpecifier(obj, nv.TopValueVar, defaultTop);
            obj.SecondValueVar = resolveColumnSpecifier(obj, nv.SecondValueVar, defaultSecond);

            validateMappings(obj);

            % set default colors (can be changed externally if desired)
            obj.TopColor    = [0 0.4470 0.7410];
            obj.SecondColor = [0.8500 0.3250 0.0980];
            obj.FadedColor  = [0.85 0.85 0.85];

            % Build plot (these methods set obj properties; obj is already assigned)
            createFigure(obj);
            drawChart(obj);
        end
    end

    methods (Access = private)
        function [teamIdx, nameIdxs, numIdxs] = detectColumns(obj)
            names = obj.T.Properties.VariableNames;
            n = numel(names);
            isTextLike = false(1,n);
            isNumericLike = false(1,n);
            for k = 1:n
                v = obj.T.(names{k});
                if isstring(v) || iscategorical(v) || iscellstr(v) || ischar(v)
                    isTextLike(k) = true;
                end
                if isnumeric(v) || islogical(v)
                    isNumericLike(k) = true;
                end
            end
            teamIdx = find(isTextLike,1);
            if isempty(teamIdx), teamIdx = 1; end

            nameCandidates = setdiff(find(isTextLike), teamIdx, 'stable');
            if numel(nameCandidates) < 2
                remaining = setdiff(1:n, teamIdx, 'stable');
                need = 2 - numel(nameCandidates);
                nameCandidates = [nameCandidates, remaining(1:need)];
            end
            nameIdxs = nameCandidates(1:2);

            numIdxs = find(isNumericLike);
            if numel(numIdxs) < 2
                error('InteractiveLollipopChart:NotEnoughNumeric', 'Need at least two numeric columns for values.');
            end
        end

        function idx = resolveColumnSpecifier(obj, spec, defaultIdx)
            if isempty(spec)
                idx = defaultIdx;
                return
            end
            if isnumeric(spec)
                idx = double(spec);
                return
            end
            specStr = string(spec);
            names = obj.T.Properties.VariableNames;
            tf = strcmp(names, specStr);
            if any(tf)
                idx = find(tf,1);
            else
                error('InteractiveLollipopChart:BadColumnName', 'Column "%s" not found.', specStr);
            end
        end

        function validateMappings(obj)
            nVars = width(obj.T);
            idxs = [obj.TeamVar, obj.TopNameVar, obj.SecondNameVar, obj.TopValueVar, obj.SecondValueVar];
            if any(idxs < 1) || any(idxs > nVars)
                error('InteractiveLollipopChart:BadIndex', 'One or more column indices out of range.');
            end
            vn = obj.T.Properties.VariableNames;
            if ~(isnumeric(obj.T.(vn{obj.TopValueVar})) || islogical(obj.T.(vn{obj.TopValueVar}))) || ...
               ~(isnumeric(obj.T.(vn{obj.SecondValueVar})) || islogical(obj.T.(vn{obj.SecondValueVar})))
                error('InteractiveLollipopChart:ValueNotNumeric', 'Selected value columns must be numeric.');
            end
        end

        function createFigure(obj)
            % Light neutral figure and white plotting area for best contrast
            obj.Fig = figure('Color', [0.95 0.95 0.95], ...
                             'Name', 'Interactive Lollipop Chart', ...
                             'NumberTitle', 'off');
            obj.Ax = axes('Parent', obj.Fig, ...
                          'Color', [0.1 0.1 0.1], ...    % plotting area background
                          'XColor', 'k', ...       % axis ticks/labels color
                          'YColor', 'k', ...
                          'FontSize', 11);
            ax.Color = [0.1 0.1 0.1];
            hold(obj.Ax, 'on');
            grid(obj.Ax, 'on');
            obj.Ax.GridColor = [0.1 0.1 0.1];
            obj.Ax.GridAlpha = 1;
            obj.Ax.XTick = [];
        end

        function drawChart(obj)
            T = obj.T;
            n = height(T);
            x = (1:n)';

            namesTop = string(T{:, obj.TopNameVar});
            namesSecond = string(T{:, obj.SecondNameVar});
            teamNames = string(T{:, obj.TeamVar});
            yTop = double(T{:, obj.TopValueVar});
            ySecond = double(T{:, obj.SecondValueVar});

            ymin = min([yTop; ySecond]);
            ymax = max([yTop; ySecond]);
            yrange = max(1, ymax - ymin);
            margin = 0.06*yrange;
            obj.Ax.YLim = [ymin - margin, ymax + margin];

            % draw connector lines (one Line object per pair, colorized)
            obj.Lines = gobjects(n,1);
            for i = 1:n
                if yTop(i) >= ySecond(i)
                    connColor = obj.TopColor;
                else
                    connColor = obj.SecondColor;
                end
                obj.Lines(i) = line(obj.Ax, [x(i) x(i)], [yTop(i) ySecond(i)], ...
                    'Color', connColor, 'LineWidth', 1.6);
            end

            % draw markers with black edges for contrast
            markerSize = 110;
            obj.ScatterTop = scatter(obj.Ax, x, yTop, markerSize, ...
                'MarkerFaceColor', obj.TopColor, 'MarkerEdgeColor', 'k', 'LineWidth', 0.8);
            obj.ScatterSecond = scatter(obj.Ax, x, ySecond, markerSize, ...
                'MarkerFaceColor', obj.SecondColor, 'MarkerEdgeColor', 'k', 'LineWidth', 0.8);

            % value text inside markers
            for i = 1:n
                text(obj.Ax, x(i), yTop(i), sprintf('%g', yTop(i)), ...
                    'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
                    'Color','w', 'FontWeight','bold', 'FontSize', 9);
                text(obj.Ax, x(i), ySecond(i), sprintf('%g', ySecond(i)), ...
                    'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
                    'Color','w', 'FontWeight','bold', 'FontSize', 9);
            end

            % name labels outside markers: black for readability
            yOffset = max(0.02*(obj.Ax.YLim(2)-obj.Ax.YLim(1)), 0.2);
            for i = 1:n
                text(obj.Ax, x(i), yTop(i)+yOffset, namesTop(i), ...
                    'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
                    'Color','w', 'FontSize', 9);
                text(obj.Ax, x(i), ySecond(i)-yOffset, namesSecond(i), ...
                    'HorizontalAlignment','center', 'VerticalAlignment','top', ...
                    'Color','w', 'FontSize', 9);
            end

            % x labels = team names
            xticks(obj.Ax, x);
            xticklabels(obj.Ax, teamNames);
            obj.Ax.XTickLabelRotation = 45;
            ylabel(obj.Ax, 'Value');

            % datatips
            topRows = [dataTipTextRow('Name', cellstr(namesTop)); dataTipTextRow('Team', cellstr(teamNames)); dataTipTextRow('Value', num2cell(yTop))];
            secondRows = [dataTipTextRow('Name', cellstr(namesSecond)); dataTipTextRow('Team', cellstr(teamNames)); dataTipTextRow('Value', num2cell(ySecond))];
            obj.ScatterTop.DataTipTemplate.DataTipRows = topRows;
            obj.ScatterSecond.DataTipTemplate.DataTipRows = secondRows;

            % legend with interactive toggling
            obj.ScatterTop.DisplayName = 'Top';
            obj.ScatterSecond.DisplayName = 'Second';
            lgd = legend(obj.Ax, [obj.ScatterTop, obj.ScatterSecond], 'Location', 'best');
            lgd.ItemHitFcn = @(lgd,event)obj.legendItemClick(lgd, event);
        end

        function legendItemClick(obj, ~, event)
            % Toggle visibility of the clicked series (scatter)
            peer = event.Peer;
            if strcmp(peer.Visible, 'on')
                peer.Visible = 'off';
            else
                peer.Visible = 'on';
            end

            % Determine current visibility state of each scatter
            topVisible = strcmp(obj.ScatterTop.Visible, 'on');
            secondVisible = strcmp(obj.ScatterSecond.Visible, 'on');

            % Update connector colors: colored only when both series visible,
            % otherwise faded
            for k = 1:numel(obj.Lines)
                if topVisible && secondVisible
                    ydata = obj.Lines(k).YData; % YData is [yTop ySecond]
                    if ydata(1) >= ydata(2)
                        obj.Lines(k).Color = obj.TopColor;
                    else
                        obj.Lines(k).Color = obj.SecondColor;
                    end
                else
                    obj.Lines(k).Color = obj.FadedColor;
                end
            end

            % Optionally fade marker face alpha when hidden (visual hint)
            if topVisible
                obj.ScatterTop.MarkerFaceAlpha = 1;
            else
                obj.ScatterTop.MarkerFaceAlpha = 0.25;
            end
            if secondVisible
                obj.ScatterSecond.MarkerFaceAlpha = 1;
            else
                obj.ScatterSecond.MarkerFaceAlpha = 0.25;
            end
        end
    end
end
