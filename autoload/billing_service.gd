extends Node
## Facade for in-app purchases. Game code talks only to this node; the store
## behind it is a BillingBackend (mock, or Google Play Billing).
##
## Fulfilment rules:
## - PENDING purchases grant nothing until they become PURCHASED.
## - Consumables are granted only after the store confirms the consume.
## - Non-consumables are granted once and always acknowledged (Google
##   refunds purchases that are not acknowledged within 3 days).
## - On startup the store is queried so owned or unfinished purchases are
##   restored and completed.

signal purchase_completed(product_id: StringName)
signal purchase_pending(product_id: StringName)
signal purchase_failed(product_id: StringName)

const CATALOG_PATH: String = "res://data/product_catalog.tres"
const SAVE_KEY_OWNED: String = "owned_products"

var catalog: ProductCatalog

var _backend: BillingBackend
var _owned: Array[StringName] = []
## Consume requests in flight: token -> product id.
var _consuming: Dictionary[String, StringName] = {}


func _ready() -> void:
	catalog = load(CATALOG_PATH) as ProductCatalog
	reload()
	set_backend(_create_backend())


## The free mock store exists only in debug builds. A release build without
## a real billing SDK gets the inert base backend, so nothing can be "bought".
func _create_backend() -> BillingBackend:
	if OS.is_debug_build():
		return MockBillingBackend.new()
	return BillingBackend.new()


func is_available() -> bool:
	return _backend != null and _backend.is_available()


## Re-reads owned products from the SaveService.
func reload() -> void:
	_owned.clear()
	_consuming.clear()
	var saved: Variant = SaveService.get_value(SAVE_KEY_OWNED)
	if saved is Array:
		for product_id: Variant in saved:
			_owned.append(StringName(str(product_id)))


## Swaps the store and restores existing purchases from it.
func set_backend(backend: BillingBackend) -> void:
	if _backend != null:
		_backend.queue_free()
	_backend = backend
	add_child(backend)
	backend.connected.connect(backend.query_purchases)
	backend.purchase_updated.connect(_on_purchase_updated)
	backend.consumed.connect(_on_consumed)
	backend.connect_store()


func get_backend() -> BillingBackend:
	return _backend


func owns(product_id: StringName) -> bool:
	return _owned.has(product_id)


func can_purchase(product: ProductData) -> bool:
	return product.consumable or not owns(product.id)


func price_text(product: ProductData) -> String:
	return _backend.price_text(product.id)


func purchase(product_id: StringName) -> void:
	var product: ProductData = catalog.find(product_id)
	if product == null or not is_available() or not can_purchase(product):
		purchase_failed.emit(product_id)
		return
	_backend.purchase(product_id)


func _on_purchase_updated(product_id: StringName, state: int, token: String) -> void:
	var product: ProductData = catalog.find(product_id)
	if product == null:
		return
	match state:
		BillingBackend.PurchaseState.PENDING:
			purchase_pending.emit(product_id)
		BillingBackend.PurchaseState.FAILED:
			purchase_failed.emit(product_id)
		BillingBackend.PurchaseState.PURCHASED:
			if product.consumable:
				if not _consuming.has(token):
					_consuming[token] = product_id
					_backend.consume(token)
			else:
				_backend.acknowledge(token)
				if not owns(product_id):
					_owned.append(product_id)
					_grant(product)
					_finish(product)


func _on_consumed(token: String, success: bool) -> void:
	if not _consuming.has(token):
		return
	var product: ProductData = catalog.find(_consuming[token])
	_consuming.erase(token)
	if not success:
		purchase_failed.emit(product.id)
		return
	_grant(product)
	_finish(product)


func _grant(product: ProductData) -> void:
	Economy.add_coins(product.coins)
	Economy.add_gems(product.gems)
	if product.removes_ads:
		AdsService.set_ads_removed(true)
	if product.skin_id != &"":
		PlayerProgress.grant_skin(product.skin_id)


func _finish(product: ProductData) -> void:
	var owned_ids: Array[String] = []
	for product_id: StringName in _owned:
		owned_ids.append(String(product_id))
	SaveService.set_value(SAVE_KEY_OWNED, owned_ids)
	SaveService.save_to_disk()
	Analytics.log_event("purchase", {"product": String(product.id)})
	purchase_completed.emit(product.id)
