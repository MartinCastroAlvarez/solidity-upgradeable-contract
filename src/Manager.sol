// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "../lib/openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol";
import "../lib/openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";

interface IVerifier {
    function verify(address user, bytes32 signature) external view returns (bool);
}

interface IMigratable {
    function migrateState(address _verifier, uint256 _counter) external;
}

contract Manager is Initializable, PausableUpgradeable, AccessControlUpgradeable {
    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");
    bytes32 public constant AUTHORITY_ROLE = keccak256("AUTHORITY_ROLE");

    IVerifier private verifier;
    uint256 private verificationCounter;
    bool private upgraded;

    event VerifierUpdated(address indexed newVerifier, address indexed updater);
    event ContractPaused(address indexed pauser);
    event ContractUnpaused(address indexed unpauser);
    event RoleAssigned(bytes32 indexed role, address indexed account, address indexed assignedBy);
    event RoleRemoved(bytes32 indexed role, address indexed account, address indexed removedBy);
    event ContractUpgraded(address indexed upgrader);

    // Modifier to check if the contract is not upgraded.
    modifier whenNotUpgraded() {
        require(!upgraded, "Manager: Contract is upgraded");
        _;
    }

    // Initialize the contract. Only admins can do this.
    function initialize(address admin) public initializer {
        __Pausable_init();
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _setRoleAdmin(MAINTAINER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(AUTHORITY_ROLE, DEFAULT_ADMIN_ROLE);
        upgraded = false;
        verificationCounter = 0;
    }

    // Pause the contract. Only admins can do this.
    function pause() external whenNotPaused whenNotUpgraded onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
        emit ContractPaused(msg.sender);
    }

    // Unpause the contract. Only admins can do this.
    function unpause() external whenPaused whenNotUpgraded onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
        emit ContractUnpaused(msg.sender);
    }

    // Set the verifier address. Only authority roles can do this.
    function setVerifier(address _verifier) external whenNotPaused whenNotUpgraded onlyRole(AUTHORITY_ROLE) {
        require(_verifier != address(0), "Manager: Invalid verifier address");
        verifier = IVerifier(_verifier);
        emit VerifierUpdated(_verifier, msg.sender);
    }

    // Get the verifier address.
    function getVerifier() external view whenNotPaused whenNotUpgraded returns (address) {
        return address(verifier);
    }

    // Get the verification counter.
    function getVerificationCounter() external view whenNotPaused whenNotUpgraded returns (uint256) {
        return verificationCounter;
    }

    // Verify a batch of signatures using the external verifier contract.
    function batchVerify(address user, bytes32[] calldata signatures)
        external
        whenNotPaused
        whenNotUpgraded
        returns (bool[] memory results)
    {
        require(address(verifier) != address(0), "Manager: Verifier not set");
        uint256 len = signatures.length;
        results = new bool[](len);
        for (uint256 i = 0; i < len; i++) {
            try verifier.verify(user, signatures[i]) returns (bool result) {
                results[i] = result;
                if (result) {
                    verificationCounter++;
                }
            } catch {
                results[i] = false;
            }
        }
        return results;
    }

    // Assign a role to an account. Only admins can do this.
    function assignRole(bytes32 role, address account) external whenNotPaused whenNotUpgraded onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(role, account);
        emit RoleAssigned(role, account, msg.sender);
    }

    // Remove a role from an account. Only admins can do this.
    function removeRole(bytes32 role, address account)
        external
        whenNotPaused
        whenNotUpgraded
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        revokeRole(role, account);
        emit RoleRemoved(role, account, msg.sender);
    }

    // Upgrade this contract to a new version and migrate the state (verifier and counter). Only maintainers can do this.
    function upgrade(address newContract) external whenNotPaused whenNotUpgraded onlyRole(MAINTAINER_ROLE) {
        require(newContract != address(0), "Manager: Invalid new contract address");
        IMigratable(newContract).migrateState(address(verifier), verificationCounter);
        upgraded = true;
        emit ContractUpgraded(msg.sender);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
