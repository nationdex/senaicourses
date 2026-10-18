-- SENAI-RN: shared tewbhv VTEX master cluster 137, products with productReferenceCode "RN|...".
DEFINE FUNCTION OVERWRITE fn::scrape::rn::step($n: int) -> object {
	RETURN fn::scrape::common::vtex::step('rn', $n, [137], NONE, ['pi', 'ro', 'ms', 'es', 'pa', 'pe', 'rn']);
};
