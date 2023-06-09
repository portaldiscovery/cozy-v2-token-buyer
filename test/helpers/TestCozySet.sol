// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.17;

import { IERC20 } from 'forge-std/interfaces/IERC20.sol';
import { IPToken } from 'src/IPToken.sol';
import { ISet } from 'src/ISet.sol';

contract TestCozySet is ISet {
    uint8 _decimals;
    uint256 _convertToProtection;
    uint256 _convertToPTokens;

    constructor() {}

    function approve(address spender_, uint256 amount_) external returns (bool success_) {}

    function asset() external view returns (IERC20 asset_) {}

    function balanceOf(address account_) external view returns (uint256 balance_) {}

    function balanceOfMatured(address account_) external view returns (uint256 balanceOfMatured_) {}

    function convertToProtection(
        uint16, /* marketId_ */
        uint256 /* ptokens_ */
    ) external view returns (uint256) {
        return _convertToProtection;
    }

    function convertToPTokens(uint16 /* marketId_ */, uint256 /* protection_ */)
        external
        view
        returns (uint256 ptokens_)
    {
        return _convertToPTokens;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function markets(
        uint256 /* marketId_ */
    )
        external
        view
        returns (
            IPToken ptoken_,
            address trigger_,
            MarketConfigStorage memory config_,
            uint8 state_,
            uint256 activeProtection_,
            uint256 lastDecayRate_,
            uint256 lastDripRate_,
            uint128 purchasesFeePool_,
            uint128 salesFeePool_,
            uint64 lastDecayTime_
        )
    {}

    function setConvertToProtection(uint256 newConvertToProtection_) external {
        _convertToProtection = newConvertToProtection_;
    }

    function setConvertToPTokens(uint256 newConvertToPTokens_) external {
        _convertToPTokens = newConvertToPTokens_;
    }


    function setDecimals(uint8 newDecimals_) external {
        _decimals = newDecimals_;
    }
}
