classdef ConnectedDotChartManager < handle
    properties
        Figure
        Ax
        Line
        Markers
        Data
        XPos      % numeric vector length n (1:n)
        MarkerSize = 8
        SourceTable
        LabelVar = ''   % optional column name for x labels
    end
    properties (Access = private)
        DragIndex = []
    end

    methods
        function obj = ConnectedDotChartManager(tbl, labelVar)
            if nargin<1 || ~istable(tbl), error('Requires table'); end
            if nargin>=2 && ~isempty(labelVar)
                validateattributes(labelVar, {'char','string'},{'row'});
                obj.LabelVar = char(labelVar);
            end
            obj.SourceTable = tbl;
            obj.Data = obj.tableToData(tbl);
            obj.XPos = (1:numel(obj.Data))';
            obj.createGraphics();
            obj.updateGraphics();
        end

        function setData(obj, tbl)
            if ~istable(tbl), error('setData expects a table.'); end
            obj.SourceTable = tbl;
            obj.Data = obj.tableToData(tbl);
            obj.XPos = (1:numel(obj.Data))';
            if isempty(obj.Figure) || ~isgraphics(obj.Figure,'figure'), obj.createGraphics(); end
            obj.updateGraphics();
        end

        function d = getData(obj), d = obj.Data; end
        function t = getSourceTable(obj), t = obj.SourceTable; end
    end

    methods (Access = private)
        function y = tableToData(~, tbl)
            names = tbl.Properties.VariableNames;
            for k = 1:numel(names)
                col = tbl.(names{k});
                if isnumeric(col) || islogical(col)
                    y = double(col(:)); return
                end
            end
            error('Table must contain at least one numeric or logical var.');
        end

        function lbls = computeXLabels(obj)
            % Prefer explicit label column, else row names, else numeric indices
            if ~isempty(obj.LabelVar) && ismember(obj.LabelVar, obj.SourceTable.Properties.VariableNames)
                col = obj.SourceTable.(obj.LabelVar);
                if iscellstr(col) || isstring(col) || iscategorical(col)
                    lbls = cellstr(string(col(:)));
                    return
                else
                    % fallback: convert to strings
                    lbls = cellstr(string(col(:)));
                    return
                end
            end
            if ~isempty(obj.SourceTable.Properties.RowNames)
                rn = obj.SourceTable.Properties.RowNames;
                lbls = rn(:);
                return
            end
            % default numeric labels
            n = numel(obj.Data);
            lbls = arrayfun(@num2str, (1:n)', 'UniformOutput', false);
        end

        function createGraphics(obj)
            if ~isempty(obj.Figure) && isgraphics(obj.Figure,'figure'), try delete(obj.Figure); catch,end; end
            obj.Figure = figure('Name','Connected Dot Chart','NumberTitle','off', ...
                'WindowButtonUpFcn', @(~,~)obj.onMouseUp(), ...
                'WindowButtonMotionFcn', @(~,~)obj.onMouseMove(), ...
                'CloseRequestFcn', @(src,~)obj.onFigureClose(src) );
            obj.Ax = axes('Parent', obj.Figure); hold(obj.Ax,'on');
            obj.Line = plot(obj.Ax, NaN, NaN, '-o', 'MarkerFaceColor','w', 'MarkerSize', obj.MarkerSize, ...
                'LineWidth',1.5,'HitTest','off');
            obj.Markers = gobjects(0,1);
            ylabel(obj.Ax,'Value');
            title(obj.Ax,'Connected Dot Chart (drag points to edit)');
        end

        function updateGraphics(obj)
            n = numel(obj.Data);
            xs = (1:n)';
            obj.XPos = xs;
            set(obj.Line,'XData',xs,'YData',obj.Data);

            if ~isempty(obj.Markers) && any(ishandle(obj.Markers)), try delete(obj.Markers(ishandle(obj.Markers))); catch,end; end
            obj.Markers = gobjects(n,1);
            for k = 1:n
                h = plot(obj.Ax, xs(k), obj.Data(k), 'o', 'MarkerSize', obj.MarkerSize, ...
                    'MarkerFaceColor','b','MarkerEdgeColor','k', 'ButtonDownFcn', @(~,~)obj.onMarkerDown(k));
                obj.Markers(k) = h;
            end

            % X ticks & labels
            if n>0
                xticks(obj.Ax, xs);
                lbls = obj.computeXLabels();
                % if labels length mismatches, fallback to numeric
                if numel(lbls) ~= n, lbls = arrayfun(@num2str, xs, 'UniformOutput', false); end
                xticklabels(obj.Ax, lbls);
                xtickangle(obj.Ax, 45);
            else
                xticks(obj.Ax, []);
                xticklabels(obj.Ax, {});
            end

            % Y limits
            if n>0
                yMin = min(obj.Data); yMax = max(obj.Data);
                if yMin==yMax, delta = max(1,abs(yMax)*0.1); yMin=yMin-delta; yMax=yMax+delta;
                else delta = 0.05*(yMax-yMin); yMin=yMin-delta; yMax=yMax+delta; end
                xlim(obj.Ax, [0.5, n+0.5]);
                ylim(obj.Ax, [yMin, yMax]);
            else
                xlim(obj.Ax, [0,1]); ylim(obj.Ax, [-1,1]);
            end
            drawnow limitrate
        end

        function onMarkerDown(obj, idx)
            obj.DragIndex = idx;
            if ~isempty(obj.Figure) && isgraphics(obj.Figure,'figure')
                try
                    figure(obj.Figure);
                    if isprop(obj.Figure,'WindowState'), obj.Figure.WindowState = 'normal'; end
                catch, end
            else
                warning('Figure missing: recreating.');
                obj.createGraphics();
                obj.updateGraphics();
            end
            drawnow;
        end

        function onMouseMove(obj)
            if isempty(obj.DragIndex), return, end
            if isempty(obj.Ax) || ~isgraphics(obj.Ax,'axes'), return, end
            C = get(obj.Ax,'CurrentPoint'); newY = C(1,2);
            obj.Data(obj.DragIndex) = newY;
            if isgraphics(obj.Line), set(obj.Line,'YData',obj.Data); end
            if isgraphics(obj.Markers(obj.DragIndex)), set(obj.Markers(obj.DragIndex),'YData',newY); end
            drawnow limitrate
        end

        function onMouseUp(obj)
            if isempty(obj.DragIndex), return, end
            obj.DragIndex = [];
            try
                names = obj.SourceTable.Properties.VariableNames;
                for k = 1:numel(names)
                    col = obj.SourceTable.(names{k});
                    if isnumeric(col) || islogical(col)
                        if numel(col) == numel(obj.Data)
                            obj.SourceTable.(names{k}) = cast(obj.Data, class(col));
                        end
                        break
                    end
                end
            catch, end
        end

        function onFigureClose(obj, src)
            try delete(src); catch, end
            obj.Figure = [];
        end
    end
end
