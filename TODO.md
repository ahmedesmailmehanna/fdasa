# fdasa — TODO

## Done
- [x] Project created (Godot 4.6.2), folders, git + GitHub
- [x] Core chain working: graph → student movement → GameManager occupancy → CameraSystem display
- [x] Floor 1 layout: 23 spots (halls, classrooms, labs, atrium edges, bathroom, office hall, principal office)
- [x] Weighted directed graphs per student (`StudentGraph`), plus `LocationList` master list and `CameraMap`
- [x] Generator (`scripts/dev/generate_graphs.gd`) validates every graph against the spot list before saving
- [x] Bees: left wing + one-way atrium drop from floor 2 + bathroom vents between floors
- [x] Meer: right wing only
- [x] Move roll: `move / (move + stay)`, never 100%, level 0 = disabled
- [x] Joe's music (in GameManager for now): raises every student's move chance AND countdown speed; Joe level 0–20 scales both
- [x] `NightConfig` (fixed levels per night, 0 = disabled) + `Students.Id` + `GameState` autoload
- [x] Student paths tool (`tools/student-paths-tool.html`): floors, cross-floor paths, bulk spot import, rename, drag/nudge, export `g.nodes` blocks for the generator

## Up next
- [x] **Wire cameras to the camera map**
  - [x] `GameManager.occupants`: a **list** of students per spot, plus a `student_moved` signal
  - [x] `CameraSystem.show_camera(camera_id)`: background + an overlay for every student on any spot that camera covers, redraws live when someone walks in/out of view
  - [x] `Animatronic.get_frame_for(camera_id, spot_id)`: builds the sprite path; missing art shows as text in the debug label instead
- [x] Camera buttons + floor switch (built from the camera map, grouped by `F0_` / `F1_` prefix)
- [ ] Overlay draw order: list each camera's spots **back to front** in the generator so closer students draw on top
- [ ] Turn off `CameraSystem.show_debug` once real art is in
- [ ] Night clock: 9 AM → 3 PM, win at 3 PM (`seconds_per_hour` export, ~90s)
- [ ] Attack logic at `F1_OfficeHall`: Bees leaves if the door is closed; Meer's 5s door check. Decide Bees' retreat spot (suggested: `F1_Bathroom`, back into the vents)
- [ ] Office scene (door / tablet UI around CameraSystem)
- [ ] Main menu sets `GameState.current_night` (story night `.tres` or custom night built from sliders)
- [ ] Strip debug prints (`>>> animatronic _ready`, `students found`) once things are stable
- [ ] The unnamed `Node` under `Night` is the graph generator runner: it rewrites `data/graphs/` every time the night runs. Move it into its own throwaway scene (e.g. `scenes/dev/generate_graphs.tscn`)

## Map & graphs (for me)
- [ ] **Finish the map / graph layout for every walker** in the Student paths tool
  - [ ] Draw floor 2 and floor 0 properly (currently only stub spots: `F2_AtriumL`, `F2_Bathroom`, `F0_StairsL/R`, `F0_Bathroom`)
  - [ ] Decide on floor 3 (the tool supports it; gameplay currently only views floors 0–1)
  - [ ] Final camera placement per floor (placeholder: 6 cameras on floor 1). Every spot two cameras see needs two sprites
  - [ ] Decide if Bees can also drop in on `F1_AtriumR`, or stays strictly left
  - [ ] After editing: **Save file** in the tool (commit the JSON as a backup), copy the `g.nodes` blocks into the generator, rerun it
  - [ ] **Every spot a graph uses must also be in the locations list.** When adding spots or a new student graph, also export **Spot list (l.nodes = …)** from the tool into the generator's `_locations()`. The generator refuses to save if a graph uses a spot that isn't listed
  - [ ] Checklist for adding a new student (walker or NPC):
    1. **+ Student** in the tool, draw the graph, copy its `g.nodes` into a new `_<name>_graph()` in the generator, and add a `_save(..., "graph_<name>.tres")` line
    2. Update `_locations()` from the tool's spot list if any spots are new
    3. Add an entry to `Students.Id` (and a level field in `NightConfig` + `get_level()`)
    4. Add an `Animatronic` node under `Night` with its Student Id, graph and starting spot
    5. Rerun the generator, then the asset layout tool
- [ ] **Add harmless walkers (NPC-like) as a distraction**
  - Idea: they wander with the same graph system and show up on cameras, but never attack, so the player has to tell threats from noise
  - Likely just another `Animatronic` with no attack logic at the office door (or a flag like `is_harmless`)
  - Decide: fixed per night, or part of `NightConfig`? Can they share spots with real students? Distinct look, or deliberately similar?
  - Each needs its own graph (tool: **+ Student**) and overlay sprites for the spots cameras see

## Art pipeline
- Backgrounds: **one per camera**, not per spot
- Overlays: **one per student × camera × spot that camera sees**. Blind spots (classrooms) need no art
- Current count for Bees + Meer with placeholder cameras: 6 backgrounds + 11 overlays
- Reuse one pose across spots with a similar angle on the same camera where possible
- Folder convention:
  ```
  res://assets/cameras/<CAMERA_ID>.png                          # background
  res://assets/students/<student>/<CAMERA_ID>/<SPOT_ID>.png     # overlay
  ```
- Photoshop sources (`.psd`) stay in `source_assets/`, outside `res://`
- [x] Add `scripts/dev/build_asset_layout.gd` (editor tool). Run it from the Script editor with **File > Run** (Ctrl+Shift+X) after every generator run:
  - creates every `assets/cameras/` and `assets/students/<student>/<camera>/` folder the lookup needs
  - prints what's **missing** and what's **unused** (e.g. art for a spot you renamed) to Output
  - writes a tick-box checklist to `res://assets/asset_checklist.md`
  - never deletes anything

## Later / open questions
- [ ] Move Joe out of GameManager into his own node once his real behavior starts (random camera, volume control, loading bar, feeds Sha3er at music 50)
- [ ] Sound cue when Bees is in the bathroom vents (the bathroom is one step from the door)
- [ ] Per-night rosters: which students unlock on which night
- [ ] Power outage: how the player gets saved (still ambiguous)
- [ ] Optional: generator reads `data/student_paths.json` directly instead of copy-pasting (code was drafted this session)

## Gotchas (for future reference)
- `%UniqueName` silently resolves to `null` if the node isn't marked "Access as Unique Name"
- A script's `extends` must match its scene root type (`Control` script needs a `Control` root)
- `GameManager` must stay above anything that looks it up in `_ready()` (sibling order = `_ready()` order)
- Empty Inspector for a script → save the script, reselect the node, or reload the project
- `print()` goes to **Output**; errors go to **Debugger → Errors**
- Nothing happens at night start? Check the `Night` node has a **Test Config** assigned
- A group is just a tag: a class never joins a group by itself, only `add_to_group()` (or the editor's Groups tab) does
- Tool data lives in the browser unless you press **Save file**
