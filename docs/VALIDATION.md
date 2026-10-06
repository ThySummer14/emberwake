# 0.8.1 source verification

The 55 runtime resources listed in builds/pack_source_hashes.json are byte-identical to the delivered 0.8.1 source. The matching PCK was built, booted and checked resource by resource. This repository retains source, tests, original art and provenance; it omits build caches, raw local QA logs, save files and duplicate PCK/ZIP downloads.

440 current assertions passed. Independent rechecking passed 456 in total (the same 440 plus 16 additional input, save-lifecycle and font probes). The continuous route test runs 13,346 input frames from a fresh journey, through the real Bellkeeper, workshop and Ledger, returning to Archive at HP 4 with no deaths. Nine save/load probes preserve flags and settle safely. Ordinary Gatewater enemies are removed in that particular route harness to isolate navigation; Bellkeeper and Rootfoundry encounters stay active with delayed cue policies.

The prior 0.8.0 native Godot X11 replay completed 2,500 input frames at full health and produced 19 inspected viewport captures. The single screenshot in this repository is explicitly from that run. The 0.8.1 delta is only the chapter-ending string and ending footer; geometry, assets, combat and save schema are unchanged. No new graphical run is claimed for this small delta.

The native environment used Mesa llvmpipe. It could not open audio output and used Godot's dummy audio driver. Audible mix, physical controllers, Mac hardware, standalone Mac export, sustained performance and a full human-controlled world playthrough remain unverified. The Foldhammer's low impact flare is still subtle beside its bronze mallet; this is a remaining presentation refinement.

Tests are design/implementation evidence, not a guarantee of human enjoyment or commercial-scale completion.
