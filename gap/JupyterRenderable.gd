#! @Chapter Jupyter Renderables
#!
#! A <C>JupyterRenderable</C> is an object that can be rendered
#! by Jupyter.
#! JupyterRenderables are component object that have to contain
#! at least the components <C>data</C> and <C>metadata</C>.
#!
#! These components are themselves GAP records which can contain
#! different representations of an object to be rendered. The
#! record component name is the MIME-Type of the representation
#! and the content is the representation itself.
#!
#! @BeginExample
#! render := JupyterRenderable(
#!       rec( text\/plain := "Integers",
#!            text\/html := "$\mathbb{Z}$" )
#!     , rec( ) );
#!
#! render2 := JupyterRenderable(
#!       rec( ("image/svg+xml") := "<svg></svg>" 
#!     , rec( ("image/svg+xml") := rec( width := 500, height := 500 ) ) );
#! @EndExample
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
#!   Basic constructor for JupyterRenderable
#! @Arguments data, metadata
#! @Returns A new JupyterRenderable
DeclareOperation("JupyterRenderable", [IsObject, IsObject] );

#! @Description
#!   Method that provides rich viewing experience if
#!   code used inside Jupyter
DeclareOperation("JupyterRender", [IsObject]);

#! @Description
#!   Accessor for data in a JupyterRenderable
DeclareAttribute("JupyterRenderableData", IsJupyterRenderable);
#! @Description
#!   Accessor for metadata in a JupyterRenderable
DeclareAttribute("JupyterRenderableMetadata", IsJupyterRenderable);



