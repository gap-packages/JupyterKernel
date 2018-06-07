# This function is used to overwrite GAP's behaviour when encountering
# a break loop.
JupyterOnBreak := function()
    # Print the traceback
    Where();
    # Skip the break loop
    ErrorLevel := ErrorLevel-1;
    ErrorLVars := errorLVars;
    if ErrorLevel = 0 then LEAVE_ALL_NAMESPACES(); fi;
    JUMP_TO_CATCH(0);
end;
