# PIXEL

A single-screen precision platformer for Godot 4.6.

Six rooms, one screen each. Run, jump, wall-jump, squash slimes, take the gems
if you want them, reach the door. The timer never stops, so the game is really
about doing a room cleanly rather than doing it at all.

**Nothing in this project is an imported asset.** There are no PNGs, no WAVs, no
fonts and no TileSet resources. Every sprite is a character grid painted into an
`Image` at boot, every sound is synthesised sample by sample into an
`AudioStreamWAV`, and all UI text is drawn with `draw_rect()` from a hand-made
5×7 bitmap font. The entire game is `.gd` source plus one nearly empty `.tscn`.

## Running it

Open the folder in Godot 4.6 and press play. The main scene is
`scenes/main.tscn`, which holds a single node running `scripts/main.gd`.

The window is 480×270 stretched to 1440×810 with `canvas_items` stretch and
nearest-neighbour filtering, so the pixel grid stays exact at any window size.

## Controls

| Action | Keyboard | Gamepad |
| --- | --- | --- |
| Move | Arrows or A / D | D-pad, left stick |
| Jump | Space, Z, K, Up, W | A |
| Confirm | Space, Enter, Z | A |
| Back | Esc, X, Backspace | B |
| Restart room | R | X |
| Pause | Esc, P | Start |

Jump height is variable — release early to hop, hold to go full height. There is
coyote time (0.09s) and a jump buffer (0.11s), so a jump pressed slightly too
early or slightly too late still comes out.

## The rooms

| # | Name | Teaches |
| --- | --- | --- |
| 1 | FIRST STEPS | moving and jumping, nothing can kill you |
| 2 | MIND THE GAP | spiked pits, one-way platforms |
| 3 | PRICKLY | floor spikes to clear, ceiling spikes to duck under |
| 4 | SLIME TIME | stomping enemies from above |
| 5 | BOUNCE | spring pads |
| 6 | THE CLIMB | wall slides and wall jumps |

Progress, best times, gem counts and audio settings live in `user://save.json`.

## Layout

```
scenes/main.tscn        one Node2D running main.gd
scripts/
  main.gd               input map, screen flow, pause
  levels.gd             all six rooms, painted onto a grid with rect/put calls
  level.gd              builds a room: baked terrain, merged collision, entities
  player.gd             movement, jumps, wall jumps, death
  slime.gd  gem.gd  spike.gd  spring.gd  exit_door.gd
  pixel_art.gd          sprite grids -> ImageTexture, terrain tile painter
  pixel_font.gd         the 5x7 font, drawn with draw_rect()
  palette.gd            the sixteen colours the whole game uses
  sfx.gd                chiptune synth: every sound effect and the music loop
  audio_manager.gd      autoload, sound library and a pool of voices
  save_manager.gd       autoload, JSON progress and settings
  menu.gd               shared skeleton for list-of-choices screens
  title_screen.gd  level_select.gd  results_screen.gd  ending_screen.gd
  pause_menu.gd  hud.gd  transition.gd  fx.gd  util.gd
  sandbox.gd            custom rooms: store, validation, share files and codes
  tile_palette.gd       the tile alphabet, named and grouped for the editor
  editor_screen.gd  sandbox_screen.gd  room_preview.gd  text_field.gd
rooms/                  drop a .pixelroom here and it joins the campaign
assets/branding/icon.svg
logo/                   the standalone logo generator and its exports
```

## Sandbox

A third mode next to the campaign and endless: an in-game room editor. The room
is drawn 1:1 under the same 14px band the HUD uses in play, so what you see in
the editor is the screen you get when you press play.

Arrows move the cursor and space paints; the mouse paints too, with the wheel
stepping through tiles. `TAB` opens the palette, `R` is a rectangle tool, `F`
fills an area, `O` sets the room's name, par, entity speed and which moves are
allowed in it, `P` plays it, `H` lists every key.

A new room starts from an empty box, or as a copy — of a campaign room or of
another one you made. The copy picker lists names on the left and draws the
room large on the right, because a campaign name like GREED tells you nothing
about what you are about to copy.

Rooms are kept in `user://sandbox.json`. Exporting one writes a readable JSON
file to `user://export/` **and** copies a `PIXEL1.…` share code to the
clipboard, so a room travels either as a file or as a paste. Importing takes
both.

Dropping an exported file into [`rooms/`](rooms/README.md) puts it on the
official map: `Levels.all()` scans that folder at boot and appends what it
finds, no code change anywhere. The full write-up is in
[docs/SANDBOX.md](docs/SANDBOX.md).

## Adding a room

Rooms are 60×32 grids of 8px tiles. They are not typed out as ASCII art —
a row of the wrong length would be impossible to spot. Instead each room is
painted onto a blank grid:

```gdscript
static func _level_7() -> PackedStringArray:
    var g := _blank()                    # sealed room, solid border
    _rect(g, 0, 27, COLS, 5, "#")        # floor
    _rect(g, 20, 22, 8, 1, "-")          # one-way platform
    _put(g, 4, 26, "P")                  # spawn
    _put(g, 50, 26, "X")                 # exit
    return _bake(g)
```

Tile characters: `#` solid, `-` one-way platform, `^` spike up, `v` spike down,
`o` gem, `S` slime, `J` spring, `P` spawn, `X` exit, `.` air. Then add an entry
to `Levels.all()` with a name, a hint line and a par time.

Useful numbers when placing geometry, all derived from the constants at the top
of `player.gd`: a full jump climbs about **4.7 tiles** and carries about **8
tiles** horizontally; a spring launches about **14 tiles** up. Keep required
gaps at five tiles or fewer and required climbs at three or fewer and a room
will read as fair.

## The logo

`logo/` holds a standalone Python generator for the wordmark and icon —
see `logo/README.md`. The game does not depend on it; `pixel_art.gd` rebuilds
the same cube from the same maths at runtime for the title screen.
