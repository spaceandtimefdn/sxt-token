/* solhint-disable imports-order */
// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std-1.9.6/src/Test.sol";
import {SpaceAndTime} from "../src/SpaceAndTime.sol";
import {SXTTokenDistributor} from "../src/distribution/SXTTokenDistributor.sol";
import {SXTTokenDistributorForTest} from "./helpers/SXTTokenDistributorForTest.sol";

// solhint-disable-next-line max-states-count
contract SXTTokenDistributorTest is Test {
    SpaceAndTime public sxt;
    SXTTokenDistributor public distributor;

    address public admin = address(1);
    address public pauser = address(2);
    address public recipient = address(this);

    address public user1 = address(0x1111);
    address public user2 = address(0x2222);
    address public user3 = address(0x3333);

    // Manually computed merkle tree for testing
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

    function setUp() public {
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

        // Set up distributor with some tokens
        distributor = new SXTTokenDistributorForTest(address(sxt), merkleRoot);

        // Transfer tokens to the distributor for distribution
        uint256 distributorAmount = 1000 * 10 ** 18;
        sxt.transfer(address(distributor), distributorAmount);
    }

    function testClaim() public {
        // Initial state
        assertEq(sxt.balanceOf(account0), 0);
        assertFalse(distributor.isClaimed(index0));

        // Claim tokens
        vm.prank(account0);
        distributor.claim(index0, account0, amount0, proof0);

        // Verify state after claim
        assertTrue(distributor.isClaimed(index0));
        assertEq(sxt.balanceOf(account0), amount0);
    }

    function testCannotClaimWithInvalidProof() public {
        // Try to claim with invalid proof
        vm.prank(account0);
        vm.expectRevert(SXTTokenDistributor.InvalidProof.selector);
        distributor.claim(index0, account0, amount0, invalidProof);
    }

    function testCannotClaimTwice() public {
        // First claim (valid)
        vm.prank(account0);
        distributor.claim(index0, account0, amount0, proof0);

        // Second claim (should fail)
        vm.prank(account0);
        vm.expectRevert(SXTTokenDistributor.AlreadyClaimed.selector);
        distributor.claim(index0, account0, amount0, proof0);
    }

    function testCannotClaimWithModifiedData() public {
        // Try to claim with modified amount
        uint256 modifiedAmount = amount0 + 1;

        vm.prank(account0);
        vm.expectRevert(SXTTokenDistributor.InvalidProof.selector);
        distributor.claim(index0, account0, modifiedAmount, proof0);

        // Try to claim with modified account
        address modifiedAccount = address(0x4444);

        vm.prank(modifiedAccount);
        vm.expectRevert(SXTTokenDistributor.InvalidProof.selector);
        distributor.claim(index0, modifiedAccount, amount0, proof0);

        // Try to claim with modified index
        uint256 modifiedIndex = index0 + 5;

        vm.prank(account0);
        vm.expectRevert(SXTTokenDistributor.InvalidProof.selector);
        distributor.claim(modifiedIndex, account0, amount0, proof0);
    }

    function testTokenAndMerkleRootGetters() public view {
        // Test token() function
        assertEq(distributor.token(), address(sxt));

        // Test merkleRoot() function
        assertEq(distributor.merkleRoot(), merkleRoot);
    }
}
