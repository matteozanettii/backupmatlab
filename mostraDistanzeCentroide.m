function Tsorted = mostraDistanzeCentroide(Tin, N)
% mostraDistanzeCentroide  Distanze Mahalanobis (FSDA) e grafico migliorato.
%   Tsorted = mostraDistanzeCentroide(T)        usa N = 3 (default).
%   Tsorted = mostraDistanzeCentroide(T, N)     stampa le top N righe.
%   Richiede la toolbox FSDA per la funzione mahalFS.
%
%   Output: table con Name e Distance ordinata discendente.

% input validation e default
if nargin < 1 || isempty(Tin)
    error('Devi fornire una table in input.');
end
if ~istable(Tin)
    error('Input deve essere una table.');
end
if nargin < 2 || isempty(N)
    N = 3;
end
validateattributes(N, {'numeric'}, {'scalar','positive','integer'}, mfilename, 'N');

% selezione variabili numeriche
numMask = varfun(@isnumeric, Tin, 'OutputFormat','uniform');
if nnz(numMask) < 1
    error('La table non contiene variabili numeriche.');
end
X = Tin{:, numMask};    % n x m
[n, m] = size(X);

if m < 1
    error('Non ci sono colonne numeriche utilizzabili.');
end

% centroide e matrice di covarianza
centroid = mean(X, 1);
S = cov(X);

% calcolo distanza Mahalanobis usando mahalFS (FSDA)
% mahalFS(X, center, S) -> distances (n x 1)
if exist('mahalFS','file') ~= 2
    error('La funzione mahalFS (FSDA toolbox) non è disponibile sul path.');
end
Maha = mahalFS(X, centroid, S);   % assume già restituisce distanze non al quadrato

% nomi righe
if ~isempty(Tin.Properties.RowNames)
    Names = string(Tin.Properties.RowNames);
elseif any(strcmp(Tin.Properties.VariableNames,'Name'))
    Names = string(Tin.Name);
else
    Names = string((1:n)');
end

% ordino discendente e creo table di output
[Sorted, ind] = sort(Maha, 'descend');
Tsorted = table(Names(ind), Sorted, 'VariableNames', {'Name','Distance'});

% limita N al numero di righe
N = min(N, n);

% display top N
fprintf('Top %d elementi piu'' lontani dal centroide (discendente):\n', N);
for i = 1:N
    fprintf('%d: %s (%.6g)\n', i, Tsorted.Name(i), Tsorted.Distance(i));
end

% --- Grafico migliorato ---
% Uso prime due variabili numeriche per il grafico; se ce ne sono >2, si può estendere.
varsIdx = find(numMask);
if numel(varsIdx) < 2
    warning('Non ci sono almeno 2 variabili numeriche; salto il grafico cartesiano.');
    return;
end

x = X(:,1);
y = X(:,2);

% costruisci la mappa colori in base alla distanza ordinata (Sorted è n×1)
cmap = parula(256);
cidx = round(1 + (Sorted - min(Sorted)) ./ (max(Sorted)-min(Sorted)+eps) * 255);
cmapPts = cmap(cidx, :);          % n x 3

% assegna ai punti nell'ordine originale: per riga
colorsOriginal = zeros(n,3);
colorsOriginal(ind, :) = cmapPts; % ora left and right sono entrambi n x 3

sz = 36;  % marker size base
figure('Color','w','Position',[200,200,900,700]);
ax = axes('Box','on');
hold(ax,'on');

% Scatter con colori e bordo nero
scatter(ax, x, y, sz, colorsOriginal, 'filled', 'MarkerEdgeColor','k');

% evidenzio centroid
plot(ax, centroid(1), centroid(2), 'kp', 'MarkerFaceColor','r', 'MarkerSize',14, 'DisplayName','Centroide');

% evidenzio top N con cerchio e testo
for kidx = 1:N
    idx = ind(kidx);
    plot(ax, x(idx), y(idx), 'o', 'MarkerSize', 12, 'MarkerEdgeColor','y', 'LineWidth',1.5);
    % etichetta vicino al punto (leggero offset)
    txt = Tsorted.Name(kidx);
    text(ax, x(idx)+0.02*range(x), y(idx)+0.02*range(y), txt, 'FontSize',10, 'FontWeight','bold');
end

% colorbar basato su distanza (map da basso -> alto)
colormap(ax, parula);
hcb = colorbar(ax);
hcb.Label.String = 'Distanza Mahalanobis (discendente)';
caxis(ax, [min(Sorted) max(Sorted)]);

xlabel(ax, Tin.Properties.VariableNames{varsIdx(1)}, 'Interpreter','none','Color','black');
ylabel(ax, Tin.Properties.VariableNames{varsIdx(2)}, 'Interpreter','none','Color','black');
title(ax, 'Distanze Mahalanobis dal Centroide ', 'Interpreter','none','Color','black');

% miglioramenti estetici
ax.FontSize = 11;
axis(ax, 'equal');
grid(ax, 'on');
legend(ax, 'off'); % evita legenda piena di elementi
% crea legenda minima
legend(ax, {'Punti','Centroide','Top N'}, 'Location','best');

hold(ax,'off');

end
