extends Node
## Shared signals between systems so they never reference each other directly. Mode-specific buses
## (B&S, Gravelight) add their own signals in M1/M2; these are the ones every mode needs.

signal mode_changed(mode: int)
signal vo_line_started(line_id: String, speaker: String, text: String)
signal vo_line_finished(line_id: String)
signal subtitle(speaker: String, text: String, color: Color, seconds: float)
signal save_written(path: String)
signal unlock_granted(unlock_id: String)
signal archive_entry_found(entry_id: String)
