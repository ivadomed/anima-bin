#!/bin/sh

# using --no-isolation is SIGNIFICANTLY faster
# but requires us to manually install the build dependencies
pip install 'setuptools>=45' 'setuptools_scm[toml]>=6.2' 'wheel'

# build the metapackage
# this one *must* be built with --wheel because the
# build script depends on seeing src/anima/bin/anima*
# (which are not actually -contents- of the metapackage)
# (maybe I could remove this limitation by...caching the list to requirements.txt?)
rm -rf build # https://github.com/pypa/wheel/issues/147
python -m build --wheel --no-isolation

# build the subpackages
# in order to use parallel xargs, these *must* be built without --wheel
# which causes it to build an sdist first then unpack that into an isolated tmp folder.
# because otherwise the parallel processes all try to use the same build/ folder.
#echo 'ANIMA_SUBPACKAGE=$1 python -m build' > build.sh
(cd src/anima/bin; ls -1 anima*) | \
	sed 's/.exe$//' | \
	xargs -P 1 -n 1 sh -c 'rm -rf build/ && ANIMA_SUBPACKAGE=$0 python -m build --wheel --no-isolation'

# throw away the sdists, we don't actually want anyone to see them
#rm dist/*.tar.gz
