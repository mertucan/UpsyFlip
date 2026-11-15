extends Node
## Facade for rewarded and interstitial ads. Game code talks only to this
## node; the provider behind it is an AdsBackend (mock, or a real SDK).
## The ad SDK is initialized only after the consent flow has finished.

signal rewarded_completed(placement: StringName)
signal rewarded_failed(placement: StringName)
signal interstitial_closed

const PLACEMENT_CONTINUE: StringName = &"continue"
const PLACEMENT_DOUBLE_COINS: StringName = &"double_coins"
const PLACEMENT_TRY_SKIN: StringName = &"try_skin"
const PLACEMENT_FREE_COINS: StringName = &"free_coins"
const SAVE_KEY_ADS_REMOVED: String = "ads_removed"
const ADMOB_SINGLETON: String = "PoingGodotAdMob"
const ADMOB_BACKEND_PATH: String = "res://services/ads/admob_ads_backend.gd"

var policy: InterstitialPolicy = InterstitialPolicy.new()
## True once the player bought "remove ads": no interstitials; rewarded ads
## stay because they are optional.
var ads_removed: bool = false

var _backend: AdsBackend
var _pending_placement: StringName = &""
var _session_time: float = 0.0


func _ready() -> void:
	ads_removed = SaveService.get_bool(SAVE_KEY_ADS_REMOVED)
	_apply_remote_config()
	RemoteConfig.changed.connect(_apply_remote_config)
	set_backend(_create_backend())


func _process(delta: float) -> void:
	_session_time += delta


## Real ads on Android builds that include the AdMob plugin, mock elsewhere.
func _create_backend() -> AdsBackend:
	if OS.get_name() == "Android" and Engine.has_singleton(ADMOB_SINGLETON):
		return (load(ADMOB_BACKEND_PATH) as GDScript).new() as AdsBackend
	# The mock hands out rewards for free, so it never ships: a release build
	# without the plugin gets the inert base backend (no ads, no rewards).
	if OS.is_debug_build():
		return MockAdsBackend.new()
	return AdsBackend.new()


## Swaps the ad provider and starts its consent flow.
func set_backend(backend: AdsBackend) -> void:
	if _backend != null:
		_backend.queue_free()
	_backend = backend
	_pending_placement = &""
	add_child(backend)
	backend.consent_resolved.connect(backend.initialize)
	backend.rewarded_closed.connect(_on_rewarded_closed)
	backend.interstitial_closed.connect(func() -> void: interstitial_closed.emit())
	backend.request_consent()


func get_backend() -> AdsBackend:
	return _backend


func set_ads_removed(value: bool) -> void:
	ads_removed = value
	SaveService.set_value(SAVE_KEY_ADS_REMOVED, value)


func is_rewarded_ready() -> bool:
	return _pending_placement == &"" and _backend.is_rewarded_ready()


## Shows a rewarded ad; the result arrives through rewarded_completed or
## rewarded_failed with the same placement.
func show_rewarded(placement: StringName) -> void:
	if not is_rewarded_ready():
		rewarded_failed.emit(placement)
		return
	_pending_placement = placement
	_backend.show_rewarded()


## Call once per finished run. Shows an interstitial if the pacing rules
## allow it and returns whether one was shown.
func notify_run_finished(duration: float) -> bool:
	policy.register_run(duration)
	if ads_removed or not policy.should_show(_session_time) or not _backend.is_interstitial_ready():
		return false
	policy.mark_shown(_session_time)
	Analytics.log_event("ad_interstitial")
	_backend.show_interstitial()
	return true


func _on_rewarded_closed(earned: bool) -> void:
	var placement: StringName = _pending_placement
	_pending_placement = &""
	if earned:
		Analytics.log_event("ad_rewarded", {"placement": String(placement)})
		rewarded_completed.emit(placement)
	else:
		rewarded_failed.emit(placement)


func _apply_remote_config() -> void:
	policy.free_runs = RemoteConfig.get_int("interstitial_free_runs")
	policy.runs_between = RemoteConfig.get_int("interstitial_runs_between")
	policy.seconds_between = RemoteConfig.get_float("interstitial_seconds_between")
	policy.min_run_seconds = RemoteConfig.get_float("interstitial_min_run_seconds")
