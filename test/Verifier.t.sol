// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Verifier.sol";
import "../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract VerifierTest is Test {
    Verifier public implementation;
    Verifier public verifier;
    address public admin;
    address public user;
    bytes32 public testSignature;

    event SignatureRegistered(address indexed user, bytes32 indexed signature);
    event SignatureRevoked(address indexed user, bytes32 indexed signature);

    function setUp() public {
        admin = address(this);
        user = address(0x1);
        testSignature = keccak256("test signature");
        
        // Deploy implementation
        implementation = new Verifier();
        
        // Encode initialization data
        bytes memory initData = abi.encodeWithSelector(
            Verifier.initialize.selector,
            admin
        );
        
        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        
        // Create interface to proxy
        verifier = Verifier(address(proxy));
    }

    function testInitialization() public view {
        assertTrue(verifier.hasRole(verifier.DEFAULT_ADMIN_ROLE(), admin));
    }

    function testRegisterSignature() public {
        vm.expectEmit(true, true, false, true);
        emit SignatureRegistered(user, testSignature);
        
        verifier.registerSignature(user, testSignature);
        assertTrue(verifier.verify(user, testSignature));
    }

    function testRevokeSignature() public {
        verifier.registerSignature(user, testSignature);
        
        vm.expectEmit(true, true, false, true);
        emit SignatureRevoked(user, testSignature);
        
        verifier.revokeSignature(user, testSignature);
        assertFalse(verifier.verify(user, testSignature));
    }

    function testRegisterSignatureUnauthorized() public {
        vm.prank(user);
        vm.expectRevert();
        verifier.registerSignature(user, testSignature);
    }

    function testRevokeSignatureUnauthorized() public {
        verifier.registerSignature(user, testSignature);
        
        vm.prank(user);
        vm.expectRevert();
        verifier.revokeSignature(user, testSignature);
    }

    function testRegisterSignatureZeroAddress() public {
        vm.expectRevert("Verifier: Invalid user address");
        verifier.registerSignature(address(0), testSignature);
    }

    function testRevokeSignatureZeroAddress() public {
        vm.expectRevert("Verifier: Invalid user address");
        verifier.revokeSignature(address(0), testSignature);
    }

    function testVerifyNonExistentSignature() public view {
        assertFalse(verifier.verify(user, testSignature));
    }

    function testMultipleSignaturesForSameUser() public {
        bytes32 signature1 = keccak256("signature1");
        bytes32 signature2 = keccak256("signature2");

        verifier.registerSignature(user, signature1);
        verifier.registerSignature(user, signature2);

        assertTrue(verifier.verify(user, signature1));
        assertTrue(verifier.verify(user, signature2));

        verifier.revokeSignature(user, signature1);

        assertFalse(verifier.verify(user, signature1));
        assertTrue(verifier.verify(user, signature2));
    }

    function testSameSignatureDifferentUsers() public {
        address user2 = address(0x2);

        verifier.registerSignature(user, testSignature);
        verifier.registerSignature(user2, testSignature);

        assertTrue(verifier.verify(user, testSignature));
        assertTrue(verifier.verify(user2, testSignature));

        verifier.revokeSignature(user, testSignature);

        assertFalse(verifier.verify(user, testSignature));
        assertTrue(verifier.verify(user2, testSignature));
    }
}
