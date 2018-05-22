DeclareRepresentation( "IsOutputStreamZmqRep",
                       IsComponentObjectRep,
                       ["kernel", "socket", "format"] );

DeclareOperation( "OutputStreamZmq", [IsObject, IsZmqSocket]);
DeclareOperation( "OutputStreamZmq", [IsObject, IsZmqSocket, IsString]);

