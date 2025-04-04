# Watchtower - One-time Hooks for Sale

The demo instructions and video are [here](./demo/README.md).

## Abstract

This is a prototype of ***Watchtower***,  a novel protocol for atomic price action triggered interventions. Uniswap V4 Hooks have allowed this protocol to
react to price changes caused by executions of swaps. The reactions are atomic first-in-line without a possibility for anyone to intercept
and front-run the reacting transaction.

Watchtower allows for anyone to permissionlessly subscribe to desired price actions caused by swaps and and take advantage of the prompt atomic actions as
desired. Such actions can be delinquent loan liquidations, limit orders, undercollateralized option and/or derivative liquidations and many other use cases.

The implementation was facilitated by our One-time Hooks, which can be attached and detached dynamically to Uniswap V4 pools.

Watchtower has an economic incentive model that is beneficial to all parties involved.

## Introduction

Traditionally, price action interventions contain the following components:
- Oracle, which provides the latest prices. This can be an off-chain Oracle, such as Chainlink, or on-chain oracle such as Uniswap Oracle (part of Uniswap V2, V3 and V4 implementations).
- Keeper, which calls Smart Contract functions in order to react to changes at the appropriate time.
- Action Code, which, when called by the Keeper, consumes the Oracle pricing, verifies that the action preconditions are met and calls the appropriate action.

This has been a problem as the Keeper has latency in reaction to events and placing on-chain call transactions. Such undesired latency issues have been mitigated
by overprotecting the target protocol, usually by asking for excessive overcollateralization in lending and leveraged protocols. This directly impacts the capital
efficiency of such protocols.

Watchtower's ability to react atomically mitigates this issue significantly.

## Implementation

