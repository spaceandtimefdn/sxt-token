// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ISXTTokenDistributor} from "./interfaces/ISXTTokenDistributor.sol";

/**
 * @title SXTTokenDistributor
 * @notice A contract that distributes SXT tokens according to a merkle root
 * @dev Based on Uniswap's MerkleDistributor pattern
 */
abstract contract SXTTokenDistributor is ISXTTokenDistributor {
    using SafeERC20 for IERC20;

    error AlreadyClaimed();
    error InvalidProof();

    address public immutable TOKEN_ADDRESS;
    bytes32 public immutable MERKLE_ROOT;

    // This is a packed array of booleans to efficiently track claimed status
    mapping(uint256 wordIndex => uint256 claimedWord) private claimedBitMap;

    /**
     * @notice Constructor for the SXTTokenDistributor
     * @param token_ The address of the SXT token contract
     * @param merkleRoot_ The merkle root containing eligible claim data
     */
    constructor(address token_, bytes32 merkleRoot_) {
        TOKEN_ADDRESS = token_;
        MERKLE_ROOT = merkleRoot_;
    }

    /**
     * @notice Returns true if the index has been claimed
     * @param index The index to check
     * @return claimed Whether the index has been claimed
     */
    function isClaimed(uint256 index) public view override returns (bool claimed) {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = claimedBitMap[claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    /**
     * @notice Sets the claim status for an index
     * @param index The index to set claimed status for
     */
    function _setClaimed(uint256 index) private {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        claimedBitMap[claimedWordIndex] = claimedBitMap[claimedWordIndex] | (1 << claimedBitIndex);
    }

    /**
     * @notice Claim SXT tokens to the specified account
     * @param index Index in the merkle tree
     * @param account Address to receive the tokens
     * @param amount Amount of tokens to claim
     * @param merkleProof Merkle proof for the claim
     */
    function claim(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof)
        public
        virtual
        override
    {
        if (isClaimed(index)) revert AlreadyClaimed();

        // Verify the merkle proof
        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        if (!MerkleProof.verify(merkleProof, MERKLE_ROOT, node)) revert InvalidProof();

        // Mark it claimed and send the token
        _setClaimed(index);
        IERC20(TOKEN_ADDRESS).safeTransfer(account, amount);

        emit Claimed(index, account, amount);
    }

    /**
     * @notice Returns the address of the token distributed by this contract
     * @return tokenAddress The address of the token
     */
    function token() external view override returns (address tokenAddress) {
        return TOKEN_ADDRESS;
    }

    /**
     * @notice Returns the merkle root of the merkle tree
     * @return root The merkle root
     */
    function merkleRoot() external view override returns (bytes32 root) {
        return MERKLE_ROOT;
    }
}
