# Diagnostic trace state. Off by default; turn on from a notebook cell
# via `JUPYTER_TRACE.enabled := true;` (or redirect with `.file`) when
# investigating a kernel-side issue. We deliberately do NOT use GAP's
# `Info` here: the trace fires inside C-level ZMQ callbacks where Info
# classes / the break loop interact poorly, and we want a deterministic
# file-side audit log when the kernel crashes.
JUPYTER_TRACE := rec( enabled := false,
                      file    := "/tmp/gap-kernel-trace.log" );

InstallGlobalFunction( JupyterLog,
function(arg)
    if JUPYTER_TRACE.enabled then
        CallFuncList(AppendTo, Concatenation([JUPYTER_TRACE.file], arg));
    fi;
end);

InstallMethod( JupyterRender, [ IsRecord ],
               r -> Objectify( JupyterRenderableType
                             , rec( data := rec( text\/plain := String(r) )
                                   , metadata := rec() ) ) );

# Extract the identifier ending at (or just before) cursor_pos. Returns a
# record { ident, startpos, endpos, fapp }: ident is the identifier as a string
# (possibly empty), start/end are 0-based [start, end) cursor positions
# (matching the Jupyter complete protocol), fapp is true if the cursor sat
# directly on `(` after an identifier — a hint that the user wants help on
# the function being applied. Shared between JUPYTER_Complete and
# JUPYTER_Inspect.
BindGlobal("JUPYTER_ExtractIdentifier",
function(code, cursor_pos)
    local n, i, j, c, fapp, ident;

    n := Length(code);
    i := Minimum(cursor_pos, n);
    fapp := false;

    # If the cursor is sitting on an opening paren, treat the preceding
    # identifier as a function application.
    if i > 0 and i <= n and code[i] = '(' then
        fapp := true;
        i := i - 1;
    fi;

    # Skip back through trailing whitespace (rare from notebook clients).
    while i > 0 and (code[i] = ' ' or code[i] = '\t') do i := i - 1; od;

    j := i;
    while j > 0 do
        c := code[j];
        if not ((c >= 'a' and c <= 'z')
                or (c >= 'A' and c <= 'Z')
                or (c >= '0' and c <= '9')
                or c = '_') then
            break;
        fi;
        j := j - 1;
    od;

    if j = i then
        ident := "";
    else
        ident := code{[j+1..i]};
    fi;

    return rec( ident := ident, startpos := j, endpos := i, fapp := fapp );
end);

# This is still an ugly hack, but its already much better than before!
BindGlobal("JupyterSplashDot",
function(dot)
    local fn, fd, r;

    fn := TmpName();
    fd := IO_File(fn, "w");
    IO_Write(fd, dot);
    IO_Close(fd);

    fd := IO_Popen(IO_FindExecutable("dot"), ["-Tsvg", fn], "r");
    r := IO_ReadUntilEOF(fd);
    IO_close(fd);
    IO_unlink(fn);

    return JupyterRenderable( rec( ("image/svg+xml") := r )
                            , rec( ("image/svg+xml") := rec( width := 500, height := 500 ) ) );
end);

# Splash the subgroup lattice of a group
BindGlobal("JupyterSplashSubgroupLattice",
function(group)
    local fn, fd, r, L, dot;

    fn := TmpName();

    L := LatticeSubgroups(group);
    DotFileLatticeSubgroups(L, fn);

    fd := IO_Popen(IO_FindExecutable("dot"), ["-Tsvg", fn], "r");
    r := IO_ReadUntilEOF(fd);
    IO_close(fd);
    IO_unlink(fn);

    return JupyterRenderable( rec( ("image/svg+xml") := r )
                            , rec( ("image/svg+xml") := rec( width := 500, height := 500 ) ) ) ;

end);

# To show TikZ in a GAP jupyter notebook
BindGlobal("JupyterSplashTikZ",
function(tikz)
    local tmpdir, fn, header, ltx, svgfile, stream, svgdata, tojupyter, hasbp, img, b64file;

    hasbp:=PositionSublist(tikz,"begin{tikzpicture}")<>fail;

    header:=Concatenation( "\\documentclass[crop,tikz]{standalone}\n",
                    "\\usepackage{pgfplots}",
                    "\\makeatletter\n",
                    "\\batchmode\n",
                    "\\nonstopmode\n",
                    "\\begin{document}\n");
    if not(hasbp) then 
        Concatenation(header, "\\begin{tikzpicture}\n");
    fi;
    header:=Concatenation(header, tikz);
    if hasbp then 
        header:=Concatenation(header,"\\end{document}");    
    else
        header:=Concatenation(header,"\\end{tikzpicture}\n\\end{document}");
    fi;

    tmpdir := DirectoryTemporary();
    fn := Filename( tmpdir, "svg_get" );

    PrintTo( Concatenation( fn, ".tex" ), header );

    ltx := Concatenation( "pdflatex -shell-escape --output-directory ",
                   Filename( tmpdir, "" ), " ",
                   Concatenation( fn, ".tex" ), " > ", Concatenation( fn, ".log2" ) );
    Exec( ltx );

    if not( IsExistingFile( Concatenation(fn, ".pdf") ) ) then
        tojupyter := rec( json := true, name := "stdout",
                          data := "No pdf was created; pdflatex is installed in your system?",metadata:=rec() );
        return JupyterRenderable(tojupyter.data, tojupyter.metadata);
    fi;

    svgfile := Concatenation( fn, ".svg" );
    b64file := Concatenation( fn, ".b64" );
    if ARCH_IS_MAC_OS_X() then 
        ltx := Concatenation( "pdf2svg ", Concatenation( fn, ".pdf" ), " ",
                    svgfile, "; base64 -i ", svgfile," >> ", b64file );

    else 
        ltx := Concatenation( "pdf2svg ", Concatenation( fn, ".pdf" ), " ",
                    svgfile, "; base64 ", svgfile," >> ", b64file );
    fi;
    Exec( ltx );
    if not( IsExistingFile( svgfile ) ) then
        tojupyter := rec( json := true, name := "stdout",
                            data := "No svg was created; pdf2svg is installed in your system?", metadata := rec());
        return JupyterRenderable(tojupyter.data, tojupyter.metadata);
    fi;
    stream := InputTextFile( b64file );
    if stream <> fail then
        svgdata := ReadAll( stream );
        CloseStream( stream );
    else
        tojupyter := rec( json := true, name := "stdout",
                            data := Concatenation( "Unable to render ", tikz ), metadata := rec() );
        return JupyterRenderable(tojupyter.data, tojupyter.metadata);
    fi;

    img:=Concatenation("<img src='data:image/svg+xml;base64,", svgdata,"'>");
    return Objectify( JupyterRenderableType, rec(  data := rec( ("text/html") := img), metadata:=rec() ));
end);

# This is really not what I should be doing here...
InstallGlobalFunction(ISO8601Stamp,
function()
    local tz, gm, pad;

    tz := IO_gettimeofday();
    pad := function(i, l, c)
        local s;
        s := String(i);
        if Length(s) < l then
            return Concatenation(RepeatedString(c, l - Length(s)), s);
        else
            return s;
        fi;
    end;

    gm := IO_gmtime(tz.tv_sec);
    return STRINGIFY( 1900 + gm.tm_year, "-"
                      , pad(gm.tm_mon + 1, 2, '0'), "-"
                      , pad(gm.tm_mday, 2, '0'), "T"
                      , pad(gm.tm_hour, 2, '0'), ":"
                      , pad(gm.tm_min, 2, '0'), ":"
                      , pad(gm.tm_sec, 2, '0'), "."
                      , pad(tz.tv_usec, 6, '0'), "Z" );
end);
