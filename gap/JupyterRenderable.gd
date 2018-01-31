#! @Chapter Jupyter Renderables
#!
#! This chapter gives reference to JupterRenderables
#!
#! @Section Handlers for Jupyter requests
#! @Description
#!   JupyterRenderable
DeclareCategory("IsJupyterRenderable", IsObject);
DeclareRepresentation( "IsJupyterRenderableRep"
                     , IsComponentObjectRep and IsJupyterRenderable
                     , [ "data", "metadata" ] );
BindGlobal( "JupyterRenderableType"
          , NewType( NewFamily("JupyterRenderableFamily")
                   , IsJupyterRenderableRep) );

#! @Description
#!   Method that provides rich viewing experience if
#!   code used inside Jupyter
DeclareOperation("JupyterRender", [IsObject]);

#! @Description
#!   Accessor for data in a JupypterRenderable
DeclareAttribute("JupyterRenderableData", IsJupyterRenderable);
#! @Description
#!   Accessor for metadata in a JupypterRenderable
DeclareAttribute("JupyterRenderableMetadata", IsJupyterRenderable);



