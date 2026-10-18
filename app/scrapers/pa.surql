-- SENAI-PA: shared tewbhv VTEX master cluster 137, products with productReferenceCode "PA|...".
DEFINE FUNCTION OVERWRITE fn::scrape::pa::step($n: int) -> object {
	RETURN fn::scrape::common::vtex::step('pa', $n, [137], NONE, ['pi', 'ro', 'ms', 'es', 'pa', 'pe', 'rn']);
};
