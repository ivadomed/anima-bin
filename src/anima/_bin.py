#!/usr/bin/env python3
#
# wrap the anima binaries; this simply finds the real path of argv[0] and calls that.
# this is meant to be used as a console_script.
# Also, it is used as _many_ console scripts, each anima binary is wrapped into this.

import sys, os, os.path, pathlib


def main():
    # sys.argv[0] is by default whatever the user typed in to call this path
    # it must end with the app name, but may or may not also include
    # a absolute or relative path to the console_script.
    # But argv[0] can actually be anything, execv() doesn't read it when deciding what program to run.

    # censor the actual path from the target binary (if a path was given)
    sys.argv[0] = os.path.basename(sys.argv[0])

    # jump into the target binary
    #
    # There are at least eleven ways to find it:
    # 1. target=pathlib.Path(__file__).parent/"bin"/sys.argv[0]
    # 1b. target=os.path.join(os.path.dirname(__file__), "bin", sys.argv[0])
    # 2. import anima.bin; target=pathlib.Path(anima.bin.__path__[0])/sys.argv[0]
    # 2b. import anima.bin; target=os.path.join(anima.bin.__path__[0], sys.argv[0])
    # 3. import anima.bin; with importlib.resources(anima.bin, sys.argv[0]) as target: pass
    # 3b. from . import bin; with importlib.resources(bin, sys.argv[0]) as target: pass
    # 3c. with importlib.resources('anima.bin', sys.argv[0]) as target: pass
    # 3d. with importlib.resources(f'{__package__}.bin', sys.argv[0]) as target: pass
    # 4. import anima.bin; target=importlib.resources.files(anima.bin).joinpath(sys.argv[0])
    # 4b. target=importlib.resources.files('anima.bin').joinpath(sys.argv[0])
    # 4c. target=importlib.resources.files(f'{__package__}.bin').joinpath(sys.argv[0])
    #
    # 1. works well here, but only because this file is near the target package.
    # 2. is a form that works well both inside and outside this package -- i.e. downstream users
    #    could use it to find and call these packages (skipping the slowness of using this wrapper)
    #    but it assumes the first __path__ is the only, and will break if a user manages to install
    #    as a "Namespace Package", i.e. with the different subpackages in different locations, like
    #    some to a venv and some to ~/.local/lib and some to /usr/local/lib/python.
    # 3. handles Namespace Packages properly, but requires importlib.resources, which, on older pythons,
    #    is an extra dependency, and plus it uses this weird 'with' syntax which is a holdover from the
    #    era when python packages used to sometimes be distributed in .zips ("eggs"), like java's .jars.
    # 4. is a variant on 3 that seems to be officially blessed, however it is an extremely new API.
    #
    # ref: https://setuptools.pypa.io/en/latest/userguide/datafiles.html?highlight=package_data#accessing-data-files-at-runtime
    os.execv(pathlib.Path(__file__).parent / "bin" / sys.argv[0], sys.argv)


if __name__ == "__main__":
    main()
