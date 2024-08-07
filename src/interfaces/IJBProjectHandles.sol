// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@ensdomains/ens-contracts/contracts/resolvers/profiles/ITextResolver.sol";
import "@bananapus/core/src/interfaces/IJBProjects.sol";

interface IJBProjectHandles {
    event SetEnsNameParts(uint256 indexed projectId, string indexed handle, string[] parts, address caller);

    function setEnsNamePartsFor(uint256 chainId, uint256 projectId, string[] memory parts) external;

    function ensNamePartsOf(
        uint256 chainId,
        uint256 projectId,
        address projectOwner
    )
        external
        view
        returns (string[] memory);

    function TEXT_KEY() external view returns (string memory);

    function handleOf(uint256 chainId, uint256 projectId, address projectOwner) external view returns (string memory);
}
