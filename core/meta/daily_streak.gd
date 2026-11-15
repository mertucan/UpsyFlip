class_name DailyStreak
extends RefCounted
## Daily login streak: one claim per calendar day; claiming on consecutive
## days walks through the reward cycle, a missed day starts it over.
## Days are integers (days since the Unix epoch, local time).

var last_claim_day: int = -1
## Position in the reward cycle of the most recent claim.
var day_index: int = -1


func can_claim(today: int) -> bool:
	return today > last_claim_day


## Reward slot a claim made `today` would give.
func next_index(today: int, cycle_length: int) -> int:
	if last_claim_day >= 0 and today == last_claim_day + 1:
		return (day_index + 1) % cycle_length
	return 0


## Slot to highlight in the UI: the claimable one, or today's already-claimed one.
func display_index(today: int, cycle_length: int) -> int:
	return next_index(today, cycle_length) if can_claim(today) else day_index


## Claims today's reward and returns its slot, or -1 if already claimed today.
func claim(today: int, cycle_length: int) -> int:
	if not can_claim(today):
		return -1
	day_index = next_index(today, cycle_length)
	last_claim_day = today
	return day_index


func to_dict() -> Dictionary:
	return {"last_claim_day": last_claim_day, "day_index": day_index}


func from_dict(data: Dictionary) -> void:
	last_claim_day = int(data.get("last_claim_day", -1))
	day_index = int(data.get("day_index", -1))
