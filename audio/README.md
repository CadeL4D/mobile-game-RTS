# Original audio production

No reference-game audio is included. The current playable build synthesizes its own deterministic 16-bit waveform assets at runtime:

- adaptive calm, danger, and corruption music layers;
- UI tap and invalid-action feedback;
- construction placement/completion cues;
- harvesting, goal, achievement, and warning cues;
- independent Master, Music, Ambience, UI, Creatures, Buildings, and Combat buses.

`content/data/audio_catalog.json` reserves the complete 16-track production soundtrack. The current three-layer procedural score is the first integrated audio pass; every catalog track still requires arrangement, mix, mobile-speaker, and long-session review before release.
