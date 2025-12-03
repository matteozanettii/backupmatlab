classdef MahalSorterFSApp < matlab.apps.AppBase
    % MahalSorterFSApp  App per visualizzare distanze Mahalanobis e Top N

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure        matlab.ui.Figure
        GridLayout      matlab.ui.container.GridLayout
        TitleLabel      matlab.ui.control.Label
        XLabel          matlab.ui.control.Label
        ddX             matlab.ui.control.DropDown
        YLabel          matlab.ui.control.Label
        ddY             matlab.ui.control.DropDown
        NLabel          matlab.ui.control.Label
        efN             matlab.ui.control.NumericEditField
        btnCompute      matlab.ui.control.Button
        lblInfo         matlab.ui.control.Label
        AX              matlab.ui.control.UIAxes
        TopTable        matlab.ui.control.Table
        ListBox         matlab.ui.control.ListBox
        btnSave         matlab.ui.control.Button
        AXRight         matlab.ui.control.UIAxes
    end

    properties (Access = private)
        Tin             table
        varsIdx         double
        varNames        cell
        scatterHandle
        centroid
        Maha
        indsSorted
    end

    methods (Access = public)
        function app = MahalSorterFSApp(TinInput, N)
            if nargin < 1 || isempty(TinInput)
                error('Devi fornire una table in input.');
            end
            if ~istable(TinInput), error('Input deve essere una table.'); end
            if nargin < 2 || isempty(N), N = 3; end
            validateattributes(N, {'numeric'}, {'scalar','positive','integer'});

            % store data
            app.Tin = TinInput;
            numMask = varfun(@isnumeric, app.Tin, 'OutputFormat','uniform');
            app.varsIdx = find(numMask);
            if isempty(app.varsIdx), error('La table non contiene variabili numeriche.'); end
            app.varNames = app.Tin.Properties.VariableNames(app.varsIdx);

            % create components
            createComponents(app);

            % initialize UI values
            app.ddX.Items = app.varNames;
            app.ddY.Items = app.varNames;
            app.ddX.Value = app.varNames{1};
            app.ddY.Value = app.varNames{min(2,numel(app.varNames))};
            app.efN.Value = double(min(max(1,N),height(app.Tin)));

            % perform initial compute
            onCompute(app,[],[]);
            movegui(app.UIFigure,'center');
        end

        function delete(app)
            if isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end
    end

    methods (Access = private)
        function createComponents(app)
            % UIFigure and grid
            app.UIFigure = uifigure('Name','MahalSorterFS Explorer','Position',[200 200 1000 650]);
            app.GridLayout = uigridlayout(app.UIFigure,[6,4]);
            app.GridLayout.RowHeight = {'fit','fit',30,'1x','fit','fit'};
            app.GridLayout.ColumnWidth = {220,'1x',300,120};
            app.GridLayout.Padding = [10 10 10 10];
            app.GridLayout.RowSpacing = 8;
            app.GridLayout.ColumnSpacing = 12;

            % Title
            app.TitleLabel = uilabel(app.GridLayout);
            app.TitleLabel.Text = 'MahalSorterFS Explorer';
            app.TitleLabel.FontSize = 16;
            app.TitleLabel.FontWeight = 'bold';
            app.TitleLabel.Layout.Row = 1;
            app.TitleLabel.Layout.Column = [1 4];

            % X dropdown
            app.XLabel = uilabel(app.GridLayout); app.XLabel.Text = 'Asse X:'; app.XLabel.Layout.Row = 2; app.XLabel.Layout.Column = 1;
            app.ddX = uidropdown(app.GridLayout); app.ddX.Layout.Row = 2; app.ddX.Layout.Column = 2;
            app.ddX.ValueChangedFcn = @(s,e) onCompute(app,[],[]);

            % Y dropdown
            app.YLabel = uilabel(app.GridLayout); app.YLabel.Text = 'Asse Y:'; app.YLabel.Layout.Row = 2; app.YLabel.Layout.Column = 3;
            app.ddY = uidropdown(app.GridLayout); app.ddY.Layout.Row = 2; app.ddY.Layout.Column = 4;
            app.ddY.ValueChangedFcn = @(s,e) onCompute(app,[],[]);

            % N editor and compute button
            app.NLabel = uilabel(app.GridLayout); app.NLabel.Text = 'Top N:'; app.NLabel.Layout.Row = 3; app.NLabel.Layout.Column = 1;
            app.efN = uieditfield(app.GridLayout,'numeric'); app.efN.Layout.Row = 3; app.efN.Layout.Column = 2;
            app.efN.RoundFractionalValues = true;
            app.efN.Limits = [1 height(app.Tin)];

            app.btnCompute = uibutton(app.GridLayout,'push'); app.btnCompute.Text = 'Calcola'; app.btnCompute.Layout.Row = 3; app.btnCompute.Layout.Column = 3;
            app.btnCompute.ButtonPushedFcn = @(s,e) onCompute(app,s,e);

            app.lblInfo = uilabel(app.GridLayout); app.lblInfo.Text = 'Pronto'; app.lblInfo.Layout.Row = 3; app.lblInfo.Layout.Column = 4;

            % Main axes
            app.AX = uiaxes(app.GridLayout); app.AX.Layout.Row = 4; app.AX.Layout.Column = [1 2]; app.AX.Box = 'on';
            title(app.AX,'Distanze Mahalanobis');

            % Table and listbox
            app.TopTable = uitable(app.GridLayout); app.TopTable.Layout.Row = [4 5]; app.TopTable.Layout.Column = 3;
            app.TopTable.ColumnName = {'Rank','Name','Distance'}; app.TopTable.ColumnEditable = false;
            app.TopTable.CellSelectionCallback = @(s,e) onTableSelect(app,s,e);

            app.ListBox = uilistbox(app.GridLayout); app.ListBox.Layout.Row = 5; app.ListBox.Layout.Column = 3; app.ListBox.Multiselect = 'off';
            app.ListBox.ValueChangedFcn = @(s,e) onListSelect(app,s,e);

            app.btnSave = uibutton(app.GridLayout,'push'); app.btnSave.Text = 'Salva Top N'; app.btnSave.Layout.Row = 6; app.btnSave.Layout.Column = 3;
            app.btnSave.ButtonPushedFcn = @(s,e) onSave(app,s,e);

            app.AXRight = uiaxes(app.GridLayout); app.AXRight.Layout.Row = [4 6]; app.AXRight.Layout.Column = 4; axis(app.AXRight,'off');
        end

        function onCompute(app,~,~)
            try
                app.lblInfo.Text = 'Calcolo in corso...'; drawnow;
                Ncur = round(app.efN.Value);
                Ncur = max(1,min(Ncur,height(app.Tin)));
                app.efN.Value = Ncur;

                xi = find(strcmp(app.varNames,app.ddX.Value),1);
                yi = find(strcmp(app.varNames,app.ddY.Value),1);
                if isempty(xi) || isempty(yi), error('Seleziona variabili valide per X e Y.'); end
                idxPair = app.varsIdx([xi yi]);

                dataAll = app.Tin{:,app.varsIdx};
                centroid = mean(dataAll,1);
                S = cov(dataAll);
                if exist('mahalFS','file') ~= 2
                    error('mahalFS (FSDA) non trovato sul path.');
                end
                MahaAll = mahalFS(dataAll, centroid, S);
                MahaAll = sqrt(max(0, MahaAll));
                [sortedVals, indDesc] = sort(MahaAll,'descend');

                app.Maha = MahaAll;
                app.indsSorted = indDesc;
                app.centroid = centroid;

                cla(app.AX);
                cmap = parula(256);
                rngVals = max(MahaAll) - min(MahaAll) + eps;
                cidx = round(1 + (MahaAll - min(MahaAll)) ./ rngVals * 255);
                cidx = max(1,min(256,cidx));
                colors = cmap(cidx,:);
                x = app.Tin{:, idxPair(1)};
                y = app.Tin{:, idxPair(2)};
                s = scatter(app.AX, x, y, 60, colors, 'filled', 'MarkerEdgeColor','k');
                app.scatterHandle = s;
                hold(app.AX,'on');
                centroidXY = centroid([xi yi]);
                plot(app.AX, centroidXY(1), centroidXY(2), 'kp','MarkerFaceColor','r','MarkerSize',14);
                Nvis = min(Ncur, numel(indDesc));
                for k = 1:Nvis
                    idx = indDesc(k);
                    plot(app.AX, x(idx), y(idx), 'o', 'MarkerSize', 12, 'MarkerEdgeColor','y', 'LineWidth',1.5);
                end
                colormap(app.AX, parula);
                hcb = colorbar(app.AX); hcb.Label.String = 'Distanza Mahalanobis';
                caxis(app.AX,[min(MahaAll) max(MahaAll)]);
                xlabel(app.AX, app.ddX.Value,'Interpreter','none');
                ylabel(app.AX, app.ddY.Value,'Interpreter','none');
                title(app.AX, 'Distanze Mahalanobis dal Centroide','Interpreter','none');
                axis(app.AX,'equal'); grid(app.AX,'on'); hold(app.AX,'off');

                if ~isempty(app.Tin.Properties.RowNames)
                    Names = string(app.Tin.Properties.RowNames);
                elseif any(strcmp(app.Tin.Properties.VariableNames,'Name'))
                    Names = string(app.Tin.Name);
                else
                    Names = string((1:height(app.Tin))');
                end

                topN = min(Ncur,height(app.Tin));
                Ttop = table((1:topN)', Names(indDesc(1:topN))', sortedVals(1:topN)', ...
                    'VariableNames', {'Rank','Name','Distance'});
                app.TopTable.Data = Ttop;
                app.ListBox.Items = cellstr(Names(indDesc(1:topN)));
                if ~isempty(app.ListBox.Items), app.ListBox.Value = app.ListBox.Items{1}; end

                app.lblInfo.Text = sprintf('Calcolo completato. Top %d aggiornati.', topN);
            catch ME
                app.lblInfo.Text = ['Errore: ' ME.message];
            end
        end

        function onTableSelect(app,~,event)
            try
                if isempty(event) || isempty(event.Indices), return; end
                row = event.Indices(1);
                if isempty(app.indsSorted) || row > numel(app.indsSorted), return; end
                idxGlobal = app.indsSorted(row);
                highlightPoint(app, idxGlobal);
            catch ME
                app.lblInfo.Text = ['Errore selezione tabella: ' ME.message];
            end
        end

        function onListSelect(app,src,~)
            try
                if isempty(src) || isempty(src.Value), return; end
                Names = getNames(app.Tin);
                idxGlobal = find(Names == string(src.Value),1);
                if ~isempty(idxGlobal), highlightPoint(app, idxGlobal); end
            catch ME
                app.lblInfo.Text = ['Errore lista: ' ME.message];
            end
        end

        function onSave(app,~,~)
            try
                Tdata = app.TopTable.Data;
                if ~istable(Tdata)
                    if iscell(Tdata)
                        colNames = app.TopTable.ColumnName;
                        if isempty(colNames), colNames = {'Col1'}; end
                        Tdata = cell2table(Tdata,'VariableNames',colNames);
                    else
                        error('Dati tabella non nel formato previsto.');
                    end
                end
                [file,path] = uiputfile('TopN_Maha.csv','Salva Top N');
                if isequal(file,0), return; end
                writetable(Tdata, fullfile(path,file));
                app.lblInfo.Text = ['Salvato: ' fullfile(path,file)];
            catch ME
                app.lblInfo.Text = ['Errore salvataggio: ' ME.message];
            end
        end

        function highlightPoint(app, idxGlobal)
            try
                delete(findall(app.AX,'Tag','HighlightMarker'));
            catch
            end
            try
                xi = find(strcmp(app.varNames,app.ddX.Value),1);
                yi = find(strcmp(app.varNames,app.ddY.Value),1);
                if isempty(xi) || isempty(yi), return; end
                idxPair = app.varsIdx([xi yi]);
                x = app.Tin{:, idxPair(1)}; y = app.Tin{:, idxPair(2)};
                if idxGlobal < 1 || idxGlobal > numel(x), return; end
                plot(app.AX, x(idxGlobal), y(idxGlobal), 'o', 'MarkerSize',16, 'MarkerEdgeColor','m','LineWidth',2, 'Tag','HighlightMarker');
                uistack(findall(app.AX,'Tag','HighlightMarker'),'top');
                if ~isempty(app.scatterHandle) && isvalid(app.scatterHandle)
                    try datatip(app.scatterHandle,'DataIndex',idxGlobal); end
                end
            catch ME
                app.lblInfo.Text = ['Errore highlight: ' ME.message];
            end
        end

        function Names = getNames(~,TinLocal)
            if ~isempty(TinLocal.Properties.RowNames)
                Names = string(TinLocal.Properties.RowNames);
            elseif any(strcmp(TinLocal.Properties.VariableNames,'Name'))
                Names = string(TinLocal.Name);
            else
                Names = string((1:height(TinLocal))');
            end
        end
    end
end
