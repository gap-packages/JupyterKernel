# This is still an ugly hack, but its already much better than before!
InstallGlobalFunction("JupyterSplashDot",
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

    fd := IO_Popen(IO_FindExecutable("dot"), ["-Nfontname=\"Arial\"","-Tsvg", fn], "r");
    r := IO_ReadUntilEOF(fd);
    IO_close(fd);
    IO_unlink(fn);

    return JupyterRenderable( rec( ("image/svg+xml") := r )
                            , rec( ("image/svg+xml") := rec( width := 500, height := 500 ) ) ) ;

end);

# To show TikZ in a GAP jupyter notebook
InstallGlobalFunction("JupyterSplashTikZ",
function(tikz)
    local tmpdir, fn, header, ltx, pngfile, stream, pngdata, tojupyter, hasbp, img, b64file, b64cmd, dims, dimsfile, pdffile, dimx;

    hasbp:=PositionSublist(tikz,"begin[border=2pt]{tikzpicture}")<>fail;

    header:=Concatenation( "\\documentclass[crop,tikz,border=2pt]{standalone}\n",
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

    pdffile:=Concatenation(fn, ".pdf");
    if not( IsExistingFile( pdffile ) ) then
        tojupyter := rec( json := true, name := "stdout",
                          data := "No pdf was created; pdflatex is installed in your system?",metadata:=rec() );
        Info(InfoWarning,1,"No pdf was created; pdflatex is installed in your system?");
        return JupyterRenderable(tojupyter.data, tojupyter.metadata);
    fi;

    dimsfile:=Concatenation(fn, "-dims.txt");
    ltx:=Concatenation("pdfinfo ",pdffile," | grep \"Page size\" > ",dimsfile);
    Exec(ltx);
    if not( IsExistingFile( dimsfile ) ) then
        tojupyter := rec( json := true, name := "stdout",
                          data := "pdfinfo missing in your system",metadata:=rec() );
        Info(InfoWarning,1,"No pdf was created; pdflatex is installed in your system?");
        return JupyterRenderable(tojupyter.data, tojupyter.metadata);
    fi;

    stream := InputTextFile( dimsfile );
    dims:= ReadAll( stream );
    NormalizeWhitespace(dims);
    CloseStream( stream );
    dimx:=Float(NormalizedWhitespace(dims{[PositionSublist(dims,": ")+2..PositionSublist(dims," x")]}));

    pngfile := Concatenation( fn, ".png" );
    ltx := Concatenation( "pdftoppm -r 300 -png ", pdffile, " > ", pngfile);
    Exec( ltx );
    
    if not( IsExistingFile( pngfile ) ) then
        tojupyter := rec( json := true, name := "stdout",
                          data := "No png was created; pdftoppm is installed in your system?",metadata:=rec() );
        Info(InfoWarning,1,"No png was created; are convert and pdftoppm installed in your system?");
        return JupyterRenderable(tojupyter.data, tojupyter.metadata);
    fi;

    b64file := Concatenation( fn, ".b64" );
    if ARCH_IS_MAC_OS_X() then 
        b64cmd:="base64 -i ";
    else 
        b64cmd:="base64 ";
    fi;
    
    ltx := Concatenation( b64cmd, pngfile," > ", b64file );
    Exec( ltx );
    stream := InputTextFile( b64file );
    pngdata:= ReadAll( stream );
    CloseStream( stream );


    img:=Concatenation("\n <img src='data:image/png;base64,",pngdata,"' style=\"width:",String(dimx),"px;\" >");

    return Objectify( JupyterRenderableType, rec(  data := rec( ("text/html") := img), metadata:=rec( ) ));
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
