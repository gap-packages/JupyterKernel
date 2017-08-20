# This is a rather basic helper function to do
# completion. It is related to the completion
# function provided in lib/cmdledit.g in the GAP
# distribution
InstallGlobalFunction(JUPYTER_Complete,
function(code, cursor_pos)
    local default, cand, i, matches, tokens, tok;

    default := rec( matches := [], cursor_start := 0,
                    cursor_end := cursor_pos, metadata := rec(),
                    status := "ok" );

    code := code{[1..cursor_pos]};
    if Length(code) = 0 then
        return default;
    fi;
    tokens := SplitString(code, "():=<>,.[]?-+*/; ");

    if tokens = [] then
        return default;
    fi;

    tok := tokens[Length(tokens)];
    cand := IDENTS_BOUND_GVARS();
    matches := Filtered(cand, i -> PositionSublist(i, tok) = 1);
    SortBy(matches, Length);
    return rec( matches := matches
              , cursor_start := cursor_pos - Length(tok)
              , cursor_end := cursor_pos
              , metadata := rec()
              , status := "ok" );
end);
