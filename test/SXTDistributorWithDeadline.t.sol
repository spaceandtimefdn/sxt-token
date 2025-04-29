// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Test} from "forge-std-1.9.6/src/Test.sol";
import {SXTDistributorWithDeadline} from "../src/distribution/SXTDistributorWithDeadline.sol";
import {SpaceAndTime} from "../src/SpaceAndTime.sol";

// solhint-disable-next-line max-states-count
contract SXTDistributorWithDeadlineTest is Test {
    SpaceAndTime public sxt;
    SXTDistributorWithDeadline public distributor;

    address public admin = address(1);
    address public pauser = address(2);
    address public recipient = address(this);
    address public owner = address(this);

    // Merkle tree data
    bytes32 public merkleRoot;

    // Leaf data
    uint256 public index0 = 0;
    address public account0 = address(0x1111);
    uint256 public amount0 = 100 * 10 ** 18;

    uint256 public index1 = 1;
    address public account1 = address(0x2222);
    uint256 public amount1 = 200 * 10 ** 18;

    // Merkle proofs
    bytes32[] public proof0;
    bytes32[] public proof1;
    bytes32[] public invalidProof;

    // Timestamp for deadline
    uint256 public startTime;
    uint256 public claimDuration = 7 days;
    uint256 public endTime;

    function setUp() public {
        // Set up current time and deadline
        // solhint-disable-next-line not-rely-on-time
        startTime = block.timestamp;
        endTime = startTime + claimDuration;

        // Deploy SXT token
        sxt = new SpaceAndTime(admin, pauser, recipient);

        // Calculate leaf nodes
        bytes32 leaf0 = keccak256(abi.encodePacked(index0, account0, amount0));
        bytes32 leaf1 = keccak256(abi.encodePacked(index1, account1, amount1));

        // Calculate merkle root (simple 2-leaf tree)
        bytes32 node01 = keccak256(abi.encodePacked(leaf0, leaf1));
        merkleRoot = node01;

        // Set up proofs
        proof0 = new bytes32[](1);
        proof0[0] = leaf1;

        proof1 = new bytes32[](1);
        proof1[0] = leaf0;

        // Set up invalid proof
        invalidProof = new bytes32[](1);
        invalidProof[0] = bytes32(uint256(1)); // Random invalid proof

        // Set up distributor with some tokens and a deadline
        distributor = new SXTDistributorWithDeadline(address(sxt), merkleRoot, endTime);

        // Transfer tokens to the distributor for distribution
        uint256 distributorAmount = 1000 * 10 ** 18;
        sxt.transfer(address(distributor), distributorAmount);
    }

    function testClaimBeforeDeadline() public {
        // Initial state
        assertEq(sxt.balanceOf(account0), 0);
        assertFalse(distributor.isClaimed(index0));

        // Ensure we're before the deadline
        // solhint-disable-next-line not-rely-on-time
        assertLt(block.timestamp, distributor.END_TIME());

        // Claim tokens
        vm.prank(account0);
        distributor.claim(index0, account0, amount0, proof0);

        // Verify state after claim
        assertTrue(distributor.isClaimed(index0));
        assertEq(sxt.balanceOf(account0), amount0);
    }

    function testWithdrawAfterDeadline() public {
        // Initial balance
        uint256 initialBalance = sxt.balanceOf(owner);
        uint256 distributorBalance = sxt.balanceOf(address(distributor));

        // Warp to after the deadline
        // solhint-disable-next-line not-rely-on-time
        vm.warp(distributor.END_TIME() + 1);

        // Withdraw remaining tokens
        distributor.withdraw();

        // Verify tokens were withdrawn to owner
        assertEq(sxt.balanceOf(owner), initialBalance + distributorBalance);
        assertEq(sxt.balanceOf(address(distributor)), 0);
    }

    function testCannotClaimAfterDeadline() public {
        // Warp to after the deadline
        // solhint-disable-next-line not-rely-on-time
        vm.warp(distributor.END_TIME() + 1);

        // Try to claim after deadline
        vm.prank(account0);
        vm.expectRevert(SXTDistributorWithDeadline.ClaimWindowFinished.selector);
        distributor.claim(index0, account0, amount0, proof0);
    }

    function testCannotWithdrawBeforeDeadline() public {
        // Ensure we're before the deadline
        // solhint-disable-next-line not-rely-on-time
        assertLt(block.timestamp, distributor.END_TIME());

        // Try to withdraw before deadline
        vm.expectRevert(SXTDistributorWithDeadline.NoWithdrawDuringClaim.selector);
        distributor.withdraw();
    }

    function testCannotConstructWithPastDeadline() public {
        // Try to create a distributor with a deadline in the past
        // solhint-disable-next-line not-rely-on-time
        uint256 pastDeadline = block.timestamp - 1;

        vm.expectRevert(SXTDistributorWithDeadline.EndTimeInPast.selector);
        new SXTDistributorWithDeadline(address(sxt), merkleRoot, pastDeadline);
    }

    function testOnlyOwnerCanWithdraw() public {
        // Warp to after the deadline
        // solhint-disable-next-line not-rely-on-time
        vm.warp(distributor.END_TIME() + 1);

        // Try to withdraw as non-owner
        vm.prank(account0);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, account0));
        distributor.withdraw();

        // Verify no tokens were withdrawn
        assertEq(sxt.balanceOf(account0), 0);
        assertGt(sxt.balanceOf(address(distributor)), 0);
    }
}
