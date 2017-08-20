
# TODO: Really we should be formatting text and HTML output
#       And the HTML output could for instance link to the 
#       documentation of the attributes
BindGlobal("JUPYTER_FormatKnown",
function(obj)
    local res, n, p, props, attrs, len;

    props := KnownPropertiesOfObject(obj);
    attrs := KnownAttributesOfObject(obj);

    len   := Maximum(List(props, Length));
    len   := Maximum(len, Maximum(List(props, Length))) + 1;

    res := "Properties:\n\n";
    props := List(props,
                  x -> STRINGIFY(String(x, -len), ": ",
                                 ValueGlobal(x)(obj)));
    Append(res, JoinStringsWithSeparator(props, "\n"));

    Append(res, "\n\nAttributes:\n\n");
    attrs := List(attrs,
                  x -> STRINGIFY(String(x, -len), ": ",
                                 ValueGlobal(x)(obj)));
    Append(res, JoinStringsWithSeparator(attrs, "\n"));
    return res;
end);

BindGlobal("JUPYTER_FindHelp",
function(ident)
    local s, matches, match, book, data, data1, lines, info;

    s := SIMPLE_STRING(ident);
    matches := HELP_GET_MATCHES(HELP_KNOWN_BOOKS[1], s, true);
    if matches[1] <> [] then
        match := matches[1][1];
    elif matches[2] <> [] then
        match := matches[2][1];
    else
        return "Undocumented";
    fi;
    book := match[1];
    info := HELP_BOOK_INFO(match[1]);

    data := HELP_BOOK_HANDLER.GapDocGAP.HelpData(info, match[2], "text");
    data1 := HELP_BOOK_HANDLER.GapDocGAP.HelpData(info, match[2] + 1, "text");

    if IsString(data.lines) then
        lines := SplitString(data.lines, "\n");
    else
        lines := data.lines;
    fi;
    return JoinStringsWithSeparator(lines{[data.start..data1.start-1]}, "\n");
end);

InstallGlobalFunction(JUPYTER_Inspect,
function(str, pos)
    local cpos, ipos, ident, ws, sep, fapp, result, found,
          var, textplain, texthtml;

    found := false;
    textplain := "";
    texthtml := "";

    # extract keyword/identifier
    # go to the left of pos
    # TODO: This should really use a GAP Parser or the
    #       SYNTAX_TREE module; SYNTAX_TREE doesn't have position
    #       information
    # Once we can parse code partially, we could even try to evaluate
    # subexpressions for help tips?

    # ( is not a separator, because we use it to
    # detect function application
    sep := [") \t\n\r;:=<>=!."];

    cpos := Minimum(pos, Length(str));
    ipos := 1;
    fapp := false;
    ident := [];

    # skip whitespace
    while cpos > 0 and (str[cpos] in " \t") do cpos := cpos - 1; od;
    while cpos > 0 and (not str[cpos] in sep) do
        if str[cpos] = '(' then
            fapp := true;
        else
            ident[ipos] := str[cpos];
            ipos := ipos + 1;
        fi;
        cpos := cpos - 1;
    od;
    ident := Reversed(ident);

    if ident <> "" then
        found := true;
        if fapp then
            # find documentation for function application
            textplain := JUPYTER_FindHelp(ident{[1..Length(ident)-1]});
        elif IsBoundGlobal(ident) then
            var := ValueGlobal(ident);
            if IsFunction(var) then
                # try finding doc?
                textplain := JUPYTER_FindHelp(ident);
            elif
                IsObject(var) then
                # Display Known Properties/Attributes/Categories/Types
                textplain := JUPYTER_FormatKnown(var);
            fi;
        fi;
    fi;
    return rec( status := "ok",
                found := found,
                data := rec( text\/html := texthtml,
                             text\/plain := textplain,
                             metadata := rec( text\/html := "",
                                              text\/plain := "" ) ) );
end);
