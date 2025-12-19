function obj = createLollipopChart(T, varargin)
% createLollipopChart  Factory function that constructs and returns the chart object.
% Usage: obj = createLollipopChart(T, 'TopValueVar', 'GoalsA', ...)

    % Pre-checks
    if nargin < 1
        error('createLollipopChart:NoTable', 'You must supply a table as the first input.');
    end
    % Construct the object and return it. If constructor errors, it will propagate.
    obj = InteractiveLollipopChart(T, varargin{:});
end
