#!/bin/sh

# build the metapackage
# this one *must* be built with --wheel because the
# build script depends on seeing src/anima/bin/anima*
# (which are not actually -contents- of the metapackage)
# (maybe I could remove this limitation by...caching the list to requirements.txt?)
python -m build --wheel

# build the subpackages
# in order to use parallel xargs, these *must* be built without --wheel
# which causes it to build an sdist first then unpack that into an isolated tmp folder.
# because otherwise the parallel processes all try to use the same build/ folder.
#echo 'ANIMA_SUBPACKAGE=$1 python -m build' > build.sh
ls -1 src/anima/bin/anima* | \
	xargs -n1 basename | \
	xargs -P 0 -n 1 sh -c 'ANIMA_SUBPACKAGE=$0 python -m build'

# throw away the sdists, we don't actually want anyone to see them
rm dist/*.tar.gz
