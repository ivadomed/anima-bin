# ANIMA bin

This wraps [ANIMA](https://github.com/Inria-Empenn/Anima-Public) into a pip-installable package,
so that these tools can be proper dependencies of python packages.

See the [ANIMA docs](https://anima.readthedocs.io/) for more information.

## Installation

```
pip install ivadomed-anima-bin
```

## Usage

Just run `anima$WHATEVER`, for example:

```
$ animaMaskImage --help

USAGE: 

   animaMaskImage  -m <mask file> -o <output image> -i <input image> [--]
                   [--version] [-h]


Where: 

   -m <mask file>,  --maskfile <mask file>
     (required)  mask file

   -o <output image>,  --outputfile <output image>
     (required)  output image

   -i <input image>,  --inputfile <input image>
     (required)  Input image

   --,  --ignore_rest
     Ignores the rest of the labeled arguments following this flag.

   --version
     Displays version information and exits.

   -h,  --help
     Displays usage information and exits.


   INRIA / IRISA - VisAGeS/Empenn Team
```
