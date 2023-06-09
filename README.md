# Cozy Token Buyer Contracts

This repository includes custom Cozy PriceFeeds and deploy scripts for [nounsDAO/token-buyer](https://github.com/nounsDAO/token-buyer).

## Contracts

- [`CozyMultiOraclePriceFeed`](https://github.com/Cozy-Finance/cozy-token-buyer-v2/blob/main/src/CozyMultiOraclePriceFeed.sol)

  - Returns a price for ETH/PToken using two external oracles (e.g. Chainlink). This PriceFeed is useful for chains where there does not exist an oracle for the specific ETH/underlying asset of the PToken (e.g. ETH/PToken using ETH/USD and USDC/USD for PToken with USDC underlying).
  - Uses a set `bidPriceWAD` which equals the percentage price per unit of protection (e.g. `0.02e18` for 2%). The owner of the `CozyMultiOraclePriceFeed` can update `bidPriceWAD`.

## Tests

Since we're running some tests with an Optimism fork, add your Optimism RPC url to your environment variables:
```sh
export OPTIMISM_RPC_URL=<yourOptimismRpcUrl>
```
Then run the tests:
```sh
forge test
```

## Deploy to Optimism

See the [`DeployL2USDCPTokenTokenBuyer`](https://github.com/Cozy-Finance/cozy-token-buyer-v2/blob/main/script/DeployL2USDCPTokenTokenBuyer.sol) script for deploying token-buyer using the [`CozyMultiOraclePriceFeed`](https://github.com/Cozy-Finance/cozy-token-buyer-v2/blob/main/src/CozyMultiOraclePriceFeed.sol) for a PToken with USDC underlying.

# Latest deployment

| Contract   | Address |
|----------- | --------|
| | |