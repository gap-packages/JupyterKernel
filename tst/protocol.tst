#
gap> conf := rec( transport := "tcp", ip := "127.0.0.1", key := "super_key", hb_port := "5555", control_port := "1111", iopub_port := "2222", shell_port := "3333", stdin_port := "4444" );;
gap> kernel := NewJupyterKernel(conf);;
gap> kernel!.ProtocolVersion = "5.3";
true
gap> msg := rec( header := rec( session := "some session" ), content := rec( code := "true = true" ) );;
gap> kernel!.MsgHandlers!.kernel_info_request( rec( header := rec( session := "some session" ) ) );;
