# Read the continuous verification gate

The gate in `.github/workflows/ci.yml` exists to answer one question: does Rig work somewhere other than the machine it was written on? Read it as four jobs, each asserting something the others cannot.

## What each job proves

`Shell lint` runs ShellCheck and `bash -n` over `bin/rig`, `install.sh`, every authored module, and the three scripts, then runs `scripts/assemble-rig --check`. It proves the committed executable matches its sources, so a change to `src/rig/` that was never assembled fails here rather than reaching someone's installation.

`Bats (ubuntu-latest)` runs the suite on GNU tools and a current Bash. It proves Rig's portable core — parsing, configuration, catalogue and profile resolution, state comparison, export — behaves the same away from macOS, and it is the only job that reads assertions a modern Bash enforces. Bash 3.2 does not apply `set -e` to a failing compound command, so a bare `[[ ... ]]` passes silently there; every assertion in the suite therefore ends in `|| false`, and this runner is what keeps that true.

`Bats (macos-latest)` runs the same suite under the system Bash 3.2 with `PATH=/usr/bin:/bin:/usr/sbin:/sbin`. It proves Rig needs nothing beyond the tools macOS ships. That restriction is the point of the job, so nothing may be added to that PATH to make a test pass.

`mandoc` lints the manual. `Release tag matches executable` runs only on a tag, and needs the other three, so a tag cannot pass over a red gate.

The benchmark is deliberately absent. A shared runner's timing is not evidence: the measurement that takes three seconds on a workstation has taken nine against an eight-second budget on a hosted runner. `scripts/benchmark-rig` stays a local check.

## What a skip means

A skipped test states its reason, and the reason is part of the contract. Two exist today.

The budget case in `tests/rig-performance.bats` skips wherever `CI` is set, because that machine's timing proves nothing. Run `scripts/benchmark-rig` locally instead.

The TOML interoperability cases skip when no interpreter with `tomllib` is available. They parse a fixture with a real TOML parser to show Rig's grammar is interoperable rather than Rig-specific — that parser is test infrastructure, not a Rig dependency. `tests/helpers/toml-parser.bash` looks at `RIG_TEST_PYTHON` first, then `python3` and the versioned names; macOS ships Python 3.9 and `tomllib` arrived in 3.11, so the macOS job names a newer interpreter through `RIG_TEST_PYTHON` without touching the restricted PATH.

A test that needs a genuinely macOS-only facility should skip elsewhere with its reason stated rather than fail or be deleted. Prefer a stub for the facility where what the test asserts is portable: the skills ordering case declares a launchd resource but asserts ordering, so it supplies a `launchctl` stub and keeps running everywhere.

## Reproduce a runner locally

The Linux runner:

```sh
bats --print-output-on-failure tests/
```

The macOS runner, which is what catches an accidental dependency on a tool the system does not ship:

```sh
bats_bin=$(command -v bats)
RIG_TEST_PYTHON=$(command -v python3) PATH=/usr/bin:/bin:/usr/sbin:/sbin \
  "$bats_bin" --print-output-on-failure tests/
```

`RIG_TEST_PYTHON` must name a real interpreter rather than a version-manager shim, because a shim cannot resolve under the restricted PATH.

Neither local run reproduces a modern Bash on macOS, and no container runtime is assumed here, so a Bash 5 difference is observed through the Linux job. Make a failure legible from the runner that produced it: Bats shows a failing test's own output, so printing the artefact under assertion — a generated plist, a rendered table — costs nothing on success and turns an opaque red run into a readable one. That is how the plist escaping defect under Bash 5.2 was found.

## Run the gate without inventing a commit

The workflow accepts `workflow_dispatch`:

```sh
gh workflow run ci.yml --ref main
gh run watch "$(gh run list --workflow ci.yml --limit 1 --json databaseId --jq '.[0].databaseId')"
```

Both runners install the same pinned `bats-core`, so a failure means the suite failed rather than that two runners run different harnesses. The pin lives in the workflow's `BATS_VERSION`.
