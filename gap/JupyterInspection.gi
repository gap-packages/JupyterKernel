# Object/identifier inspection (Shift-Tab). Identifier extraction is
# shared with JUPYTER_Complete via JUPYTER_ExtractIdentifier.

# Format known properties and attributes of an object as a plain-text table.
BindGlobal("JUPYTER_FormatKnown",
function(obj)
    local res, props, attrs, len;

    props := KnownPropertiesOfObject(obj);
    attrs := KnownAttributesOfObject(obj);
    if props = [] and attrs = [] then
        return "";
    fi;

    len := Maximum( Concatenation( List(props, Length),
                                   List(attrs, Length),
                                   [ 1 ] ) ) + 1;

    res := "Properties:\n\n";
    Append( res, JoinStringsWithSeparator(
                     List(props, x -> STRINGIFY(String(x, -len), ": ",
                                                ValueGlobal(x)(obj))),
                     "\n") );
    Append(res, "\n\nAttributes:\n\n");
    Append( res, JoinStringsWithSeparator(
                     List(attrs, x -> STRINGIFY(String(x, -len), ": ",
                                                ValueGlobal(x)(obj))),
                     "\n") );
    return res;
end);

# Find documentation for an identifier in the GAP help books, return as
# plain text or "Undocumented" if no match.
BindGlobal("JUPYTER_FindHelp",
function(ident)
    local s, matches, match, info, data, data1, lines;

    s := SIMPLE_STRING(ident);
    matches := HELP_GET_MATCHES(HELP_KNOWN_BOOKS[1], s, true);
    if matches[1] <> [] then
        match := matches[1][1];
    elif matches[2] <> [] then
        match := matches[2][1];
    else
        return "Undocumented";
    fi;
    info := HELP_BOOK_INFO(match[1]);

    data  := HELP_BOOK_HANDLER.GapDocGAP.HelpData(info, match[2], "text");
    data1 := HELP_BOOK_HANDLER.GapDocGAP.HelpData(info, match[2] + 1, "text");

    if IsString(data.lines) then
        lines := SplitString(data.lines, "\n");
    else
        lines := data.lines;
    fi;
    return JoinStringsWithSeparator( lines{[data.start..data1.start - 1]}, "\n" );
end);

InstallGlobalFunction(JUPYTER_Inspect,
function(str, pos)
    local extracted, textplain, found, var;

    extracted := JUPYTER_ExtractIdentifier(str, pos);
    textplain := "";
    found := false;

    if extracted.ident <> "" then
        if extracted.fapp then
            textplain := JUPYTER_FindHelp(extracted.ident);
            found := textplain <> "Undocumented";
        elif IsBoundGlobal(extracted.ident) then
            found := true;
            var := ValueGlobal(extracted.ident);
            if IsFunction(var) then
                textplain := JUPYTER_FindHelp(extracted.ident);
            elif IsObject(var) then
                textplain := JUPYTER_FormatKnown(var);
            fi;
        fi;
    fi;

    return rec( status := "ok",
                found := found,
                data := rec( text\/html := "",
                             text\/plain := textplain ),
                metadata := rec() );
end);
