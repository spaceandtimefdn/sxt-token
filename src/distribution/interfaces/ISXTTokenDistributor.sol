// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// Allows anyone to claim SXT tokens if they exist in a merkle root.
interface ISXTTokenDistributor {
    // Returns the address of the SXT token distributed by this contract.
    function token() external view returns (address tokenAddress);

    // Returns the merkle root of the merkle tree containing account balances available to claim.
    function merkleRoot() external view returns (bytes32 root);

    // Returns true if the index has been marked claimed.
    function isClaimed(uint256 index) external view returns (bool claimed);

    // Claim the given amount of the token to the given address. Reverts if the inputs are invalid.
    function claim(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) external;

    // This event is triggered whenever a call to #claim succeeds.
    event Claimed(uint256 indexed index, address indexed account, uint256 indexed amount);
}
