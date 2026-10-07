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
false
gap> JUPYTER_Inspect("DefinitelyNoSuchGlobal", 22).found;
false
gap> G := Group((1,2,3));;
gap> ins2 := JUPYTER_Inspect("G", 1);;
gap> ins2.status;
"ok"

# Code point <-> UTF-8 byte offsets: alpha is 2 bytes, U+1F600 is 4.
gap> code := "\316\261x\360\237\230\200y";;
gap> List([0 .. 5], cp -> JUPYTER_ByteOffset(code, cp));
[ 0, 2, 3, 7, 8, 8 ]
gap> List([0, 2, 3, 7, 8], b -> JUPYTER_CodePointOffset(code, b));
[ 0, 1, 2, 3, 4 ]

# Inspection values are cut to one line of JUPYTER_INSPECT_WIDTH bytes,
# never inside a UTF-8 character.
gap> v := JUPYTER_InspectValue(List([1 .. 1000], i -> i^2));;
gap> Length(v) = JUPYTER_INSPECT_WIDTH and EndsWith(v, "...");
true
gap> IsUTF8ViewTest := NewFilter("IsUTF8ViewTest");;
gap> InstallMethod(ViewString, [IsUTF8ViewTest],
>        o -> Concatenation(ListWithIdenticalEntries(80, "\316\261")));
gap> v := JUPYTER_InspectValue(Objectify(NewType(NewFamily("UTF8ViewTest"),
>             IsUTF8ViewTest and IsComponentObjectRep), rec()));;
gap> v{[Length(v) - 4 .. Length(v)]} = "\316\261..." and Length(v) <= JUPYTER_INSPECT_WIDTH;
true
gap> STOP_TEST("basic.tst", 1);
