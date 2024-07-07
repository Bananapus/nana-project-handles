// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Sphinx} from "@sphinx-labs/contracts/SphinxPlugin.sol";
import {Script} from "forge-std/Script.sol";

import {JBProjectHandles} from "../src/JBProjectHandles.sol";

contract Deploy is Script, Sphinx {
    /// @notice The address that is allowed to forward calls to the terminal and controller on a users behalf.
    address private constant TRUSTED_FORWARDER =
        0xB2b5841DBeF766d4b521221732F9B618fCf34A87;

    /// @notice the salts that are used to deploy the contracts.
    bytes32 PROJECT_HANDLES = "JBProjectHandles";

    function configureSphinx() public override {
        // TODO: Update to contain revnet devs.
        sphinxConfig.projectName = "project-handles-testnet";
        sphinxConfig.mainnets = ["ethereum", "optimism", "base", "arbitrum"];
        sphinxConfig.testnets = [
            "ethereum_sepolia",
            "optimism_sepolia",
            "base_sepolia",
            "arbitrum_sepolia"
        ];
    }

    function run() public {
        // Perform the deployment transactions.
        deploy();
    }

    function deploy() public sphinx {
        // Check if the contracts are already deployed or if there are any changes.
        if (
            !_isDeployed(
                PROJECT_HANDLES,
                type(JBProjectHandles).creationCode,
                abi.encode(TRUSTED_FORWARDER)
            )
        ) new JBProjectHandles{salt: PROJECT_HANDLES}(TRUSTED_FORWARDER);
    }

    function _isDeployed(
        bytes32 salt,
        bytes memory creationCode,
        bytes memory arguments
    ) internal view returns (bool) {
        address _deployedTo = vm.computeCreate2Address({
            salt: salt,
            initCodeHash: keccak256(abi.encodePacked(creationCode, arguments)),
            // Arachnid/deterministic-deployment-proxy address.
            deployer: address(0x4e59b44847b379578588920cA78FbF26c0B4956C)
        });

        // Return if code is already present at this address.
        return address(_deployedTo).code.length != 0;
    }
}
