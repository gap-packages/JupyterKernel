# Notebook help uses GAP's own topic matching and navigation.
InstallGlobalFunction(JUPYTER_Pager, function(data)
    local lines, start;
    start := 1;
    if IsRecord(data) then
        if IsBound(data.start) then start := data.start; fi;
        lines := data.lines;
    else
        lines := data;
    fi;
    if IsString(lines) then lines := SplitString(lines, "\n"); fi;
    if IsString(start) then
        start := PositionProperty(lines, line -> PositionSublist(line, start) <> fail);
        if start = fail then start := 1; fi;
    fi;
    Print("\c");
    FlushOutputStream(_KERNEL!.StdOut);
    if start <= Length(lines) then
        WriteAll(_KERNEL!.StdOut,
            Concatenation(JoinStringsWithSeparator(lines{[start..Length(lines)]}, "\n"), "\n"));
        FlushOutputStream(_KERNEL!.StdOut);
    fi;
end);

BindGlobal("JUPYTER_HelpViewer", function(prefix)
    local render;
    render := function(url)
        local root, html;
        for root in GAPInfo.RootPaths do
            url := ReplacedString(url, root, prefix);
        od;
        html := ReplacedString(url, "&", "&amp;");
        html := ReplacedString(html, "<", "&lt;");
        html := ReplacedString(html, ">", "&gt;");
        html := ReplacedString(html, "\"", "&quot;");
        return JupyterRenderable(rec(("text/plain") := url,
            ("text/html") := Concatenation("<a target=\"_blank\" href=\"", html,
                "\">Open GAP help</a>")), rec());
    end;
    return rec(type := "url", render := render, show := function(url)
        local result;
        result := render(url);
        if IsGAPJupyterKernel(_KERNEL) and IsBound(_KERNEL!.IOPub) then
            Print("\c");
            FlushOutputStream(_KERNEL!.StdOut);
            if not _KERNEL!.Silent then
                JupyterMsgSend(_KERNEL, _KERNEL!.IOPub,
                    JupyterMsg(_KERNEL, "display_data", _KERNEL!.CurrentMsg,
                        rec(data := JupyterRenderableData(result), metadata := rec()), rec()));
            fi;
        else
            Print(url, "\n");
        fi;
        return result;
    end);
end);

HELP_VIEWER_INFO.jupyter_online := JUPYTER_HelpViewer("https://docs.gap-system.org/");
HELP_VIEWER_INFO.jupyter_local := JUPYTER_HelpViewer("/files/");
HELP_VIEWER_INFO.jupyter_text := rec(type := "text", show := JUPYTER_Pager);

InstallGlobalFunction(JUPYTER_HELP, function(topic)
    HELP(topic);
    return fail;
end);

# Load some help stuff (Experimental)
InstallGlobalFunction(JUPYTER_FindManSection,
function(file, name)
    local xml, sections, p, s, res;
    xml := ParseTreeXMLFile(file);
    CheckAndCleanGapDocTree(xml);
    sections := XMLElements(xml, "ManSection");;
    res := [];
    for s in sections do
        if IsBound(s.content) then
            p := PositionProperty(s.content, x ->
                                               IsBound(x.attributes) and
                                             IsBound(x.attributes.Name) and
                                             x.attributes.Name = name);
            if p <> fail then
                Add(res, s);
            fi;
        fi;
    od;
    return res;
end);
