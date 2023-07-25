# Cozy Token Buyer Contracts

This repository includes custom [Cozy V2](https://v2.cozy.finance/) price feeds and deploy scripts for [nounsDAO/token-buyer](https://github.com/nounsDAO/token-buyer).

## Contracts

- [`CozyMultiOraclePriceFeed`](https://github.com/Cozy-Finance/cozy-token-buyer-v2/blob/main/src/CozyMultiOraclePriceFeed.sol)

  - Returns a price for ETH/PToken using two external oracles (e.g. Chainlink). A PToken is an ERC20 that represents protection purchased from a specific Cozy market (e.g. stETH Peg Protection).
  - This price feed is useful for chains where there does not exist an oracle for the specific ETH/underlying asset of the PToken (e.g. ETH/PToken using ETH/USD and USDC/USD for PToken with USDC underlying).
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

## Scripts

This repo includes Forge scripts under `script/` for:
- Scripts to deploy the token-buyer contracts with Cozy V2 price feeds
- Scripts to sell PTokens to TokenBuyer

Specific instructions on how to run them is embedded into the comments of each script.

## Deploy to Optimism

See the [`DeployL2USDCPTokenTokenBuyer`](https://github.com/Cozy-Finance/cozy-token-buyer-v2/blob/main/script/DeployL2USDCPTokenTokenBuyer.sol) script for deploying token-buyer using the [`CozyMultiOraclePriceFeed`](https://github.com/Cozy-Finance/cozy-token-buyer-v2/blob/main/src/CozyMultiOraclePriceFeed.sol) for a PToken with USDC underlying.

# Latest deployment

## Optimism

| Contract   | Address |
|----------- | --------|
| TokenBuyer | 0xdD9e5Dab49d8394660d4Fe2383692448e3944d2b |
| Payer | 0xc2A9A0D746535cEc8dd841651172396dEa38464C |
| CozyMultiOraclePriceFeed | 0x31D2CfCFD44e0e1F5c36d065E665b56B6354EA5c |