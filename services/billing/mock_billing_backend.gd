class_name MockBillingBackend
extends BillingBackend
## Stand-in store for desktop and tests. Purchases succeed instantly and
## cost nothing, so it is only ever created in debug builds.

## State the next purchase() reports; tests set this to PENDING or FAILED.
var next_state: PurchaseState = PurchaseState.PURCHASED
var acknowledged: Array[String] = []
var consumed_tokens: Array[String] = []

## token -> product id for purchases the mock store still holds.
var _held: Dictionary[String, StringName] = {}
var _next_token: int = 1


func is_available() -> bool:
	return true


func query_purchases() -> void:
	for token: String in _held.keys():
		purchase_updated.emit(_held[token], PurchaseState.PURCHASED, token)


func purchase(product_id: StringName) -> void:
	var token: String = "mock-%d" % _next_token
	_next_token += 1
	if next_state != PurchaseState.FAILED:
		_held[token] = product_id
	purchase_updated.emit(product_id, next_state, token)


## Simulates a PENDING payment clearing later.
func complete_pending(token: String) -> void:
	if _held.has(token):
		purchase_updated.emit(_held[token], PurchaseState.PURCHASED, token)


func consume(token: String) -> void:
	var known: bool = _held.has(token)
	if known:
		_held.erase(token)
		consumed_tokens.append(token)
	consumed.emit(token, known)


func acknowledge(token: String) -> void:
	if not acknowledged.has(token):
		acknowledged.append(token)


func price_text(_product_id: StringName) -> String:
	return "TEST"
