# SXT Token

## Installation

This project uses [Soldeer](https://github.com/Vectorized/soldeer) for dependency management.

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Soldeer](https://github.com/Vectorized/soldeer#installation)

### Setup

1. Clone the repository
   ```bash
   git clone https://github.com/spaceandtimelabs/sxt-token.git
   cd sxt-token
   ```

2. Install dependencies using Soldeer
   ```bash
   forge soldeer install
   ```

## Deployment

This can be deployed by running the following

* Set environment variables, preferrably using an env file `.env` file
  ```bash
  # .env file

  # This variable must be the url of the RPC node
  ETH_RPC_URL=

  # Uncomment the following line when using a keystore account
  #ETH_KEYSTORE_ACCOUNT=

  # Uncomment the following line when using a private key
  #PRIVATE_KEY=
  ```
  ```bash
  source .env
  ```
* Dry run the transaction using any of the following (or variations). NOTE: this will ensure that the sum of the recipient amounts is equal to the expected total supply value.
    1. Use a Ledger hardware wallet
        ```bash
        forge script script/SpaceAndTime.s.sol --rpc-url=$ETH_RPC_URL --ledger
        ```
    2. Use a Trezor hardware wallet
        ```bash
        forge script script/SpaceAndTime.s.sol --rpc-url=$ETH_RPC_URL --trezor
        ```
    3. Use the foundry keystore, which can be set up using `cast wallet`. Be sure to set the `ETH_KEYSTORE_ACCOUNT` env variable.
        ```bash
        forge script script/SpaceAndTime.s.sol --rpc-url=$ETH_RPC_URL
        ```
    4. Use a private key
        ```bash
        forge script script/SpaceAndTime.s.sol --rpc-url=$ETH_RPC_URL --private-key=$PRIVATE_KEY
        ```
* Add `--broadcast` to actually run the deployment.

## SXT token contract

SpaceAndTime.sol is the ERC20 contract for the SXT token, generated using the [OpenZeppelin Wizard](https://wizard.openzeppelin.com/). To regenerate the contract, follow these steps:

1. visit the [OpenZeppelin Wizard](https://wizard.openzeppelin.com/)
2. select `ERC20`
3. set name to `Space and Time`
4. set symbol to `SXT`
5. set premint to `5000000000` (5 billion)
6. check `Pausable`
7. check `Permit`
8. select `Votes` with block number so Uses voting durations expressed as block numbers.
9. select `Roles` under `Access Control`

SXTDeployer.sol is a helper contract for deploying the SXT token. It is used to deploy the token and mint the initial supply to the deployer.

## Merkle Tree Testing

The project includes comprehensive testing for the Merkle tree implementation used in the SXTTokenDistributor contract. The tests are designed to verify the functionality of the Merkle tree with various dataset sizes, from small trees (10 accounts) to extremely large trees (up to 100,000 accounts).

### Running Merkle Tree Tests

By default, the tests run with 10 accounts for quick testing and CI:

```bash
forge test --match-test "MerkleTreeTest"
```

To run tests with a specific number of accounts, use the `MERKLE_TEST_ACCOUNTS` environment variable:

```bash
# Test with 100 accounts
MERKLE_TEST_ACCOUNTS=100 forge test --match-test "MerkleTreeTest"

# Test with 1,000 accounts
MERKLE_TEST_ACCOUNTS=1000 forge test --match-test "MerkleTreeTest"

# Test with 10,000 accounts
MERKLE_TEST_ACCOUNTS=10000 forge test --match-test "MerkleTreeTest"

# Test with 100,000 accounts
MERKLE_TEST_ACCOUNTS=100000 forge test --match-test "MerkleTreeTest"
```

For extremely large trees (50,000+ accounts), the test uses a sample-based approach to generate the Merkle root and verify claims for a subset of accounts. This approach allows testing the core functionality without running into memory or gas limitations.

### Test Optimization Strategies

The Merkle tree tests implement several optimization strategies to handle large datasets:

1. **Configurable Account Numbers**: The number of test accounts can be configured via the `MERKLE_TEST_ACCOUNTS` environment variable.

2. **Adaptive Testing Approach**:
   - For small trees (≤ 10,000 accounts): Standard testing with full Merkle tree generation
   - For large trees (10,000-50,000 accounts): Optimized batch processing
   - For extremely large trees (> 50,000 accounts): Sample-based Merkle tree approach

3. **Gas Optimizations**:
   - `vm.txGasPrice(0)` to bypass gas restrictions for large batch processing
   - Batch processing with configurable batch sizes
   - Fixed token amounts to reduce gas usage

4. **Memory Optimizations**:
   - Chunk-based processing to avoid stack too deep errors
   - Sample-based approach for extremely large datasets

### Test Coverage

The tests cover various scenarios including:

- Basic claim functionality
- Multiple claims
- Duplicate claim prevention
- Invalid proof handling
- Random sampling for large trees
- Claiming all tokens in a tree

These tests ensure that the SXTTokenDistributor contract correctly implements the Merkle tree verification logic and can handle distributions to a large number of recipients.

## Linting and Code Quality

The project uses several tools to ensure code quality:

### Solhint Configuration

The `.solhint.json` file contains configuration for the Solidity linter. Notable decisions include:

- **not-rely-on-time**: This rule is disabled because the `SXTDistributorWithDeadline` contract intentionally uses `block.timestamp` for its core functionality (deadline checks). The security implications are documented in the contract, and the usage is considered safe for this use case since:
  1. The time window for claims is expected to be long (days/weeks)
  2. A few seconds/minutes of manipulation would not significantly impact the contract's functionality
  3. There is no financial incentive for miners to manipulate the timestamp for this contract

- **imports-order**: This rule is disabled to allow for more flexible organization of imports.

### Slither Analysis

Slither security analysis is used to identify potential vulnerabilities. The `slither-disable-next-line timestamp` comments are used in the `SXTDistributorWithDeadline` contract to acknowledge the intentional use of `block.timestamp` for time-based logic.

### Code Coverage

The project maintains 100% test coverage for all contracts, which can be verified by running:

```bash
bash jobs/check_coverage.sh
```

This ensures that all code paths are tested and functioning as expected.
