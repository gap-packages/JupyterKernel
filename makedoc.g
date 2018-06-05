#
# JupyterKernel: Jupyter kernel using ZeroMQ
#
# This file is a script which compiles the package manual.
#
if fail = LoadPackage("AutoDoc", ">= 2014.03.27") then
    Error("AutoDoc version 2014.03.27 is required.");
fi;

AutoDoc( rec( autodoc := true
            , scaffold := rec( includes := [ "intro.xml " ]
                             , entities := rec( Jupyter := "<URL Text=\"Jupyter\">https://jupyter.org</URL>"
                                              , ZeroMQ := "<URL Text=\"ZeroMQ\">https://zeromq.org</URL>"
                                              , uuid := "<Package>uuid</Package>"
                                              , crypting := "<Package>crypting</Package>"
                                              , json := "<Package>json</Package>"
                                              , IO := "<Package>IO</Package>"
                                              , ZeroMQInterface := "<Package>ZeroMQInterface</Package>"
                                              ) ) ) );
QUIT;
