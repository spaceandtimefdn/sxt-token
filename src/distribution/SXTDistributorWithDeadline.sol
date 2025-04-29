// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/* solhint-disable not-rely-on-time */
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SXTTokenDistributor} from "./SXTTokenDistributor.sol";

/**
 * @title SXTDistributorWithDeadline
 * @notice A token distributor with a deadline after which tokens can be withdrawn
 * @dev This contract uses block.timestamp for time-based logic. While timestamps can be slightly manipulated by miners,
 *      this is acceptable for this use case as:
 *      1. The time window for claims is expected to be long (days/weeks)
 *      2. A few seconds/minutes of manipulation would not significantly impact the contract's functionality
 *      3. There is no financial incentive for miners to manipulate the timestamp for this contract
 */
contract SXTDistributorWithDeadline is SXTTokenDistributor, Ownable {
    using SafeERC20 for IERC20;

    error EndTimeInPast();
    error ClaimWindowFinished();
    error NoWithdrawDuringClaim();

    /// @notice The timestamp at which the claim window ends
    uint256 public immutable END_TIME;

    /**
     * @notice Constructor for the SXTDistributorWithDeadline
     * @param token_ The address of the SXT token contract
     * @param merkleRoot_ The merkle root containing eligible claim data
     * @param endTime_ The timestamp at which the claim window ends
     * @dev Uses block.timestamp comparison which is safe for this use case
     */
    constructor(address token_, bytes32 merkleRoot_, uint256 endTime_)
        SXTTokenDistributor(token_, merkleRoot_)
        Ownable(msg.sender)
    {
        // slither-disable-next-line timestamp
        if (endTime_ < block.timestamp) revert EndTimeInPast();
        END_TIME = endTime_;
    }

    /**
     * @notice Claim tokens from the distributor
     * @param index Index in the merkle tree
     * @param account Address that should receive tokens
     * @param amount Amount of tokens to claim
     * @param merkleProof Merkle proof for the claim
     * @dev Uses block.timestamp comparison which is safe for this use case
     */
    function claim(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) public override {
        // slither-disable-next-line timestamp
        if (block.timestamp > END_TIME) revert ClaimWindowFinished();
        super.claim(index, account, amount, merkleProof);
    }

    /**
     * @notice Withdraw unclaimed tokens after the claim window has ended
     * @dev Can only be called after the claim period has ended
     * @dev Uses block.timestamp comparison which is safe for this use case
     */
    function withdraw() external onlyOwner {
        // slither-disable-next-line timestamp
        if (!(block.timestamp > END_TIME)) revert NoWithdrawDuringClaim();

        // Get the token address from the parent contract
        address tokenAddress = TOKEN_ADDRESS;

        // Transfer all tokens to the owner
        uint256 balance = IERC20(tokenAddress).balanceOf(address(this));
        IERC20(tokenAddress).safeTransfer(msg.sender, balance);
    }
}
