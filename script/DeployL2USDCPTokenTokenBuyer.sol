// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { console2 } from 'forge-std/console2.sol';
import { stdJson } from "forge-std/StdJson.sol";
import { Payer } from 'token-buyer/src/Payer.sol';
import { TokenBuyer } from 'token-buyer/src/TokenBuyer.sol';
import { CozyMultiOraclePriceFeed } from 'src/CozyMultiOraclePriceFeed.sol';
import { AggregatorV3Interface } from 'token-buyer/src/AggregatorV3Interface.sol';
import { ScriptUtils } from 'script/ScriptUtils.sol';
import { IPToken } from 'src/IPToken.sol';
import { ISet } from 'src/ISet.sol';

/**
 * @dev
 * Before running this script, update configuration in script/input/<chain id>/deploy-usdc-ptoken-token-buyer.json
 *
 * To run this script:
 * ```sh
 * # Perform a dry run of the script.
 * forge script script/DeployL2USDCPTokenTokenBuyer.s.sol \
 *   --sig "run(string)" "deploy-usdc-ptoken-token-buyer"
 *   --rpc-url <rpc-url> \
 *   -vvvv
 *
 * # Or, to broadcast transactions.
 * forge script script/DeployL2USDCPTokenTokenBuyer.s.sol \
 *   --sig "run(string)" "deploy-usdc-ptoken-token-buyer"
 *   --rpc-url <rpc-url> \
 *   --private-key $DEPLOYER_PRIVATE_KEY \
 *   --broadcast \
 *   -vvvv
 * ```
 */
contract DeployL2USDCPTokenTokenBuyer is ScriptUtils {
    using stdJson for string;

    AggregatorV3Interface chainlinkA;
    AggregatorV3Interface chainlinkB;

    uint256 chainlinkAHeartbeat;
    uint256 chainlinkBHeartbeat;

    ISet set;
    IPToken ptoken;
    uint16 marketId;

    address owner;

    function run(string memory fileName_) public {
        /**
        ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
        Configuration
        ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
        */
        string memory json_ = readInput(fileName_);

        chainlinkA = AggregatorV3Interface(json_.readAddress(".chainlinkA"));
        chainlinkB = AggregatorV3Interface(json_.readAddress(".chainlinkB"));

        chainlinkAHeartbeat = json_.readUint(".chainlinkAHeartbeat");
        chainlinkBHeartbeat = json_.readUint(".chainlinkBHeartbeat");

        set = ISet(json_.readAddress(".set"));
        ptoken = IPToken(json_.readAddress(".ptoken"));
        marketId = uint16(json_.readUint(".marketId"));

        owner = json_.readAddress(".owner");

        // Sanity check marketId is correct
        (IPToken ptokenCheck_,,,,,,,,,) = set.markets(marketId);
        require(ptoken == ptokenCheck_);

        /**
        ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
        Execute contract deployments
        ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
        */
        vm.broadcast();
        Payer payer_ = new Payer(owner, address(ptoken));
        console2.log('Payer deployed: ', address(payer_));
        console2.log('    owner:', owner);
        console2.log('    paymentToken:', address(ptoken));

        vm.broadcast();
        CozyMultiOraclePriceFeed priceFeed_ = new CozyMultiOraclePriceFeed(
            set,
            marketId,
            chainlinkA,
            chainlinkB,
            chainlinkAHeartbeat,
            chainlinkBHeartbeat,
            0, // Initialize to 0 as governance will update this via proposal execution.
            owner
        );
        console2.log('CozyMultiOraclePriceFeed deployed: ', address(priceFeed_));
        console2.log('    set:', address(set));
        console2.log('    marketId:', marketId);
        console2.log('    chainlinkA:', address(chainlinkA));
        console2.log('    chainlinkB:', address(chainlinkB));
        console2.log('    staleAfterChainlinkA:', chainlinkAHeartbeat);
        console2.log('    staleAfterChainlinkB:', chainlinkBHeartbeat);
        console2.log('    owner:', owner);

        vm.broadcast();
        TokenBuyer tokenBuyer_ = new TokenBuyer(
            priceFeed_,
            // baselinePaymentTokenAmount - There is no specific balance of PTokens the payer needs to have,
            // set sufficiently high since PToken exchange rate changes over time and all ETH in the
            // TokenBuyer is expected to be exchanged for PTokens
            type(uint128).max,
            0, // minAdminBaselinePaymentTokenAmount
            type(uint128).max, // maxAdminBaselinePaymentTokenAmount
            0, // botDiscountBPs - For the CozyMultiOraclePriceFeed, bidPriceWAD is the exact price to pay
            0, // minAdminBotDiscountBPs
            150, // maxAdminBotDiscountBPs
            owner, // owner
            owner, // admin
            address(payer_)
        );
        console2.log('TokenBuyer deployed: ', address(tokenBuyer_));
        console2.log('    priceFeed:', address(tokenBuyer_.priceFeed()));
        console2.log('    baselinePaymentTokenAmount:', tokenBuyer_.baselinePaymentTokenAmount());
        console2.log('    owner:', tokenBuyer_.owner());
        console2.log('    admin:', tokenBuyer_.admin());
        console2.log('    payer:', address(tokenBuyer_.payer()));
    }
}