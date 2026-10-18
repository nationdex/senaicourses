-- SENAI-GO: its own four VTEX clusters (profissionalizantes, técnicos, presenciais, ead) on the
-- tewbhv account. Every product in those clusters is GO's, so no reference-code prefix filter.
DEFINE FUNCTION OVERWRITE fn::scrape::go::step($n: int) -> object {
	RETURN fn::scrape::common::vtex::step('go', $n, [550, 551, 553, 554], 'go', ['go']);
};
