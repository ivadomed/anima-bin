# Contributing Guidelines


This simply wraps the pre-built binaries that ANIMA publishes,
using a CI script.

We use it in https://github.com/ivadomed/ms-challenge-2021, so at the moment, we're using
the name "ivadomed-anima-bin" to avoid name-squatting. Maybe it will be promoted to the
official pip package some point.

## Publishing

If a new release of ANIMA appears on https://github.com/Inria-Empenn/Anima-Public/releases,
go to [/releases/new](https://github.com/ivadomed/anima-bin/releases/new), fill in a tag
matching the tag they used, then click Publish.

Monitor its progress at [/actions](https://github.com/ivadomed/anima-bin/actions).

After a couple minutes, it should upload `.whl`s to to [/releases](https://github.com/ivadomed/anima-bin/releases)
and to [PyPI](https://pypi.org/project/ivadomed-anima-bin).

