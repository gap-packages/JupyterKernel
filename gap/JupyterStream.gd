DeclareRepresentation( "IsOutputStreamZmqRep",
                       IsComponentObjectRep,
                       ["kernel", "socket", "format", "streamname", "buffer",
                        "credit", "lastcheck"] );

DeclareOperation( "OutputStreamZmq", [IsObject, IsZmqSocket]);
DeclareOperation( "OutputStreamZmq", [IsObject, IsZmqSocket, IsString]);

DeclareOperation( "FlushOutputStream", [IsOutputStreamZmqRep] );
