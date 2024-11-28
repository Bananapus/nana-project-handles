// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ENS} from "@ensdomains/ens-contracts/contracts/registry/ENS.sol";
import {ITextResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/ITextResolver.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import {IJBProjectHandles} from "./interfaces/IJBProjectHandles.sol";

/// @notice `JBProjectHandles` allows Juicebox project owners to associate their project with an ENS node. If that ENS
/// node has a matching text record which points back to the project, clients will treat that ENS node as the project's
/// handle.
/// @dev By convention, clients read the `juicebox` text field of the ENS node with the format `chainId:projectId`.
/// For example, project ID #5 on Optimism mainnet would be represented by a `juicebox` text record of `10:5`.
contract JBProjectHandles is IJBProjectHandles, ERC2771Context {
    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

    error EMPTY_NAME_PART();
    error NO_PARTS();

    //*********************************************************************//
    // ---------------- public constant stored properties ---------------- //
    //*********************************************************************//

    /// @notice The key of the ENS text record which points back to a project.
    string public constant override TEXT_KEY = "juicebox";

    /// @notice The ENS registry contract address.
    /// @dev Same on Ethereum mainnet and most of its testnets.
    ENS public constant ENS_REGISTRY =
        ENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);

    //*********************************************************************//
    // --------------------- private stored properties ------------------- //
    //*********************************************************************//

    /// @notice A private mapping storing ENS name parts set by different owner addresses for different projects.
    /// @dev The `ensParts` ["jbx", "dao", "foo"] represents foo.dao.jbx.eth.
    /// @custom:param chainId The chain ID of the network the project is on.
    /// @custom:param projectId The ID of the project to get the ENS parts of.
    /// @custom:param setter The address that set the requested `ensParts`. This should be the project's current owner.
    mapping(uint256 chainId => mapping(uint256 projectId => mapping(address setter => string[] ensParts)))
        private _ensNamePartsOf;

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice Returns a project's verified handle. If the handle isn't verified, returns the empty string.
    /// @dev The ENS record text record with the `TEXT_KEY` record containing `chainId:projectId`.
    /// @param chainId The chain ID of the network the project is on.
    /// @param projectId The ID of the project to get the handle of.
    /// @param setter The address which set the requested handle. This should be the project's current owner.
    /// @return handle The project's verified handle.
    function handleOf(
        uint256 chainId,
        uint256 projectId,
        address setter
    ) external view override returns (string memory) {
        // Get a reference to the project's ENS name parts.
        string[] memory ensNameParts = _ensNamePartsOf[chainId][projectId][
            setter
        ];

        // Return an empty string if not found.
        if (ensNameParts.length == 0) return "";

        // Compute the hash of the handle
        bytes32 hashedName = _namehash(ensNameParts);

        // Get the resolver for this handle, returns address(0) if non-existing
        address textResolver = ENS_REGISTRY.resolver(hashedName);

        // If the handle is not a registered ENS, return empty string
        if (textResolver == address(0)) return "";

        // Find the `projectId` that the text record of the ENS name is mapped to.
        string memory textRecord = ITextResolver(textResolver).text(
            hashedName,
            TEXT_KEY
        );

        // Return empty string if text record from ENS name doesn't match `projectId` and `chainId`.
        if (
            keccak256(bytes(textRecord)) !=
            keccak256(
                bytes(
                    string.concat(
                        Strings.toString(chainId),
                        ":",
                        Strings.toString(projectId)
                    )
                )
            )
        ) return "";

        // Format the handle from the name parts.
        return _formatHandle(ensNameParts);
    }

    /// @notice The parts of the stored ENS name of a project.
    /// @param chainId The chain ID of the network on which the project ID exists.
    /// @param projectId The ID of the project to get the ENS name of.
    /// @param setter The address that set the requested record in this contract.
    /// @return The parts of the ENS name parts of a project.
    function ensNamePartsOf(
        uint256 chainId,
        uint256 projectId,
        address setter
    ) external view override returns (string[] memory) {
        return _ensNamePartsOf[chainId][projectId][setter];
    }

    //*********************************************************************//
    // ---------------------------- constructor -------------------------- //
    //*********************************************************************//

    /// @param trustedForwarder The trusted forwarder for the ERC2771Context.
    constructor(address trustedForwarder) ERC2771Context(trustedForwarder) {}

    //*********************************************************************//
    // --------------------- external transactions ----------------------- //
    //*********************************************************************//

    /// @notice Point from a Juicebox project to an ENS node.
    /// @dev The `parts` ["jbx", "dao", "foo"] represents foo.dao.jbx.eth.
    /// @dev The project's owner must call this function to set its ENS name parts.
    /// @param chainId The chain ID of the network the project is on.
    /// @param projectId The ID of the project to set an ENS handle for.
    /// @param parts The parts of the ENS domain to use as the project handle, excluding the trailing .eth.
    function setEnsNamePartsFor(
        uint256 chainId,
        uint256 projectId,
        string[] memory parts
    ) external override {
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

        emit SetEnsNameParts(
            projectId,
            _formatHandle(parts),
            parts,
            _msgSender()
        );
    }

    //*********************************************************************//
    // ------------------------ internal functions ----------------------- //
    //*********************************************************************//

    /// @notice Formats ENS name parts into a handle.
    /// @param ensNameParts The ENS name parts to format into a handle.
    /// @return handle The formatted ENS handle.
    function _formatHandle(
        string[] memory ensNameParts
    ) internal pure returns (string memory handle) {
        // Get a reference to the number of parts are in the ENS name.
        uint256 partsLength = ensNameParts.length;

        // Concatenate each name part.
        for (uint256 i = 1; i <= partsLength; i++) {
            // Compute the handle.
            // slither-disable-next-line encode-packed-collision
            handle = string(
                abi.encodePacked(handle, ensNameParts[partsLength - i])
            );

            // Add a dot if this part isn't the last.
            if (i < partsLength) handle = string(abi.encodePacked(handle, "."));
        }
    }

    /// @notice Returns a namehash for an ENS name.
    /// @dev See https://eips.ethereum.org/EIPS/eip-137.
    /// @param ensNameParts The parts of an ENS name to hash.
    /// @return namehash The namehash for an ENS name parts.
    function _namehash(
        string[] memory ensNameParts
    ) internal pure returns (bytes32 namehash) {
        // Hash the trailing "eth" suffix.
        namehash = keccak256(
            abi.encodePacked(namehash, keccak256(abi.encodePacked("eth")))
        );

        // Get a reference to the number of parts are in the ENS name.
        uint256 nameLength = ensNameParts.length;

        // Hash each part.
        for (uint256 i; i < nameLength; i++) {
            namehash = keccak256(
                abi.encodePacked(
                    namehash,
                    keccak256(abi.encodePacked(ensNameParts[i]))
                )
            );
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
    function _contextSuffixLength()
        internal
        view
        virtual
        override
        returns (uint256)
    {
        return super._contextSuffixLength();
    }
}
