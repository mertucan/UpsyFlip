class_name AdsConfig
extends Resource
## Ad unit IDs. The defaults are Google's public TEST units, which always
## serve test ads and need no AdMob account. Replace them with real unit IDs
## (and set the AdMob app ID in Project Settings > AdMob) before release.

@export var rewarded_unit_id: String = "ca-app-pub-3940256099942544/5224354917"
@export var interstitial_unit_id: String = "ca-app-pub-3940256099942544/1033173712"
## Seconds to wait before retrying after an ad fails to load.
@export var reload_delay: float = 30.0
