// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Sphinx} from "@sphinx-labs/contracts/SphinxPlugin.sol";
import {Script} from "forge-std/Script.sol";

import {JBProjectHandles} from "../src/JBProjectHandles.sol";
import "@bananapus/core/script/helpers/CoreDeploymentLib.sol";

contract Deploy is Script, Sphinx {
    /// @notice tracks the deployment of the core contracts for the chain we are deploying to.
    CoreDeployment core;

    /// @notice The address that is allowed to forward calls to the terminal and controller on a users behalf.
    address private TRUSTED_FORWARDER;

    /// @notice the salts that are used to deploy the contracts.
    bytes32 PROJECT_HANDLES = "JBProjectHandles";

    function configureSphinx() public override {
        sphinxConfig.projectName = "nana-project-handles-testnet";
        sphinxConfig.mainnets = ["ethereum"];
        sphinxConfig.testnets = ["ethereum_sepolia"];
    }

    function run() public {
        // Get the deployment addresses for the nana CORE for this chain.
        // We want to do this outside of the `sphinx` modifier.
        core = CoreDeploymentLib.getDeployment(
            vm.envOr("NANA_CORE_DEPLOYMENT_PATH", string("node_modules/@bananapus/core/deployments/"))
        );

        // We use the same trusted forwarder as the core deployment.
        TRUSTED_FORWARDER = core.trustedForwarder;

        // Perform the deployment transactions.
        deploy();
    }

    function deploy() public sphinx {
        // Check if the contracts are already deployed or if there are any changes.
        if (!_isDeployed(PROJECT_HANDLES, type(JBProjectHandles).creationCode, abi.encode(TRUSTED_FORWARDER))) {
            new JBProjectHandles{salt: PROJECT_HANDLES}(TRUSTED_FORWARDER);
        }
    }

    function _isDeployed(
        bytes32 salt,
        bytes memory creationCode,
        bytes memory arguments
    )
        internal
        view
        returns (bool)
    {
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
