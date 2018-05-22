#
# This is a humongously bad hack to display error messages
#

GAP_ERROR_STREAM := "*errout*";

MakeReadWriteGlobal("ErrorInner");
Unbind(ErrorInner);

BIND_GLOBAL("ErrorInner",
        function( arg )
    local   context, mayReturnVoid,  mayReturnObj,  lateMessage,  earlyMessage,
            x,  prompt,  res, errorLVars, justQuit, printThisStatement,
            location;

        context := arg[1].context;
    if not IsLVarsBag(context) then
        PrintTo(GAP_ERROR_STREAM, "ErrorInner:   option context must be a local variables bag\n");
        LEAVE_ALL_NAMESPACES();
        JUMP_TO_CATCH(1);
    fi;

    if IsBound(arg[1].justQuit) then
        justQuit := arg[1].justQuit;
        if not justQuit in [false, true] then
            PrintTo(GAP_ERROR_STREAM, "ErrorInner: option justQuit must be true or false\n");
            LEAVE_ALL_NAMESPACES();
            JUMP_TO_CATCH(1);
        fi;
    else
        justQuit := false;
    fi;

    if IsBound(arg[1].mayReturnVoid) then
        mayReturnVoid := arg[1].mayReturnVoid;
        if not mayReturnVoid in [false, true] then
            PrintTo(GAP_ERROR_STREAM, "ErrorInner: option mayReturnVoid must be true or false\n");
            LEAVE_ALL_NAMESPACES();
            JUMP_TO_CATCH(1);
        fi;
    else
        mayReturnVoid := false;
    fi;

    if IsBound(arg[1].mayReturnObj) then
        mayReturnObj := arg[1].mayReturnObj;
        if not mayReturnObj in [false, true] then
            PrintTo(GAP_ERROR_STREAM, "ErrorInner: option mayReturnObj must be true or false\n");
            LEAVE_ALL_NAMESPACES();
            JUMP_TO_CATCH(1);
        fi;
    else
        mayReturnObj := false;
    fi;

    if IsBound(arg[1].printThisStatement) then
        printThisStatement := arg[1].printThisStatement;
        if not printThisStatement in [false, true] then
            PrintTo(GAP_ERROR_STREAM, "ErrorInner: option printThisStatement must be true or false\n");
            LEAVE_ALL_NAMESPACES();
            JUMP_TO_CATCH(1);
        fi;
    else
        printThisStatement := true;
    fi;

    if IsBound(arg[1].lateMessage) then
        lateMessage := arg[1].lateMessage;
        if not lateMessage in [false, true] and not IsString(lateMessage) then
            PrintTo(GAP_ERROR_STREAM, "ErrorInner: option lateMessage must be a string or false\n");
            LEAVE_ALL_NAMESPACES();
            JUMP_TO_CATCH(1);
        fi;
    else
        lateMessage := "";
    fi;
    
       earlyMessage := arg[2];
    if Length(arg) <> 2 then
        PrintTo(GAP_ERROR_STREAM,"ErrorInner: new format takes exactly two arguments\n");
        LEAVE_ALL_NAMESPACES();
        JUMP_TO_CATCH(1);
    fi;
        
    ErrorLevel := ErrorLevel+1;
    ERROR_COUNT := ERROR_COUNT+1;
    errorLVars := ErrorLVars;
    ErrorLVars := context;
    if QUITTING or not BreakOnError then
        PrintTo(GAP_ERROR_STREAM,"Error, ");
        for x in earlyMessage do
            PrintTo(GAP_ERROR_STREAM,x);
        od;
        PrintTo(GAP_ERROR_STREAM,"\n");
        ErrorLevel := ErrorLevel-1;
        ErrorLVars := errorLVars;
        if ErrorLevel = 0 then LEAVE_ALL_NAMESPACES(); fi;
        JUMP_TO_CATCH(0);
    fi;
    PrintTo(GAP_ERROR_STREAM,"Error, ");
    for x in earlyMessage do
        PrintTo(GAP_ERROR_STREAM,x);
    od;
    if printThisStatement then 
        if context <> GetBottomLVars() then
            PrintTo(GAP_ERROR_STREAM," in\n  \c");
            PRINT_CURRENT_STATEMENT(context);
            Print("\c");
            PrintTo(GAP_ERROR_STREAM," called from \n");
        else
            PrintTo(GAP_ERROR_STREAM,"\c\n");
        fi;
    else
        location := CURRENT_STATEMENT_LOCATION(context);
        if location <> fail then          PrintTo(GAP_ERROR_STREAM, " at ", location[1], ":", location[2]);
        fi;
        PrintTo(GAP_ERROR_STREAM," called from\c\n");
    fi;

    if SHOULD_QUIT_ON_BREAK() then
        FORCE_QUIT_GAP(1);
    fi;

    if IsBound(OnBreak) and IsFunction(OnBreak) then
        OnBreak();
    fi;
    if IsString(lateMessage) then
        PrintTo(GAP_ERROR_STREAM,lateMessage,"\n");
    elif lateMessage then
        if IsBound(OnBreakMessage) and IsFunction(OnBreakMessage) then
            OnBreakMessage();
        fi;
    fi;
    if ErrorLevel > 1 then
        prompt := Concatenation("brk_",String(ErrorLevel),"> ");
    else
        prompt := "brk> ";
    fi;
    if not justQuit then
        res := SHELL(context,mayReturnVoid,mayReturnObj,3,false,prompt,false,"*errin*",GAP_ERROR_STREAM,false);
    else
        res := fail;
    fi;
    ErrorLevel := ErrorLevel-1;
    ErrorLVars := errorLVars;
    if res = fail then
        if IsBound(OnQuit) and IsFunction(OnQuit) then
            OnQuit();
        fi;
        if ErrorLevel = 0 then LEAVE_ALL_NAMESPACES(); fi;
        if not justQuit then
           # dont try and do anything else after this before the longjump       
            SetUserHasQuit(1);  
        fi;
        JUMP_TO_CATCH(3);
    fi;
    if Length(res) > 0 then
        return res[1];
    else
        return;
    fi;
end);
