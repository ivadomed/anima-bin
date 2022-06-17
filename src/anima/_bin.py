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
    os.execv(pathlib.Path(__file__).parent/"bin"/sys.argv[0], sys.argv)

if __name__ == '__main__':
    main()
