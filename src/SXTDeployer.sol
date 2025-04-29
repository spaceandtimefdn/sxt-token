// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {SafeERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/utils/SafeERC20.sol";
import {SpaceAndTime} from "./SpaceAndTime.sol";

contract SXTDeployer {
    using SafeERC20 for SpaceAndTime;

    SpaceAndTime public immutable SXT_TOKEN;

    error RecipientCannotBeZero();
    /// @notice Duplicate recipient in the list
    /// @dev Recipients must be unique and in ascending order
    error DuplicateRecipient();
    error DeployerHasRemainingTokens();

    // NOTE: the order of these fields should be alphabetically
    // ordered in order for vm.parseJson to work correctly
    /// @notice Represents a token recipient and the amount they should receive
    /// @param amount The number of tokens to transfer to the recipient
    /// @param recipient The address that will receive the tokens
    struct RecipientAmount {
        uint256 amount;
        address recipient;
    }

    // NOTE: the order of these fields should be alphabetically
    // ordered in order for vm.parseJson to work correctly
    /// @notice Configuration for deploying and initializing the SXT token
    /// @param defaultAdmin The address that will receive the DEFAULT_ADMIN_ROLE
    /// @param pauserAdmin The address that will receive the PAUSER_ROLE
    /// @param recipients Array of recipients and their token amounts for initial distribution
    struct Config {
        address defaultAdmin;
        address pauserAdmin;
        RecipientAmount[] recipients;
    }

    constructor(Config memory config) {
        SXT_TOKEN = new SpaceAndTime(config.defaultAdmin, config.pauserAdmin, address(this));

        uint256 recipientsLength = config.recipients.length;
        if (recipientsLength != 0 && config.recipients[0].recipient == address(0)) {
            revert RecipientCannotBeZero();
        }
        for (uint256 i = 0; i < recipientsLength; ++i) {
            if (i > 0 && !(config.recipients[i].recipient > config.recipients[i - 1].recipient)) {
                revert DuplicateRecipient();
            }
            // Reference: https://github.com/crytic/slither/wiki/Detector-Documentation/#calls-inside-a-loop
            // safe since the callee is known and deployed by contract
            // slither-disable-next-line calls-loop
            SXT_TOKEN.safeTransfer(config.recipients[i].recipient, config.recipients[i].amount);
        }

        if (SXT_TOKEN.balanceOf(address(this)) != 0) {
            revert DeployerHasRemainingTokens();
        }
    }

    function tokenAddress() public view returns (address token) {
        token = address(SXT_TOKEN);
    }
}
