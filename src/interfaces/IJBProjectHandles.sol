// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/ens-contracts/contracts/resolvers/profiles/ITextResolver.sol";
import "lib/juice-contracts-v4/src/interfaces/IJBProjects.sol";

interface IJBProjectHandles {
    event SetEnsNameParts(uint256 indexed projectId, string indexed handle, string[] parts, address caller);

    function setEnsNamePartsFor(uint256 _projectId, string[] memory _parts) external;

    function ensNamePartsOf(uint256 _projectId) external view returns (string[] memory);

    function TEXT_KEY() external view returns (string memory);

    function PROJECTS() external view returns (IJBProjects);

    function handleOf(uint256 _projectId) external view returns (string memory);
}
