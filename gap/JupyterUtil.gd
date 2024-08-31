#! @Chapter Jupyter Utility Functions
#! @Section Functions
#! @Description
#!   Jupyter printing
DeclareGlobalFunction("JUPYTER_print");

#! @Description
#!   This function is called when the user presses Tab in a code
#!   cell and produces a list of possible completions. It is passed the
#!   current code in the cell, and the curser position inside the code.
#!
DeclareGlobalFunction("JUPYTER_Complete");

#! @Description
#!   This function is called when the user presses Shift-Tab in a code
#!   cell. It tries to extract some documentation to display for brief
#!   inspection, and the full documentation for full inspection.
#!
#!   If it detects an object under the cursor it returns a list of
#!   known filters and attributes of that object. 

DeclareGlobalFunction("JUPYTER_Inspect");

#! @Section Additional Utility Functions
#!
#! @Description
#!   Current date and time as ISO8601 timestamp.
#!   Don't trust this function.
DeclareGlobalFunction("ISO8601Stamp");

#! @Description
#! @Arguments dot
#! The input is a dot (grpahviz) string. 
#!
#! The output is the graph corresponding to the dot string.
#!
#! Examples can be found in the numericalsgps notebook in the demo folder
#!
#! Prerrequisites: dot must be installed in the system.
DeclareGlobalFunction("JupyterSplashDot");

#! @Description
#! @Arguments tikz
#! The input is a string containing a tikzfigure. 
#!
#! The output is the figure corresponding to that tikzfigure.
#! 
#! Examples can be found in the inpic notebook in the demo folder
#!
#! Prerrequisites: pdflatex, pdfinfo, pdftoppm, and base64 must be installed in the system.
DeclareGlobalFunction("JupyterSplashTikZ");
