# solidity-upgradeable-contract

Upgradeable Solidity contract with access management.

![wallpaper.jpg](./wallpaper.jpg)

## References

- [Solidity Upgradeable Contracts](https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable)
- [Running Anvil](https://github.com/MartinCastroAlvarez/anvil-of-fury/tree/main)

## Overview

- [Manager.sol](./src/Manager.sol) is an upgradeable Solidity contract built with OpenZeppelin's upgradeable libraries that offers a secure and flexible solution for managing signature verifications. It combines a robust access control system, pausing functionality for emergencies, and upgradeability with state migration to ensure the contract remains secure and maintainable over time.
- [Verifier.sol](./src/Verifier.sol) is a simple Solidity contract that allows to register and revoke signatures.
- [Deploy.sol](./Deploy.sol) is a script that deploys the [Manager.sol](./src/Manager.sol) and [Verifier.sol](./src/Verifier.sol) contracts.
- [test/Manager.t.sol](./test/Manager.t.sol) is a test file that tests the [Manager.sol](./src/Manager.sol) contract.
- [test/Verifier.t.sol](./test/Verifier.t.sol) is a test file that tests the [Verifier.sol](./src/Verifier.sol) contract.

#### Interfaces

- The `Initializable` base contract is use to guarantee that a contract is only initialized once.
- The `Upgradeable` base contract is use to guarantee that a contract is upgradeable.
- The `AccessControl` base contract is use to manage access control.
- The `Pausable` base contract is use to pause the contract in case of emergency.

#### Access Control

The [Manager](./src/Manager.sol) contract implements a role-based access control system to restrict functionalities to authorized users. There are three primary roles:

- **Admin (DEFAULT_ADMIN_ROLE):** Has full control over the contract, can execute all methods, and is the only role allowed to remove roles.
- **Maintainer (MAINTAINER_ROLE):** Authorized to upgrade the contract and assign other maintainers.
- **Authority (AUTHORITY_ROLE):** Empowered to set or update the verifier contract and assign other authorities.

#### Upgradeability

The contract supports upgradeability via an upgrade function that can only be called by an Admin or a Maintainer. During an upgrade, the current state—specifically the verifier address and the verification counter—is migrated to a new contract instance through a defined migration interface. After upgrading, no further operations can be performed on the original contract, ensuring a secure transition.

#### Pausability

Manager incorporates a pausability feature that allows an Admin to pause or unpause the contract in emergency scenarios. When paused, all functions—including verification, access control modifications, and upgrades—are disabled, safeguarding the contract from potential malicious activities or unforeseen issues until the situation is resolved.

#### Verification

The contract performs batch verification of signatures by interacting with an external verifier contract. The `batchVerify` function processes an array of signatures for a given user, calling the verifier's `verify` method on each signature. Each successful verification increments a counter using SafeMath to prevent overflows, enabling accurate tracking of valid verifications.

#### Error Handling

Robust error handling is built into the contract to ensure that if any call fails—such as an invalid verifier address or an error during verification—the entire transaction is reverted. This mechanism prevents partial state updates and ensures the integrity and consistency of the contract's state under all conditions.

## Setup

Start Anvil:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
anvil
```

Install Foundry dependencies:

```bash
forge install foundry-rs/forge-std
```

Install OpenZeppelin dependencies:

```bash
forge install OpenZeppelin/openzeppelin-contracts
forge install OpenZeppelin/openzeppelin-contracts-upgradeable
```

## Deployment

To test the [Manager](./src/Manager.sol) contract, run the following command:

```bash
forge test
```

Response:

```bash
[...]
Ran 2 test suites in 298.44ms (2.46ms CPU time): 21 tests passed, 0 failed, 0 skipped (21 total tests)
```

Next, to deploy the [Manager](./src/Manager.sol) and [Verifier](./src/Verifier.sol) contracts, run the following command:

```bash
forge script ./Deploy.sol \
    --rpc-url http://127.0.0.1:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    --broadcast
```

Response:

```bash
[...]
Script ran successfully.

== Logs ==
  Manager proxy deployed at: 0xc6e7DF5E7b4f2A278906862b61205850344D4e7d
  Verifier proxy deployed at: 0x59b670e9fA9D0A427751Af201D676719a970857b
[...]
```

Export the contract ABIs:

```bash
cat out/Manager.sol/Manager.json | jq -r '.abi' > Manager.abi
cat out/Verifier.sol/Verifier.json | jq -r '.abi' > Verifier.abi
```

## Testing

Set the env vars before running the tests:

```bash
# Update these with your proxy addresses from deployment
export MANAGER_ADDRESS=0xc6e7DF5E7b4f2A278906862b61205850344D4e7d
export VERIFIER_ADDRESS=0x59b670e9fA9D0A427751Af201D676719a970857b
export ADMIN_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
export ADMIN_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export ETHEREUM_RPC_URL=http://127.0.0.1:8545
export AUTHORITY_ROLE=$(cast keccak "AUTHORITY_ROLE")
export USER_ADDRESS=0x742d35cc6634c0532925a3b844f51317abc046cd
export USER_SIGNATURE=0x0000000000000000000000000000000000000000000000000000000000000000
```

Grant AUTHORITY_ROLE to admin (needed to set verifier):

```bash
cast send $MANAGER_ADDRESS "assignRole(bytes32,address)" $AUTHORITY_ROLE $ADMIN_ADDRESS \
    --private-key $ADMIN_PRIVATE_KEY --rpc-url $ETHEREUM_RPC_URL
```

Pause the Manager contract:

```bash
cast send $MANAGER_ADDRESS "pause()" \
    --private-key $ADMIN_PRIVATE_KEY --rpc-url $ETHEREUM_RPC_URL
```

Verify the contract is paused:

```bash
cast call $MANAGER_ADDRESS "paused()" --rpc-url $ETHEREUM_RPC_URL
```

Unpause the Manager contract:

```bash
cast send $MANAGER_ADDRESS "unpause()" \
    --private-key $ADMIN_PRIVATE_KEY --rpc-url $ETHEREUM_RPC_URL
```

Set the Verifier contract in the Manager:

```bash
cast send $MANAGER_ADDRESS "setVerifier(address)" $VERIFIER_ADDRESS \
    --private-key $ADMIN_PRIVATE_KEY --rpc-url $ETHEREUM_RPC_URL
```

Verify the verifier address is set correctly:

```bash
cast call $MANAGER_ADDRESS "getVerifier()" --rpc-url $ETHEREUM_RPC_URL
```

Register a signature in the Verifier contract:

```bash
cast send $VERIFIER_ADDRESS "registerSignature(address,bytes32)" $USER_ADDRESS $USER_SIGNATURE \
    --private-key $ADMIN_PRIVATE_KEY --rpc-url $ETHEREUM_RPC_URL
```

Verify the signature through the Manager contract:

```bash
# Create an array with one signature for batch verification
export SIGNATURES="[$USER_SIGNATURE]"
cast send $MANAGER_ADDRESS "batchVerify(address,bytes32[])" $USER_ADDRESS $SIGNATURES \
    --private-key $ADMIN_PRIVATE_KEY --rpc-url $ETHEREUM_RPC_URL
```

Check the verification counter (should be 1):

```bash
cast call $MANAGER_ADDRESS "getVerificationCounter()" --rpc-url $ETHEREUM_RPC_URL
```

The counter value will be returned in hex format. To convert it to decimal:

```bash
cast --to-dec $(cast call $MANAGER_ADDRESS "getVerificationCounter()" --rpc-url $ETHEREUM_RPC_URL)
```
