#
gap> JUPYTER_Complete("Gro", 3);
rec( cursor_end := 3, cursor_start := 0, matches := [ "Group", "GroupRing", "GroupBases", "GroupClass", "GroupByRws", "GroupOfPcp", "GroupSt\
ring", "GroupForTom", "GroupByPcgs", "GroupOfPcgs", "GroupByRwsNC", "GrobnerBasis", "GroebnerBasis", "GroupStabChain", "GroebnerBasisNC", "G\
roupWithMemory", "GroupByGenerators", "GroupForGroupInfo", "GroupExtEquations", "Group_PseudoRandom", "GroupwordToMonword", "GroupWithGenera\
tors", "GroupByPrimeResidues", "GroupByQuotientSystem", "GrowthFunctionOfGroup", "GroupOnSubgroupsOrbit", "Group_InitPseudoRandom", "GroupBy\
NiceMonomorphism", "GroupEnumeratorByClosure", "GroupHomomorphismByImages", "GroupHClassOfGreensDClass", "GroupInfoForCharacterTable", "Grou\
pByMultiplicationTable", "GroupHomomorphismByFunction", "GroupGeneralMappingByImages", "GroupHomomorphismByImagesNC", "GroupMethodByNiceMono\
morphism", "GroupGeneralMappingByImagesNC", "GroupGeneralMappingByImages_for_pcp", "GroupSeriesMethodByNiceMonomorphism", "GroupMethodByNice\
MonomorphismCollElm", "GroupMethodByNiceMonomorphismCollColl", "GroupMethodByNiceMonomorphismCollOther", "GroupSeriesMethodByNiceMonomorphis\
mCollElm", "GroupToAdditiveGroupHomomorphismByFunction", "GroupSeriesMethodByNiceMonomorphismCollColl", "GroupSeriesMethodByNiceMonomorphism\
CollOther" ], metadata := rec(  ), status := "ok" )

gap> JUPYTER_Inspect("Gro", 3);
rec( data := rec( metadata := rec( text/html := "", text/plain := "" ), text/html := "", text/plain := "" ), found := true, status := "ok" )

#
gap> G := Group((1,2,3));
Group([ (1,2,3) ])
gap> JUPYTER_Inspect("G", 1);
rec( data := rec( metadata := rec( text/html := "", text/plain := "" ), text/html := "", text/plain := "Properties:

IsFinite                        : true
CanEasilyCompareElements        : true
CanEasilySortElements           : true
IsDuplicateFree                 : true
IsGeneratorsOfMagmaWithInverses : true
IsAssociative                   : true
IsCommutative                   : true
IsGeneratorsOfSemigroup         : true
IsSimpleSemigroup               : true
IsRegularSemigroup              : true
IsInverseSemigroup              : true
IsCompletelyRegularSemigroup    : true
IsCompletelySimpleSemigroup     : true
IsGroupAsSemigroup              : true
IsMonoidAsSemigroup             : true
IsOrthodoxSemigroup             : true
IsCyclic                        : true
IsFinitelyGeneratedGroup        : true
IsSubsetLocallyFiniteGroup      : true
KnowsHowToDecompose             : true
IsNilpotentGroup                : true
IsSupersolvableGroup            : true
IsMonomialGroup                 : true
IsSolvableGroup                 : true
IsPolycyclicGroup               : true
IsNilpotentByFinite             : true

Attributes:

LargestMovedPoint               : 3
GeneratorsOfMagmaWithInverses   : [ (1,2,3) ]
MultiplicativeNeutralElement    : ()" ), found := true, status := "ok" )

#
