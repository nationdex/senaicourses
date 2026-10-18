-- SENAI-PI: shared tewbhv VTEX master cluster 137, products with productReferenceCode "PI|...".
DEFINE FUNCTION OVERWRITE fn::scrape::pi::step($n: int) -> object {
	RETURN fn::scrape::common::vtex::step('pi', $n, [137], NONE, ['pi', 'ro', 'ms', 'es', 'pa', 'pe', 'rn']);
};
