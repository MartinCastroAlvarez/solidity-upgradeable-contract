// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Manager.sol";
import "../src/Verifier.sol";
import "../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../lib//openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol";

contract MockNewManager is Manager {
    bool public migrated;
    address public migratedVerifier;
    uint256 public migratedCounter;

    function migrateState(address _verifier, uint256 _counter) external {
        migrated = true;
        migratedVerifier = _verifier;
        migratedCounter = _counter;
    }
}

contract ManagerTest is Test {
    Manager public implementation;
    Manager public manager;
    Verifier public verifier;
    address public admin;
    address public maintainer;
    address public authority;
    address public user;

    event VerifierUpdated(address indexed newVerifier, address indexed updater);
    event ContractPaused(address indexed pauser);
    event ContractUnpaused(address indexed unpauser);
    event RoleAssigned(bytes32 indexed role, address indexed account, address indexed assignedBy);
    event RoleRemoved(bytes32 indexed role, address indexed account, address indexed removedBy);
    event ContractUpgraded(address indexed upgrader);

    function setUp() public {
        admin = address(this);
        maintainer = address(0x1);
        authority = address(0x2);
        user = address(0x3);

        // Deploy Manager implementation and proxy
        implementation = new Manager();
        bytes memory initData = abi.encodeWithSelector(
            Manager.initialize.selector,
            admin
        );
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        manager = Manager(address(proxy));

        // Deploy Verifier
        Verifier verifierImpl = new Verifier();
        bytes memory verifierInitData = abi.encodeWithSelector(
            Verifier.initialize.selector,
            admin
        );
        ERC1967Proxy verifierProxy = new ERC1967Proxy(
            address(verifierImpl),
            verifierInitData
        );
        verifier = Verifier(address(verifierProxy));

        // Setup roles
        manager.assignRole(manager.MAINTAINER_ROLE(), maintainer);
        manager.assignRole(manager.AUTHORITY_ROLE(), authority);
    }

    function testInitialization() public view {
        assertTrue(manager.hasRole(manager.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(manager.hasRole(manager.MAINTAINER_ROLE(), maintainer));
        assertTrue(manager.hasRole(manager.AUTHORITY_ROLE(), authority));
        assertEq(manager.getVerificationCounter(), 0);
    }

    function testSetVerifier() public {
        vm.startPrank(authority);
        vm.expectEmit(true, true, false, true);
        emit VerifierUpdated(address(verifier), authority);
        manager.setVerifier(address(verifier));
        assertEq(manager.getVerifier(), address(verifier));
        vm.stopPrank();
    }

    function testSetVerifierUnauthorized() public {
        vm.prank(user);
        vm.expectRevert();
        manager.setVerifier(address(verifier));
    }

    function testBatchVerify() public {
        // Setup verifier with some valid signatures
        bytes32[] memory signatures = new bytes32[](3);
        signatures[0] = keccak256("sig1");
        signatures[1] = keccak256("sig2");
        signatures[2] = keccak256("sig3");

        vm.startPrank(authority);
        manager.setVerifier(address(verifier));
        vm.stopPrank();

        vm.startPrank(admin);
        verifier.registerSignature(user, signatures[0]);
        verifier.registerSignature(user, signatures[2]);
        vm.stopPrank();

        bool[] memory results = manager.batchVerify(user, signatures);
        
        assertTrue(results[0]);
        assertFalse(results[1]);
        assertTrue(results[2]);
        assertEq(manager.getVerificationCounter(), 2);
    }

    function testPause() public {
        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit ContractPaused(admin);
        manager.pause();
        assertTrue(manager.paused());
    }

    function testUnpause() public {
        vm.startPrank(admin);
        manager.pause();
        vm.expectEmit(true, false, false, true);
        emit ContractUnpaused(admin);
        manager.unpause();
        vm.stopPrank();
        assertFalse(manager.paused());
    }

    function testUpgrade() public {
        // Setup initial state
        vm.prank(authority);
        manager.setVerifier(address(verifier));

        // Create new version of contract
        MockNewManager newManager = new MockNewManager();
        
        vm.startPrank(maintainer);
        vm.expectEmit(true, false, false, true);
        emit ContractUpgraded(maintainer);
        manager.upgrade(address(newManager));
        vm.stopPrank();

        assertTrue(newManager.migrated());
        assertEq(newManager.migratedVerifier(), address(verifier));
        assertEq(newManager.migratedCounter(), 0);
    }

    function testRoleManagement() public {
        address newAuthority = address(0x4);
        
        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit RoleAssigned(manager.AUTHORITY_ROLE(), newAuthority, admin);
        manager.assignRole(manager.AUTHORITY_ROLE(), newAuthority);
        assertTrue(manager.hasRole(manager.AUTHORITY_ROLE(), newAuthority));

        vm.expectEmit(true, true, true, true);
        emit RoleRemoved(manager.AUTHORITY_ROLE(), newAuthority, admin);
        manager.removeRole(manager.AUTHORITY_ROLE(), newAuthority);
        assertFalse(manager.hasRole(manager.AUTHORITY_ROLE(), newAuthority));
        vm.stopPrank();
    }

    function testPausedOperations() public {
        vm.prank(admin);
        manager.pause();

        vm.startPrank(authority);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        manager.setVerifier(address(verifier));
        vm.stopPrank();

        bytes32[] memory signatures = new bytes32[](1);
        signatures[0] = keccak256("sig1");
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        manager.batchVerify(user, signatures);
    }

    function testUpgradedOperations() public {
        MockNewManager newManager = new MockNewManager();
        
        vm.prank(maintainer);
        manager.upgrade(address(newManager));

        vm.startPrank(authority);
        vm.expectRevert("Manager: Contract is upgraded");
        manager.setVerifier(address(verifier));
        vm.stopPrank();

        bytes32[] memory signatures = new bytes32[](1);
        signatures[0] = keccak256("sig1");
        vm.expectRevert("Manager: Contract is upgraded");
        manager.batchVerify(user, signatures);
    }
}
