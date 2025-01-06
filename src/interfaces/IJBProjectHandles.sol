// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBProjects} from "@bananapus/core/src/interfaces/IJBProjects.sol";
import {ENS} from "@ensdomains/ens-contracts/contracts/registry/ENS.sol";
import {ITextResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/ITextResolver.sol";

interface IJBProjectHandles {
    event SetEnsNameParts(
        uint256 indexed projectId,
        string handle,
        string[] parts,
        address caller
    );

    function TEXT_KEY() external view returns (string memory);
    function ENS_REGISTRY() external view returns (ENS);

    function ensNamePartsOf(
        uint256 chainId,
        uint256 projectId,
        address projectOwner
    ) external view returns (string[] memory);

    function handleOf(
        uint256 chainId,
        uint256 projectId,
        address projectOwner
    ) external view returns (string memory);

    function setEnsNamePartsFor(
        uint256 chainId,
        uint256 projectId,
        string[] memory parts
    ) external;
}
