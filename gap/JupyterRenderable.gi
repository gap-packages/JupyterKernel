
InstallMethod( JupyterRender, "default fallback"
             , [ IsObject ],
function(obj)
    local str;
    str := ViewString(obj);
    RemoveCharacters(str, "\<\>\n");
    return Objectify( JupyterRenderableType
                    , rec( data := rec( text\/plain := str )
                         , metadata := rec( text\/plain := "") ) );
end);

InstallMethod( JupyterRenderableData, "for a JupyterRenderable"
               , [  IsJupyterRenderableRep ]
               , x -> x!.data );

InstallMethod( JupyterRenderableMetadata, "for a JupyterRenderable"
               , [  IsJupyterRenderableRep ]
               , x -> x!.metadata );

InstallMethod( ViewString, "for a JupyterRenderable"
             , [  IsJupyterRenderableRep ]
             , x -> "<jupyter renderable>" );

