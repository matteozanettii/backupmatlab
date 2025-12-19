function chart = connectedDotChart(tbl, labelVar)
% connectedDotChart  Factory that returns an interactive chart manager.
%   chart = connectedDotChart(T) uses row names (if any) for x labels.
%   chart = connectedDotChart(T, labelVar) uses table column labelVar for x labels.
    arguments
        tbl table
        labelVar (1,:) char = ''
    end
    chart = ConnectedDotChartManager(tbl, labelVar);
end
