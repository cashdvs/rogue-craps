## Autoload "SplashState": remembers that the studio boot splash already ran
## this boot, so returning to the title/main scene never replays it.
## Settings can flip `reduced_motion` before the splash runs (e.g. from a
## saved option); the splash also honours its config's reduced_motion flag.
extends Node

## True once the splash has started playing during this process.
var played: bool = false
## Runtime reduced-motion override (Settings / OS). OR-ed with the config flag.
var reduced_motion: bool = false
