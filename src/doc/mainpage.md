\mainpage HSK XC878 Electronic Control Unit Stub

This project is a stub to clone when starting the development of a new
device.

The `hsk-libs` repository is included as a submodule, a
`git submodule update` may be necessary to populate it.

See the `Makefile` for documentation on build parameters and `Makefile.local`
to overide defaults locally.

After setting the new project up, run `uVisionupdate.sh` to update the
µVision project file. The `uVisionupdate.sh` script also generates
the list of ISR callbacks for µVision's call tree/overlaying engine.

The list generation only recognizes direct assignments to
`hsk_isr<number>.<SOURCE>` and calls with function pointer
arguments to:
- `hsk_timer[01]_setup()`
- `hsk_ex_channel_enable()`

More complex assignments might require an update of
`hsk-libs/scripts/overlays.awk`.

@see [PDF Version](hsk-ecu-stub.pdf)
