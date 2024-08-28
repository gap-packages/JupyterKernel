InstallMethod( JupyterRender, [ IsRecord ],
               r -> Objectify( JupyterRenderableType
                             , rec( data := rec( text\/plain := String(r) )
                                   , metadata := rec() ) ) );

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
    local tmpdir, fn, header, ltx, svgfile, stream, svgdata, tojupyter, b64file, hasbp, img;

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
                          data := "No pdf was created; pdflatex is installed in your system?" );
    else
        svgfile := Concatenation( fn, ".svg" );
        b64file := Concatenation( fn, ".b64" );
        ltx := Concatenation( "pdf2svg ", Concatenation( fn, ".pdf" ), " ",
                       svgfile, "; base64 -i ", svgfile," >> ", b64file );
        Exec( ltx );
        if not( IsExistingFile( svgfile ) ) then
            tojupyter := rec( json := true, name := "stdout",
                              data := "No svg was created; pdf2svg is installed in your system?", metadata := rec());
            return JupyterRenderable(tojupyter.data, tojupyter.metadata);
        elif not( IsExistingFile( b64file ) ) then
            tojupyter := rec( json := true, name := "stdout",
                              data := "No svg was created; base64 is installed in your system?", metadata := rec());
            return JupyterRenderable(tojupyter.data, tojupyter.metadata);
        else
            stream := InputTextFile( b64file );
            if stream <> fail then
                svgdata := ReadLine( stream );
                CloseStream( stream );
            else
                tojupyter := rec( json := true, name := "stdout",
                                  data := Concatenation( "Unable to render ", tikz ), metadata := rec() );
                return JupyterRenderable(tojupyter.data, tojupyter.metadata);
            fi;
        fi;
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
                      , pad(tz.tv_usec, 6, '0') );
end);
