-- SENAI-ES: shared tewbhv VTEX master cluster 137, products with productReferenceCode "ES|...".
DEFINE FUNCTION OVERWRITE fn::scrape::es::step($n: int) -> object {
	RETURN fn::scrape::common::vtex::step('es', $n, [137], NONE, ['pi', 'ro', 'ms', 'es', 'pa', 'pe', 'rn']);
};
