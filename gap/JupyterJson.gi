InstallMethod(ToJsonStream, "for a record",
[IsOutputTextStream, IsRecord],
function(os, r)
    local i, k, l, AppendComponent;
    AppendComponent := function(k, v)
        WriteAll(os, STRINGIFY("\"", k, "\" : "));
        ToJsonStream(os, v);
    end;

    WriteAll(os, "{");
    k := NamesOfComponents(r);
    for i in [1..Length(k)-1] do
        AppendComponent(k[i], r.(k[i]));
        WriteAll(os, ",");
    od;
    if Length(k) > 0 then
        AppendComponent(k[Length(k)], r.(k[Length(k)]));
    fi;
    WriteAll(os, "}");
end);

InstallMethod(ToJsonStream, "for a string",
[IsOutputTextStream, IsString],
function(os, s)
    local ch, byte;

    WriteByte(os, INT_CHAR('"'));
    for ch in s do
        byte := INT_CHAR(ch);
        if byte > 3 then
            if byte in [ 92, 34 ] then
                WriteByte(os, 92);
                WriteByte(os, byte);
            elif byte = 10 then # \n
                WriteByte(os, 92);
                WriteByte(os, 110); # n
            elif byte = 13 then
                WriteByte(os, 92); # \r
                WriteByte(os, 114); # r
            else;
                WriteByte(os, byte);
            fi;
        fi;
    od;
    WriteByte(os, INT_CHAR('"'));
end);

InstallMethod(ToJsonStream, "for a list",
[IsOutputTextStream, IsList],
function(os, l)
    local i;
    AppendTo(os, "[");
    if Length(l) > 0 then
        for i in [1..Length(l)-1] do
            ToJsonStream(os, l[i]);
            AppendTo(os, ",");
        od;
        ToJsonStream(os, l[Length(l)]);
    fi;
    AppendTo(os, "]");
end);

InstallMethod(ToJsonStream, "for an integer",
[IsOutputTextStream, IsInt],
function(os, i)
   AppendTo(os, String(i));
end);

InstallMethod(ToJsonStream, "for a bool",
[IsOutputTextStream, IsBool],
function(os, b)
   WriteAll(os, ViewString(b));
end);
