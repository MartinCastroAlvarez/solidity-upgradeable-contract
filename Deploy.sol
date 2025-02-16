// Deploy.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./lib/forge-std/src/Script.sol";  // Import Foundry's standard library
import "./src/Manager.sol"; // Import ZoKrates verifier contract
import "./src/Verifier.sol";
import "./lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployScript is Script {
    function run() external {
        vm.startBroadcast(); // Allows transaction broadcasting

        // Deploy implementation contracts
        Manager managerImpl = new Manager();
        Verifier verifierImpl = new Verifier();

        // Encode initialization data
        bytes memory managerData = abi.encodeWithSelector(
            Manager.initialize.selector,
            msg.sender // This will be the admin address
        );
        bytes memory verifierData = abi.encodeWithSelector(
            Verifier.initialize.selector,
            msg.sender // This will be the admin address
        );

        // Deploy proxies
        ERC1967Proxy managerProxy = new ERC1967Proxy(
            address(managerImpl),
            managerData
        );

        ERC1967Proxy verifierProxy = new ERC1967Proxy(
            address(verifierImpl),
            verifierData
        );

        vm.stopBroadcast();
        
        console.log("Manager proxy deployed at:", address(managerProxy));
        console.log("Verifier proxy deployed at:", address(verifierProxy));
    }
}
