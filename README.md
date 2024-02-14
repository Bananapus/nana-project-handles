# Bananapus Project Handles

Juicebox projects can use an ENS address as their project's "handle" in frontend clients like [juicebox.money](https://juicebox.money). To make this association, they must first set their `juicebox_project` ENS text record to their project's ID.

This `JBProjectHandles` contract manages reverse records that point from project IDs to ENS nodes. If the two records match, that ENS is considered the project's handle.

_If you're having trouble understanding this contract, take a look at the [core protocol contracts](https://github.com/Bananapus/nana-core) and the [documentation](https://docs.juicebox.money/) first. If you have questions, reach out on [Discord](https://discord.com/invite/ErQYmth4dS)._

## Install

For `npm` projects (recommended):

```bash
npm install @bananapus/core
```

For `forge` projects (not recommended):

```bash
forge install Bananapus/nana-core
```

Add `@bananapus/project-handles/=lib/nana-project-handles/` to `remappings.txt`. You'll also need to install `nana-project-handles`'s dependencies and add similar remappings for them.

## Develop

`nana-project-handles` uses [npm](https://www.npmjs.com/) for package management and the [Foundry](https://github.com/foundry-rs/foundry) development toolchain for builds, tests, and deployments. To get set up, [install Node.js](https://nodejs.org/en/download) and install [Foundry](https://github.com/foundry-rs/foundry):

```bash
curl -L https://foundry.paradigm.xyz | sh
```

You can download and install dependencies with:

```bash
npm install && forge install
```

If you run into trouble with `forge install`, try using `git submodule update --init --recursive` to ensure that nested submodules have been properly initialized.

Some useful commands:

| Command               | Description                                         |
| --------------------- | --------------------------------------------------- |
| `forge build`         | Compile the contracts and write artifacts to `out`. |
| `forge fmt`           | Lint.                                               |
| `forge test`          | Run the tests.                                      |
| `forge build --sizes` | Get contract sizes.                                 |
| `forge coverage`      | Generate a test coverage report.                    |
| `foundryup`           | Update foundry. Run this periodically.              |
| `forge clean`         | Remove the build artifacts and cache directories.   |

To learn more, visit the [Foundry Book](https://book.getfoundry.sh/) docs.
