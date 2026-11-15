extends Node
## Player meta progress: owned skins, daily streak, daily missions and skin
## mastery. Thin glue between the pure logic classes in core/meta, the
## Economy and the SaveService.

signal changed

const META_CONFIG_PATH: String = "res://data/meta_config.tres"
const SKIN_CATALOG_PATH: String = "res://skins/skin_catalog.tres"
const SAVE_KEY_INVENTORY: String = "inventory"
const SAVE_KEY_DAILY: String = "daily"
const SAVE_KEY_MISSIONS: String = "missions"
const SAVE_KEY_MASTERY: String = "mastery"
const SAVE_KEY_FREE_COINS_DAY: String = "free_coins_day"
const SECONDS_PER_DAY: int = 86400


var config: MetaConfig
var catalog: SkinCatalog
var inventory: SkinInventory = SkinInventory.new()
var daily: DailyStreak = DailyStreak.new()
var missions: MissionBoard = MissionBoard.new()
var mastery: MasteryTracker = MasteryTracker.new()


func _ready() -> void:
	config = load(META_CONFIG_PATH) as MetaConfig
	catalog = load(SKIN_CATALOG_PATH) as SkinCatalog
	reload()


## Rebuilds all state from the SaveService.
func reload() -> void:
	inventory.from_dict(SaveService.get_dict(SAVE_KEY_INVENTORY))
	inventory.ensure_valid(catalog.skins[0].id)
	daily.from_dict(SaveService.get_dict(SAVE_KEY_DAILY))
	missions.from_dict(SaveService.get_dict(SAVE_KEY_MISSIONS))
	mastery.from_dict(SaveService.get_dict(SAVE_KEY_MASTERY))


func save() -> void:
	SaveService.set_value(SAVE_KEY_INVENTORY, inventory.to_dict())
	SaveService.set_value(SAVE_KEY_DAILY, daily.to_dict())
	SaveService.set_value(SAVE_KEY_MISSIONS, missions.to_dict())
	SaveService.set_value(SAVE_KEY_MASTERY, mastery.to_dict())
	SaveService.save_to_disk()
	changed.emit()


## Days since the Unix epoch in the player's local time zone.
func today() -> int:
	var bias_seconds: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return floori((Time.get_unix_time_from_system() + bias_seconds) / SECONDS_PER_DAY)


# --- Skins ------------------------------------------------------------------

func selected_skin() -> SkinData:
	return catalog.find(inventory.selected)


func select_skin(skin: SkinData) -> bool:
	if not inventory.select(skin.id):
		return false
	save()
	return true


func buy_skin(skin: SkinData, with_gems: bool) -> bool:
	var balance: int = Economy.gems if with_gems else Economy.coins
	if not inventory.can_buy(skin, with_gems, balance):
		return false
	var price: int = SkinInventory.price_of(skin, with_gems)
	var paid: bool = Economy.spend_gems(price) if with_gems else Economy.spend_coins(price)
	if not paid:
		return false
	inventory.add(skin.id)
	inventory.select(skin.id)
	Analytics.log_event("skin_unlocked", {
		"skin": String(skin.id), "currency": "gems" if with_gems else "coins",
	})
	save()
	return true


## Gives a skin without payment (in-app purchase bundles).
func grant_skin(skin_id: StringName) -> void:
	if inventory.owns(skin_id):
		return
	inventory.add(skin_id)
	Analytics.log_event("skin_unlocked", {"skin": String(skin_id), "currency": "iap"})
	save()


## Cheapest coin-priced skin still locked, or null.
func next_skin_goal() -> SkinData:
	return inventory.next_coin_goal(catalog.skins)


func mastery_level(skin: SkinData) -> int:
	return mastery.level_of(skin.id, config.mastery_thresholds)


func trail_color(skin: SkinData) -> Color:
	var colors: PackedColorArray = config.mastery_trail_colors
	return colors[clampi(mastery_level(skin) - 1, 0, colors.size() - 1)]


# --- Daily streak -----------------------------------------------------------

func can_claim_daily() -> bool:
	return daily.can_claim(today())


## Claims today's reward. Returns the reward slot, or -1 if already claimed.
func claim_daily() -> int:
	var slot: int = daily.claim(today(), config.cycle_length())
	if slot < 0:
		return -1
	Economy.add_coins(config.daily_coins[slot])
	Economy.add_gems(config.daily_gems[slot])
	save()
	return slot


# --- Free daily coins (rewarded ad) -----------------------------------------

func can_claim_free_coins() -> bool:
	return SaveService.get_int(SAVE_KEY_FREE_COINS_DAY, -1) < today()


## Call after the rewarded ad finished. Returns the coins granted (0 if
## already claimed today).
func claim_free_coins() -> int:
	if not can_claim_free_coins():
		return 0
	var amount: int = RemoteConfig.get_int("free_coins_amount")
	SaveService.set_value(SAVE_KEY_FREE_COINS_DAY, today())
	Economy.add_coins(amount)
	save()
	return amount


# --- Missions ---------------------------------------------------------------

func todays_missions() -> Array[MissionData]:
	if missions.roll_if_needed(today(), config.mission_pool, inventory.owned, config.missions_per_day):
		save()
	return missions.active_missions(config.mission_pool)


# --- Runs -------------------------------------------------------------------

## Banks a finished run: coins, mission progress and rewards, mastery XP.
func record_run(summary: RunSummary) -> RunRewards:
	var rewards: RunRewards = RunRewards.new()
	rewards.run_coins = summary.coins
	todays_missions()
	rewards.completed_missions = missions.apply_run(summary, config.mission_pool)
	for mission: MissionData in rewards.completed_missions:
		rewards.mission_coins += mission.reward_coins
	var run_xp: int = 0 if summary.is_continuation else config.mastery_xp_per_run
	rewards.mastery_level_up = mastery.add_xp(
			summary.skin_id, run_xp + summary.height_gain, config.mastery_thresholds)
	Economy.add_coins(rewards.run_coins + rewards.mission_coins)
	save()
	return rewards
