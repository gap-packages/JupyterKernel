# Load some help stuff (Experimental)
_JUPYTER_HelpXML := ParseTreeXMLFile("/home/makx/ac/jupyter-gap/jupyter_kernel_gap/gap/help.xml");;
CheckAndCleanGapDocTree(_JUPYTER_HelpXML);;
_JUPYTER_ManSections := XMLElements(_JUPYTER_HelpXML, "ManSection");;
_JUPYTER_FindManSection := function(name)
    local p, s, res;
    res := [];
    for s in _JUPYTER_ManSections do
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
