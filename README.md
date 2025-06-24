# what4-solvers

Multi-platform binary creation for solvers of the versions most suitable for use
with [What4](https://github.com/GaloisInc/what4), as well as tools built on top
of What4, such as [Cryptol](https://cryptol.net/),
[Crux](https://crux.galois.com/), and [SAW](https://saw.galois.com/).

Binary distributions can be found at the
[releases page](https://github.com/GaloisInc/what4-solvers/releases).
Currently, `what4-solvers` offers the following solver versions:

* ABC - [99ab99bf](https://github.com/berkeley-abc/abc/tree/99ab99bfa6d1c2cc11d59af16aa26b273f611674)
* Bitwuzla - [0.7.0](https://github.com/bitwuzla/bitwuzla/tree/3cf7c35b97c60016883cc19c4d6a9344a989a4d6)
* Boolector - [3.2.2](https://github.com/Boolector/boolector/tree/e7aba964f69cd52dbe509e46e818a4411b316cd3)
* CVC4 - [1.8](https://github.com/CVC4/CVC4-archived/tree/5247901077efbc7b9016ba35fded7a6ab459a379)
* CVC5 - [1.1.1](https://github.com/cvc5/cvc5/tree/ebfdf84d5698eeb83e0fa4e45101fe4a8f4543eb)
* Yices - [2.6.5](https://github.com/SRI-CSL/yices2/tree/8e6297e233299631147f98659224c3118fc6a215)
* Z3 - [4.15.1](https://github.com/Z3Prover/z3/tree/b665c99d0608fd392b951a04559191f97a51eb38)

Built for the following operating systems:

* macOS Ventura 13 (x86-64)
* macOS Sonoma 14 (arm64)
* Ubuntu 22.04 (x86-64)
* Ubuntu 24.04 (x86-64)
* Ubuntu 24.04 (arm64)
* Windows Server 2022 (x86-64)

All of the binary distributions are built from CI.

## FAQ

### Why build for multiple x86-64 Ubuntu versions?

We attempt to offer somewhat broad coverage of different x86-64 Linux versions.
To that end, we build each solver on the two most recent x86-64 Ubuntu LTS
releases. This ensures relatively complete coverage of different shared library
dependencies (e.g., different `glibc` versions).

In contrast, we currently only build each solver on the latest arm64 Ubuntu LTS
release. Please file an issue is this support window is too narrow for your
needs.
