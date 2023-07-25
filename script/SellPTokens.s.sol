// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { Script } from 'forge-std/Script.sol';
import { console2 } from 'forge-std/console2.sol';
import { IPToken } from 'src/IPToken.sol';

interface ITokenBuyer {
  function buyETH(uint256 tokenAmount) external;
}

/**
 * @dev
 *
 * This script can be used to exchange PTokens for ETH with a TokenBuyer.
 *
 * Note: This script trades the full matured balance of PTokens owned by the sender.
 *
 * To run this script:
 * ```sh
 * # Perform a dry run of the script.
 * forge script script/SellPTokens.s.sol \
 *   --sig "run(address,address)" <TokenBuyer address> <PToken address>
 *   --rpc-url <rpc-url> \
 *   --private-key $SELLER_PRIVATE_KEY \
 *   -vvvv
 *
 * # Or, to broadcast transactions.
 * forge script script/SellPTokens.s.sol \
 *   --sig "run(address,address)" <TokenBuyer address> <PToken address>
 *   --rpc-url <rpc-url> \
 *   --private-key $SELLER_PRIVATE_KEY \
 *   --broadcast \
 *   -vvvv
 * ```
 */
contract SellPTokens is Script {

  function run(ITokenBuyer tokenBuyer_, IPToken ptoken_) public {
    uint256 initBalanceOfMaturedPTokens_ = ptoken_.balanceOfMatured(msg.sender);
    require(initBalanceOfMaturedPTokens_ > 0, "Balance of matured PTokens must be greater than zero.");

    // Approve the TokenBuyer to spend msg.sender's full balance of matured PTokens.
    vm.broadcast();
    ptoken_.approve(address(tokenBuyer_), initBalanceOfMaturedPTokens_);

    uint256 ethBalanceBefore_ = msg.sender.balance;

    // Exchange full balance of matured PTokens for ETH with the TokenBuyer.
    vm.broadcast();
    tokenBuyer_.buyETH(initBalanceOfMaturedPTokens_);

    // Confirm result.
    console2.log("Sold PTokens:", initBalanceOfMaturedPTokens_ - ptoken_.balanceOfMatured(msg.sender));
    console2.log("Received ETH:", msg.sender.balance - ethBalanceBefore_);
  }
}