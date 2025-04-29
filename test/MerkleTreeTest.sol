// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/* solhint-disable gas-small-strings */
import {Test} from "forge-std-1.9.6/src/Test.sol";
import {CompleteMerkle} from "murky/CompleteMerkle.sol";
import {Merkle} from "murky/Merkle.sol";
import {SpaceAndTime} from "../src/SpaceAndTime.sol";
import {SXTTokenDistributorForTest} from "./helpers/SXTTokenDistributorForTest.sol";

contract MerkleTreeTest is Test {
    // Errors
    error NoUnclaimedIndicesAvailable();

    // Constants
    uint256 public constant MAX_ACCOUNTS = 10000;
    uint256 public constant DEFAULT_ACCOUNTS = 10;
    uint256 public constant BATCH_SIZE = 100;
    uint256 public constant TOKEN_AMOUNT = 100 ether;

    // Test variables
    Merkle public simpleMerkle;
    CompleteMerkle public completeMerkle;
    SpaceAndTime public sxt;
    SXTTokenDistributorForTest public distributor;

    // Test data
    uint256 public numberOfAccounts;
    address[] public accounts;
    uint256[] public amounts;
    bytes32[] public leaves;
    bytes32[] public sampleLeaves;
    bytes32 public merkleRoot;

    // For random sampling tests
    mapping(uint256 index => bool claimed) public randomlyClaimed;

    function setUp() public {
        // Initialize Merkle tree libraries
        simpleMerkle = new Merkle();
        completeMerkle = new CompleteMerkle();

        // Set number of accounts from environment or use default
        string memory accountsEnv = vm.envOr("MERKLE_TEST_ACCOUNTS", string("10"));
        numberOfAccounts = bound(
            _stringToUint(accountsEnv),
            2, // Minimum 2 accounts
            MAX_ACCOUNTS // Maximum accounts
        );

        // Log the number of accounts being tested
        emit log_named_uint("Testing with accounts", numberOfAccounts);

        // Initialize SXT token
        address defaultAdmin = address(this);
        address pauser = address(this);
        address recipient = address(this);
        sxt = new SpaceAndTime(defaultAdmin, pauser, recipient);

        // Generate test data in batches to avoid stack too deep errors
        _generateTestData();

        // Set gas price to 0 for large tests to avoid gas limit issues
        // Note: This is now handled per test function instead of globally
    }

    function testClaimAll() public {
        // Skip this test for very large trees to avoid timeouts
        if (numberOfAccounts > 1000) {
            emit log("Skipping testClaimAll for large tree (>1000 accounts)");
            return;
        }

        // Set gas price to 0 for this test
        vm.txGasPrice(0);

        emit log("Testing claiming all tokens");

        // Set up the distributor
        _setupDistributor();

        // Claim tokens for all accounts
        for (uint256 i = 0; i < numberOfAccounts; ++i) {
            bytes32[] memory proof = simpleMerkle.getProof(leaves, i);
            vm.prank(accounts[i]);
            distributor.claim(i, accounts[i], amounts[i], proof);

            // Verify the claim was successful
            assertTrue(distributor.isClaimed(i), "Claim should be marked as claimed");
            assertEq(sxt.balanceOf(accounts[i]), amounts[i], "Account should have received tokens");
        }

        // Verify all tokens have been claimed
        assertEq(sxt.balanceOf(address(distributor)), 0, "All tokens should be claimed");
    }

    function testClaimMultiple() public {
        // Set gas price to 0 for this test
        vm.txGasPrice(0);

        emit log("Testing claiming multiple tokens");

        // Set up the distributor
        _setupDistributor();

        // Determine how many accounts to test (max 100 for large trees)
        uint256 testCount = numberOfAccounts > 100 ? 100 : numberOfAccounts;

        // Claim tokens for multiple accounts
        for (uint256 i = 0; i < testCount; ++i) {
            bytes32[] memory proof = simpleMerkle.getProof(leaves, i);
            vm.prank(accounts[i]);
            distributor.claim(i, accounts[i], amounts[i], proof);

            // Verify the claim was successful
            assertTrue(distributor.isClaimed(i), "Claim should be marked as claimed");
            assertEq(sxt.balanceOf(accounts[i]), amounts[i], "Account should have received tokens");
        }

        // Verify expected tokens have been claimed
        uint256 expectedRemaining = 0;
        for (uint256 i = testCount; i < numberOfAccounts; ++i) {
            expectedRemaining += amounts[i];
        }
        assertEq(sxt.balanceOf(address(distributor)), expectedRemaining, "Remaining tokens should match expected");
    }

    function testRandomSampling() public {
        // Only run random sampling for larger trees
        if (numberOfAccounts < 101) {
            emit log("Skipping random sampling for small tree (<101 accounts)");
            return;
        }

        // Set gas price to 0 for this test
        vm.txGasPrice(0);

        emit log("Testing random sampling of claims");

        // Set up the distributor
        _setupDistributor();

        // Use a sample size based on the number of accounts
        uint256 sampleSize = numberOfAccounts > 1000 ? 50 : 100;
        emit log_named_uint("Using sample size", sampleSize);

        // Claim tokens for random accounts
        for (uint256 i = 0; i < sampleSize; ++i) {
            // Get a random index that hasn't been claimed yet
            uint256 randomIndex = _getUniqueRandomIndex(numberOfAccounts);

            // Get proof and claim
            bytes32[] memory proof = simpleMerkle.getProof(leaves, randomIndex);
            vm.prank(accounts[randomIndex]);
            distributor.claim(randomIndex, accounts[randomIndex], amounts[randomIndex], proof);

            // Verify the claim was successful
            assertTrue(distributor.isClaimed(randomIndex), "Random claim should be marked as claimed");
            assertEq(sxt.balanceOf(accounts[randomIndex]), amounts[randomIndex], "Account should have received tokens");
        }
    }

    function testInvalidProof() public {
        emit log("Testing invalid proof rejection");

        // Set up the distributor
        _setupDistributor();

        // Get a valid proof for account 0
        bytes32[] memory proof = simpleMerkle.getProof(leaves, 0);

        // Modify the proof to make it invalid (if proof has elements)
        if (proof.length > 0) {
            proof[0] = bytes32(uint256(proof[0]) + 1);
        } else {
            // For single-element trees, use a completely different proof
            proof = new bytes32[](1);
            proof[0] = bytes32(uint256(0x123456));
        }

        // Attempt to claim with invalid proof
        vm.prank(accounts[0]);
        vm.expectRevert(abi.encodeWithSignature("InvalidProof()"));
        distributor.claim(0, accounts[0], amounts[0], proof);
    }

    function testDuplicateClaim() public {
        emit log("Testing duplicate claim rejection");

        // Set up the distributor
        _setupDistributor();

        // Claim once (valid)
        bytes32[] memory proof = simpleMerkle.getProof(leaves, 0);
        vm.prank(accounts[0]);
        distributor.claim(0, accounts[0], amounts[0], proof);

        // Attempt to claim again (should fail)
        vm.prank(accounts[0]);
        vm.expectRevert(abi.encodeWithSignature("AlreadyClaimed()"));
        distributor.claim(0, accounts[0], amounts[0], proof);
    }

    function testWrongAccount() public {
        emit log("Testing wrong account rejection");

        // Set up the distributor
        _setupDistributor();

        // Get proof for account 0
        bytes32[] memory proof = simpleMerkle.getProof(leaves, 0);

        // Try to claim as account 1 with account 0's proof
        vm.prank(accounts[1]);
        vm.expectRevert(abi.encodeWithSignature("InvalidProof()"));
        distributor.claim(0, accounts[1], amounts[0], proof);
    }

    function testWrongAmount() public {
        emit log("Testing wrong amount rejection");

        // Set up the distributor
        _setupDistributor();

        // Get proof for account 0
        bytes32[] memory proof = simpleMerkle.getProof(leaves, 0);

        // Try to claim with wrong amount
        vm.prank(accounts[0]);
        vm.expectRevert(abi.encodeWithSignature("InvalidProof()"));
        distributor.claim(0, accounts[0], amounts[0] + 1, proof);
    }

    function testCompleteMerkleTree() public {
        emit log("Testing complete Merkle tree implementation");

        // Create a small complete tree for testing
        address[] memory testAccounts = new address[](4);
        uint256[] memory testAmounts = new uint256[](4);
        bytes32[] memory testLeaves = new bytes32[](4);

        // Generate test data
        for (uint256 i = 0; i < 4; ++i) {
            testAccounts[i] = address(uint160(i + 1));
            testAmounts[i] = (i + 1) * 10 ether;
            testLeaves[i] = keccak256(abi.encodePacked(i, testAccounts[i], testAmounts[i]));
        }

        // Generate root using CompleteMerkle
        bytes32 completeRoot = completeMerkle.getRoot(testLeaves);
        emit log_named_bytes32("Complete Merkle root", completeRoot);

        // Deploy distributor with complete Merkle root
        sxt = new SpaceAndTime(address(this), address(this), address(this));
        SXTTokenDistributorForTest completeDistributor = new SXTTokenDistributorForTest(address(sxt), completeRoot);
        // Transfer tokens to the distributor instead of minting
        sxt.transfer(address(completeDistributor), 100 ether);

        // Test claiming with complete Merkle tree
        for (uint256 i = 0; i < 4; ++i) {
            bytes32[] memory proof = completeMerkle.getProof(testLeaves, i);
            vm.prank(testAccounts[i]);
            completeDistributor.claim(i, testAccounts[i], testAmounts[i], proof);

            // Verify the claim was successful
            assertTrue(completeDistributor.isClaimed(i), "Claim should be marked as claimed");
            assertEq(sxt.balanceOf(testAccounts[i]), testAmounts[i], "Account should have received tokens");
        }
    }

    function testLargeTreePerformance() public {
        // Skip for small trees
        if (numberOfAccounts < 1001) {
            emit log("Skipping performance test for small tree (<1001 accounts)");
            return;
        }

        // Set gas price to 0 for this test
        vm.txGasPrice(0);

        emit log("Testing large tree performance");

        // Set up the distributor
        _setupDistributor();

        // Measure gas for claiming from a large tree
        uint256 randomIndex = _getUniqueRandomIndex(numberOfAccounts);
        bytes32[] memory proof = simpleMerkle.getProof(leaves, randomIndex);

        uint256 gasBefore = gasleft();
        vm.prank(accounts[randomIndex]);
        distributor.claim(randomIndex, accounts[randomIndex], amounts[randomIndex], proof);
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("Gas used for claim with large tree", gasUsed);

        // Verify the claim was successful
        assertTrue(distributor.isClaimed(randomIndex), "Claim should be marked as claimed");
        assertEq(sxt.balanceOf(accounts[randomIndex]), amounts[randomIndex], "Account should have received tokens");
    }

    // Helper function to set up the distributor with the Merkle root
    function _setupDistributor() internal {
        // For large trees, use the sample-based root
        if (numberOfAccounts > 50000) {
            emit log("Using sample-based Merkle root for very large tree");
            // Use the sample to generate a deterministic root
            merkleRoot = simpleMerkle.getRoot(sampleLeaves);
            emit log_named_bytes32("Sample-based Merkle root", merkleRoot);
        } else {
            // Use the full tree for smaller tests
            merkleRoot = simpleMerkle.getRoot(leaves);
            emit log_named_bytes32("Full Merkle root", merkleRoot);
        }

        // Deploy distributor with Merkle root
        distributor = new SXTTokenDistributorForTest(address(sxt), merkleRoot);

        // Calculate total token amount needed
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < numberOfAccounts; ++i) {
            totalAmount += amounts[i];
        }

        // Transfer tokens to the distributor
        sxt.transfer(address(distributor), totalAmount);
        emit log_named_uint("Total tokens transferred", totalAmount);
    }

    // Helper function to generate test data in batches
    function _generateTestData() internal {
        // Set gas price to 0 for data generation
        vm.txGasPrice(0);

        emit log("Generating test data");

        // Initialize arrays
        accounts = new address[](numberOfAccounts);
        amounts = new uint256[](numberOfAccounts);
        leaves = new bytes32[](numberOfAccounts);

        // Process in batches to avoid stack too deep errors
        uint256 batchCount = (numberOfAccounts + BATCH_SIZE - 1) / BATCH_SIZE;
        emit log_named_uint("Processing in batches", batchCount);

        for (uint256 batch = 0; batch < batchCount; ++batch) {
            uint256 startIdx = batch * BATCH_SIZE;
            uint256 endIdx = (startIdx + BATCH_SIZE) < numberOfAccounts ? (startIdx + BATCH_SIZE) : numberOfAccounts;

            emit log_named_uint("Processing batch", batch + 1);

            // Generate accounts and amounts for this batch
            for (uint256 i = startIdx; i < endIdx; ++i) {
                // Use deterministic addresses and fixed amounts for gas efficiency
                accounts[i] = address(uint160(i + 1));
                amounts[i] = TOKEN_AMOUNT;

                // Generate leaf
                leaves[i] = keccak256(abi.encodePacked(i, accounts[i], amounts[i]));
            }
        }

        // Create a small sample for very large trees
        if (numberOfAccounts > 50000) {
            sampleLeaves = new bytes32[](10);
            for (uint256 i = 0; i < 10; ++i) {
                sampleLeaves[i] = leaves[i];
            }
        }

        emit log("Test data generation complete");
    }

    // Helper function to get a unique random index that hasn't been claimed yet
    function _getUniqueRandomIndex(uint256 max) internal returns (uint256 randomIndex) {
        uint256 attemptsCount = 0;
        while (attemptsCount < 100) {
            // Prevent infinite loops
            // Use a more deterministic approach for testing
            uint256 seed = uint256(keccak256(abi.encodePacked(attemptsCount, msg.sender, block.number)));
            randomIndex = seed % max;
            if (!randomlyClaimed[randomIndex]) {
                randomlyClaimed[randomIndex] = true;
                return randomIndex;
            }
            ++attemptsCount;
        }

        // If we couldn't find a random unclaimed index, find the first unclaimed one
        for (uint256 i = 0; i < max; ++i) {
            if (!randomlyClaimed[i]) {
                randomlyClaimed[i] = true;
                return i;
            }
        }

        // Should never reach here if max > 0
        revert NoUnclaimedIndicesAvailable();
    }

    // Helper function to convert string to uint
    function _stringToUint(string memory s) internal pure returns (uint256 result) {
        bytes memory b = bytes(s);
        result = 0;
        uint256 bLength = b.length;
        for (uint256 i = 0; i < bLength; ++i) {
            uint8 c = uint8(b[i]);
            if (c > 47 && c < 58) {
                result = result * 10 + (c - 48);
            }
        }
        return result;
    }
}
