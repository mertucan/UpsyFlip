extends "res://tests/test_case.gd"
## Ads pacing, rewarded flow, billing fulfilment, remote config and analytics,
## all against the mock backends.

const TEST_SAVE_PATH: String = "user://test_services_save.json"

var _original_save_path: String = ""


## Points every autoload at an empty throwaway save and fresh mock backends.
func _begin() -> void:
	_original_save_path = SaveService.save_path
	_delete_test_save()
	SaveService.save_path = TEST_SAVE_PATH
	_reload_all()


func _end() -> void:
	_delete_test_save()
	SaveService.save_path = _original_save_path
	RemoteConfig.apply_remote({})
	_reload_all()


func _reload_all() -> void:
	SaveService.load_from_disk()
	Economy.reload()
	PlayerProgress.reload()
	BillingService.reload()
	BillingService.set_backend(MockBillingBackend.new())
	AdsService.ads_removed = SaveService.get_bool(AdsService.SAVE_KEY_ADS_REMOVED)
	AdsService.policy = InterstitialPolicy.new()
	AdsService.set_backend(MockAdsBackend.new())
	Analytics.recent_events.clear()


func _delete_test_save() -> void:
	for suffix: String in ["", ".bak"]:
		var path: String = ProjectSettings.globalize_path(TEST_SAVE_PATH + suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _mock_ads() -> MockAdsBackend:
	return AdsService.get_backend() as MockAdsBackend


func _mock_store() -> MockBillingBackend:
	return BillingService.get_backend() as MockBillingBackend


# --- Interstitial pacing ----------------------------------------------------

func test_no_interstitial_in_first_three_runs() -> void:
	var policy: InterstitialPolicy = InterstitialPolicy.new()
	for run: int in 3:
		policy.register_run(60.0)
		assert_true(not policy.should_show(1000.0), "run %d is ad-free" % (run + 1))
	policy.register_run(60.0)
	assert_true(policy.should_show(1000.0), "fourth run may show an ad")


func test_no_interstitial_after_a_short_run() -> void:
	var policy: InterstitialPolicy = InterstitialPolicy.new()
	for run: int in 10:
		policy.register_run(14.9)
		assert_true(not policy.should_show(10000.0), "short run never shows an ad")
	policy.register_run(15.0)
	assert_true(policy.should_show(10000.0), "a 15 second run is long enough")


func test_interstitial_frequency_cap() -> void:
	var policy: InterstitialPolicy = InterstitialPolicy.new()
	for run: int in 4:
		policy.register_run(30.0)
	assert_true(policy.should_show(100.0), "eligible after the free runs")
	policy.mark_shown(100.0)

	policy.register_run(30.0)
	assert_true(not policy.should_show(130.0), "1 run and 30 s later: too soon")
	policy.register_run(30.0)
	assert_true(not policy.should_show(160.0), "2 runs and 60 s later: too soon")
	policy.register_run(30.0)
	assert_true(policy.should_show(190.0), "3 runs later: allowed")
	policy.mark_shown(190.0)

	policy.register_run(130.0)
	assert_true(policy.should_show(320.0), "1 run but 130 s later: allowed")


func test_ads_service_paces_and_respects_remove_ads() -> void:
	_begin()
	for run: int in 3:
		assert_true(not AdsService.notify_run_finished(40.0), "free run %d" % (run + 1))
	assert_true(AdsService.notify_run_finished(40.0), "interstitial after the free runs")
	assert_eq(_mock_ads().interstitials_shown, 1, "backend showed one interstitial")
	assert_eq(Analytics.count("ad_interstitial"), 1, "interstitial is logged")
	assert_true(not AdsService.notify_run_finished(40.0), "not again right away")

	AdsService.set_ads_removed(true)
	for run: int in 10:
		assert_true(not AdsService.notify_run_finished(200.0), "no interstitials once ads are removed")
	assert_true(AdsService.is_rewarded_ready(), "rewarded ads stay available")
	_end()


func test_remote_config_changes_pacing() -> void:
	_begin()
	RemoteConfig.apply_remote({"interstitial_free_runs": 0, "interstitial_runs_between": 1, "unknown_key": 5})
	assert_eq(AdsService.policy.free_runs, 0, "remote value applied")
	assert_eq(RemoteConfig.get_value("unknown_key"), null, "unknown keys are ignored")
	assert_true(AdsService.notify_run_finished(20.0), "first run already shows an ad")
	RemoteConfig.apply_remote({})
	assert_eq(AdsService.policy.free_runs, 3, "defaults return when overrides are cleared")
	_end()


# --- Rewarded ads -----------------------------------------------------------

func test_rewarded_ad_reports_its_placement() -> void:
	_begin()
	var completed: Array[StringName] = []
	var on_completed: Callable = func(placement: StringName) -> void: completed.append(placement)
	AdsService.rewarded_completed.connect(on_completed)
	AdsService.show_rewarded(AdsService.PLACEMENT_DOUBLE_COINS)
	assert_eq(completed, [AdsService.PLACEMENT_DOUBLE_COINS] as Array[StringName], "reward delivered with its placement")
	assert_eq(Analytics.count("ad_rewarded"), 1, "rewarded ad is logged")
	AdsService.rewarded_completed.disconnect(on_completed)
	_end()


func test_free_coins_once_per_day() -> void:
	_begin()
	assert_true(PlayerProgress.can_claim_free_coins(), "free coins available")
	assert_eq(PlayerProgress.claim_free_coins(), RemoteConfig.get_int("free_coins_amount"), "coins granted")
	assert_eq(PlayerProgress.claim_free_coins(), 0, "only once per day")
	assert_eq(Economy.coins, RemoteConfig.get_int("free_coins_amount"), "balance reflects one claim")
	_end()


# --- Billing ----------------------------------------------------------------

func test_consumable_is_granted_after_consume() -> void:
	_begin()
	var product: ProductData = BillingService.catalog.find(&"coins_small")
	BillingService.purchase(&"coins_small")
	assert_eq(Economy.coins, product.coins, "coins granted")
	assert_eq(_mock_store().consumed_tokens.size(), 1, "purchase was consumed")
	BillingService.purchase(&"coins_small")
	assert_eq(Economy.coins, product.coins * 2, "consumables can be bought again")
	assert_eq(Analytics.count("purchase"), 2, "purchases are logged")
	_end()


func test_non_consumable_is_granted_once_and_acknowledged() -> void:
	_begin()
	BillingService.purchase(&"remove_ads")
	assert_true(BillingService.owns(&"remove_ads"), "product is owned")
	assert_true(AdsService.ads_removed, "ads are removed")
	assert_eq(_mock_store().acknowledged.size(), 1, "purchase was acknowledged")
	var failed: Array[StringName] = []
	var on_failed: Callable = func(product_id: StringName) -> void: failed.append(product_id)
	BillingService.purchase_failed.connect(on_failed)
	BillingService.purchase(&"remove_ads")
	assert_eq(failed.size(), 1, "cannot buy a non-consumable twice")
	BillingService.purchase_failed.disconnect(on_failed)
	_end()


func test_pending_purchase_grants_nothing_until_paid() -> void:
	_begin()
	_mock_store().next_state = BillingBackend.PurchaseState.PENDING
	BillingService.purchase(&"gems_small")
	assert_eq(Economy.gems, 0, "PENDING grants nothing")
	_mock_store().complete_pending("mock-1")
	assert_eq(Economy.gems, BillingService.catalog.find(&"gems_small").gems, "gems arrive once PURCHASED")
	_end()


func test_failed_purchase_grants_nothing() -> void:
	_begin()
	_mock_store().next_state = BillingBackend.PurchaseState.FAILED
	BillingService.purchase(&"coins_large")
	assert_eq(Economy.coins, 0, "failed purchase grants nothing")
	_end()


func test_starter_pack_bundle() -> void:
	_begin()
	var pack: ProductData = BillingService.catalog.find(&"starter_pack")
	assert_true(not pack.consumable and pack.removes_ads and pack.skin_id != &"", "starter pack is a one-time bundle")
	BillingService.purchase(&"starter_pack")
	assert_true(AdsService.ads_removed, "bundle removes ads")
	assert_true(PlayerProgress.inventory.owns(pack.skin_id), "bundle unlocks the exclusive skin")
	assert_eq(Economy.coins, pack.coins, "bundle grants coins")
	assert_true(not BillingService.can_purchase(pack), "bundle cannot be bought again")
	_end()


func test_exclusive_skin_cannot_be_bought_with_currency() -> void:
	var skin: SkinData = PlayerProgress.catalog.find(&"gold_knife")
	assert_true(skin.exclusive, "gold knife is exclusive")
	assert_true(not SkinInventory.new().can_buy(skin, false, 999999), "not for coins")
	assert_true(not SkinInventory.new().can_buy(skin, true, 999999), "not for gems")


func test_restore_completes_unfinished_purchases_without_duplicates() -> void:
	_begin()
	BillingService.purchase(&"remove_ads")
	# A coin pack was paid for but the app closed before it was consumed.
	var store: MockBillingBackend = _mock_store()
	store._held["mock-99"] = &"coins_medium"

	# Next app start: same save, store reports what it still holds.
	BillingService.reload()
	Economy.reload()
	store.query_purchases()
	assert_eq(Economy.coins, BillingService.catalog.find(&"coins_medium").coins, "unconsumed pack is delivered on restore")
	assert_true(BillingService.owns(&"remove_ads"), "non-consumable is still owned")
	store.query_purchases()
	assert_eq(Economy.coins, BillingService.catalog.find(&"coins_medium").coins, "restoring again grants nothing more")
	_end()


func test_product_catalog_matches_the_spec() -> void:
	var expected: Array[StringName] = [
		&"starter_pack", &"remove_ads", &"coins_small", &"coins_medium", &"coins_large",
		&"gems_small", &"gems_medium", &"gems_large",
	]
	var ids: Array[StringName] = []
	for product: ProductData in BillingService.catalog.products:
		ids.append(product.id)
	assert_eq(ids, expected, "product IDs")
	assert_true(not BillingService.catalog.find(&"remove_ads").consumable, "remove_ads is non-consumable")
	assert_true(BillingService.catalog.find(&"coins_small").consumable, "coin packs are consumable")


# --- Continue ---------------------------------------------------------------

func test_continued_run_is_not_counted_twice() -> void:
	var runs: MissionData = MissionData.new()
	runs.id = &"runs"
	runs.type = MissionData.Type.RUNS
	runs.target = 5
	var total: MissionData = MissionData.new()
	total.id = &"total"
	total.type = MissionData.Type.HEIGHT_TOTAL
	total.target = 500
	var pool: Array[MissionData] = [runs, total]
	var board: MissionBoard = MissionBoard.new()
	board.roll_if_needed(1, pool, [] as Array[StringName], 2)

	var first: RunSummary = RunSummary.new()
	first.height = 40
	first.height_gain = 40
	board.apply_run(first, pool)
	var second: RunSummary = RunSummary.new()
	second.is_continuation = true
	second.height = 65
	second.height_gain = 25
	board.apply_run(second, pool)
	assert_eq(board.progress_of(runs), 1, "a continued run counts as one run")
	assert_eq(board.progress_of(total), 65, "total height counts each meter once")


# --- Builds without real SDKs -----------------------------------------------

func test_inert_store_sells_nothing() -> void:
	_begin()
	BillingService.set_backend(BillingBackend.new())
	assert_true(not BillingService.is_available(), "the base backend is not a store")
	var failed: Array[StringName] = []
	var on_failed: Callable = func(product_id: StringName) -> void: failed.append(product_id)
	BillingService.purchase_failed.connect(on_failed)
	BillingService.purchase(&"coins_large")
	BillingService.purchase(&"remove_ads")
	assert_eq(failed.size(), 2, "purchases are refused")
	assert_eq(Economy.coins, 0, "nothing is granted")
	assert_true(not AdsService.ads_removed, "ads are not removed")
	BillingService.purchase_failed.disconnect(on_failed)
	_end()


func test_inert_ads_backend_gives_no_rewards() -> void:
	_begin()
	AdsService.set_backend(AdsBackend.new())
	assert_true(not AdsService.is_rewarded_ready(), "no rewarded ad without an ad SDK")
	var completed: Array[StringName] = []
	var on_completed: Callable = func(placement: StringName) -> void: completed.append(placement)
	AdsService.rewarded_completed.connect(on_completed)
	AdsService.show_rewarded(AdsService.PLACEMENT_FREE_COINS)
	assert_eq(completed.size(), 0, "no reward is handed out")
	for run: int in 6:
		assert_true(not AdsService.notify_run_finished(60.0), "no interstitial without an ad SDK")
	AdsService.rewarded_completed.disconnect(on_completed)
	_end()