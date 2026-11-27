# Tab completion: returns identifiers from IDENTS_BOUND_GVARS that share
# the prefix at the cursor. Identifier extraction is shared with
# JUPYTER_Inspect via JUPYTER_ExtractIdentifier (gap/JupyterUtil.gi).
InstallGlobalFunction(JUPYTER_Complete,
function(code, cursor_pos)
    local extracted, matches;

    extracted := JUPYTER_ExtractIdentifier(code, cursor_pos);
    if extracted.ident = "" then
        return rec( matches := [], cursor_start := cursor_pos,
                    cursor_end := cursor_pos, metadata := rec(),
                    status := "ok" );
    fi;

    matches := Filtered( IDENTS_BOUND_GVARS(),
                         x -> PositionSublist(x, extracted.ident) = 1 );
    SortBy(matches, Length);
    return rec( matches := matches
              , cursor_start := extracted.startpos
              , cursor_end := extracted.endpos
              , metadata := rec()
              , status := "ok" );
end);
