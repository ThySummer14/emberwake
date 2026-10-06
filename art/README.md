# Original art sources

The five full-resolution Gatewater creation sheets are retained here. The original Rootfoundry and Ledger sheets are already present byte-for-byte in godot/assets/: rootfoundry_background.png, rootfoundry_modules.png, breaker_poses.png, carrier_poses.png, ledger_background.png, tilu_modular.png and foldhammer_poses.png. They are not duplicated here. Prompt records are in prompts/.

The Python files preserve the Gatewater asset-authoring process (Pillow/NumPy and, for sound conversion, FFmpeg). Some authoring paths refer to standard Linux system fonts. They are not required to run or edit the Godot game and should only be run in a disposable working copy because they write to godot/assets/. The checked-in runtime assets are the validated version. See docs/ART_PROVENANCE.md and builds/pack_source_hashes.json.
