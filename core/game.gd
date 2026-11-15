extends Node3D
## Main scene: endless seeded climb plus the menu -> play -> results flow.
## The world keeps running behind the menu so play starts with one tap.

enum Flow { MENU, PLAYING, RESULTS }

const FEEL_CONFIG_PATH: String = "res://data/feel_config.tres"
const LEVEL_CONFIG_PATH: String = "res://data/level_config.tres"

const SAVE_KEY_BEST_SCORE: String = "best_score"
const SAVE_KEY_BEST_HEIGHT: String = "best_height"

const SPAWN_AHEAD: float = 6.0
const CULL_BELOW: float = 4.0
const PLANK_DEPTH: float = 1.4
const BACKDROP_Z: float = -1.5
const BAR_COUNT: int = 8
const STRIPE_COUNT: int = 16
const MAX_FRAME_DELTA: float = 0.1
## Seconds of 3-2-1 countdown after the app returns from the background.
const RESUME_COUNTDOWN: float = 3.0
const THEME_VIBRATE_MS: int = 60

const COLOR_BLADE: Color = Color(0.93, 0.95, 0.98)
const COLOR_TIP: Color = Color(1.0, 0.82, 0.25)
const COLOR_HANDLE: Color = Color(1.0, 0.33, 0.36)
const COLOR_BEST_LINE: Color = Color(1.0, 0.86, 0.3)
const COLOR_BALLOON: Color = Color(1.0, 0.4, 0.55)
const COLOR_WATERMELON: Color = Color(0.3, 0.75, 0.35)
const COLOR_WATERMELON_FLESH: Color = Color(0.95, 0.3, 0.35)
const COLOR_TARGET_CENTER: Color = Color(0.97, 0.97, 0.97)
const COLOR_COIN_TEXT: Color = Color(1.0, 0.86, 0.3)
const COLOR_TRAIL: Color = Color(0.93, 0.95, 0.98)
const COLOR_FEVER: Color = Color(1.0, 0.5, 0.15)

var _feel: FeelConfig
var _level: LevelConfig
var _sim: FlightSim
var _generator: LevelGenerator
var _score: ScoreKeeper
var _camera: ClimbCamera
var _hud: Hud
var _knife: Node3D
var _environment: Environment
var _wall_material: StandardMaterial3D
var _stripe_material: StandardMaterial3D
var _walls: Array[MeshInstance3D] = []
var _stripes: Array[MeshInstance3D] = []
var _bars: Array[MeshInstance3D] = []
var _backdrop_ordinal: int = -1
var _best_line: Node3D
var _surface_nodes: Dictionary[SurfaceRect, Node3D] = {}
var _pickup_nodes: Dictionary[Pickup, Node3D] = {}
var _static_materials: Dictionary[Color, StandardMaterial3D] = {}

var _flow: Flow = Flow.MENU
var _menu: MainMenu
var _results: ResultsPanel
var _shop: ShopSheet
var _missions_sheet: MissionsSheet
var _daily_sheet: DailySheet
var _settings_sheet: SettingsSheet
var _store: StoreSheet
## Skin being played for one run via the "try" rewarded ad.
var _trial_active: bool = false
var _pending_trial: SkinData
var _continue_used: bool = false
var _last_rewards: RunRewards
## Run totals already banked by an earlier death in the same run (continue).
var _banked_coins: int = 0
var _banked_perfects: int = 0
var _banked_sticks: int = 0
var _banked_height: int = 0
## Run frozen because the app lost focus or went to the background.
var _paused: bool = false
var _resume_countdown: float = 0.0
var _trail_color: Color = COLOR_TRAIL
var _run_seed: int = 0
var _run_time: float = 0.0
var _run_perfects: int = 0
var _run_sticks: int = 0
var _skin: SkinData
var _accumulator: float = 0.0
var _theme_ordinal: int = 0
var _dead_time: float = 0.0
var _charging: bool = false
var _charge_direction: int = 1
var _charge_elapsed: float = 0.0
var _combo: ComboTracker
var _trail: CPUParticles3D
var _surface_colors: Dictionary[SurfaceRect, Color] = {}
var _time_scale: float = 1.0
var _slowmo_left: float = 0.0
var _slowmo_scale: float = 1.0
## Seconds since the last stick; drives the visual wobble.
var _wobble_elapsed: float = 100.0


func _ready() -> void:
	GraphicsSettings.apply_saved_locale()
	_feel = (load(FEEL_CONFIG_PATH) as FeelConfig).duplicate() as FeelConfig
	_level = load(LEVEL_CONFIG_PATH) as LevelConfig
	_build_world()
	_hud = Hud.new()
	add_child(_hud)
	_build_menus()
	_select_skin(PlayerProgress.selected_skin())
	_reset_run()
	_set_flow(Flow.MENU)
	_apply_graphics()
	_apply_debug_preview()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_pause_run()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			_resume_run()


## Freezes an active run (phone call, screen off, app switch).
func _pause_run() -> void:
	if _flow != Flow.PLAYING or _paused or _hud == null:
		return
	_paused = true
	_resume_countdown = 0.0
	_charging = false
	_hud.show_power(false)
	_hud.show_center_text(tr("PAUSED"))


## Starts the 3-2-1 countdown that leads back into the run.
func _resume_run() -> void:
	if not _paused:
		return
	_paused = false
	_resume_countdown = RESUME_COUNTDOWN


func _is_frozen() -> bool:
	return _paused or _resume_countdown > 0.0


func _process(delta: float) -> void:
	delta = minf(delta, MAX_FRAME_DELTA)
	if _paused:
		return
	if _resume_countdown > 0.0:
		_resume_countdown -= delta
		_hud.show_center_text(str(ceili(_resume_countdown)) if _resume_countdown > 0.0 else "")
		return
	if _flow == Flow.PLAYING and GraphicsSettings.track_performance(delta, Engine.get_frames_per_second()):
		_apply_graphics()
	if _charging:
		_charge_elapsed += delta
		_hud.show_power(true, _charge_power())

	# Slow motion scales how much simulated time passes per frame; the sim
	# itself still advances in fixed steps, so it stays deterministic.
	if _slowmo_left > 0.0:
		_slowmo_left -= delta
		_time_scale = _slowmo_scale
	else:
		_time_scale = lerpf(_time_scale, 1.0, 1.0 - exp(-_feel.slowmo_recover_speed * delta))
	var sim_delta: float = delta * _time_scale
	_accumulator += sim_delta
	while _accumulator >= _feel.sim_step:
		_accumulator -= _feel.sim_step
		_sim.step(_feel.sim_step)
	_combo.advance(sim_delta)
	_hud.set_fever(_combo.is_fever(), _combo.fever_fraction())

	_wobble_elapsed += delta
	_update_knife_visual()

	var anchor_offset: float = _camera.half_height() * _feel.camera_anchor
	if _sim.state == FlightSim.State.STUCK:
		_camera.follow(_sim.position.y + anchor_offset, delta)
	elif _sim.state == FlightSim.State.FLYING:
		_camera.follow(_sim.position.y + anchor_offset - _feel.camera_flight_slack, delta)
	else:
		_camera.follow(-INF, delta)
	_sim.kill_y = _camera.bottom_y() - _feel.death_margin

	_spawn_rows()
	_cull_below_view()
	_sync_level_nodes()
	_update_backdrop()

	if _flow == Flow.PLAYING:
		_run_time += delta
	elif _flow == Flow.RESULTS:
		_dead_time += delta


func _unhandled_input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch == null or _flow == Flow.MENU or _is_frozen():
		return
	var direction: int = -1 if touch.position.x < get_viewport().get_visible_rect().size.x * 0.5 else 1

	if _flow == Flow.RESULTS:
		if touch.pressed and _dead_time >= _feel.restart_delay:
			_end_trial()
			_reset_run()
			_start_play()
		return

	if _feel.hold_to_charge:
		if touch.pressed and _sim.can_launch():
			_charging = true
			_charge_direction = direction
			_charge_elapsed = 0.0
			_hud.show_power(true, 0.0)
		elif not touch.pressed and _charging:
			_charging = false
			_hud.show_power(false)
			_sim.launch(_charge_direction, _charge_power())
	elif touch.pressed:
		_sim.launch(direction)


func _charge_power() -> float:
	return clampf(_charge_elapsed / _feel.charge_time, 0.0, 1.0)


## Places the knife model, adding a decaying wobble around the tip after a stick.
func _update_knife_visual() -> void:
	var visual_angle: float = _sim.angle
	if _sim.state == FlightSim.State.STUCK:
		visual_angle += deg_to_rad(_feel.wobble_angle_deg) \
				* exp(-_feel.wobble_damping * _wobble_elapsed) \
				* sin(_feel.wobble_frequency * _wobble_elapsed)
	var tip: Vector2 = _sim.tip_point()
	var pivot: Vector2 = tip - _sim.active_tip_local().rotated(visual_angle)
	_knife.position = Vector3(pivot.x, pivot.y, 0.0)
	_knife.rotation.z = visual_angle
	_trail.emitting = _sim.state == FlightSim.State.FLYING or _sim.state == FlightSim.State.RETURNING


func _start_slowmo(time_scale: float, duration: float) -> void:
	_slowmo_scale = time_scale
	_slowmo_left = duration
	_time_scale = time_scale


func _tip_position_3d() -> Vector3:
	var tip: Vector2 = _sim.tip_point()
	return Vector3(tip.x, tip.y, 0.0)


# --- Run flow ---------------------------------------------------------------

func _reset_run() -> void:
	for node: Node3D in _surface_nodes.values():
		node.queue_free()
	_surface_nodes.clear()
	_surface_colors.clear()
	for node: Node3D in _pickup_nodes.values():
		node.queue_free()
	_pickup_nodes.clear()

	_run_seed = GameState.next_run_seed()
	_generator = LevelGenerator.new(_level, _run_seed)
	_score = ScoreKeeper.new()
	_combo = ComboTracker.new(_feel)
	_combo.fever_started.connect(_on_fever_started)
	_combo.fever_ended.connect(_on_fever_ended)
	_sim = FlightSim.new(_feel, _skin)
	_sim.launched.connect(_on_launched)
	_sim.shot_fired.connect(_on_shot_fired)
	_sim.return_started.connect(_on_return_started)
	_sim.returned.connect(_on_returned)
	_sim.stuck.connect(_on_stuck)
	_sim.bounced.connect(_on_bounced)
	_sim.pickup_collected.connect(_on_pickup_collected)
	_sim.died.connect(_on_died)

	for side: int in [-1, 1]:
		var wall: SurfaceRect = SurfaceRect.new(_level.wall_rect(side), SurfaceRect.FACES_NONE)
		wall.permanent = true
		_sim.surfaces.append(wall)

	var floor_surface: SurfaceRect = SurfaceRect.new(_level.floor_rect())
	_add_surface(floor_surface, 0.0)
	_sim.place_stuck_in(Vector2(_level.start_x, 0.0), -PI * 0.5, floor_surface)

	_theme_ordinal = 0
	_dead_time = 0.0
	_run_time = 0.0
	_run_perfects = 0
	_run_sticks = 0
	_continue_used = false
	_banked_coins = 0
	_banked_perfects = 0
	_banked_sticks = 0
	_banked_height = 0
	_accumulator = 0.0
	_charging = false
	_time_scale = 1.0
	_slowmo_left = 0.0
	_wobble_elapsed = 100.0
	_backdrop_ordinal = -1
	Burst.set_color(_trail, _trail_color)
	_hud.set_combo(0)
	_hud.set_fever(false)
	_camera.snap_to(_sim.position.y + _camera.half_height() * _feel.camera_anchor)
	_spawn_rows()
	_place_best_line()

	_hud.show_power(false)

	_update_ammo()
	_hud.set_score(0)
	_hud.set_coins(0)
	_hud.set_best(SaveService.get_int(SAVE_KEY_BEST_SCORE))



func _on_launched(_direction: int, _power: float) -> void:
	AudioService.play_sfx(&"launch", randf_range(0.92, 1.08))
	_update_ammo()


func _on_shot_fired(muzzle: Vector2, direction: Vector2) -> void:
	AudioService.play_sfx(&"shot", randf_range(0.95, 1.05))
	Haptics.vibrate(_feel.perfect_vibrate_ms)
	_camera.add_shake(_feel.shake_perfect)
	Burst.spawn(
			self, Vector3(muzzle.x, muzzle.y, 0.0), _skin.accent_color, 10, 7.0,
			Vector3(direction.x, direction.y, 0.0), 25.0, 0.25, 0.08)
	_update_ammo()


func _on_return_started() -> void:
	_combo.register_miss()
	_hud.set_combo(0)
	_hud.flash("SECOND CHANCE", _skin.primary_color)
	AudioService.play_sfx(&"return")
	Haptics.vibrate(_feel.stick_vibrate_ms)


func _on_returned() -> void:
	_wobble_elapsed = 0.0
	AudioService.play_sfx(&"stick")
	Haptics.vibrate(_feel.stick_vibrate_ms)
	_update_ammo()


func _update_ammo() -> void:
	_hud.set_ammo(_sim.charges_left, _skin.ability_charges)


func _on_stuck(quality: int, surface: SurfaceRect) -> void:
	var tip: Vector2 = _sim.tip_point()
	var is_perfect: bool = quality == StickRules.Quality.PERFECT
	_run_sticks += 1
	if is_perfect:
		_run_perfects += 1
	_score.register_height(tip.y)
	_score.add_bonus(_combo.register_stick(quality))
	_hud.set_combo(_combo.multiplier())
	_update_ammo()
	_wobble_elapsed = 0.0
	Burst.spawn(
			self, _tip_position_3d(), _surface_colors.get(surface, COLOR_BLADE),
			14 if is_perfect else 8, 4.0, Vector3(0.0, 1.0, 0.6))

	var spec: PlatformSpec = surface.spec
	var is_target_hit: bool = spec != null and spec.kind == PlatformSpec.Kind.TARGET \
			and not surface.bonus_claimed
	if is_target_hit:
		surface.bonus_claimed = true
		var points: int = spec.bonus_points
		var is_center: bool = absf(tip.x - surface.rect.get_center().x) <= spec.center_zone
		if is_center:
			points += spec.center_bonus_points
		_score.add_bonus(points)
		_hud.flash((tr("BULLSEYE +%d") if is_center else "+%d") % points, COLOR_TIP)
		AudioService.play_sfx(&"target")
		Haptics.vibrate(_feel.perfect_vibrate_ms)
		_camera.add_shake(_feel.shake_perfect)
	elif is_perfect:
		_hud.flash("PERFECT", COLOR_TIP)
		# Each PERFECT in a streak rings a little higher.
		AudioService.play_sfx(&"perfect", 1.0 + 0.06 * (_combo.multiplier() - 1))
		Haptics.vibrate(_feel.perfect_vibrate_ms)
		_camera.add_shake(_feel.shake_perfect)
		Burst.spawn(self, _tip_position_3d(), COLOR_TIP, 10, 5.0, Vector3.UP, 180.0, 0.4, 0.07)
		if _combo.is_fever():
			_start_slowmo(_feel.fever_slowmo_scale, _feel.fever_perfect_slowmo_time)
	else:
		AudioService.play_sfx(&"stick", randf_range(0.94, 1.06))
		Haptics.vibrate(_feel.stick_vibrate_ms)
		_camera.add_shake(_feel.shake_stick)

	var height_above_bottom: float = _sim.position.y - _camera.bottom_y()
	if StickRules.is_clutch(height_above_bottom, _sim.last_impact_velocity.y, _feel.clutch_zone):
		_score.add_bonus(_feel.clutch_points)
		_hud.show_banner("CLUTCH!", COLOR_HANDLE)
		AudioService.play_sfx(&"clutch")
		Haptics.play_pattern(_feel.clutch_haptic_pattern)
		_camera.add_shake(_feel.shake_clutch)
		_start_slowmo(_feel.clutch_slowmo_scale, _feel.clutch_slowmo_time)

	var ordinal: int = _level.theme_ordinal_at(float(_score.height))
	if ordinal > _theme_ordinal:
		_theme_ordinal = ordinal
		_hud.show_banner(_level.theme_by_ordinal(ordinal).display_name, Color.WHITE)
		AudioService.play_sfx(&"theme")
		Haptics.vibrate(THEME_VIBRATE_MS)

	GameState.current_score = _score.total()
	_hud.set_score(_score.total())


func _on_bounced(point: Vector2, normal: Vector2) -> void:
	_combo.register_miss()
	_hud.set_combo(0)
	_hud.flash("MISS", COLOR_HANDLE)
	AudioService.play_sfx(&"bounce", randf_range(0.9, 1.1))
	Haptics.vibrate(_feel.bounce_vibrate_ms)
	_camera.add_shake(_feel.shake_bounce)
	Burst.spawn(
			self, Vector3(point.x, point.y, 0.0), COLOR_BLADE, 5, 3.0,
			Vector3(normal.x, normal.y, 0.0), 50.0, 0.35, 0.06)


func _on_pickup_collected(pickup: Pickup) -> void:
	var coins: int = pickup.coins * _combo.coin_multiplier()
	_score.add_coins(coins)
	_hud.set_coins(_score.coins)
	_hud.flash("+%d" % coins, COLOR_COIN_TEXT)
	AudioService.play_sfx(&"coin")
	Haptics.vibrate(_feel.stick_vibrate_ms)
	var is_watermelon: bool = pickup.kind == Pickup.Kind.WATERMELON
	Burst.spawn(
			self, Vector3(pickup.position.x, pickup.position.y, 0.0),
			COLOR_WATERMELON_FLESH if is_watermelon else COLOR_BALLOON,
			16, 5.0, Vector3.UP, 180.0, 0.45, 0.1)
	# The sim is iterating its pickup list right now; it is pruned in
	# _cull_below_view instead.
	if _pickup_nodes.has(pickup):
		_pickup_nodes[pickup].queue_free()
		_pickup_nodes.erase(pickup)


func _on_fever_started() -> void:
	_hud.show_banner("FEVER!", COLOR_FEVER)
	AudioService.play_sfx(&"fever")
	Haptics.play_pattern(_feel.fever_haptic_pattern)
	Burst.set_color(_trail, COLOR_FEVER)
	_start_slowmo(_feel.fever_slowmo_scale, _feel.fever_slowmo_time)


func _on_fever_ended() -> void:
	Burst.set_color(_trail, _trail_color)


func _on_died() -> void:
	_charging = false
	_hud.show_power(false)
	_hud.set_combo(0)
	AudioService.play_sfx(&"death")
	Haptics.vibrate(_feel.death_vibrate_ms)
	_camera.add_shake(_feel.shake_death)

	# After a continue, only what was earned since then is banked again.
	var summary: RunSummary = RunSummary.new()
	summary.skin_id = _skin.id
	summary.height = _score.height
	summary.height_gain = _score.height - _banked_height
	summary.score = _score.total()
	summary.coins = _score.coins - _banked_coins
	summary.perfects = _run_perfects - _banked_perfects
	summary.sticks = _run_sticks - _banked_sticks
	summary.duration = _run_time
	summary.death_reason = _sim.death_reason
	summary.is_continuation = _continue_used
	_banked_coins = _score.coins
	_banked_perfects = _run_perfects
	_banked_sticks = _run_sticks
	_banked_height = _score.height

	var previous_best: int = SaveService.get_int(SAVE_KEY_BEST_SCORE)
	var is_new_best: bool = summary.score > previous_best
	if is_new_best:
		SaveService.set_value(SAVE_KEY_BEST_SCORE, summary.score)
		SaveService.set_value(SAVE_KEY_BEST_HEIGHT, summary.height)
	# record_run banks coins, missions and mastery, then writes the save file.
	_last_rewards = PlayerProgress.record_run(summary)
	Analytics.log_event("run_end", {
		"score": summary.score, "height": summary.height,
		"duration": snappedf(summary.duration, 0.1), "skin": String(summary.skin_id),
		"death_reason": summary.death_reason, "continued": _continue_used,
	})
	GameState.end_run()

	var can_continue: bool = not _continue_used and AdsService.is_rewarded_ready() \
			and summary.height >= RemoteConfig.get_int("continue_min_height")
	var can_double: bool = summary.coins > 0 and AdsService.is_rewarded_ready()
	_results.show_results(
			summary, _last_rewards, is_new_best, maxi(previous_best, summary.score),
			can_continue, can_double)
	_set_flow(Flow.RESULTS)
	AdsService.notify_run_finished(_run_time)


# --- Rewarded ads -----------------------------------------------------------

func _on_rewarded_completed(placement: StringName) -> void:
	match placement:
		AdsService.PLACEMENT_CONTINUE:
			if _flow == Flow.RESULTS and not _continue_used:
				_revive()
		AdsService.PLACEMENT_DOUBLE_COINS:
			if _flow == Flow.RESULTS and _last_rewards != null:
				Economy.add_coins(_last_rewards.run_coins)
				SaveService.save_to_disk()
				_results.show_doubled(_last_rewards.run_coins * 2)
				AudioService.play_sfx(&"coin")
		AdsService.PLACEMENT_TRY_SKIN:
			if _pending_trial != null:
				_start_trial(_pending_trial)
		AdsService.PLACEMENT_FREE_COINS:
			if PlayerProgress.claim_free_coins() > 0:
				AudioService.play_sfx(&"coin")
			_menu.refresh()
	_pending_trial = null


## Second life after a rewarded ad: the object is put back on the platform
## nearest to its usual resting height and the same run goes on.
func _revive() -> void:
	var resting_y: float = _camera.position.y - _camera.half_height() * _feel.camera_anchor
	var floor_y: float = _camera.bottom_y() + 1.0
	var best: SurfaceRect = null
	for surface: SurfaceRect in _surface_nodes:
		var top: float = surface.rect.end.y
		if top < floor_y:
			continue
		if best == null or absf(top - resting_y) < absf(best.rect.end.y - resting_y):
			best = surface
	if best == null:
		return
	_continue_used = true
	_sim.place_stuck_in(Vector2(best.rect.get_center().x, best.rect.end.y), -PI * 0.5, best)
	_wobble_elapsed = 0.0
	_dead_time = 0.0
	GameState.is_run_active = true
	AudioService.play_sfx(&"theme")
	Haptics.vibrate(_feel.perfect_vibrate_ms)
	_update_ammo()
	_set_flow(Flow.PLAYING)


func _on_try_requested(skin: SkinData) -> void:
	_pending_trial = skin
	AdsService.show_rewarded(AdsService.PLACEMENT_TRY_SKIN)


## Plays one run with a locked skin, starting right away.
func _start_trial(skin: SkinData) -> void:
	_shop.close()
	_trial_active = true
	_select_skin(skin)
	_reset_run()
	_start_play()


func _end_trial() -> void:
	if _trial_active:
		_trial_active = false
		_select_skin(PlayerProgress.selected_skin())


# --- Flow and menus ---------------------------------------------------------

func _set_flow(flow: Flow) -> void:
	_flow = flow
	_menu.visible = flow == Flow.MENU
	_results.visible = flow == Flow.RESULTS
	_hud.visible = flow == Flow.PLAYING
	_paused = false
	_resume_countdown = 0.0
	_hud.show_center_text("")
	GraphicsSettings.apply_frame_cap(flow == Flow.MENU)
	if flow == Flow.MENU:
		_menu.refresh()


func _apply_graphics() -> void:
	GraphicsSettings.apply_to(get_viewport())
	GraphicsSettings.apply_frame_cap(_flow == Flow.MENU)


func _on_language_changed() -> void:
	(_best_line.get_child(1) as Label3D).text = tr("BEST")
	_menu.refresh()


func _start_play() -> void:
	_set_flow(Flow.PLAYING)
	GameState.start_run(_run_seed)
	Analytics.log_event("run_start", {"skin": String(_skin.id), "seed": _run_seed})


func _on_home_pressed() -> void:
	_trial_active = false
	_select_skin(PlayerProgress.selected_skin())
	_reset_run()
	_set_flow(Flow.MENU)


## The selected skin changed in the shop: show it in the world right away.
func _on_skin_changed() -> void:
	_select_skin(PlayerProgress.selected_skin())
	_reset_run()


func _select_skin(skin: SkinData) -> void:
	_skin = skin
	if _knife != null:
		_knife.queue_free()
	_knife = SkinModels.build(_skin)
	add_child(_knife)
	_trail_color = PlayerProgress.trail_color(_skin)
	_trail = Burst.make_trail(_knife, _trail_color)


## Debug builds only: `-- --locale=ja --preview=shop|missions|daily|settings|store|results`
## opens a screen at startup so UI can be checked without input.
func _apply_debug_preview() -> void:
	if not OS.is_debug_build():
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--locale="):
			TranslationServer.set_locale(argument.trim_prefix("--locale="))
			_on_language_changed()
		match argument:
			"--preview=shop":
				_shop.open()
			"--preview=missions":
				_missions_sheet.open()
			"--preview=daily":
				_daily_sheet.open()
			"--preview=settings":
				_settings_sheet.open()
			"--preview=store":
				_store.open()
			"--preview=results":
				var summary: RunSummary = RunSummary.new()
				summary.skin_id = _skin.id
				summary.score = 57
				var rewards: RunRewards = RunRewards.new()
				rewards.run_coins = 6
				rewards.completed_missions = PlayerProgress.todays_missions().slice(0, 1)
				rewards.mastery_level_up = 2
				_results.show_results(summary, rewards, true, 57, true, true)
				_set_flow(Flow.RESULTS)


func _build_menus() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 2
	add_child(layer)

	_menu = MainMenu.new()
	layer.add_child(_menu)
	_results = ResultsPanel.new()
	layer.add_child(_results)
	_shop = ShopSheet.new()
	layer.add_child(_shop)
	_missions_sheet = MissionsSheet.new()
	layer.add_child(_missions_sheet)
	_daily_sheet = DailySheet.new()
	layer.add_child(_daily_sheet)
	_settings_sheet = SettingsSheet.new()
	layer.add_child(_settings_sheet)
	_store = StoreSheet.new()
	layer.add_child(_store)

	_menu.play_pressed.connect(_start_play)
	_menu.shop_pressed.connect(_shop.open)
	_menu.missions_pressed.connect(_missions_sheet.open)
	_menu.daily_pressed.connect(_daily_sheet.open)
	_menu.settings_pressed.connect(_settings_sheet.open)
	_results.home_pressed.connect(_on_home_pressed)
	_shop.skin_changed.connect(_on_skin_changed)
	_shop.try_requested.connect(_on_try_requested)
	_menu.store_pressed.connect(_store.open)
	_menu.free_coins_pressed.connect(
			func() -> void: AdsService.show_rewarded(AdsService.PLACEMENT_FREE_COINS))
	_results.continue_pressed.connect(
			func() -> void: AdsService.show_rewarded(AdsService.PLACEMENT_CONTINUE))
	_results.double_pressed.connect(
			func() -> void: AdsService.show_rewarded(AdsService.PLACEMENT_DOUBLE_COINS))
	AdsService.rewarded_completed.connect(_on_rewarded_completed)
	_settings_sheet.graphics_changed.connect(_apply_graphics)
	_settings_sheet.language_changed.connect(_on_language_changed)
	for sheet: Sheet in [_shop, _missions_sheet, _daily_sheet, _settings_sheet, _store]:
		sheet.closed.connect(_menu.refresh)


# --- Level ------------------------------------------------------------------

func _spawn_rows() -> void:
	while _generator.last_top < _camera.top_y() + SPAWN_AHEAD:
		var spec: PlatformSpec = _generator.next()
		var surface: SurfaceRect = SurfaceRect.from_spec(spec)
		surface.advance(_sim.time)
		_add_surface(surface, spec.rect.end.y)
		if spec.pickup != null:
			_add_pickup(spec.pickup)


func _cull_below_view() -> void:
	var limit: float = _camera.bottom_y() - CULL_BELOW
	for surface: SurfaceRect in _surface_nodes.keys():
		if surface.rect.end.y < limit and surface != _sim.stuck_surface and surface != _sim.return_surface:
			_surface_nodes[surface].queue_free()
			_surface_nodes.erase(surface)
			_surface_colors.erase(surface)
			_sim.surfaces.erase(surface)
	for index: int in range(_sim.pickups.size() - 1, -1, -1):
		var pickup: Pickup = _sim.pickups[index]
		if pickup.collected or pickup.position.y < limit:
			_sim.pickups.remove_at(index)
			if _pickup_nodes.has(pickup):
				_pickup_nodes[pickup].queue_free()
				_pickup_nodes.erase(pickup)


func _sync_level_nodes() -> void:
	for surface: SurfaceRect in _surface_nodes:
		if surface.is_moving():
			_surface_nodes[surface].position.x = surface.rect.get_center().x
	for pickup: Pickup in _pickup_nodes:
		var bob: float = sin(_sim.time * 2.5 + pickup.position.x * 3.0) * 0.08
		_pickup_nodes[pickup].position.y = pickup.position.y + bob


## Platform colors come from the theme at the platform's own height, so a
## theme change scrolls into view gradually.
func _add_surface(surface: SurfaceRect, theme_height: float) -> void:
	_sim.surfaces.append(surface)
	var rect: Rect2 = surface.rect
	var spec: PlatformSpec = surface.spec
	var color_property: StringName = &"platform_color"
	if spec != null and spec.kind == PlatformSpec.Kind.MOVING:
		color_property = &"moving_platform_color"
	elif spec != null and spec.kind == PlatformSpec.Kind.TARGET:
		color_property = &"target_color"

	var node: Node3D = Node3D.new()
	var center: Vector2 = rect.get_center()
	node.position = Vector3(center.x, center.y, 0.0)
	var color: Color = _level.blended_color(theme_height, color_property)
	_surface_colors[surface] = color
	node.add_child(_make_plank(
			rect.size, color, _level.blended_color(theme_height, &"platform_underside_color")))
	if spec != null and spec.kind == PlatformSpec.Kind.TARGET:
		var bullseye: MeshInstance3D = _make_box(
				Vector3(spec.center_zone * 2.0, rect.size.y + 0.04, PLANK_DEPTH + 0.04),
				_static_material(COLOR_TARGET_CENTER))
		node.add_child(bullseye)
	add_child(node)
	_surface_nodes[surface] = node


## Chamfered low-poly plank: colored upper part (sticks) over a darker
## underside (bounces).
func _make_plank(size: Vector2, color: Color, underside_color: Color) -> MeshInstance3D:
	var half: Vector2 = size * 0.5
	var chamfer: float = minf(0.07, half.y * 0.4)
	var split: float = -half.y + minf(0.1, size.y * 0.25)
	var builder: LowPoly = LowPoly.new(Rect2(-half, size))
	builder.add_extrusion(PackedVector2Array([
		Vector2(-half.x, split), Vector2(half.x, split), Vector2(half.x, half.y - chamfer),
		Vector2(half.x - chamfer, half.y), Vector2(-half.x + chamfer, half.y),
		Vector2(-half.x, half.y - chamfer),
	]), PLANK_DEPTH, color)
	builder.add_extrusion(PackedVector2Array([
		Vector2(-half.x + chamfer, -half.y), Vector2(half.x - chamfer, -half.y),
		Vector2(half.x, split), Vector2(-half.x, split),
	]), PLANK_DEPTH, underside_color)
	return builder.build()


func _add_pickup(pickup: Pickup) -> void:
	_sim.pickups.append(pickup)
	var node: Node3D = Node3D.new()
	node.position = Vector3(pickup.position.x, pickup.position.y, 0.0)
	if pickup.kind == Pickup.Kind.WATERMELON:
		node.add_child(_make_watermelon(pickup.radius))
	else:
		node.add_child(_make_balloon(pickup.radius))
	add_child(node)
	_pickup_nodes[pickup] = node


## Low-poly balloon: faceted body, knot and a short string.
func _make_balloon(radius: float) -> MeshInstance3D:
	var builder: LowPoly = LowPoly.new(Rect2(-radius, -radius * 2.2, radius * 2.0, radius * 3.4))
	var body: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in LowPoly.regular_polygon(Vector2.ZERO, radius, 8, PI / 8.0):
		body.append(Vector2(point.x, point.y * 1.2))
	builder.add_extrusion(body, radius * 1.3, COLOR_BALLOON)
	builder.add_extrusion(PackedVector2Array([
		Vector2(0.0, -radius * 1.1), Vector2(radius * 0.22, -radius * 1.4),
		Vector2(-radius * 0.22, -radius * 1.4),
	]), radius * 0.4, COLOR_BALLOON.darkened(0.25))
	builder.add_box(
			Rect2(-0.015, -radius * 2.2, 0.03, radius * 0.8), 0.03, COLOR_TARGET_CENTER)
	return builder.build()


## Low-poly watermelon: green rind with a red cut face and dark seeds.
func _make_watermelon(radius: float) -> MeshInstance3D:
	var builder: LowPoly = LowPoly.new(Rect2(-radius * 1.2, -radius, radius * 2.4, radius * 2.0))
	var rind: PackedVector2Array = PackedVector2Array()
	var flesh: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in LowPoly.regular_polygon(Vector2.ZERO, radius, 10):
		rind.append(Vector2(point.x * 1.2, point.y))
		flesh.append(Vector2(point.x * 1.2, point.y) * 0.78)
	builder.add_extrusion(rind, radius * 1.2, COLOR_WATERMELON)
	builder.add_extrusion(flesh, radius * 1.3, COLOR_WATERMELON_FLESH)
	for seed_position: Vector2 in [Vector2(-0.4, 0.2), Vector2(0.3, 0.3), Vector2(0.0, -0.3), Vector2(0.45, -0.15)]:
		builder.add_box(
				Rect2(seed_position * radius - Vector2(0.025, 0.04), Vector2(0.05, 0.08)),
				radius * 1.36, Color(0.15, 0.1, 0.1))
	return builder.build()


func _place_best_line() -> void:
	var best_height: int = SaveService.get_int(SAVE_KEY_BEST_HEIGHT)
	_best_line.visible = best_height > 0
	_best_line.position.y = float(best_height)


func _update_backdrop() -> void:
	var height: float = _camera.position.y
	var background: Color = _level.blended_color(height, &"background_color")
	if _combo.is_fever():
		background = background.lerp(COLOR_FEVER, 0.22)
	_environment.background_color = background
	_wall_material.albedo_color = _level.blended_color(height, &"wall_color")
	_stripe_material.albedo_color = _level.blended_color(height, &"stripe_color")
	for wall: MeshInstance3D in _walls:
		wall.position.y = height
	var ordinal: int = _level.theme_ordinal_at(height)
	var theme: ThemeData = _level.theme_by_ordinal(ordinal)
	var first: float = floorf(_camera.bottom_y() / theme.stripe_spacing) * theme.stripe_spacing
	for index: int in _stripes.size():
		_stripes[index].position.y = first + index * theme.stripe_spacing
	if ordinal != _backdrop_ordinal:
		_backdrop_ordinal = ordinal
		_layout_bars(theme)
	for bar: MeshInstance3D in _bars:
		bar.position.y = height


## Vertical backdrop bars (tile seams, tree trunks...) for the current theme.
func _layout_bars(theme: ThemeData) -> void:
	for index: int in _bars.size():
		var bar: MeshInstance3D = _bars[index]
		var x: float = -_level.wall_x + (index + 0.5) * theme.bar_spacing
		bar.visible = theme.bar_spacing > 0.0 and x < _level.wall_x - theme.bar_width * 0.5
		bar.position.x = x
		(bar.mesh as BoxMesh).size.x = theme.bar_width


# --- Scene construction -----------------------------------------------------

func _build_world() -> void:
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.78, 0.8, 0.9)
	_environment.ambient_light_energy = 0.7
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = _environment
	add_child(world_environment)

	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50.0, -25.0, 0.0)
	add_child(light)

	_camera = ClimbCamera.new()
	add_child(_camera)
	_camera.setup(_feel.camera_half_width, _feel.camera_fov_deg, _feel.camera_follow_speed)
	_camera.shake_max_offset = _feel.shake_max_offset
	_camera.shake_decay = _feel.shake_decay

	_wall_material = StandardMaterial3D.new()
	for side: int in [-1, 1]:
		var wall: MeshInstance3D = _make_box(Vector3(_level.wall_thickness, 80.0, 3.0), _wall_material)
		wall.position.x = side * (_level.wall_x + _level.wall_thickness * 0.5)
		add_child(wall)
		_walls.append(wall)

	_stripe_material = StandardMaterial3D.new()
	_stripe_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for index: int in STRIPE_COUNT:
		var stripe: MeshInstance3D = _make_box(
				Vector3(_level.wall_x * 2.0, 0.12, 0.05), _stripe_material)
		stripe.position.z = BACKDROP_Z
		add_child(stripe)
		_stripes.append(stripe)
	for index: int in BAR_COUNT:
		var bar: MeshInstance3D = _make_box(Vector3(0.1, 80.0, 0.05), _stripe_material)
		bar.position.z = BACKDROP_Z
		add_child(bar)
		_bars.append(bar)

	_best_line = _build_best_line()
	add_child(_best_line)


func _build_best_line() -> Node3D:
	var line: Node3D = Node3D.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = COLOR_BEST_LINE
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var bar: MeshInstance3D = _make_box(Vector3(_level.wall_x * 2.0, 0.07, 0.05), material)
	bar.position.z = BACKDROP_Z + 0.2
	line.add_child(bar)
	var label: Label3D = Label3D.new()
	label.text = tr("BEST")
	label.font_size = 96
	label.pixel_size = 0.004
	label.modulate = COLOR_BEST_LINE
	label.outline_modulate = Color(0.05, 0.06, 0.12)
	label.position = Vector3(0.0, 0.3, BACKDROP_Z + 0.2)
	line.add_child(label)
	return line


func _make_box(size: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	return instance


func _new_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	return material


## Shared material for colors that never change at runtime.
func _static_material(color: Color) -> StandardMaterial3D:
	if not _static_materials.has(color):
		_static_materials[color] = _new_material(color)
	return _static_materials[color]
