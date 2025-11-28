function [pippo, info] = Corrcdf3D(Rho, n, rlow, rup)%#codegen
%CORRCDF3D  Calcola P = corrcdf(rup, rho, n) - corrcdf(rlow, rho, n)
%   [pippo, info] = Corrcdf3D(Rho, n)
%   [pippo, info] = Corrcdf3D(Rho, n, rlow, rup)
%   Rho, n possono essere scalari o vettori compatibili; rlow/rup sono opzionali.
%
%   Default per rlow/rup (se non forniti):
%     rlow = Rho - delta; rup = Rho + delta
%     delta = max(0.05, 0.05 * (max(Rho(:)) - min(Rho(:))))
%   i valori vengono poi riclampati in (-0.999, 0.999).
warning off
if nargin < 2
    error('Fornire almeno Rho e n.');
end

% Forma e vettorizzazione
Rho_orig = Rho;
Rho = Rho(:);
Nn = numel(Rho);

if isscalar(n), n = repmat(n, Nn, 1); else n = n(:); end

% default rlow/rup se non forniti
if nargin < 3 || isempty(rlow) || nargin < 4 || isempty(rup)
    % delta basato sul range di Rho (valore minimo fisso 0.05)
    Rrange = max(Rho) - min(Rho);
    delta = max(0.05, 0.05 * max(Rrange, eps));
    if nargin < 3 || isempty(rlow)
        rlow = Rho - delta;
    end
    if nargin < 4 || isempty(rup)
        rup = Rho + delta;
    end
end

% broadcast scalari
if isscalar(rlow), rlow = repmat(rlow, Nn, 1); else rlow = rlow(:); end
if isscalar(rup),  rup  = repmat(rup,  Nn, 1); else rup  = rup(:);  end

if ~(numel(rlow)==Nn && numel(rup)==Nn && numel(n)==Nn)
    error('Dimensione degli argomenti incompatibile dopo il broadcast.');
end

% clip per sicurezza (atanh numericamente instabile vicino ±1)
epsclip = 0.999;
Rho = min(max(Rho, -epsclip), epsclip);
rlow = min(max(rlow, -epsclip), epsclip);
rup  = min(max(rup,  -epsclip), epsclip);

pippo_vec = nan(Nn,1);
info = struct('UsedCorrcdf', false, 'Method', '', 'Notes', '', 'PlotHandles', []);

% Provo corrcdf se disponibile
if exist('corrcdf','file') == 2
    try
        C_low = corrcdf(rlow, n, Rho);   C_up  = corrcdf(rup,  n, Rho);
        if numel(C_low)==Nn && numel(C_up)==Nn
            pippo_vec = C_up - C_low; info.UsedCorrcdf = true; info.Method = 'corrcdf (r,n,Rho)';
        end
    catch, end
    if ~info.UsedCorrcdf
        try
            C_low = corrcdf(rlow, Rho, n); C_up  = corrcdf(rup,  Rho, n);
            if numel(C_low)==Nn && numel(C_up)==Nn
                pippo_vec = C_up - C_low; info.UsedCorrcdf = true; info.Method = 'corrcdf (r,Rho,n)';
            end
        catch, end
    end
    if ~info.UsedCorrcdf
        % elementwise fallback
        for i = 1:Nn
            try
                cl = corrcdf(rlow(i), n(i), Rho(i)); cu = corrcdf(rup(i), n(i), Rho(i));
            catch
                try
                    cl = corrcdf(rlow(i), Rho(i), n(i)); cu = corrcdf(rup(i), Rho(i), n(i));
                catch
                    cl = NaN; cu = NaN;
                end
            end
            pippo_vec(i) = cu - cl;
        end
        if ~all(isnan(pippo_vec))
            info.UsedCorrcdf = true; info.Method = 'corrcdf (elementwise)';
        else
            info.Notes = 'corrcdf presente ma non riuscita per tutti gli elementi; uso Fisher-z';
        end
    end
end

% Fisher-z fallback (per n > 3)
if ~info.UsedCorrcdf
    info.UsedCorrcdf = false; info.Method = 'fisher-z';
    invalidMask = n <= 3;
    pippo_vec(invalidMask) = NaN;
    validIdx = find(~invalidMask);
    if ~isempty(validIdx)
        z_low  = atanh(rlow(validIdx));
        z_up   = atanh(rup(validIdx));
        mu_z   = atanh(Rho(validIdx));
        sigma  = sqrt(1 ./ (n(validIdx) - 3));
        Z_low  = (z_low - mu_z) ./ sigma;
        Z_up   = (z_up  - mu_z) ./ sigma;
        CDF_low = 0.5 .* (1 + erf(Z_low ./ sqrt(2)));
        CDF_up  = 0.5 .* (1 + erf(Z_up  ./ sqrt(2)));
        pippo_vec(validIdx) = CDF_up - CDF_low;
    end
end

% Clamp numerico [0,1]
ok = ~isnan(pippo_vec);
pippo_vec(ok) = max(0, min(1, pippo_vec(ok)));

% Restituisco con shape originale
pippo = reshape(pippo_vec, size(Rho_orig));

% Plot diretto: ordine assi X = n, Y = P, Z = Rho e centering
mask = ~isnan(n) & ~isnan(Rho) & ~isnan(pippo_vec);
if any(mask)
    X = n(mask);
    Y = pippo_vec(mask);
    Z = Rho(mask);
    figure;
    hold on;
    hLine = plot3(X, Y, Z, '-o', 'LineWidth', 1.5, 'MarkerSize',6, 'MarkerFaceColor','auto');
    % centro e limiti
    centroid = [mean(X), mean(Y), mean(Z)];
    rngX = max(X) - min(X); if rngX == 0, rngX = 1; end
    rngY = max(Y) - min(Y); if rngY == 0, rngY = 1; end
    rngZ = max(Z) - min(Z); if rngZ == 0, rngZ = 1; end
    margin = 0.6;
    halfX = 0.5 * rngX * (1 + margin);
    halfY = 0.5 * rngY * (1 + margin);
    halfZ = 0.5 * rngZ * (1 + margin);
    xlim(centroid(1) + [-halfX, halfX]);
    ylim(centroid(2) + [-halfY, halfY]);
    zlim(centroid(3) + [-halfZ, halfZ]);
    axis equal;
    xlabel('n');
    ylabel('P (total correlation)');
    zlabel('\rho');
    view(45,30);
    rotate3d on;
    grid on;
    hold off;
    info.PlotHandles = struct('Line', hLine);
else
    warning('Nessun punto valido da plottare.');
    info.PlotHandles = struct('Line', []);
end

end
