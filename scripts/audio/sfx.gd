extends Node

# Plays one-shot sounds (SoundEvents) from anywhere: Sfx.play(event)
# Registered as an autoload called "Sfx", so it exists in every scene,
# including menus.
#
# It keeps a small "pool" of AudioStreamPlayers and reuses them, instead of
# creating a new node per sound. When every player is busy, the one that
# started longest ago is cut off, so there are never more than POOL_SIZE
# sounds at once (a common way to keep a busy mix from turning into mush).

const POOL_SIZE := 12

var _players: Array[AudioStreamPlayer] = []
var _next_steal := 0   # which player to cut off next when all are busy

func _ready() -> void:
	# Keep playing while the game is paused (menu clicks, etc.)
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

# Plays a sound once.
# Input: the SoundEvent, and an optional loudness 0..1 (e.g. from Hearing,
#        for something heard from far away). 1 = full volume.
# Output: the player it's on (so you could stop it early), or null if
#         nothing played (no event, no stream, or too quiet to hear)
func play(event: SoundEvent, loudness := 1.0) -> AudioStreamPlayer:
	if event == null or loudness <= 0.001:
		return null
	# The current voice language's version for spoken lines, else the plain stream
	var stream := event.get_stream()
	if stream == null:
		return null
	var p := _get_player()
	p.stream = stream
	p.bus = _checked_bus(event.bus)
	# linear_to_db: 1.0 -> 0 dB, 0.5 -> about -6 dB, 0.1 -> -20 dB
	p.volume_db = event.volume_db + linear_to_db(loudness)
	p.pitch_scale = randf_range(event.pitch_range.x, event.pitch_range.y)
	p.play()
	return p

# Stops every one-shot (e.g. on a jumpscare or when leaving the night)
func stop_all() -> void:
	for p in _players:
		p.stop()

# A free player if there is one; otherwise the next one in line gets reused
func _get_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	var p := _players[_next_steal]
	_next_steal = (_next_steal + 1) % POOL_SIZE
	return p

# A typo in a bus name would silently play on Master. Warn instead.
func _checked_bus(bus: StringName) -> StringName:
	if AudioServer.get_bus_index(bus) == -1:
		push_warning("Sfx: there's no audio bus called '%s'. Check the Audio tab." % bus)
		return &"Master"
	return bus
