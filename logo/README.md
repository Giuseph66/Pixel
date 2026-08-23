# PIXEL logo

A standalone generator for the game's wordmark and icon. Everything is drawn on
an integer grid and scaled with nearest-neighbour, so the exports are crisp at
any size.

## Regenerating

```sh
python3 make_logo.py            # renders PIXEL
python3 make_logo.py NEURELIX   # any other word
```

Requires Pillow. Output lands in this folder.

## Files

| File | Use |
| --- | --- |
| `logo.png` | stacked lockup at 1×, 44×38 px — the source of truth |
| `logo@8x.png` | stacked lockup at 8×, for slides and READMEs |
| `logo_transparent@8x.png` | same, background dropped, for dark surfaces |
| `logo_wide.png` / `logo_wide@8x.png` | horizontal lockup, for headers and banners |
| `logo_wide_transparent@8x.png` | horizontal, background dropped |
| `icon.png` / `icon_256.png` | square icon, 32 px grid |
| `logo.svg`, `logo_wide.svg`, `icon.svg` | vector, one `<rect>` per run of pixels |
| `logo_transparent.svg` | vector, no background plate |

Use the stacked lockup when there is vertical room and the wide one in a header
strip. Use a transparent variant only over a background darker than `#16162a` —
the wordmark's white will disappear on anything light.

The game itself does not read these files. `scripts/pixel_art.gd` rebuilds the
cube from the same maths at runtime, and `scripts/pixel_font.gd` carries the
same 5×7 glyphs, so the title screen and the exported logo stay in step.

## Font

5×7 glyphs, 1 px tracking. Covers `A–Z`, `0–9`, space and `- + = / * % ( ) [ ]
< > . , : ; ' ! ? _ # @ ^`. Lowercase input is upper-cased before rendering.
Unknown characters render as `?`.

## Palette

| Key | Hex | Used for |
| --- | --- | --- |
| `bg` | `#0f0f1b` | background plate |
| `frame` | `#2a2a44` | outer border |
| `outline` | `#070710` | dark outline around the cube |
| `top` | `#7ce8ff` | cube top face |
| `left` | `#3aa7d8` | cube left face |
| `right` | `#1c5c8c` | cube right face |
| `shine` | `#ffffff` | specular pixels, sparkles |
| `text` | `#f2f4ff` | wordmark |
| `shadow` | `#a82545` | wordmark extrude |
| `bar` | `#ff4d6d` | dashed rule under the wordmark |

To reskin, edit the `P` dict at the top of `make_logo.py` and re-run. The game's
copy of these colours lives in `scripts/palette.gd` and has to be edited to
match.
