#!/bin/zsh

# Run anvil.sh in another shell before running this

# To load the variables in the .env file
source .env

# To deploy and verify our contract
forge script script/Watchtower.s.sol:Deploy --legacy --rpc-url "https://rpc.cardona.zkevm-rpc.com" --sender $SENDER --private-key $PRIVATE_KEY --broadcast -vvvv
