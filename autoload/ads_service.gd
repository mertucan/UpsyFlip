extends Node
## Facade for rewarded/interstitial ads. Game code talks only to this node;
## the real (AdMob) and mock backends are plugged in during Phase 6.

signal rewarded_completed(placement: String)
signal rewarded_failed(placement: String)
signal interstitial_closed
