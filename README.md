# Bananapus Project Handles

Juicebox projects can use an ENS address as their project's "handle" in frontend clients like [juicebox.money](https://juicebox.money). To make this association, they must set their `juicebox_project` ENS name's text record to their project's ID. The `JBProjectHandles` contract manages reverse records that point from project IDs to ENS names. If the two records match, that ENS name is considered the project's handle, and is shown in frontend clients.

<details>
  <summary>Table of Contents</summary>
  <ol>
    <li><a href="#usage">Usage</a></li>
  <ul>
    <li><a href="#install">Install</a></li>
    <li><a href="#develop">Develop</a></li>
    <li><a href="#scripts">Scripts</a></li>
    <li><a href="#deployments">Deployments</a></li>
    <li><a href="#tips">Tips</a></li>
    </ul>
    <li><a href="#repository-layout">Repository Layout</a></li>
    <li><a href="#description">Description</a></li>
  <ul>
    <li><a href="#motivation">Motivation</a></li>
    <li><a href="#text-record-and-multichain">Text Record and Multichain</a></li>
    </ul>
    <li><a href="#example-usage">Example Usage</a></li>
  </ul>
  </ol>
</details>

_If you're having trouble understanding this contract, take a look at the [core protocol contracts](https://github.com/Bananapus/nana-core) and the [documentation](https://docs.juicebox.money/) first. If you have questions, reach out on [Discord](https://discord.com/invite/ErQYmth4dS)._

## Usage

### Install

How to install `nana-project-handles` in another project.

For projects using `npm` to manage dependencies (recommended):

```bash
npm install @bananapus/project-handles
```

For projects using `forge` to manage dependencies (not recommended):

```bash
forge install Bananapus/nana-project-handles
```

If you're using `forge` to manage dependencies, add `@bananapus/project-handles/=lib/nana-project-handles/` to `remappings.txt`. You'll also need to install `nana-project-handles`' dependencies and add similar remappings for them.

### Develop

`nana-project-handles` uses [npm](https://www.npmjs.com/) (version >=20.0.0) for package management and the [Foundry](https://github.com/foundry-rs/foundry) development toolchain for builds, tests, and deployments. To get set up, [install Node.js](https://nodejs.org/en/download) and install [Foundry](https://github.com/foundry-rs/foundry):

```bash
curl -L https://foundry.paradigm.xyz | sh
```

You can download and install dependencies with:

```bash
npm ci && forge install
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

### Scripts

For convenience, several utility commands are available in `package.json`.

| Command             | Description                            |
| ------------------- | -------------------------------------- |
| `npm test`          | Run local tests.                       |
| `npm run test:fork` | Run fork tests (for use in CI).        |
| `npm run coverage`  | Generate an LCOV test coverage report. |

### Deployments

To deploy, you'll need to set up a `.env` file based on `.example.env`. Then run one of the following commands:

| Command                           | Description                        |
| --------------------------------- | ---------------------------------- |
| `npm run deploy:ethereum-mainnet` | Deploy to Ethereum mainnet         |
| `npm run deploy:ethereum-sepolia` | Deploy to Ethereum Sepolia testnet |
| `npm run deploy:optimism-mainnet` | Deploy to Optimism mainnet         |
| `npm run deploy:optimism-sepolia` | Deploy to Optimism testnet         |

### Tips

To view test coverage, run `npm run coverage` to generate an LCOV test report. You can use an extension like [Coverage Gutters](https://marketplace.visualstudio.com/items?itemName=ryanluker.vscode-coverage-gutters) to view coverage in your editor.

If you're using Nomic Foundation's [Solidity](https://marketplace.visualstudio.com/items?itemName=NomicFoundation.hardhat-solidity) extension in VSCode, you may run into LSP errors because the extension cannot find dependencies outside of `lib`. You can often fix this by running:

```bash
forge remappings >> remappings.txt
```

This makes the extension aware of default remappings.

## Repository Layout

The root directory contains this README, an MIT license, and config files.

The important source directories are:

```
nana-project-handles/
├── script/
│   └── Deploy.sol - The deployment script.
├── src/
│   ├── JBProjectHandles.sol - The main JBProjectHandles contract.
│   └── interfaces/
│       └── IJBProjectHandles.sol - The project handles interface.
└── test/
    └── JBProjectHandles.t.sol - Unit tests.
```

Other directories:

```
nana-project-handles/
├── .github/
│   └── workflows/ - CI/CD workflows.
└── broadcast/ - Deployment logs.
```

## Description

### Motivation

Handles are easier to remember than IDs, but leaving this to clients could get messy. ENS names are often used as handles in the Ethereum ecosystem, because they can have _text records_ – arbitrary key-value text pairs which can be accessed onchain. If Juicebox frontend clients were to trust ENS text records alone as a source of truth, anyone could associate their ENS handle with any Juicebox project, and could use this to mislead others. Therefore, we need a two-way association between Juicebox projects and ENS names. The `JBProjectHandles` contract is the "reverse record" – it allows a Juicebox project's owner to associate their project with an ENS name. If an ENS name has a text record pointing to a Juicebox project, and the project points to that ENS name through the `JBProjectHandles` contract, the ENS name is the project's handle.

### Text Record and Multichain

The canonical ENS registry and the `JBProjectHandles` contract are only available on Ethereum mainnet, but Juicebox projects can be deployed on several EVM-compatible networks. To allow project owners to set their handles on multiple chains, the text record specifies both the chain ID and the project ID.

To point an ENS name at a Juicebox project, use the name's `juicebox` text record, with the format `chainId:projectId`. For example, to point `jeff.eth` to project ID #5 on Optimism mainnet (which has chain ID 10), `jeff.eth` must have its `juicebox` text record set to `10:5`.

To point a Juicebox project at an ENS name, the project's owner must call [`JBProjectHandles.setEnsNamePartsFor(...)`](https://github.com/Bananapus/nana-project-handles/blob/main/src/JBProjectHandles.sol#L113):

```solidity
/// @notice Associate an ENS name with a project.
/// @dev ["jbx", "dao", "foo"] represents foo.dao.jbx.eth.
/// @dev Only a project's owner can set its ENS name parts.
/// @param chainId The chain ID of the network on which the project ID exists.
/// @param projectId The ID of the project to set an ENS handle for.
/// @param parts The parts of the ENS domain to use as the project handle, excluding the trailing .eth.
function setEnsNamePartsFor(uint256 chainId, uint256 projectId, string[] memory parts) external override { ... }
```

To point project #5 on Optimism mainnet back at his ENS, Jeff would have to call `JBProjectHandles.setEnsNamePartsFor(10, 5, ["jeff"])`. The same address which owns the project on Optimism must call `setEnsNamePartsFor(…)` on mainnet. If the project's owner changes, the new owner must call `setEnsNamePartsFor(…)` again.

## Example Usage

1. `jeff.eth` deploys project ID #5 on Optimism mainnet. He wants to set its handle as `project.jeff.eth`.
2. To point his ENS at his Juicebox project, he calls `PublicResolver.setText(…)` on the [ENS website](https://app.ens.domains/). He sets the `juicebox` text record for `project.jeff.eth` to `10:5`.
3. To point his project at his ENS, he calls `setEnsNamePartsFor(…)`:

```solidity
JBProjectHandles.setEnsNamePartsFor({
  chainId: 10, // Optimism mainnet
  projectId: 5,
  parts: ["project", "jeff"]
});
```

Now, clients associate his project with `project.jeff.eth`.
