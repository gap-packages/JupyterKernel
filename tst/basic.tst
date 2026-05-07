# Basic smoke checks for the user-callable JUPYTER_Complete and
# JUPYTER_Inspect entry points. Protocol-level / handler tests are in
# protocol.tst; encoder tests in msg.tst; stream tests in stream.tst.

gap> START_TEST("JupyterKernel: basic.tst");
gap> JUPYTER_ExtractIdentifier("Gro", 3).ident;
"Gro"
gap> JUPYTER_ExtractIdentifier("Group(", 6).ident;
"Group"
gap> JUPYTER_ExtractIdentifier("Group(", 6).fapp;
true
gap> JUPYTER_ExtractIdentifier("x.Foo", 5).ident;
"Foo"
gap> JUPYTER_ExtractIdentifier("", 0).ident;
""
gap> result := JUPYTER_Complete("Gro", 3);;
gap> result.status;
"ok"
gap> "Group" in result.matches;
true
gap> result.cursor_start;
0
gap> result.cursor_end;
3
gap> ins := JUPYTER_Inspect("Gro", 3);;
gap> ins.status;
"ok"
gap> ins.found;
true
gap> G := Group((1,2,3));;
gap> ins2 := JUPYTER_Inspect("G", 1);;
gap> ins2.status;
"ok"
gap> STOP_TEST("basic.tst", 1);
