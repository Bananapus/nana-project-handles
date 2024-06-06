// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "forge-std/Test.sol";

import {ENS} from "@ensdomains/ens-contracts/contracts/registry/ENS.sol"; // This is an interface...
import {ITextResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/ITextResolver.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {JBProjects} from "@bananapus/core/src/JBProjects.sol";
import {JBPermissions} from "@bananapus/core/src/JBPermissions.sol";
import {JBPermissionsData} from "@bananapus/core/src/structs/JBPermissionsData.sol";
import "../src/JBProjectHandles.sol";
import {JBPermissionIds} from "@bananapus/permission-ids/src/JBPermissionIds.sol";

ENS constant ensRegistry = ENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);
IJBProjectHandles constant oldHandle = IJBProjectHandles(
    0x41126eC99F8A989fEB503ac7bB4c5e5D40E06FA4
);

contract ContractTest is Test {
    // For testing the event emitted
    event SetEnsNameParts(
        uint256 indexed projectId,
        string indexed ensName,
        string[] parts,
        address caller
    );

    address projectOwner = address(6_942_069);

    ITextResolver ensTextResolver = ITextResolver(address(69_420)); // Mocked
    JBPermissions jbPermissions;
    JBProjects jbProjects;
    JBProjectHandles projectHandle;

    function setUp() public {
        vm.etch(address(ensTextResolver), "0x69");
        vm.etch(address(ensRegistry), "0x69");
        vm.label(address(ensTextResolver), "ensTextResolver");
        vm.label(address(ensRegistry), "ensRegistry");

        jbPermissions = new JBPermissions();
        jbProjects = new JBProjects(address(69));
        projectHandle = new JBProjectHandles(jbProjects, address(0x0));
    }

    //*********************************************************************//
    // ------------------------ SetEnsNamePartsFor(..) ------------------- //
    //*********************************************************************//

    function testSetEnsNamePartsFor_passIfCallerIsProjectOwnerAndOnlyName(
        string calldata name
    ) public {
        vm.assume(bytes(name).length != 0);

        uint256 projectId = jbProjects.createFor(projectOwner);
        uint256 chainId = 1;

        string[] memory nameParts = new string[](1);
        nameParts[0] = name;

        // Test the event emitted
        vm.expectEmit(true, true, true, true);
        emit SetEnsNameParts(projectId, name, nameParts, projectOwner);

        vm.prank(projectOwner);
        projectHandle.setEnsNamePartsFor(chainId, projectId, nameParts);

        // Control: correct ENS name?
        assertEq(
            projectHandle.ensNamePartsOf(chainId, projectId, projectOwner),
            nameParts
        );
    }

    function testSetEnsNameWithSubdomainFor_passIfMultipleSubdomainLevels(
        string memory name,
        string memory subdomain,
        string memory subsubdomain
    ) public {
        vm.assume(
            bytes(name).length > 0 &&
                bytes(subdomain).length > 0 &&
                bytes(subsubdomain).length > 0
        );

        uint256 projectId = jbProjects.createFor(projectOwner);
        uint256 chainId = 1;

        // name.subdomain.subsubdomain.eth is stored as ['subsubdomain', 'subdomain', 'domain']
        string[] memory nameParts = new string[](3);
        nameParts[0] = subsubdomain;
        nameParts[1] = subdomain;
        nameParts[2] = name;

        string memory fullName = string(
            abi.encodePacked(name, ".", subdomain, ".", subsubdomain)
        );

        // Test event
        vm.expectEmit(true, true, true, true);
        emit SetEnsNameParts(projectId, fullName, nameParts, projectOwner);

        vm.prank(projectOwner);
        projectHandle.setEnsNamePartsFor(chainId, projectId, nameParts);

        // Control: ENS has correct name and domain
        assertEq(
            projectHandle.ensNamePartsOf(chainId, projectId, projectOwner),
            nameParts
        );
    }

    function testSetEnsNameWithSubdomainFor_RevertIfEmptyElementInNameParts(
        string memory name,
        string memory subdomain,
        string memory subsubdomain
    ) public {
        vm.assume(
            bytes(name).length == 0 ||
                bytes(subdomain).length == 0 ||
                bytes(subsubdomain).length == 0
        );

        uint256 projectId = jbProjects.createFor(projectOwner);
        uint256 chainId = 1;

        // name.subdomain.subsubdomain.eth is stored as ['subsubdomain', 'subdomain', 'domain']
        string[] memory nameParts = new string[](3);
        nameParts[0] = subsubdomain;
        nameParts[1] = subdomain;
        nameParts[2] = name;

        vm.prank(projectOwner);
        vm.expectRevert(abi.encodeWithSignature("EMPTY_NAME_PART()"));
        projectHandle.setEnsNamePartsFor(chainId, projectId, nameParts);

        // Control: ENS has correct name and domain
        assertEq(
            projectHandle.ensNamePartsOf(chainId, projectId, projectOwner),
            new string[](0)
        );
    }

    function testSetEnsNameWithSubdomainFor_RevertIfEmptyNameParts() public {
        uint256 projectId = jbProjects.createFor(projectOwner);
        uint256 chainId = 1;

        // name.subdomain.subsubdomain.eth is stored as ['subsubdomain', 'subdomain', 'domain']
        string[] memory nameParts = new string[](0);

        vm.prank(projectOwner);
        vm.expectRevert(abi.encodeWithSignature("NO_PARTS()"));
        projectHandle.setEnsNamePartsFor(chainId, projectId, nameParts);

        // Control: ENS has correct name and domain
        assertEq(
            projectHandle.ensNamePartsOf(chainId, projectId, projectOwner),
            new string[](0)
        );
    }

    //*********************************************************************//
    // ---------------------------- handleOf(..) ------------------------- //
    //*********************************************************************//

    function testHandleOf_returnsEmptyStringIfNoHandleSet(
        uint256 chainId,
        uint256 projectId
    ) public {
        // No handle set on the previous JBProjectHandle version neither
        vm.mockCall(
            address(oldHandle),
            abi.encodeCall(
                IJBProjectHandles.ensNamePartsOf,
                (chainId, projectId, projectOwner)
            ),
            abi.encode(new string[](0))
        );

        assertEq(projectHandle.handleOf(chainId, projectId, projectOwner), "");
    }

    function testHandleOf_returnsHandleFromNewestContractIfRegisteredOnBothOldAndNew(
        string calldata name,
        string calldata subdomain,
        string calldata subsubdomain
    ) public {
        vm.assume(
            bytes(name).length > 0 &&
                bytes(subdomain).length > 0 &&
                bytes(subsubdomain).length > 0
        );

        uint256 projectId = jbProjects.createFor(projectOwner);
        uint256 chainId = 1;

        string memory KEY = projectHandle.TEXT_KEY();

        // name.subdomain.subsubdomain.eth is stored as ['subsubdomain', 'subdomain', 'domain']
        string[] memory nameParts = new string[](3);
        nameParts[0] = subsubdomain;
        nameParts[1] = subdomain;
        nameParts[2] = name;

        // The name parts stored in the old contract
        string[] memory oldNamePart = new string[](3);
        oldNamePart[0] = "it hurts";
        oldNamePart[1] = "so deprecated that";
        oldNamePart[2] = "I am";

        vm.prank(projectOwner);
        projectHandle.setEnsNamePartsFor(chainId, projectId, nameParts);

        vm.mockCall(
            address(ensRegistry),
            abi.encodeWithSelector(ENS.resolver.selector, _namehash(nameParts)),
            abi.encode(address(ensTextResolver))
        );

        vm.mockCall(
            address(ensTextResolver),
            abi.encodeWithSelector(
                ITextResolver.text.selector,
                _namehash(nameParts),
                KEY
            ),
            abi.encode(
                string.concat(
                    Strings.toString(chainId),
                    ":",
                    Strings.toString(projectId),
                    ":",
                    Strings.toHexString(uint256(uint160(projectOwner)))
                )
            )
        );

        // Mock the registration on the previous version
        vm.mockCall(
            address(oldHandle),
            abi.encodeCall(
                IJBProjectHandles.ensNamePartsOf,
                (chainId, projectId, projectOwner)
            ),
            abi.encode(oldNamePart)
        );

        // Returns the handle from the latest version
        assertEq(
            projectHandle.handleOf(chainId, projectId, projectOwner),
            string(abi.encodePacked(name, ".", subdomain, ".", subsubdomain))
        );
    }

    function testHandleOf_returnsEmptyStringIfENSIsNotRegistered(
        uint256 chainId,
        uint256 projectId,
        uint256 reverseId,
        string calldata name,
        string calldata subdomain,
        string calldata subsubdomain
    ) public {
        vm.assume(projectId != reverseId);

        // No handle set on the previous JBProjectHandle version
        vm.mockCall(
            address(oldHandle),
            abi.encodeCall(
                IJBProjectHandles.ensNamePartsOf,
                (chainId, projectId, projectOwner)
            ),
            abi.encode(new string[](0))
        );

        // name.subdomain.subsubdomain.eth is stored as ['subsubdomain', 'subdomain', 'domain']
        string[] memory nameParts = new string[](3);
        nameParts[0] = subsubdomain;
        nameParts[1] = subdomain;
        nameParts[2] = name;

        vm.mockCall(
            address(ensRegistry),
            abi.encodeWithSelector(ENS.resolver.selector, _namehash(nameParts)),
            abi.encode(address(0))
        );

        assertEq(projectHandle.handleOf(chainId, projectId, projectOwner), "");
    }

    function testHandleOf_returnsEmptyStringIfReverseIdDoesNotMatchProjectId(
        uint256 chainId,
        uint256 projectId,
        uint256 reverseId,
        string calldata name,
        string calldata subdomain,
        string calldata subsubdomain
    ) public {
        vm.assume(projectId != reverseId);

        // No handle set on the previous JBProjectHandle version
        vm.mockCall(
            address(oldHandle),
            abi.encodeCall(
                IJBProjectHandles.ensNamePartsOf,
                (chainId, projectId, projectOwner)
            ),
            abi.encode(new string[](0))
        );

        string memory KEY = projectHandle.TEXT_KEY();

        // name.subdomain.subsubdomain.eth is stored as ['subsubdomain', 'subdomain', 'domain']
        string[] memory nameParts = new string[](3);
        nameParts[0] = subsubdomain;
        nameParts[1] = subdomain;
        nameParts[2] = name;

        vm.mockCall(
            address(ensRegistry),
            abi.encodeWithSelector(ENS.resolver.selector, _namehash(nameParts)),
            abi.encode(address(ensTextResolver))
        );

        vm.mockCall(
            address(ensTextResolver),
            abi.encodeWithSelector(
                ITextResolver.text.selector,
                _namehash(nameParts),
                KEY
            ),
            abi.encode(Strings.toString(reverseId))
        );

        assertEq(projectHandle.handleOf(chainId, projectId, projectOwner), "");
    }

    function testHandleOf_returnsHandleIfReverseIdMatchProjectId(
        string calldata name,
        string calldata subdomain,
        string calldata subsubdomain
    ) public {
        vm.assume(
            bytes(name).length > 0 &&
                bytes(subdomain).length > 0 &&
                bytes(subsubdomain).length > 0
        );

        uint256 projectId = jbProjects.createFor(projectOwner);
        uint256 chainId = 1;

        string memory KEY = projectHandle.TEXT_KEY();

        // name.subdomain.subsubdomain.eth is stored as ['subsubdomain', 'subdomain', 'domain']
        string[] memory nameParts = new string[](3);
        nameParts[0] = subsubdomain;
        nameParts[1] = subdomain;
        nameParts[2] = name;

        vm.prank(projectOwner);
        projectHandle.setEnsNamePartsFor(chainId, projectId, nameParts);

        vm.mockCall(
            address(ensRegistry),
            abi.encodeWithSelector(ENS.resolver.selector, _namehash(nameParts)),
            abi.encode(address(ensTextResolver))
        );

        vm.mockCall(
            address(ensTextResolver),
            abi.encodeWithSelector(
                ITextResolver.text.selector,
                _namehash(nameParts),
                KEY
            ),
            abi.encode(
                string.concat(
                    Strings.toString(chainId),
                    ":",
                    Strings.toString(projectId),
                    ":",
                    Strings.toHexString(uint256(uint160(projectOwner)))
                )
            )
        );

        assertEq(
            projectHandle.handleOf(chainId, projectId, projectOwner),
            string(abi.encodePacked(name, ".", subdomain, ".", subsubdomain))
        );
    }

    //*********************************************************************//
    // ---------------------------- helpers ---- ------------------------- //
    //*********************************************************************//

    // Assert equals between two string arrays
    function assertEq(string[] memory first, string[] memory second) internal {
        assertEq(first.length, second.length);
        for (uint256 i; i < first.length; i++) {
            assertEq(keccak256(bytes(first[i])), keccak256(bytes(second[i])));
        }
    }

    function _namehash(
        string[] memory ensName
    ) internal pure returns (bytes32 namehash) {
        namehash = keccak256(
            abi.encodePacked(namehash, keccak256(abi.encodePacked("eth")))
        );

        // Get a reference to the number of parts are in the ENS name.
        uint256 nameLength = ensName.length;

        // Hash each part.
        for (uint256 i = 0; i < nameLength; i++) {
            namehash = keccak256(
                abi.encodePacked(
                    namehash,
                    keccak256(abi.encodePacked(ensName[i]))
                )
            );
        }
    }
}
