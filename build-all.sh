#!/bin/bash

set -eu
set -o pipefail

PLATFORM="${1:-}"

# using --no-isolation is SIGNIFICANTLY faster when building a hundred packages
# but requires us to manually install the build dependencies
(set -x; pip install -U 'build' 'setuptools>=45' 'setuptools_scm[toml]>=6.2' 'wheel' 'auditwheel')

if [ -z "${PLATFORM:-}" ]; then
	if [ "$(uname)" = "Linux" ] && [ -f /etc/os-release ]; then
		PLATFORM="$(. /etc/os-release && echo "$ID")"
	elif [ "$(uname)" = "Darwin" ]; then
		PLATFORM="macOS"
	elif [ "$OS" = "Windows_NT" ] || [ "$OSTYPE" = "msys" ]; then
		# TODO: surely there's a better way to detect Windows than this
		PLATFORM="Windows"
	else
		echo "Cannot autodetect a known platform" >&2
		exit 1
	fi
fi

# Determine version from the git tag
# (we could also use `git describe --always` but this is guaranteed to match the built tag
VERSION="$(python -c 'import setuptools_scm; print(setuptools_scm.get_version())')"
VERSION="${VERSION#v}"     # strip leading 'v'
VERSION="${VERSION%rc*}"   # and trailing 'rc' or 'dev' tags
VERSION="${VERSION%.dev*}"  # to leave only the version number
        # This allows for testing this packaging script without risking uploading a bad package,
	# by tagging a release candidate

if [ "$PLATFORM" = "macOS" ]; then
	# macOS used to be called OS X, and ANIMA<=3.2 called it that.
	 # TODO: is there a way to do reliable version comparisons without python tuples? maybe awk?
	if python -c 'import sys; sys.exit(not (tuple(int(e) for e in sys.argv[1].split(".")) <= (3,2)))' "${VERSION}"; then
		PLATFORM="OSX"
	fi
fi

export PLATFORM VERSION

# Download prebuilt ANIMA binaries
# (-C - makes this resumable; GitHub has a glitch: if the file is fully downloaded, then 'resuming' it returns HTTP 416 instead of 200 with 0-length content; because of this, we first download to a .part file which is only renamed to the final name if the download is successful
if ! [ -f Anima-${PLATFORM}-${VERSION}.zip ]; then
	(set -x; curl -Lf -C - https://github.com/Inria-Empenn/Anima-Public/releases/download/v${VERSION}/Anima-${PLATFORM}-${VERSION}.zip -o Anima-${PLATFORM}-${VERSION}.zip.part)
	(set -x;  mv Anima-${PLATFORM}-${VERSION}.zip{.part,})
fi
ls -la # DEBUG

#- name: Unpack Anima binaries
# ANIMA hasn't always been consistent about the folder structure within their releases;
#  -j means throw away the folder structure, and
#  -d then dumps the files directly into our python package
# unzip returns 1 for "mostly success"; warnings like
# >  appears to use backslashes as path separators
# will return 1, but should not fail the build.

if [ "$(uname)" = "Darwin" ]; then
	xargs_() {
	  xargs "$@"
	}
else
	# GNU xargs tries to execute on null input
	xargs_() {
	  xargs -r "$@"
	}
fi

# We could do rm -r src/anima/bin, but to speed up rebuilds
# we instead use unzip -u followed by a selective rm -v (i.e. the same operation as rsync -r --delete):
#(set -x; unzip -uo -j Anima-${PLATFORM}-${VERSION}.zip '*/animaG*' -d src/anima/bin) || [ $? -lt 2 ] # DEBUG: test with a smaller set
(set -x; unzip -uo -j Anima-${PLATFORM}-${VERSION}.zip -d src/anima/bin) || [ $? -lt 2 ]
# drop unwanted files
# TODO: broken on Windows: it unzips then immediately deletes everything? Also, unnecessary when running in CI, which starts from a clean state anyway
# set difference: https://catonmat.net/set-operations-in-unix-shell
#(set +o pipefail
#grep -vxF -f <((set -x; zipinfo -1 Anima-${PLATFORM}-${VERSION}.zip ) | xargs_ -n1 basename | sort) \
#             <(ls -1 src/anima/bin | xargs_ -n1 basename | sort) | \
#    (cd src/anima/bin && xargs_ -n1 rm -v)
#)

# build the metapackage
# this one *must* be built with --wheel because the
# build script depends on seeing src/anima/bin/anima*
# (which are not actually -contents- of the metapackage)
# (maybe I could remove this limitation by...caching the list to requirements.txt?)
(set -x; rm -rf build) # https://github.com/pypa/wheel/issues/147
(set -x; python -m build --wheel --no-isolation)

# build the subpackages
# in order to use parallel xargs, these *must* be built without --wheel
# which causes it to build an sdist first then unpack that into an isolated tmp folder.
# because otherwise the parallel processes all try to use the same build/ folder.
#echo 'ANIMA_SUBPACKAGE=$1 python -m build' > build.sh
(cd src/anima/bin; ls -1 anima*) | \
	xargs -P 1 -n 1 sh -c 'rm -rf build/ && ANIMA_APP=$0 python -m build --wheel --no-isolation'

# Fixup the platform tags.
# Note: this cannot be done cross-platform:
# - auditwheel needs to run on Linux packages on Linux
# - otool needs to run on macOS binaries on a mac
# in case this will simply fail and leave the tags inaccurate.
if [ "$(uname)" = "Linux" ]; then
	# 'linux' isn't a legal platform tag on PyPI, but it's the only one wheel wants to produce.
	# Only 'manylinux*' are legal on PyPI, and to choose an accurate one needs a separate tool.
	# ref: https://peps.python.org/pep-0513/
	# ref: https://peps.python.org/pep-0600/
	# ref: https://packaging.python.org/en/latest/specifications/platform-compatibility-tags/
	# auditwheel will read all binaries inside of the wheel, figure out their minimum glibc version requirement
	# and replace "linux_x86_64" with "manylinux_$MAJOR_$MINOR_x86_64".
	pip install -U auditwheel

	for whl in dist/*-linux*.whl; do
		# auditwheel show can print the appropriate tag, but not in an easy machine-readable form
		# auditwheel repair can replace the tag, but the tag it defaults to is the one for the
		#   *current system*, not the one based on the contents of the package, which doesn't work for us.
		# auditwheel addtag can detect and put the proper tag into the, but it *appends* it,
		#   so the tag ends up being "linux_x86_64.manylinux_x_y_x86_64"
		# What I really want is `auditwheel settag`, but that doesn't exist.
		# So there's no good answer, only workarounds.
		MANYLINUX_TAG=$(auditwheel show "$whl" | egrep -o 'manylinux_[0-9][0-9]*_[0-9][0-9]*' | head -n 1)
		echo $MANYLINUX_TAG
		if [ -z "$MANYLINUX_TAG" ]; then
			echo "error: unable to read target manylinux_x_y tag for "$whl""
			exit 1
		fi
		(set -x; mv -v "$whl" "$(echo "$whl" | sed 's/linux/'"$MANYLINUX_TAG"'/')")
        done
elif [ "$(uname)" = "Darwin" ]; then
	# auditwheel is only for Linux
	# so we have to replicate it on OS X.
	# And we need to be *on* OS X to do this because we need `otool`.

	for whl in dist/*macosx_*.whl; do
		# examine the first (and should be only) binary in each .whl with otool
		# ref: http://stackoverflow.com/questions/17143373
		unzip -jo "$whl" 'anima/bin/anima*' -d otool-check
		VERSION_MIN_MACOSX="$(otool -l otool-check/* | \
			awk '/LC_VERSION_MIN_MACOSX/ { M=1 } M==1 && /version/ { print $2; exit }' | \
			sed 's/\./_/')"
		rm -r otool-check

		# then fix up its tag
		# FIXME: this is broken on macos 11+, so skip it; the default macos_10_15 tag is good enough for 99% of people anyway.
		if [ -n "$VERSION_MIN_MACOSX" ]; then
			mv -v "$whl" $(echo "$whl" | sed 's/macosx_[0-9][0-9]*_[0-9][0-9]*/macosx_'"$VERSION_MIN_MACOSX"'/')
		fi
	done
elif [ "$OS" = "Windows_NT" ] || [ "$OSTYPE" = "msys" ]; then
	# and Windows has a stable enough ABI that we don't need to worry about it.
	echo -n
fi
