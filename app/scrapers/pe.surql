-- SENAI-PE: shared tewbhv VTEX master cluster 137, products with productReferenceCode "PE|...".
DEFINE FUNCTION OVERWRITE fn::scrape::pe::step($n: int) -> object {
	RETURN fn::scrape::common::vtex::step('pe', $n, [137], NONE, ['pi', 'ro', 'ms', 'es', 'pa', 'pe', 'rn']);
};
