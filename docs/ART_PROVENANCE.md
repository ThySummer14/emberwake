# Art and audio provenance

All game-specific characters, places, narrative, sprites, world geometry and audio were authored for EMBERWAKE. Project-specific image generation was used for the original environment and refined animation sheets. No character, sprite, map or music was extracted from the reference games.

## Gatewater
- city.png: original generated drowned copper bell-city environment. Full-resolution source: art/emberwake_city_original.png.
- player.png, enemies.png, bellkeeper.png, props.png and tiles.png: game-native raster artwork authored with art/build_assets.py, using explicit frame poses and a shared palette.
- player_keyposes.png: original copper lantern-diver refined into 16 movement/action poses; original in art/player_generated_keyposes.png. Inspected crops, shared palette and stable body/foot anchors are recorded by prepare_player_keyposes.py.
- bellkeeper_keyposes.png: eight original Bellkeeper poses. Original in art/bellkeeper_generated_keyposes.png; explicit regions select anticipation, charge, leap, impact, recovery and phase-change poses.
- enemy_keyposes.png: four original enemy families with four action poses each; original in art/enemies_generated_keyposes.png.
- props_refined.png: original Lampweaver, lamp, brazier, bell, tree and archive-shelf refinements; original in art/props_generated_sheet.png.

## Rootfoundry and Ledger
The original high-resolution source sheets are also the unchanged runtime PNGs in godot/assets/, so there is no second duplicate copy: rootfoundry_background.png, rootfoundry_modules.png, breaker_poses.png, carrier_poses.png, ledger_background.png, tilu_modular.png and foldhammer_poses.png. Prompt records are in art/prompts/. Runtime rendering selects inspected crop regions with explicit foot/body origins, including mirrored transforms. Tilu's desk is separate from the animated actor so the furniture remains fixed. Transparent sheets contain genuine alpha; all sheets were visually inspected before use.

## Audio and fonts
- gatewater.ogg: original synthesized ambient composition created with art/build_assets.py. No sampled or copied music.
- Runtime effects, including pressure and stamping cues: synthesized in godot/scripts/audio.gd.
- title_font.ttf: DejaVu Serif; Bitstream Vera/DejaVu license in godot/licenses/DejaVu.txt.
- ui_font.otf: subset of Noto Sans CJK; SIL Open Font License in godot/licenses/Noto-CJK.txt.

Raw artwork remains editable. The checked-in runtime bytes are the validated 0.8.1 assets; rerunning historical authoring scripts is not required to run the game and can overwrite those files.
