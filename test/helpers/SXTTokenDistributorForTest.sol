// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {SXTTokenDistributor} from "../../src/distribution/SXTTokenDistributor.sol";

/**
 * @title SXTTokenDistributorForTest
 * @notice A concrete implementation of SXTTokenDistributor for testing
 */
contract SXTTokenDistributorForTest is SXTTokenDistributor {
    constructor(address token_, bytes32 merkleRoot_) SXTTokenDistributor(token_, merkleRoot_) {}
}
