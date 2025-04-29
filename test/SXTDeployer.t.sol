// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20Errors} from "@openzeppelin-contracts-5.2.0/interfaces/draft-IERC6093.sol";
import {Test} from "forge-std-1.9.6/src/Test.sol";
import {SpaceAndTime} from "./../src/SpaceAndTime.sol";
import {SXTDeployer} from "./../src/SXTDeployer.sol";

// Disabling gas-small-strings because of the file paths
// solhint-disable gas-small-strings
contract SXTDeployerTest is Test {
    function testDeploy() public {
        SXTDeployer.Config memory config = SXTDeployer.Config({
            defaultAdmin: address(0x2),
            pauserAdmin: address(0x3),
            recipients: new SXTDeployer.RecipientAmount[](3)
        });
        config.recipients[0] = SXTDeployer.RecipientAmount({amount: 1 * 1e9 * 1e18, recipient: address(0x4)});
        config.recipients[1] = SXTDeployer.RecipientAmount({amount: 2 * 1e9 * 1e18, recipient: address(0x5)});
        config.recipients[2] = SXTDeployer.RecipientAmount({amount: 2 * 1e9 * 1e18, recipient: address(0x6)});

        SXTDeployer deployer = new SXTDeployer(config);

        // get token address
        address token = deployer.tokenAddress();
        SpaceAndTime sxt = SpaceAndTime(token);

        assertEq(sxt.balanceOf(address(0x4)), 1 * 1e9 * 1e18);
        assertEq(sxt.balanceOf(address(0x5)), 2 * 1e9 * 1e18);
        assertEq(sxt.balanceOf(address(0x6)), 2 * 1e9 * 1e18);
    }

    function testDeployFromConfig() public {
        SXTDeployer.Config memory config = abi.decode(
            vm.parseJson(vm.readFile(string.concat(vm.projectRoot(), "/test/input/validConfig.json"))),
            (SXTDeployer.Config)
        );

        SXTDeployer deployer = new SXTDeployer(config);

        // get token address
        address token = deployer.tokenAddress();

        SpaceAndTime sxt = SpaceAndTime(token);
        uint256 recipientsLength = config.recipients.length;
        for (uint256 i = 0; i < recipientsLength; ++i) {
            assertEq(sxt.balanceOf(config.recipients[i].recipient), config.recipients[i].amount);
        }
    }

    function testDeployWithTooLittleDistributed() public {
        SXTDeployer.Config memory config = SXTDeployer.Config({
            defaultAdmin: address(0x2),
            pauserAdmin: address(0x3),
            recipients: new SXTDeployer.RecipientAmount[](3)
        });
        config.recipients[0] = SXTDeployer.RecipientAmount({amount: 1 * 1e9 * 1e18, recipient: address(0x4)});
        config.recipients[1] = SXTDeployer.RecipientAmount({amount: 1 * 1e9 * 1e18, recipient: address(0x5)});
        config.recipients[2] = SXTDeployer.RecipientAmount({amount: 2 * 1e9 * 1e18, recipient: address(0x6)});

        vm.expectRevert(SXTDeployer.DeployerHasRemainingTokens.selector);
        new SXTDeployer(config);
    }

    function testDeployFromConfigWithTooLittleDistributed() public {
        SXTDeployer.Config memory config = abi.decode(
            vm.parseJson(vm.readFile(string.concat(vm.projectRoot(), "/test/input/tooLittleDistributedConfig.json"))),
            (SXTDeployer.Config)
        );

        vm.expectRevert(SXTDeployer.DeployerHasRemainingTokens.selector);
        new SXTDeployer(config);
    }

    function testDeployWithTooMuchDistributed() public {
        SXTDeployer.Config memory config = SXTDeployer.Config({
            defaultAdmin: address(0x2),
            pauserAdmin: address(0x3),
            recipients: new SXTDeployer.RecipientAmount[](3)
        });
        config.recipients[0] = SXTDeployer.RecipientAmount({amount: 1 * 1e9 * 1e18, recipient: address(0x4)});
        config.recipients[1] = SXTDeployer.RecipientAmount({amount: 2 * 1e9 * 1e18, recipient: address(0x5)});
        config.recipients[2] = SXTDeployer.RecipientAmount({amount: 3 * 1e9 * 1e18, recipient: address(0x6)});

        vm.expectPartialRevert(IERC20Errors.ERC20InsufficientBalance.selector);
        new SXTDeployer(config);
    }

    function testDeployFromConfigWithTooMuchDistributed() public {
        SXTDeployer.Config memory config = abi.decode(
            vm.parseJson(vm.readFile(string.concat(vm.projectRoot(), "/test/input/tooMuchDistributedConfig.json"))),
            (SXTDeployer.Config)
        );

        vm.expectPartialRevert(IERC20Errors.ERC20InsufficientBalance.selector);
        new SXTDeployer(config);
    }

    function testDeployWithZeroRecipient() public {
        SXTDeployer.Config memory config = SXTDeployer.Config({
            defaultAdmin: address(0x2),
            pauserAdmin: address(0x3),
            recipients: new SXTDeployer.RecipientAmount[](3)
        });
        config.recipients[0] = SXTDeployer.RecipientAmount({amount: 1 * 1e9 * 1e18, recipient: address(0x0)});
        config.recipients[1] = SXTDeployer.RecipientAmount({amount: 2 * 1e9 * 1e18, recipient: address(0x5)});
        config.recipients[2] = SXTDeployer.RecipientAmount({amount: 2 * 1e9 * 1e18, recipient: address(0x6)});

        vm.expectRevert(SXTDeployer.RecipientCannotBeZero.selector);
        new SXTDeployer(config);
    }

    function testDeployFromConfigWithZeroRecipient() public {
        SXTDeployer.Config memory config = abi.decode(
            vm.parseJson(vm.readFile(string.concat(vm.projectRoot(), "/test/input/zeroRecipientConfig.json"))),
            (SXTDeployer.Config)
        );

        vm.expectRevert(SXTDeployer.RecipientCannotBeZero.selector);
        new SXTDeployer(config);
    }

    function testDeployWithDuplicateRecipients() public {
        SXTDeployer.Config memory config = SXTDeployer.Config({
            defaultAdmin: address(0x2),
            pauserAdmin: address(0x3),
            recipients: new SXTDeployer.RecipientAmount[](3)
        });
        config.recipients[0] = SXTDeployer.RecipientAmount({amount: 1 * 1e9 * 1e18, recipient: address(0x4)});
        config.recipients[1] = SXTDeployer.RecipientAmount({amount: 2 * 1e9 * 1e18, recipient: address(0x4)});
        config.recipients[2] = SXTDeployer.RecipientAmount({amount: 2 * 1e9 * 1e18, recipient: address(0x6)});

        vm.expectRevert(SXTDeployer.DuplicateRecipient.selector);
        new SXTDeployer(config);
    }

    function testDeployFromConfigWithDuplicateRecipients() public {
        SXTDeployer.Config memory config = abi.decode(
            vm.parseJson(vm.readFile(string.concat(vm.projectRoot(), "/test/input/duplicateRecipientsConfig.json"))),
            (SXTDeployer.Config)
        );

        vm.expectRevert(SXTDeployer.DuplicateRecipient.selector);
        new SXTDeployer(config);
    }

    function testFuzzDeployRandomInput(SXTDeployer.Config memory config) public {
        vm.expectRevert();
        new SXTDeployer(config);
    }
}
