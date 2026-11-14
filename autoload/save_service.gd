extends Node
## Persistent player progress under user://. Skeleton; implemented in Phase 5.

const SAVE_VERSION: int = 1
const SAVE_PATH: String = "user://save.json"

signal loaded
signal saved
