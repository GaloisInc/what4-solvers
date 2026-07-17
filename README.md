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
* CVC5 - [1.3.1](https://github.com/cvc5/cvc5/tree/ea1b484fa54bfe56c0f8b3ac90a6e3e2f46441e7)
* Yices - [2.7.0](https://github.com/SRI-CSL/yices2/tree/85cf17e44eac76b5d14b297c09fc9bfecf47ef65)
* Z3 - [5.0.0](https://github.com/Z3Prover/z3/tree/8e3402b215a810a4154eb183a7dfc4e853eb2f52)

Built for the following operating systems:

* macOS Sequoia 15 (arm64 and x86-64)
* RedHat UBI9 (arm64 and x86-64)
* Ubuntu 22.04 (arm64 and x86-64)
* Ubuntu 24.04 (arm64 and x86-64)
* Windows Server 2022 (x86-64)

All of the binary distributions are built from CI.

## Download solvers GitHub Action

For convenience, we provide a GitHub action that automatically detects OS and architecture,
downloads the appropriate solver binaries from GitHub releases, and adds them to the `PATH`.
Solvers are downloaded to the `what4-solvers` folder by default.

The simplest use is to add a step to your workflow:

```
- name: Setup what4-solvers
  uses: GaloisInc/what4-solvers@v1
```

To override the default values, use the `with` keyword:

```
- name: Setup what4-solvers with custom destination
  uses: GaloisInc/what4-solvers@v1
  with:
    dest: ${{ github.workspace }}/my-solvers
```

or

```
- name: Setup what4-solvers with specific release
  uses: GaloisInc/what4-solvers@main
    with:
    release: snapshot-20251112
```

Consult `action.yml` for more details.

## FAQ

### Why build for multiple Ubuntu versions?

We attempt to offer somewhat broad coverage of different Linux versions.
To that end, we build each solver on the two most recent Ubuntu LTS
releases, as well as the latest RedHat Linux. This ensures relatively
complete coverage of different shared library dependencies (e.g., different `glibc` versions).
