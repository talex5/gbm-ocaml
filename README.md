OCaml bindings for [gbm](https://en.wikipedia.org/wiki/Mesa_(computer_graphics)#Generic_Buffer_Management).

The example displays a test image (run from a Linux VT, e.g. Ctrl-Alt-F2):

```
$ dune exec -- ./examples/atomic.exe
Using GBM backed "drm"
Found 1 connected connectors
Preparing settings for DP-1
DP-1: Using plane 52
(device does not support modifiers)
Committing changes
Success!
Restoring old configuration
```
