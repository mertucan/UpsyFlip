class_name ProductCatalog
extends Resource
## Every in-app product, in store display order.

@export var products: Array[ProductData] = []


func find(product_id: StringName) -> ProductData:
	for product: ProductData in products:
		if product.id == product_id:
			return product
	return null
