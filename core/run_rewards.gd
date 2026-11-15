class_name RunRewards
extends RefCounted
## Everything a finished run earned, for the results screen.

var run_coins: int = 0
var mission_coins: int = 0
var completed_missions: Array[MissionData] = []
## New mastery level of the played skin, or 0 if it did not level up.
var mastery_level_up: int = 0
