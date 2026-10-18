-- SENAI-RO: shared tewbhv VTEX master cluster 137, products with productReferenceCode "RO|...".
DEFINE FUNCTION OVERWRITE fn::scrape::ro::step($n: int) -> object {
	RETURN fn::scrape::common::vtex::step('ro', $n, [137], NONE, ['pi', 'ro', 'ms', 'es', 'pa', 'pe', 'rn']);
};
