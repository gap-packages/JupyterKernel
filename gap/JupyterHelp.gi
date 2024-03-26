# This is another ugly hack to make the GAP Help System
# play ball. Let us please fix this soon.
# TODO: This is now broken because we got rid of parsing
#       on the python side. HELP now should result
#       in a record that can be sent back to jupyter
#       as a JSON string
HELP_VIEWER_INFO.jupyter_online :=
    rec(
         type := "url",
         show := function( data )
             # data[1] is the text preceding the hyperlink (name of the help book),
             # data[2] is the text to be linked, and data[3] is the URL
             local p,r;

             p := data[3];

             for r in GAPInfo.RootPaths do
                 p := ReplacedString(data[3], r, "https://docs.gap-system.org/");
             od;
             return JupyterRenderable( rec( ("text/html") := Concatenation( data[1], ": <a target=\"_blank\" href=\"", p, "\">", data[2], "</a>") )
                                     , rec( ) );
         end
        );

HELP_VIEWER_INFO.jupyter_local :=
    rec( type := "url",
         show := function( data )
             # data[1] is the text preceding the hyperlink (name of the help book),
             # data[2] is the text to be linked, and data[3] is the URL
             local p,r;

             p := data[3];

             for r in GAPInfo.RootPaths do
                 p := ReplacedString(data[3], r, "/");
             od;
             return JupyterRenderable( rec( ("text/html") := Concatenation( data[1], ": <a target=\"_blank\" href=\"files", p, "\">", data[2], "</a>") )
                                     , rec( ) );
         end);

#############################################################################
##
#F  GET_HELP_URL( <match> ) . . . . . .  print the url for the help section
##
##  Based on HELP_PRINT_MATCH
##
##  <match> is [book, entrynr]
##
InstallGlobalFunction(GET_HELP_URL, function(match)
local book, entrynr, viewer, hv, pos, type, data;
  book := HELP_BOOK_INFO(match[1]);
  entrynr := match[2];
  viewer:= UserPreference("HelpViewers");
  if HELP_LAST.NEXT_VIEWER = false then
    hv := viewer;
  else
    pos := Position( viewer, HELP_LAST.VIEWER );
    if pos = fail then
      hv := viewer;
    else
      hv := viewer{Concatenation([pos+1..Length(viewer)],[1..pos])};
    fi;
    HELP_LAST.NEXT_VIEWER := false;
  fi;
  for viewer in hv do
    # type of data we need now depends on help viewer
    type := HELP_VIEWER_INFO.(viewer).type;
    # get the data via appropriate handler
    data := HELP_BOOK_HANDLER.(book.handler).HelpData(book, entrynr, type);
    if data <> fail then
      # show the data
      return HELP_VIEWER_INFO.(viewer).show(
        [ book.bookname, StripEscapeSequences(book.entries[entrynr][1]), data]);
          # name of the help book, the text to be linked, and the URL
    else
        return JupyterRenderable( rec( ("text/html") := Concatenation( book.bookname, ": "
                                                                       , StripEscapeSequences(book.entries[entrynr][1])
                                                                       , " - no html help available. Please check other formats!" ) )
                                , rec( ) );
    fi;
    HELP_LAST.VIEWER := viewer;
  od;
  HELP_LAST.BOOK := book;
  HELP_LAST.MATCH := entrynr;
  HELP_LAST.VIEWER := viewer;
  return true;
end);

InstallGlobalFunction(JUPYTER_HELP_SHOW_MATCHES, function( books, topic, frombegin )
local   exact,  match,  x,  lines,  cnt,  i,  str,  n, res;

  # first get lists of exact and other matches
  x := HELP_GET_MATCHES( books, topic, frombegin );
  exact := x[1];
  match := x[2];

  # no topic found
  if 0 = Length(match) and 0 = Length(exact)  then
    Print( "Help: no matching entry found\n" );
    return false;

  # one exact or together one topic found
  elif 1 = Length(exact) or (0 = Length(exact) and 1 = Length(match)) then
    if Length(exact) = 0 then exact := match; fi;
    i := exact[1];
    return GET_HELP_URL(i);

  # more than one topic found, show overview in pager
  else
    lines :=
        ["","Help: several entries match this topic - type ?2 to get match [2]\n"];
        # there is an empty line in the beginning since `tail' will start from line 2
    HELP_LAST.TOPICS:=[];
    cnt := 0;
    # show exact matches first
    match := Concatenation(exact, match);
    res:="";
    for i  in match  do
      cnt := cnt+1;
      topic := Concatenation(i[1].bookname,": ",i[1].entries[i[2]][1]);
      Add(HELP_LAST.TOPICS, i);
      Append(res, GET_HELP_URL(i)!.data.("text/html"));
      Append(res, "<br/>");
    od;
    return JupyterRenderable( rec( ("text/html") := res )
                            , rec( ) );
  fi;
end);

InstallGlobalFunction(JUPYTER_HELP, function( str )
  local origstr, nwostr, p, book, books, move, add;

  origstr := ShallowCopy(str);
  nwostr := NormalizedWhitespace(origstr);

  # extract the book
  p := Position( str, ':' );
  if p <> fail  then
      book := str{[1..p-1]};
      str  := str{[p+1..Length(str)]};
  else
      book := "";
  fi;

  # normalizing for search
  book := SIMPLE_STRING(book);
  str := SIMPLE_STRING(str);

  # we check if `book' MATCH_BEGINs some of the available books
  books := Filtered(HELP_KNOWN_BOOKS[1], bn-> MATCH_BEGIN(bn, book));
  if Length(book) > 0 and Length(books) = 0 then
    Print("Help: None of the available books matches (try: '?books').\n");
    return;
  fi;

  # function to add a topic to the ring
  move := false;
  add  := function( books, topic )
      if not move  then
          HELP_RING_IDX := (HELP_RING_IDX+1) mod HELP_RING_SIZE;
          HELP_BOOK_RING[HELP_RING_IDX+1]  := books;
          HELP_TOPIC_RING[HELP_RING_IDX+1] := topic;
      fi;
  end;

  # if the topic is empty show the last shown one again
  if  book = "" and str = ""  then
       if HELP_LAST.BOOK = 0 then
         HELP("Tutorial: Help");
       else
         return GET_HELP_URL( [HELP_LAST.BOOK, HELP_LAST.MATCH] );
       fi;
       return;

  # if topic is "&" shobn;w last topic again, but with next viewer in viewer
  # list, or with last viewer again if there is no next one
  elif book = "" and str = "&" and Length(nwostr) = 1 then
       if HELP_LAST.BOOK = 0 then
         HELP("Tutorial: Help");
       else
         HELP_LAST.NEXT_VIEWER := true;
         return GET_HELP_URL( [HELP_LAST.BOOK, HELP_LAST.MATCH] );
       fi;
       return;

  # if the topic is '-' we are interested in the previous search again
  elif book = "" and str = "-" and Length(nwostr) = 1  then
      HELP_RING_IDX := (HELP_RING_IDX-1) mod HELP_RING_SIZE;
      books := HELP_BOOK_RING[HELP_RING_IDX+1];
      str  := HELP_TOPIC_RING[HELP_RING_IDX+1];
      move := true;

  # if the topic is '+' we are interested in the last section again
  elif book = "" and str = "+" and Length(nwostr) = 1  then
      HELP_RING_IDX := (HELP_RING_IDX+1) mod HELP_RING_SIZE;
      books := HELP_BOOK_RING[HELP_RING_IDX+1];
      str  := HELP_TOPIC_RING[HELP_RING_IDX+1];
      move := true;
  fi;

  # number means topic from HELP_LAST.TOPICS list
  if book = "" and ForAll(str, a-> a in "0123456789") then
      HELP_SHOW_FROM_LAST_TOPICS(Int(str));

  # if the topic is '<' we are interested in the one before 'LastTopic'
  elif book = "" and str = "<" and Length(nwostr) = 1  then
      HELP_SHOW_PREV();

  # if the topic is '>' we are interested in the one after 'LastTopic'
  elif book = "" and str = ">" and Length(nwostr) = 1  then
      HELP_SHOW_NEXT();

  # if the topic is '<<' we are interested in the previous chapter intro
  elif book = "" and str = "<<"  then
      HELP_SHOW_PREV_CHAPTER();

  # if the topic is '>>' we are interested in the next chapter intro
  elif book = "" and str = ">>"  then
      HELP_SHOW_NEXT_CHAPTER();

  # if the subject is 'Welcome to GAP' display a welcome message
  elif book = "" and str = "welcome to gap"  then
      if HELP_SHOW_WELCOME(book)  then
          add( books, "Welcome to GAP" );
      fi;

  # if the topic is 'books' display the table of books
  elif book = "" and str = "books"  then
      if HELP_SHOW_BOOKS()  then
          add( books, "books" );
      fi;

  # if the topic is 'chapters' display the table of chapters
  elif str = "chapters"  or str = "contents" or book <> "" and str = "" then
      if ForAll(books, b->  HELP_SHOW_CHAPTERS(b)) then
        add( books, "chapters" );
      fi;

  # if the topic is 'sections' display the table of sections
  elif str = "sections"  then
      if ForAll(books, b-> HELP_SHOW_SECTIONS(b)) then
        add(books, "sections");
      fi;

  # if the topic is '?<string>' search the index for any entries for
  # which <string> is a substring (as opposed to an abbreviation)
  elif Length(str) > 0 and str[1] = '?'  then
      str := str{[2..Length(str)]};
      NormalizeWhitespace(str);
      return HELP_SHOW_MATCHES( books, str, false);

  # search for this topic
  elif IsJupyterRenderable( HELP_SHOW_MATCHES( books, str, true ) ) then
      return HELP_SHOW_MATCHES( books, str, true );
  elif origstr in NAMES_SYSTEM_GVARS then
      Print( "Help: '", origstr, "' is currently undocumented.\n",
             "      For details, try ?Undocumented Variables\n" );
  elif book = "" and
                 ForAny(HELP_KNOWN_BOOKS[1], bk -> MATCH_BEGIN(bk, str)) then
      Print( "Help: Are you looking for a certain book? (Trying '?", origstr,
             ":' ...\n");
      return HELP( Concatenation(origstr, ":") );
  else
     # seems unnecessary, since some message is already printed in all
     # cases above (?):
     # Print( "Help: Sorry, could not find a match for '", origstr, "'.\n");
  fi;
end);

# Load some help stuff (Experimental)
InstallGlobalFunction(JUPYTER_FindManSection,
function(file, name)
    local xml, sections, p, s, res;
    xml := ParseTreeXMLFile(file);
    CheckAndCleanGapDocTree(xml);
    sections := XMLElements(xml, "ManSection");;
    res := [];
    for s in sections do
        if IsBound(s.content) then
            p := PositionProperty(s.content, x ->
                                               IsBound(x.attributes) and
                                             IsBound(x.attributes.Name) and
                                             x.attributes.Name = name);
            if p <> fail then
                Add(res, s);
            fi;
        fi;
    od;
    return res;
end);

