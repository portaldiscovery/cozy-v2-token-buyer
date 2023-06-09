// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { IPriceFeed } from 'token-buyer/src/IPriceFeed.sol';
import { AggregatorV3Interface } from 'token-buyer/src/AggregatorV3Interface.sol';
import { Ownable } from 'openzeppelin-contracts/contracts/access/Ownable.sol';
import { SafeCast } from 'openzeppelin-contracts/contracts/utils/math/SafeCast.sol';
import { ISet } from 'src/ISet.sol';

/**
 * @notice Provides price data to {TokenBuyer}.
 */

/// @title CozyMultiOraclePriceFeed
/// @notice Provides price data to `TokenBuyer` for a PToken using two Chainlink price feeds
/// @dev Using multiple Chainlink oracles is useful for cases where there is no oracle available
/// for the specific asset pairing needed. For example, if the Cozy Set has USDC underlying on
/// a chain where there is no ETH/USDC Chainlink oracle, ETH/USD and USDC/USD oracles can be
/// used in tandem to calculate the same conversion.
contract CozyMultiOraclePriceFeed is Ownable, IPriceFeed {
    using SafeCast for int256;

    uint256 constant WAD_DECIMALS = 18;

    /**
     ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
      ERRORS
     ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    error BidPriceWADZero();
    error ChainlinkBPriceZero();
    error StaleOracle(AggregatorV3Interface oracle, uint256 updatedAt);

    /**
     ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
      EVENTS
     ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    event BidPriceWADSet(uint256 oldBidPriceWAD, uint256 newBidPriceWAD);

    /**
     ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
      IMMUTABLES
     ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    /// @notice Chainlink price feed A
    AggregatorV3Interface public immutable chainlinkA;

    /// @notice Chainlink price feed B, to be used in tandem with price feed A which shares the same denominator
    /// (e.g. chainlinkA ETH/USD with chainlinkB USDC/USD)
    AggregatorV3Interface public immutable chainlinkB;

    /// @notice The Cozy set to purchase PTokens from, which uses the same underlying asset that chainlinkB converts from
    ISet public immutable set;

    /// @notice Market id of the market in the Cozy set to purchase PTokens from
    uint16 public immutable marketId;

    /// @notice Number of decimals of the chainlink price feed answer for chainlinkA
    uint8 public immutable decimalsChainlinkA;

    /// @notice Number of decimals of the chainlink price feed answer for chainlinkB
    uint8 public immutable decimalsChainlinkB;

    /// @notice Number of decimals of the Cozy Set. The underlying asset and
    /// the PTokens of the Set use the same number of decimals.
    uint8 public immutable decimalsSet;

    /// @dev A factor to multiply or divide by to get to 18 decimals for chainlinkA
    uint256 public immutable decimalFactorChainlinkA;

    /// @dev A factor to multiply or divide by to get to 18 decimals for chainlinkB
    uint256 public immutable decimalFactorChainlinkB;

    /// @dev A factor to multiply or divide by to get to 18 decimals for PTokens
    uint256 public immutable decimalFactorSet;

    /// @dev Max staleness allowed from chainlink, in seconds for chainlinkA
    uint256 public immutable staleAfterChainlinkA;

    /// @dev Max staleness allowed from chainlink, in seconds for chainlinkB
    uint256 public immutable staleAfterChainlinkB;

    /**
     ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
      STORAGE VARIABLES
     ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    /// @dev Sanity check: target price per unit of protection, expressed as a WAD percentage.
    /// The bid price is in terms of the protection value of PTokens.
    /// For example, $2 per $100 of protection == 0.02e18 == 2% price per unit of protection.
    uint256 public bidPriceWAD;

    constructor(
        ISet set_,
        uint16 marketId_,
        AggregatorV3Interface chainlinkA_,
        AggregatorV3Interface chainlinkB_,
        uint256 staleAfterChainlinkA_,
        uint256 staleAfterChainlinkB_,
        address owner_
    ) {
        set = set_;
        marketId = marketId_;
        decimalsSet = set.decimals();
        chainlinkA = chainlinkA_;
        chainlinkB = chainlinkB_;
        decimalsChainlinkA = chainlinkA.decimals();
        staleAfterChainlinkA = staleAfterChainlinkA_;
        decimalsChainlinkB = chainlinkB.decimals();
        staleAfterChainlinkB = staleAfterChainlinkB_;

        decimalFactorChainlinkA = getDecimalFactor(decimalsChainlinkA);
        decimalFactorChainlinkB = getDecimalFactor(decimalsChainlinkB);
        decimalFactorSet = getDecimalFactor(decimalsSet);

        transferOwnership(owner_);
    }

    /**
     ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
      VIEW FUNCTIONS
     ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    /// @notice Returns the price of ETH/PToken by fetching from Chainlink and Cozy
    /// @return The price is returned in WAD (18 decimals)
    function price() external view override returns (uint256) {
        (, int256 chainlinkPriceA_, , uint256 updatedAtA_, ) = chainlinkA.latestRoundData();
        (, int256 chainlinkPriceB_, , uint256 updatedAtB_, ) = chainlinkB.latestRoundData();

        if (updatedAtA_ < block.timestamp - staleAfterChainlinkA) {
            revert StaleOracle(chainlinkA, updatedAtA_);
        }
        if (updatedAtB_ < block.timestamp - staleAfterChainlinkB) {
            revert StaleOracle(chainlinkB, updatedAtB_);
        }
        if (chainlinkPriceB_ == 0) {
            revert ChainlinkBPriceZero();
        }
        if (bidPriceWAD == 0) {
            revert BidPriceWADZero();
        }

        uint256 aPriceWAD_ = toWAD(chainlinkPriceA_.toUint256(), decimalsChainlinkA, decimalFactorChainlinkA);
        uint256 bPriceWAD_ = toWAD(chainlinkPriceB_.toUint256(), decimalsChainlinkB, decimalFactorChainlinkB);

        // First, determine the price of A in B with respect to the bid price, where chainlinkA is A/C, chainlinkB
        // is B/C, and the Set has B underlying asset.
        // e.g. The price of 1 ETH in PToken protection value with USDC underlying using ETH/USD and USDC/USD oracles:
        // Protection in USDC = (1 ETH price in USD / 1e6 USDC price in USD) * (1e18 / bidPriceWAD) * USDC decimals
        //                    = (1700e8 / 0.99e8) * (1e18 / 0.02e18) * 1e6
        //                    = 85858.585858e6
        // Note: The Set shares the same amount of decimals as the underlying asset
        uint256 protectionValueInB_ = aPriceWAD_ * 1e18 * 10**decimalsSet / (bPriceWAD_ * bidPriceWAD);
        // Return the protection amount converted to PTokens
        return toWAD(set.convertToPTokens(marketId, protectionValueInB_), decimalsSet, decimalFactorSet);
    }

    /**
     ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
      OWNER TRANSACTIONS
     ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    /// @notice Update the bid price for PToken protection value
    /// @dev Expressed as a WAD percentage. For example, 0.02e18 == 2% price per unit of protection
    function setBidPriceWAD(uint256 newBidPriceWAD_) external onlyOwner {
        emit BidPriceWADSet(bidPriceWAD, newBidPriceWAD_);
        bidPriceWAD = newBidPriceWAD_;
    }

    /**
     ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
      INTERNAL FUNCTIONS
     ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    /// @dev Convert price to 18 decimals
    function toWAD(uint256 chainlinkPrice_, uint256 decimals_, uint256 decimalFactor_) internal pure returns (uint256) {
        if (decimals_ == WAD_DECIMALS) {
            return chainlinkPrice_;
        } else if (decimals_ < WAD_DECIMALS) {
            return chainlinkPrice_ * decimalFactor_;
        } else {
            return chainlinkPrice_ / decimalFactor_;
        }
    }

    /// @dev Compute the decimal factor to multiply or divide `chainlinkDecimals_` by to get 18 decimals
    function getDecimalFactor(uint256 chainlinkDecimals_) internal pure returns (uint256) {
        uint256 decimalFactorTemp_ = 1;
        if (chainlinkDecimals_ < WAD_DECIMALS) {
            decimalFactorTemp_ = 10**(WAD_DECIMALS - chainlinkDecimals_);
        } else if (chainlinkDecimals_ > WAD_DECIMALS) {
            decimalFactorTemp_ = 10**(chainlinkDecimals_ - WAD_DECIMALS);
        }

        return decimalFactorTemp_;
    }
}
