#
gap> JUPYTER_Complete("Gro", 3);;

#
gap> JUPYTER_Inspect("Gro", 3);
rec( 
  data := rec( metadata := rec( ("text/html") := "", ("text/plain") := "" ), 
      ("text/html") := "", ("text/plain") := "" ), found := true, 
  status := "ok" )

#
gap> G := Group((1,2,3));;
gap> JUPYTER_Inspect("G", 1);;

#
