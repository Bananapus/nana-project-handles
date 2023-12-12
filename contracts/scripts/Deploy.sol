// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import {IJBPermissions} from "@jbx-protocol/src/interfaces/IJBPermissions.sol";
import {IJBProjects} from "@jbx-protocol/src/interfaces/IJBProjects.sol";

import "../JBProjectHandles.sol";

contract DeployGoerli is Test {
    IJBPermissions permissions =
        IJBPermissions(0x99dB6b517683237dE9C494bbd17861f3608F3585);
    IJBProjects projects =
        IJBProjects(0x21263a042aFE4bAE34F08Bb318056C181bD96D3b);

    JBProjectHandles jbProjectHandles;

    function run() external {
        vm.startBroadcast();

        jbProjectHandles = new JBProjectHandles(projects, permissions);
    }
}

contract DeployMainnet is Test {
    IJBPermissions permissions =
        IJBPermissions(0x6F3C5afCa0c9eDf3926eF2dDF17c8ae6391afEfb);
    IJBProjects projects =
        IJBProjects(0xD8B4359143eda5B2d763E127Ed27c77addBc47d3);

    JBProjectHandles jbProjectHandles;

    function run() external {
        vm.startBroadcast();

        jbProjectHandles = new JBProjectHandles(projects, permissions);
    }
}
