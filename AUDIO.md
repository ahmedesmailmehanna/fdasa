# Audio in fdasa — how it works and how to add sounds

Keep this next to `README.md`. It explains the audio system and has a recipe
for every kind of sound you'll add.

## The big picture

```
 Gameplay (no audio code)          Audio layer                        Mixer
 ─────────────────────────         ───────────────────────            ────────────
 Tablet.tablet_toggled   ─┐
 Tablet.camera_changed    ├──►  NightAudio  ──► Sfx.play(event) ──►  UI ─────┐
 TeacherDispatch.sent    ─┘     (director)       (pool of players)    Voice ──┤
                                    │                                 SFX ────┼─► Master ─► speakers
 Joe.music_started ──────────►  JoeMusic  (its own player, live volume) ─► Music ┘
                                    ▲
                     Hearing.loudness(listener, sound)  ← one shared distance rule
```

**The one rule:** gameplay scripts never play sounds. They emit signals about
what happened (`teacher_sent`, `tablet_toggled`, ...). `NightAudio` listens and
decides what each event sounds like. So adding, changing or removing a sound
only ever touches the audio layer.

## The pieces

| Piece | File | What it does |
|---|---|---|
| Buses | `default_bus_layout.tres` (Audio tab) | Mixer channels: Music, SFX, Voice, Ambience, UI → Master |
| `SoundEvent` | `scripts/audio/sound_event.gd` | A sound as data: stream, bus, volume, pitch range, and for voices a list of translations. Saved as `.tres` |
| `VoiceTranslation` | `scripts/audio/voice_translation.gd` | One extra language of a voice line: a language code + a stream |
| `Sfx` (autoload) | `scripts/audio/sfx.gd` | Plays one-shots from anywhere: `Sfx.play(event, loudness)`. Pool of 12 players |
| `Hearing` | `scripts/audio/hearing.gd` | The math: distance + floors loudness, and left/right pan |
| `NightAudio` | `scripts/audio/night_audio.gd`, node in `night.tscn` | The director: signals in, sounds out. Knows where the player listens from and which way they face. `hear(spot)` returns loudness, muffling and pan |
| `SpatialPlayer` | `scripts/audio/spatial_player.gd` | A sound with its own bus: low-pass filter (walls) + panner (left/right), all eased. Either driven every frame by its owner (JoeMusic), or placed in a spot where it follows the listener by itself (`NightAudio.play_at`) |
| `JoeMusic` | `scripts/joe_music.gd`, node in `night.tscn` | Joe's music, through a SpatialPlayer: clear when the camera sees him, muffled and panned otherwise |

## Folders and naming

```
assets/audio/
  sfx/        one-shot effects: doors, clicks, footsteps   (.wav)
  voice/<character>/  spoken lines, language in the name:
					  teacher_found_en_1.wav, teacher_found_ar_1.wav
  music/      menu music, stingers                         (.ogg)
  ambience/   office hum, vents, rain                      (.ogg)
  joe/        Joe's songs                                  (.mp3/.ogg)
audio/events/ the SoundEvent .tres files, one per "thing that makes a sound"
```

- Name events after **what happens**, not the file: `bees_door.tres`, not `rattle_02.tres`.
- Short effects as **.wav** (instant, no decoding). Music, voice and long loops as **.ogg** (small).

## Which bus?

| Bus | For |
|---|---|
| `Music` | Joe's songs, menu music, stingers |
| `SFX` | Doors, footsteps, static, jumpscares, anything happening in the school |
| `Voice` | Voices heard **in the building**, usually placed in a room with `play_at` (teacher finding Joe, student lines) |
| `Phone` | Voices **through the phone**: phone guy, teacher calling back. Sends into Voice. Sounds like a phone speaker, always centered, no walls |
| `Ambience` | Long background loops: office hum, vents |
| `UI` | Tablet flip, camera switch, buttons, menus |

## Quick dB guide

Volume is logarithmic. `linear_to_db()` turns 0..1 loudness into dB.

| dB | Sounds like |
|---|---|
| 0 | As recorded |
| −6 | About half as loud |
| −12 | About a quarter |
| −20 | About a tenth |
| −80 | Silent |

---

# Recipes

## 1. Make a SoundEvent

Every recipe starts here.

1. Put the file in the right `assets/audio/` folder.
2. In FileSystem, right-click `audio/events/` → **Create New → Resource…** → `SoundEvent`.
3. Name it after the event (e.g. `door_slam.tres`) and fill in the Inspector:
   - **Stream**: drag the file in.
   - **Bus**: one from the table above.
   - **Volume Db**: start at 0, adjust by ear.
   - **Pitch Range**: `1, 1` for voices and music, `0.95, 1.05` for effects that repeat.

## 2. An event-driven cue (most sounds)

Example: Bees rattles the door when he reaches it.

1. Make `bees_door.tres` (recipe 1), bus `SFX`, pitch `0.95, 1.05`.
2. Make sure the gameplay script **emits a signal** for the moment. If it doesn't exist yet, add one there, e.g. in Bees' script:
   ```gdscript
   signal reached_door
   ...
   reached_door.emit()
   ```
3. In `night_audio.gd`, add a slot:
   ```gdscript
   @export var bees_door: SoundEvent
   ```
   and one line in `_connect_cues()`:
   ```gdscript
   bees.reached_door.connect(func() -> void: Sfx.play(bees_door))
   ```
   (find `bees` the same way `teacher` is found: a group lookup or an `@export`.)
4. Drag the `.tres` into the new **Cues** slot on the `NightAudio` node.

## 3. Several variations of one sound

Example: 4 different footstep recordings.

1. In the SoundEvent's **Stream**, choose **New AudioStreamRandomizer**.
2. Expand it → **Streams** → **Add Element** once per file, drag each file in.
3. **Playback Mode**: *Random (Avoid Repeats)*.
4. Optionally set its own **Random Pitch** / **Random Volume Offset Db** for extra variety.

No code changes: `Sfx.play()` gets a different variation every time.

## 4. A positional one-shot (heard by distance)

Example: footsteps or a door that's louder on the camera nearest to it, quieter
from the office.

Inside `NightAudio`, pass a loudness to `Sfx.play`:

```gdscript
Sfx.play(footstep, loudness_of(spot, 500.0, 0.35))
```

- `spot`: where the sound happens, e.g. the spot a student just walked to.
- `500.0`: how far it carries on one floor (a floor is 1060 wide). Small = only nearby cameras hear it.
- `0.35`: how much is kept per floor between you and it.
- Too far away to hear → `Sfx.play` simply doesn't play it.

Example, footsteps whenever any student moves:
```gdscript
var gm := get_tree().get_first_node_in_group("game_manager") as GameManager
gm.student_moved.connect(func(_s: Animatronic, _from: String, to: String) -> void:
	if to != "":
		Sfx.play(footstep, loudness_of(to, 500.0, 0.35)))
```

## 5. A voice line (in English and Arabic)

Spoken lines exist in both languages. The UI is always English; only voices
(and cutscene subtitles) follow the **voice language**, `GameState.voice_language`
(`"ar"`, the main language and the default, `"en"`, or any language you add
later; set by the options menu).

One SoundEvent holds both languages, so cues never have to choose:

1. Put the files in `assets/audio/voice/<character>/`, with the language in the
   name: `teacher_found_en_1.wav`, `teacher_found_ar_1.wav`, ...
2. Make the SoundEvent (recipe 1): bus `Voice`, pitch `1, 1` (voices sound wrong pitched).
3. **Stream** = the Arabic version (the main one).
4. **Translations** → **Add Element** → **New VoiceTranslation** for each other
   language: set **Language** (`en`, matching `GameState.voice_language`) and
   its **Stream**.

   For several takes of a language, use a **New AudioStreamRandomizer** in that
   stream slot and add each take; a single take can be dragged straight in.
5. Play it like anything else: `Sfx.play(teacher_found)`. It speaks the current voice language, picking a random take.

A language with no translation entry plays the Arabic **Stream**, so a line
works before its translation is recorded. Adding a language later is only data:
add a VoiceTranslation with the new code to each voice event, no code changes.
Effects and music only use **Stream** and are never affected by the language.

**Phone or in the room?** Pick by where the voice comes from in the story:
- **through the phone** → bus `Phone`, play with `Sfx.play(event)`: in your ear, same everywhere;
- **somewhere in the school** → bus `Voice`, play with `night_audio.play_at(event, spot)` (recipe 13): walls, distance and panning apply.

**Example in the game, the teacher:** sending a teacher plays `teacher_call`
(a phone ringing, bus SFX). When the teacher arrives (`teacher_arrived(spot, stopped_joe)`):
- **found Joe** → `teacher_found` plays **in Joe's room** with `play_at` (bus Voice): clear on a camera that sees the room, muffled and quieter elsewhere. No phone call: you hear it happen.
- **didn't find him** → `teacher_not_found` plays as a **phone call back** (bus Phone).

**Lines that must not be cut off:** keep the player `Sfx.play()` returns and wait for it:
```gdscript
var p := Sfx.play(phone_call)
if p:
	await p.finished
```

## 6. A looping background sound (ambience)

Example: the office hum, always playing.

One-shots go through `Sfx`. Long loops get their **own player** in NightAudio:

1. Make `office_hum.tres`, bus `Ambience`. Select the audio file in FileSystem → **Import** tab → tick **Loop** → **Reimport**.
2. In `night_audio.gd`:
   ```gdscript
   @export var office_hum: SoundEvent
   var _hum: AudioStreamPlayer

   # in _connect_cues():
   if office_hum:
       _hum = AudioStreamPlayer.new()
       _hum.stream = office_hum.stream
       _hum.bus = office_hum.bus
       _hum.volume_db = office_hum.volume_db
       add_child(_hum)
       _hum.play()
   ```
3. To make it quieter while the tablet is up (you're "looking away"), in the `tablet_toggled` cue:
   ```gdscript
   create_tween().tween_property(_hum, "volume_db", office_hum.volume_db - (10.0 if open else 0.0), 0.3)
   ```

## 7. A long sound that lives in a room (walls, distance, left/right)

Example: Joe's music. Use this for any sound that lasts and sits somewhere in
the school: Sha3er's whispers, a phone ringing in a classroom, a radio.

Copy the shape of `JoeMusic`:

```gdscript
var _sound: SpatialPlayer

func _ready() -> void:
	_sound = SpatialPlayer.new()
	_sound.event = my_event          # a SoundEvent, bus e.g. SFX or Music
	add_child(_sound)                # creates its own bus with the filters

func start() -> void:
	_sound.play()

func _process(delta: float) -> void:
	if not _sound.player.playing:
		return
	var heard := night_audio.hear(spot, 600.0, 0.35)   # spot, range, floor dampening
	_sound.set_target(heard.loudness, heard.cutoff_hz, heard.pan, delta)
```

What `hear()` gives you, and you don't need to do anything else for:
- **seen by the watched camera** → full volume, no muffling (`direct = true`);
- **not seen** → quieter with distance and floors, and muffled: the further / quieter, the duller;
- **pan** → from where the listener faces (camera: where its view cone points; office: `office_facing_degrees`).

Multiply `heard.loudness` by the source's own level if it varies (Joe does `* music_level / 100`).

## 8. UI and menu sounds

Example: button clicks in the main menu.

`Sfx` is an autoload, so it works in any scene, menus included, and keeps
playing while the game is paused:

```gdscript
@export var click: SoundEvent   # bus UI
...
button.pressed.connect(func() -> void: Sfx.play(click))
```

## 9. Ducking: music dips when someone talks

1. **Audio** tab → on the **Music** bus, **Add Effect → Compressor**.
2. Select it, set **Sidechain** to `Voice`.
3. Start with **Threshold** −30 dB, **Ratio** 4, **Release** 300 ms. Tune by ear.

Whenever anything plays on Voice, Music automatically gets quieter. No code.

## 10. Muffled one-shots (behind walls, other floors)

Long sounds get muffling automatically through `SpatialPlayer` (recipe 7). For
short one-shots, a shared muffled bus is simpler:

1. **Audio** tab → **Add Bus**, name it `SFX_Muffled`, send to `SFX`.
2. **Add Effect → LowPassFilter**, **Cutoff Hz** around 800.
3. Make muffled versions of events use bus `SFX_Muffled`, or pick the bus in code:
   ```gdscript
   var p := Sfx.play(door_slam, loud)
   if p and loud < 0.3:
	   p.bus = &"SFX_Muffled"
   ```

## 11. Tuning walls and panning

All on the `NightAudio` node, **Walls and panning** group:

| Setting | Does | Try |
|---|---|---|
| Muffled Cutoff Near | How muffled a sound right behind a wall is (Hz). Higher = clearer | 2000–4000 |
| Muffled Cutoff Far | How muffled a barely audible sound is (Hz). Lower = more bass-only | 250–500 |
| Pan Strength | How far sounds pan. 1 = fully one speaker | 0.6–0.9 |
| Office Facing Degrees | Which way you face in the office: −90 up the map, 0 right, 90 down, 180 left | match your office art |

Rough cutoff guide: 20,000 Hz = untouched · 3,000 = next room · 1,000 = down
the hall · 400 = other end of the school / another floor.

## 12. Volume settings (later, for an options menu)

```gdscript
var bus := AudioServer.get_bus_index("Music")
AudioServer.set_bus_volume_db(bus, linear_to_db(slider.value))   # slider 0..1
AudioServer.set_bus_mute(bus, slider.value <= 0.0)
```

---

## 13. A one-shot in a room (a voice or sound placed in the school)

Example: the teacher shouting when they catch Joe, a locker slamming in 1B.

```gdscript
night_audio.play_at(teacher_found, spot)            # inside NightAudio: play_at(...)
night_audio.play_at(locker_slam, "F1_1B", 500.0)    # optional: range, floor dampening
```

- Clear and full volume on a camera that sees `spot`; quieter, muffled and panned elsewhere.
- It keeps following the listener while it plays: switch cameras mid-line and it changes.
- It cleans up after itself (its temporary `Spatial_<event>` bus included).
- Voice lines still follow the voice language.

Use `Sfx.play` instead for things not in the building: UI, the phone, stingers.

## 14. The Phone bus (how it's built)

A phone speaker only reproduces about 300–3,400 Hz and adds some grit. The
**Phone** bus (sends to **Voice**) does that with three effects, in order:

| Effect | Setting | Why |
|---|---|---|
| HighPassFilter | Cutoff ~400 Hz | Removes the bass: phones have none |
| LowPassFilter | Cutoff ~3,400 Hz | Removes the airy highs |
| Distortion | Mode Overdrive, Drive ~0.35, Post Gain ~−4 dB | The small cheap speaker crunch |

Tune by ear: a narrower band (e.g. 500–2,800 Hz) sounds like an older, worse
phone; more Drive sounds like a bad connection.

## Troubleshooting

| Problem | Check |
|---|---|
| No sound at all | Is the SoundEvent assigned in the NightAudio Inspector slot? Does the event have a Stream? |
| Warning "no audio bus called ..." | Typo in the event's Bus field, or the bus isn't in the Audio tab |
| Positional sound never plays | The spot has no position in `c.positions` (re-export from the tool), or the range is too small |
| Sound cuts out when lots happens | More than 12 one-shots at once: raise `POOL_SIZE` in `sfx.gd` |
| Loop stops after one play | Import tab → tick **Loop** → **Reimport** |
| Click/pop when volume changes | Change volume gradually (`move_toward` or a tween), never in one jump |
| Same footstep every time | Use an AudioStreamRandomizer (recipe 3) |
| A voice line plays Arabic in English mode | It has no Translations entry with Language `en` (check the spelling), or that entry's Stream is empty |
| Audio file won't attach / red ✕ in FileSystem | Usually a 32-bit float WAV. Re-export as **WAV, Signed 16-bit PCM** (Audacity: Encoding in the export dialog) |
| Can't find the `Spatial_...` bus in the Audio tab | It's created while the game runs and removed after. Normal |
| Panning feels backwards in the office | Set `office_facing_degrees` to the way your office art faces |
| A camera hears Joe muffled though he's on screen | That camera's list in `cameras.tres` doesn't include his spot. Fix it in the tool (Cameras mode) and re-export |
