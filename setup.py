# Package up https://anima.readthedocs.io into a pip-compatible package.

# Note: this assumes that src/anima/bin/ already contains the programs
# from the ANIMA project, either built from source or download as binaries
# * https://anima.readthedocs.io/en/latest/compile_source.html
# * https://anima.readthedocs.io/en/latest/install_binaries.html
#
# It also assumes that git tag matches the build/downloaded version of anima
# because it uses setuptools_scm to generate the python version tag.
#
# And, this generates a *split-package* because a monolithic package is too large to fit on PyPI:
# each binary is packaged into "animaWhatever==$VERSION", and then "anima-bin==$VERSION" depends
# on all the "animaWhatever"s. It's convoluted. Read the code.
#
# Basically, for several reasons this setup.py isn't enough by itself
# to make a reliable build, you need to nest this in a further build script.
#
# This is a bit weird to do as a python package, but it's not the only one:
# * https://simonwillison.net/2022/May/23/bundling-binary-tools-in-python-wheels/
# * https://news.ycombinator.com/item?id=31776873
#
# TODO: is it possible to do this with the more modern setup.cfg?
#       pyproject.toml? or is it not worth the trouble?

from setuptools import setup, find_namespace_packages
import setuptools_scm

import os

ANIMA_APP = os.getenv("ANIMA_APP", None)
PLATFORM = os.getenv("PLATFORM", None)

ANIMA_APPS = [app for app in os.listdir("src/anima/bin") if app.startswith("anima")]
if ANIMA_APP and ANIMA_APP not in ANIMA_APPS:
    raise ValueError(f"ANIMA_APP={ANIMA_APP} not found in src/anima/bin")

# Build ${name}-${version}-py3-none-${OS}.whl, meaning we are:
# - compatible with any python (because there's essentially no python in this package)
# - but dependent on a given OS (win/macOS/manylinux1/manylinux2010/manylinux2014)
#
# Thanks @Yelp: https://github.com/Yelp/dumb-init/blob/48db0c0d0ecb4598d1a6400710445b85d67616bf/setup.py#L11-L27
# see https://stackoverflow.com/a/45150383
from wheel.bdist_wheel import bdist_wheel as _bdist_wheel


class bdist_wheel(_bdist_wheel):
    def get_tag(self):
        # get_tag() examines this to decide to return
        # plat = 'any' or plat = <actual platform tag>;
        # but if we set it globally, it causes package_data to be duplicated for some reason
        # so instead just set it for the duration of this call.
        _root_is_pure = self.root_is_pure
        self.root_is_pure = False
        python, abi, plat = _bdist_wheel.get_tag(self)
        self.root_is_pure = _root_is_pure

        # override the tags, to declare that we don't depend on a specific python implementation
        python, abi = "py2.py3", "none"

        #
        plat = {
            "Windows": "win_amd64",
            "macOS": "macosx_10_15_x86_64",
            "OSX": "macosx_10_15_x86_64",
            "Ubuntu": "linux_x86_64",
        }.get(PLATFORM, plat)

        return python, abi, plat


setup(
    name="ivadomed-"
    + ("anima-bin" if not ANIMA_APP else ANIMA_APP.removesuffix(".exe")),
    description="ANIMA medical image processing program"
    + ("s" if not ANIMA_APP else ": " + ANIMA_APP.removesuffix(".exe")),
    long_description=open(
        "README.md"
    ).read(),  # TODO: use a template for the subpackages?
    long_description_content_type="text/markdown",
    author="Inria",
    license="AGPL 3+",
    license_file="License.txt",
    url="https://github.com/ivadomed/anima-bin/",
    project_urls={
        "Homepage": "https://github.com/ivadomed/anima-bin/",
        "Repository": "https://github.com/ivadomed/anima-bin/",
    },
    use_scm_version=True,
    setup_requires=["setuptools_scm"],
    packages=find_namespace_packages(
        where="src", exclude=["anima" if ANIMA_APP else "anima.bin"]
    ),
    package_dir={"": "src"},
    include_package_data=True,
    # limit package_data to *only* package the specific requested app
    package_data={"anima.bin": [ANIMA_APP] if ANIMA_APP else []},
    # wrap each anima binary in a python script.
    # (the ".exe" bit is to handle Windows)
    # this introduces a big lag: each anima call requires booting the python interpreter.
    # but there's no other way to get pip to add binaries to $PATH.
    entry_points={
        "console_scripts": (
            []
            if not ANIMA_APP
            else [f'{ANIMA_APP.removesuffix(".exe")} = anima._bin:main']
        )
    },
    install_requires=(
        [
            f'ivadomed-{bin.removesuffix(".exe")}=={setuptools_scm.get_version()}'
            for bin in ANIMA_APPS
        ]
        if not ANIMA_APP
        else []
    ),
    cmdclass={
        # use the correct platform tag; see above
        "bdist_wheel": (_bdist_wheel if not ANIMA_APP else bdist_wheel)
    },
)
