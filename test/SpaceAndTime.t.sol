// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std-1.9.6/src/Test.sol";
import {SpaceAndTime} from "../src/SpaceAndTime.sol";
import {SigUtils} from "./utils/SigUtils.sol";

contract SXTTest is Test {
    SigUtils internal sigUtils;

    SpaceAndTime public sxt;
    uint256 internal ownerPrivateKey;
    uint256 internal spenderPrivateKey;

    address internal owner;
    address internal spender;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    function setUp() public {
        sxt = new SpaceAndTime(address(this), address(this), address(this));

        sigUtils = new SigUtils(sxt.DOMAIN_SEPARATOR());

        ownerPrivateKey = 0xA11CE;
        spenderPrivateKey = 0xB0B;

        owner = vm.addr(ownerPrivateKey);
        spender = vm.addr(spenderPrivateKey);
    }

    function testTransfer() public {
        sxt.transfer(address(0x01), 1000);
        assertEq(sxt.balanceOf(address(0x01)), 1000);
    }

    function testApprove() public {
        sxt.approve(address(this), 1000);
        assertEq(sxt.allowance(address(this), address(this)), 1000);
    }

    function testPause() public {
        sxt.pause();
        assertEq(sxt.paused(), true);
    }

    function testUnpause() public {
        sxt.pause();

        sxt.unpause();
        assertEq(sxt.paused(), false);
    }

    function testRenouncePauserRole() public {
        assertEq(sxt.hasRole(PAUSER_ROLE, address(this)), true);

        sxt.renounceRole(PAUSER_ROLE, address(this));
        assertEq(sxt.hasRole(PAUSER_ROLE, address(this)), false);
    }

    function testRenounceDefaultAdminRole() public {
        assertEq(sxt.hasRole(DEFAULT_ADMIN_ROLE, address(this)), true);

        sxt.renounceRole(DEFAULT_ADMIN_ROLE, address(this));
        assertEq(sxt.hasRole(DEFAULT_ADMIN_ROLE, address(this)), false);
    }

    function testNonces() public view {
        assertEq(sxt.nonces(address(this)), 0);
    }

    function testPermit() public {
        SigUtils.Permit memory permit =
            SigUtils.Permit({owner: owner, spender: spender, value: 1e18, nonce: 0, deadline: 1 days});

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        sxt.permit({
            owner: permit.owner,
            spender: permit.spender,
            value: permit.value,
            deadline: permit.deadline,
            v: v,
            r: r,
            s: s
        });

        assertEq(sxt.allowance(owner, spender), 1e18);
        assertEq(sxt.nonces(owner), 1);
    }
}
