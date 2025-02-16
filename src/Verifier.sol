// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../lib/openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import "../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";

contract Verifier is Initializable, AccessControlUpgradeable {
    // Mapping to store valid signatures for each user
    mapping(address => mapping(bytes32 => bool)) private validSignatures;
    
    event SignatureRegistered(address indexed user, bytes32 indexed signature);
    event SignatureRevoked(address indexed user, bytes32 indexed signature);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin) public initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /**
     * @dev Registers a signature as valid for a user
     * @param user The address of the user
     * @param signature The signature to register
     */
    function registerSignature(address user, bytes32 signature) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(user != address(0), "Verifier: Invalid user address");
        validSignatures[user][signature] = true;
        emit SignatureRegistered(user, signature);
    }

    /**
     * @dev Revokes a previously registered signature
     * @param user The address of the user
     * @param signature The signature to revoke
     */
    function revokeSignature(address user, bytes32 signature) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(user != address(0), "Verifier: Invalid user address");
        validSignatures[user][signature] = false;
        emit SignatureRevoked(user, signature);
    }

    /**
     * @dev Verifies if a signature is valid for a user
     * @param user The address of the user
     * @param signature The signature to verify
     * @return bool Returns true if the signature is valid for the user
     */
    function verify(address user, bytes32 signature) external view returns (bool) {
        return validSignatures[user][signature];
    }
} 