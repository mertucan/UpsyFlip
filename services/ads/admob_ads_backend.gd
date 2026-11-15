extends AdsBackend
## Google AdMob through the Poing Studios plugin (res://addons/admob).
## Loaded only on Android builds that contain the plugin; everywhere else
## the MockAdsBackend is used. Deliberately has no class_name so the plugin
## classes are never touched on desktop.
##
## Order of operations: UMP consent flow -> SDK initialization -> preload one
## rewarded and one interstitial ad, reloading after each show or failure.

const CONFIG_PATH: String = "res://data/ads_config.tres"

var _config: AdsConfig
var _consent_done: bool = false
var _initialized: bool = false
var _rewarded_loader: RewardedAdLoader = RewardedAdLoader.new()
var _interstitial_loader: InterstitialAdLoader = InterstitialAdLoader.new()
var _rewarded: RewardedAd = null
var _interstitial: InterstitialAd = null
var _reward_earned: bool = false


func _ready() -> void:
	_config = load(CONFIG_PATH) as AdsConfig


# --- Consent ----------------------------------------------------------------

func request_consent() -> void:
	var update_listener: OnConsentInfoUpdateListener = OnConsentInfoUpdateListener.new()
	update_listener.on_consent_info_update_success = func() -> void:
		if ConsentInformation.is_consent_form_available():
			var dismissed_listener: OnConsentFormDismissedListener = OnConsentFormDismissedListener.new()
			dismissed_listener.on_consent_form_dismissed = func(_error: FormError) -> void:
				_finish_consent()
			ConsentForm.load_and_show_consent_form_if_required(dismissed_listener)
		else:
			_finish_consent()
	update_listener.on_consent_info_update_failure = func(_error: FormError) -> void:
		_finish_consent()
	ConsentInformation.request_consent_info_update(ConsentRequestParameters.new(), update_listener)


func _finish_consent() -> void:
	if _consent_done:
		return
	_consent_done = true
	consent_resolved.emit.call_deferred()


# --- Initialization ---------------------------------------------------------

func initialize() -> void:
	var listener: OnInitializationCompleteListener = OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status: InitializationStatus) -> void:
		_initialized = true
		_load_rewarded()
		_load_interstitial()
	MobileAds.set_request_configuration(RequestConfiguration.new())
	MobileAds.initialize(listener)


# --- Rewarded ---------------------------------------------------------------

func is_rewarded_ready() -> bool:
	return _rewarded != null


func show_rewarded() -> void:
	if _rewarded == null:
		rewarded_closed.emit(false)
		return
	_reward_earned = false
	var reward_listener: OnUserEarnedRewardListener = OnUserEarnedRewardListener.new()
	reward_listener.on_user_earned_reward = func(_item: RewardedItem) -> void:
		_reward_earned = true
	_rewarded.show(reward_listener)


func _load_rewarded() -> void:
	var callback: RewardedAdLoadCallback = RewardedAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: RewardedAd) -> void:
		_rewarded = ad
		var content: FullScreenContentCallback = FullScreenContentCallback.new()
		content.on_ad_dismissed_full_screen_content = func() -> void:
			_finish_rewarded(_reward_earned)
		content.on_ad_failed_to_show_full_screen_content = func(_error: AdError) -> void:
			_finish_rewarded(false)
		ad.full_screen_content_callback = content
	callback.on_ad_failed_to_load = func(_error: LoadAdError) -> void:
		_retry_later(_load_rewarded)
	_rewarded_loader.load(_config.rewarded_unit_id, AdRequest.new(), callback)


func _finish_rewarded(earned: bool) -> void:
	if _rewarded != null:
		_rewarded.destroy()
		_rewarded = null
	rewarded_closed.emit.call_deferred(earned)
	_load_rewarded()


# --- Interstitial -----------------------------------------------------------

func is_interstitial_ready() -> bool:
	return _interstitial != null


func show_interstitial() -> void:
	if _interstitial == null:
		interstitial_closed.emit()
		return
	_interstitial.show()


func _load_interstitial() -> void:
	var callback: InterstitialAdLoadCallback = InterstitialAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: InterstitialAd) -> void:
		_interstitial = ad
		var content: FullScreenContentCallback = FullScreenContentCallback.new()
		content.on_ad_dismissed_full_screen_content = func() -> void:
			_finish_interstitial()
		content.on_ad_failed_to_show_full_screen_content = func(_error: AdError) -> void:
			_finish_interstitial()
		ad.full_screen_content_callback = content
	callback.on_ad_failed_to_load = func(_error: LoadAdError) -> void:
		_retry_later(_load_interstitial)
	_interstitial_loader.load(_config.interstitial_unit_id, AdRequest.new(), callback)


func _finish_interstitial() -> void:
	if _interstitial != null:
		_interstitial.destroy()
		_interstitial = null
	interstitial_closed.emit.call_deferred()
	_load_interstitial()


func _retry_later(loader: Callable) -> void:
	if not is_inside_tree():
		return
	get_tree().create_timer(_config.reload_delay, true, false, true).timeout.connect(loader)
