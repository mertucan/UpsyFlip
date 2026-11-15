class_name RunSummary
extends RefCounted
## What happened in one finished run; feeds missions, mastery, analytics and
## ad pacing.

var skin_id: StringName = &""
var height: int = 0
var score: int = 0
var coins: int = 0
var perfects: int = 0
var sticks: int = 0
var duration: float = 0.0
var death_reason: int = 0
## True for the part of a run played after a rewarded-ad continue. In that
## case coins, perfects and sticks hold only what was earned since the
## continue, while height and score are still the run totals.
var is_continuation: bool = false
## Meters gained in this part of the run (equals height unless continued).
var height_gain: int = 0
