# Retired generators

These scripts used to write every card, Askew, encounter, event and relic
`.tres` under `source/data/`. They are not used any more: the `.tres` files are
the source of truth and are edited in the Godot inspector.

**Do not run them.** Each one overwrites its whole directory, so a run throws
away every edit made in the editor since. They are kept because their comments
record why a number is what it is (card pricing, enemy break windows, and so
on), and nowhere else holds that reasoning.

The `.gdignore` here keeps Godot from importing or parsing them, so they are
free to fall out of date with the classes they build.

When they were retired, regenerating from them reproduced the shipped data
exactly, ignoring resource ids. Anything that differs now was changed in
the editor after that.
