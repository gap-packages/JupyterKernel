#
# JupyterKernel: Jupyter kernel written in GAP
#
# This file contains package meta data. For additional information on
# the meaning and correct usage of these fields, please consult the
# manual of the "Example" package as well as the comments in its
# PackageInfo.g file.
#
SetPackageInfo( rec(

PackageName := "JupyterKernel",
Subtitle := "Jupyter kernel written in GAP",
Version := "0.999999",
Date := "31/07/2018", # dd/mm/yyyy format

Persons := [
  rec(
    IsAuthor := true,
    IsMaintainer := true,
    FirstNames := "Markus",
    LastName := "Pfeiffer",
    WWWHome := "https://markusp.morphism.de/",
    Email := "markus.pfeiffer@morphism.de",
    PostalAddress := "School of Computer Science\nNorth Haugh\nSt Andrews\nFife\nKY16 9SX\nScotland",
    Place := "St Andrews",
    Institution := "University of St Andrews",
  ),
],

SourceRepository := rec(
    Type := "git",
    URL := Concatenation( "https://github.com/gap-packages/", ~.PackageName ),
),
IssueTrackerURL := Concatenation( ~.SourceRepository.URL, "/issues" ),

PackageWWWHome := "https://gap-packages.github.io/JupyterKernel/",

ArchiveURL     := Concatenation("https://github.com/gap-packages/JupyterKernel/",
                                "releases/download/v", ~.Version,
                                "/JupyterKernel-", ~.Version),
README_URL     := Concatenation( ~.PackageWWWHome, "README.md" ),
PackageInfoURL := Concatenation( ~.PackageWWWHome, "PackageInfo.g" ),

ArchiveFormats := ".tar.gz",

##  Status information. Currently the following cases are recognized:
##    "accepted"      for successfully refereed packages
##    "submitted"     for packages submitted for the refereeing
##    "deposited"     for packages for which the GAP developers agreed
##                    to distribute them with the core GAP system
##    "dev"           for development versions of packages
##    "other"         for all other packages
##
Status := "deposited",

AbstractHTML := "The <span class=\"pkgname\">JupyterKernel</span> package provides a so-called kernel for the Jupyter interactive document system.",

PackageDoc := rec(
  BookName  := "JupyterKernel",
  ArchiveURLSubset := ["doc"],
  HTMLStart := "doc/chap0.html",
  PDFFile   := "doc/manual.pdf",
  SixFile   := "doc/manual.six",
  LongTitle := "Jupyter kernel written in GAP",
),

Dependencies := rec(
  GAP := ">= 4.9",
  NeededOtherPackages := [ [ "GAPDoc", ">= 1.5" ]
                         , [ "io",     ">= 4.4.6" ]
                         , [ "json",   ">= 1.1.0" ]
                         , [ "uuid",   ">= 0.4" ]
                         , [ "ZeroMQInterface", ">= 0.8" ]
                         , [ "crypting", ">= 0.7"] ],

  SuggestedOtherPackages := [ ],
  ExternalConditions := [ [ "Jupyter", "https://jupyter.org/install" ] ],
),

AvailabilityTest := ReturnTrue,

TestFile := "tst/testall.g",

Keywords := [ "Jupyter", "User Interface" ],

));


