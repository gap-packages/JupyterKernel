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
#!   Diagnostic trace of the messages the kernel receives and sends.
#!   When <C>JUPYTER_TRACE.enabled</C> is <K>true</K>, appends its
#!   arguments to the file <C>JUPYTER_TRACE.file</C>, which must be set
#!   first. Arguments are evaluated even when tracing is off, so callers
#!   should pass only cheap ones.
DeclareGlobalFunction("JupyterLog");

#! @Description
#!   Writes the concatenation of its arguments, followed by a newline, to
#!   the standard error of the kernel process, which Jupyter shows in the
#!   server's terminal. Unlike <C>ERROR_OUTPUT</C> and <C>*errout*</C>,
#!   this output does not reach the notebook.
DeclareGlobalFunction("JupyterServerLog");

