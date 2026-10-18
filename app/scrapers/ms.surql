-- SENAI-MS: shared tewbhv VTEX master cluster 137, products with productReferenceCode "MS|...".
DEFINE FUNCTION OVERWRITE fn::scrape::ms::step($n: int) -> object {
	RETURN fn::scrape::common::vtex::step('ms', $n, [137], NONE, ['pi', 'ro', 'ms', 'es', 'pa', 'pe', 'rn']);
};
