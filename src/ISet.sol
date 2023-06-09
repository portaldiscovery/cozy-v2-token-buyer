// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import { IERC20 } from 'forge-std/interfaces/IERC20.sol';
import { IPToken } from 'src/IPToken.sol';

interface ISet {
    struct MarketConfigStorage {
        address costModel;
        address dripDecayModel;
        uint16 weight;
        uint16 purchaseFee;
        uint16 saleFee;
    }

    function asset() external view returns (IERC20);

    /// @notice The amount of protection that the Set would exchange for the amount of PTokens in the underlying asset of
    /// the Set.
    function convertToProtection(uint16 marketId, uint256 ptokens)
        external
        view
        returns (uint256);

    /// @notice The amount of PTokens that the set would exchange for the amount of protection.
    function convertToPTokens(uint16 marketId_, uint256 protection_) external view returns (uint256);

    /// @notice Returns the number of decimals of the token. PTokens in the Set use the same number of decimals, which
    /// also matches the number of decimals for the underlying asset of the Set.
    function decimals() external view returns (uint8);

    /// @notice Array of market data for each market in the set.
    function markets(uint256)
        external
        view
        returns (
            IPToken ptoken,
            address trigger,
            MarketConfigStorage memory config,
            uint8 state,
            uint256 activeProtection,
            uint256 lastDecayRate,
            uint256 lastDripRate,
            uint128 purchasesFeePool,
            uint128 salesFeePool,
            uint64 lastDecayTime
        );
}
