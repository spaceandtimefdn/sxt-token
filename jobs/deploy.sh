#!/bin/bash
source .env

# check required environment variables
required_env_vars=("ETH_RPC_URL" "ETHERSCAN_API_KEY" "GAS_PAYER_ADDRESS")
for var in "${required_env_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "$var is not set"
        exit 1
    fi
done

# generate a private key
PRIVATE_KEY=$(openssl rand -hex 32)
WALLET_ADDRESS=$(cast wallet address $PRIVATE_KEY)

# generate qr code for the wallet address in form of ethereum:wallet_address
WALLET_ADDRESS_QR=$(echo "ethereum:$WALLET_ADDRESS" | qrencode -t UTF8i -s 2 -o - )
echo -e "Wallet Address QR:\n$WALLET_ADDRESS_QR"
echo -e "Wallet Address: $WALLET_ADDRESS\n" 


while true; do
    BALANCE=$(cast balance $WALLET_ADDRESS --rpc-url $ETH_RPC_URL)
    if [ "$BALANCE" -gt 0 ]; then
        break
    fi
    echo "Balance is 0, waiting for funds..."
    sleep 10
done

echo "Funds received, continuing..."

if forge script script/SpaceAndTime.s.sol --broadcast --rpc-url=$ETH_RPC_URL --private-key=$PRIVATE_KEY --verify; then
    echo "Deployment successful!"
else
    echo "Deployment failed!"
fi

GAS_PRICE=$(cast gas-price --rpc-url $ETH_RPC_URL)
TRANSFER_GAS_LIMIT=21000 
TRANSFER_GAS_COST=$(($TRANSFER_GAS_LIMIT * $GAS_PRICE))
BALANCE=$(cast balance $WALLET_ADDRESS --rpc-url $ETH_RPC_URL)
BALANCE_TO_RECOVER=$(($BALANCE - $TRANSFER_GAS_COST))
echo "Balance to recover: $BALANCE_TO_RECOVER"

# send the balance to the gas payer
cast send --rpc-url $ETH_RPC_URL --gas-limit $TRANSFER_GAS_LIMIT --gas-price $GAS_PRICE --private-key $PRIVATE_KEY --value $BALANCE_TO_RECOVER $GAS_PAYER_ADDRESS
echo "Funds recovered!"

unset PRIVATE_KEY