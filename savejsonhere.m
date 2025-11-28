%SaveFunctionSignatures_SaveHere.m
FS = struct();
FS._schemaVersion = "1.0.0";

fn = struct();
fn.help = "Calcola e plotta la retta principale 3D usando PCA. Uso: out = PlotPrincipalLinePCA(T, cols, Name,Value).";

fn.inputs = [ ...
    struct("name","T","kind","required","type",{{"table"}},"purpose","Table MATLAB contenente le variabili; devono essere presenti almeno 3 variabili numeriche."), ...
    struct("name","cols","kind","optional","type",{{"numeric","string","cellstr","char","[]"}},"purpose","Selezione delle 3 colonne: indici [i j k], nomi {'Var1','Var2','Var3'}, singola stringa 'select' per GUI, o vuoto per auto-selezione."), ...
    struct("name","Nline","kind","namevalue","type",{{"numeric"}},"purpose","Numero di punti per disegnare la retta (intero scalare > 1).","default",200), ...
    struct("name","Scale","kind","namevalue","type",{{"numeric"}},"purpose","Fattore di estensione della retta oltre l'intervallo dei punteggi (scalar).","default",3) ...
];

fn.outputs = [ ...
    struct("name","out","type","struct","purpose","Struct con campi mu, v1, Xproj, tproj, coeff, score, explained, cols, X, linePts, options.") ...
];

fn.signatures = [ ...
    struct("signature","PlotPrincipalLinePCA(T)","purpose","Calcola e disegna usando la selezione automatica di 3 variabili numeriche."), ...
    struct("signature","PlotPrincipalLinePCA(T, 'select')","purpose","Apre GUI per scegliere esattamente 3 variabili."), ...
    struct("signature","PlotPrincipalLinePCA(T, [i j k])","purpose","Specificare 3 indici di colonna numerici (ordine utente preservato)."), ...
    struct("signature","PlotPrincipalLinePCA(T, {'Var1','Var2','Var3'})","purpose","Specificare 3 nomi di variabile (cell array di char / string)."), ...
    struct("signature","PlotPrincipalLinePCA(..., 'Nline', N, 'Scale', S)","purpose","Opzioni name-value per numero di punti della retta e scala.") ...
];

FS.PlotPrincipalLinePCA = fn;

% Encode and write file in UTF-8
jsonText = jsonencode(FS);
% pretty print (simple)
jsonText = prettyjson(jsonText);

fid = fopen('functionSignatures.json','w','n','UTF-8');
if fid < 0
    error('Cannot open functionSignatures.json for writing in current folder: %s', pwd);
end
fwrite(fid, jsonText, 'char');
fclose(fid);
fprintf('Wrote %s\n', fullfile(pwd,'functionSignatures.json'));

% --- small pretty-printer ---
function out = prettyjson(in)
    out = regexprep(in,'([{,[])(?="\w)','$1' + newline,'emptymatch'); %#ok<STRNU,PFUNK>
    % fallback minimal formatting
    out = regexprep(in,'([{\[,])','${newline}$1');
    out = regexprep(out,',',',$1');
    out = strrep(out,'$1',char(10));
    lines = regexp(out,char(10),'split');
    level = 0;
    for i=1:numel(lines)
        ln = strtrim(lines{i});
        if isempty(ln), lines{i} = ''; continue; end
        if startsWith(ln,'}') || startsWith(ln,']'), level = max(level-1,0); end
        lines{i} = [repmat('  ',1,level) ln];
        if endsWith(ln,'{') || endsWith(ln,'['), level = level + 1; end
    end
    out = strjoin(lines,char(10));
end
