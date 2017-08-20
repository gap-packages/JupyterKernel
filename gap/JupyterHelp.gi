# Load some help stuff (Experimental)
_JUPYTER_FindManSection := function(file, name)
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
end;
