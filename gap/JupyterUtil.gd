

#! @Description
#!   Method that provides rich viewing experience if
#!   code used inside Jupyter
DeclareOperation("JUPYTER_ViewString", [IsObject]);

#! @Description
#!   Jupyter printing
DeclareGlobalFunction("JUPYTER_print");

#! @Description
#!   Jupyter completion
DeclareGlobalFunction("JUPYTER_Complete");

#! @Description
#!   Jupyter inspection
DeclareGlobalFunction("JUPYTER_Inspect");

#! @Description
#!   Current date and time as ISO8601 timestamp
#!   Don't trust this function
DeclareGlobalFunction("ISO8601Stamp");

