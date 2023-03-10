# what4-solvers

Multi-platform binary creation for solvers of the versions most suitable for use
with [What4](https://github.com/GaloisInc/what4), as well as tools built on top
of What4, such as [Cryptol](https://cryptol.net/),
[Crux](https://crux.galois.com/), and [SAW](https://saw.galois.com/).

Binary distributions can be found at the
[releases page](https://github.com/GaloisInc/what4-solvers/releases).
Currently, `what4-solvers` offers the following solver versions:

* ABC - [99ab99bf](https://github.com/berkeley-abc/abc/tree/99ab99bfa6d1c2cc11d59af16aa26b273f611674)
* Boolector - [3.2.2](https://github.com/Boolector/boolector/tree/e7aba964f69cd52dbe509e46e818a4411b316cd3)
* CVC4 - [1.8](https://github.com/CVC4/CVC4-archived/tree/5247901077efbc7b9016ba35fded7a6ab459a379)
* CVC5 - [1.0.5](https://github.com/cvc5/cvc5/tree/4cb2ab9eb36f64295272a50f61dd1c62903aca4b)
* Yices - [2.6.2](https://github.com/SRI-CSL/yices2/tree/8509cfb5c294df3c0ac3a4814483f39c58879606)
* Z3 - [4.8.8](https://github.com/Z3Prover/z3/tree/ad55a1f1c617a7f0c3dd735c0780fc758424c7f1) and
       [4.8.14](https://github.com/Z3Prover/z3/tree/df8f9d7dcb8b9f9b3de1072017b7c2b7f63f0af8)

Built for the following operating systems:

* macOS Monterey 12
* Ubuntu 20.04
* Ubuntu 22.04
* Windows Server 2019

## FAQ

### Why build for multiple Ubuntu versions?

We attempt to offer somewhat broad coverage of different Linux versions. To
that end, we build each solver on the two most recent Ubuntu LTS releases. This
ensures relatively complete coverage of different shared library dependencies
(e.g., different `glibc` versions).

### Why offer multiple Z3 versions?

We use Z3 as the default SMT solver in many different projects' CI, including
the CI for Cryptol and SAW. Unfortunately, certain Z3 versions have been known
to non-deterministically fail or time out on certain SMT queries. See, for
example, [this Cryptol issue](https://github.com/GaloisInc/cryptol/issues/1107)
regarding Z3 4.8.10 and
[this SAW issue](https://github.com/GaloisInc/saw-script/issues/1772) regarding
Z3 4.8.14. As a consequence, it is very difficult to find a single Z3 version
that works reliably across all of our tools' CI.

As a compromise, we offer multiple Z3 versions so that tools can pick one that
is known to work well for their particular needs. If we successfully identify a
later version of Z3 that is known to work reliably across all CI
configurations, we may reconsider this choice.
