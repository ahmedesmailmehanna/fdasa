extends Node

# Which night to play. The main menu sets this right before loading
# night.tscn. It's null when you run night.tscn directly to test.
var current_night: NightConfig = null

# Language of spoken lines (teacher replies, phone calls, cutscene voices and
# their subtitles): "en" or "ar". The UI itself is always English.
# The options menu will set this; SoundEvent.get_stream() reads it.
var voice_language := "ar"
