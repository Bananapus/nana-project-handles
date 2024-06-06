// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ENS} from "@ensdomains/ens-contracts/contracts/registry/ENS.sol";
import {ITextResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/ITextResolver.sol";
import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import {IJBProjects} from "@bananapus/core/src/interfaces/IJBProjects.sol";
import {IJBProjectHandles} from "./interfaces/IJBProjectHandles.sol";

/// @notice Manages reverse records that point from JB project IDs to ENS nodes. If the reverse record of a project ID
/// is pointed to an ENS node with a TXT record matching the ID of that project, then the ENS node will be considered
/// the "handle" for that project.
contract JBProjectHandles is IJBProjectHandles, ERC2771Context {
    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

    error EMPTY_NAME_PART();
    error NO_PARTS();

    //*********************************************************************//
    // ---------------- public constant stored properties ---------------- //
    //*********************************************************************//

    /// @notice The key of the ENS text record.
    string public constant override TEXT_KEY = "juicebox";

    /// @notice The ENS registry contract address.
    /// @dev Same on every network
    ENS public constant ENS_REGISTRY = ENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);

    //*********************************************************************//
    // --------------- public immutable stored properties ---------------- //
    //*********************************************************************//

    /// @notice A contract which mints ERC-721's that represent project ownership and transfers.
    IJBProjects public immutable override PROJECTS;

    //*********************************************************************//
    // --------------------- private stored properties ------------------- //
    //*********************************************************************//

    /// @notice Mapping of project ID to an array of strings that make up an ENS name and its subdomains.
    /// @dev ["jbx", "dao", "foo"] represents foo.dao.jbx.eth.
    /// @custom:param chainId The chain ID of the network on which the project ID exists.
    /// @custom:param projectId The ID of the project to get an ENS name for.
    /// @custom:param projectOwner The address of the project's owner.
    mapping(uint256 chainId => mapping(uint256 projectId => mapping(address projectOwner => string[] ensParts))) private
        _ensNamePartsOf;

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice Returns the handle for a project.
    /// @dev Requires a TXT record for the `TEXT_KEY` that matches the `projectId`. As some handles were set in the
    /// previous version, try to retrieve it too (this version takes precedence on the previous version).
    /// @param chainId The chain ID of the network on which the project ID exists.
    /// @param projectId The ID of the project to get the handle of.
    /// @param projectOwner The address of the project's owner.
    /// @return handle The project's handle.
    function handleOf(
        uint256 chainId,
        uint256 projectId,
        address projectOwner
    )
        external
        view
        override
        returns (string memory)
    {
        // Get a reference to the project's ENS name parts.
        string[] memory ensNameParts = _ensNamePartsOf[chainId][projectId][projectOwner];

        // Return an empty string if not found.
        if (ensNameParts.length == 0) return "";

        // Compute the hash of the handle
        bytes32 hashedName = _namehash(ensNameParts);

        // Get the resolver for this handle, returns address(0) if non-existing
        address textResolver = ENS_REGISTRY.resolver(hashedName);

        // If the handle is not a registered ENS, return empty string
        if (textResolver == address(0)) return "";

        // Find the projectId that the text record of the ENS name is mapped to.
        string memory textRecord = ITextResolver(textResolver).text(hashedName, TEXT_KEY);

        // Return empty string if text record from ENS name doesn't match projectId or chainId.
        if (
            keccak256(bytes(textRecord))
                != keccak256(bytes(string.concat(Strings.toString(chainId), ":", Strings.toString(projectId))))
        ) return "";

        // Format the handle from the name parts.
        return _formatHandle(ensNameParts);
    }

    /// @notice The parts of the stored ENS name of a project.
    /// @param chainId The chain ID of the network on which the project ID exists.
    /// @param projectId The ID of the project to get the ENS name of.
    /// @param projectOwner The address of the project's owner.
    /// @return The parts of the ENS name parts of a project.
    function ensNamePartsOf(
        uint256 chainId,
        uint256 projectId,
        address projectOwner
    )
        external
        view
        override
        returns (string[] memory)
    {
        return _ensNamePartsOf[chainId][projectId][projectOwner];
    }

    //*********************************************************************//
    // ---------------------------- constructor -------------------------- //
    //*********************************************************************//

    /// @param projects A contract which mints ERC-721's that represent project ownership and transfers.
    /// @param trustedForwarder The trusted forwarder for the ERC2771Context.
    constructor(IJBProjects projects, address trustedForwarder) ERC2771Context(trustedForwarder) {
        PROJECTS = projects;
    }

    //*********************************************************************//
    // --------------------- external transactions ----------------------- //
    //*********************************************************************//

    /// @notice Associate an ENS name with a project.
    /// @dev ["jbx", "dao", "foo"] represents foo.dao.jbx.eth.
    /// @dev Only a project's owner or a designated operator can set its ENS name parts.
    /// @param chainId The chain ID of the network on which the project ID exists.
    /// @param projectId The ID of the project to set an ENS handle for.
    /// @param parts The parts of the ENS domain to use as the project handle, excluding the trailing .eth.
    function setEnsNamePartsFor(uint256 chainId, uint256 projectId, string[] memory parts) external override {
        // Get a reference to the number of parts are in the ENS name.
        uint256 partsLength = parts.length;

        // Make sure there are ens name parts.
        if (partsLength == 0) revert NO_PARTS();

        // Make sure no provided parts are empty.
        for (uint256 i; i < partsLength; i++) {
            if (bytes(parts[i]).length == 0) revert EMPTY_NAME_PART();
        }

        // Store the parts.
        _ensNamePartsOf[chainId][projectId][_msgSender()] = parts;

        emit SetEnsNameParts(projectId, _formatHandle(parts), parts, _msgSender());
    }

    //*********************************************************************//
    // ------------------------ internal functions ----------------------- //
    //*********************************************************************//

    /// @notice Formats ENS name parts into a handle.
    /// @param ensNameParts The ENS name parts to format into a handle.
    /// @return handle The formatted ENS handle.
    function _formatHandle(string[] memory ensNameParts) internal pure returns (string memory handle) {
        // Get a reference to the number of parts are in the ENS name.
        uint256 partsLength = ensNameParts.length;

        // Concatenate each name part.
        for (uint256 i = 1; i <= partsLength; i++) {
            // Compute the handle.
            handle = string(abi.encodePacked(handle, ensNameParts[partsLength - i]));

            // Add a dot if this part isn't the last.
            if (i < partsLength) handle = string(abi.encodePacked(handle, "."));
        }
    }

    /// @notice Returns a namehash for an ENS name.
    /// @dev See https://eips.ethereum.org/EIPS/eip-137.
    /// @param ensNameParts The parts of an ENS name to hash.
    /// @return namehash The namehash for an ENS name parts.
    function _namehash(string[] memory ensNameParts) internal pure returns (bytes32 namehash) {
        // Hash the trailing "eth" suffix.
        namehash = keccak256(abi.encodePacked(namehash, keccak256(abi.encodePacked("eth"))));

        // Get a reference to the number of parts are in the ENS name.
        uint256 nameLength = ensNameParts.length;

        // Hash each part.
        for (uint256 i; i < nameLength; i++) {
            namehash = keccak256(abi.encodePacked(namehash, keccak256(abi.encodePacked(ensNameParts[i]))));
        }
    }

    /// @notice Returns the sender, prefered to use over `msg.sender`
    /// @return sender the sender address of this call.
    function _msgSender() internal view override returns (address sender) {
        return ERC2771Context._msgSender();
    }

    /// @notice Returns the calldata, prefered to use over `msg.data`
    /// @return calldata the `msg.data` of this call
    function _msgData() internal view override returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    /// @dev ERC-2771 specifies the context as being a single address (20 bytes).
    function _contextSuffixLength() internal view virtual override returns (uint256) {
        return super._contextSuffixLength();
    }
}
