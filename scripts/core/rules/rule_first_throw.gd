## First Throw (Elite twist): "Bounties only claimable on a hand's first
## throw." Pots from later throws (incl. after a Hot Hand) still score.
## params.throws (default 1): how many opening throws count.
class_name RuleFirstThrow
extends TableRule


func bounties_count(run: BonfireRun) -> bool:
	return run.throws_this_hand <= int(param("throws", 1))
