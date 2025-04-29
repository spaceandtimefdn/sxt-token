// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std-1.9.6/src/Script.sol";
import {SXTDeployer} from "src/SXTDeployer.sol";

contract SpaceAndTimeScript is Script {
    function run() public {
        SXTDeployer.Config memory config = abi.decode(
            vm.parseJson(vm.readFile(string.concat(vm.projectRoot(), "/script/input/config.json"))),
            (SXTDeployer.Config)
        );

        vm.startBroadcast();

        new SXTDeployer(config);

        vm.stopBroadcast();
    }
}
