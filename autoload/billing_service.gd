extends Node
## Facade for in-app purchases. Game code talks only to this node;
## the real (Play Billing) and mock backends are plugged in during Phase 6.

signal purchase_completed(product_id: String)
signal purchase_failed(product_id: String)
