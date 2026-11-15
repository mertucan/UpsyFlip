class_name BillingBackend
extends Node
## Interface every store implements. Game code never talks to a backend
## directly; it goes through the BillingService autoload.
## Used as-is, this class is the "no store" backend for release builds that
## do not contain a real billing SDK.

enum PurchaseState { PURCHASED, PENDING, FAILED }

signal connected
## A purchase changed state, or an existing purchase was found by query_purchases().
signal purchase_updated(product_id: StringName, state: int, token: String)
signal consumed(token: String, success: bool)


## False for this base class: a build without a real store sells nothing.
func is_available() -> bool:
	return false


func connect_store() -> void:
	connected.emit()


## Reports every purchase the store still holds (owned or not yet consumed).
func query_purchases() -> void:
	pass


func purchase(_product_id: StringName) -> void:
	pass


func consume(token: String) -> void:
	consumed.emit(token, false)


func acknowledge(_token: String) -> void:
	pass


## Localized price from the store, or "" while unknown.
func price_text(_product_id: StringName) -> String:
	return ""
