// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IPToken {

    /// @notice Sets `amount_` as the allowance of `spender_` over the caller's PTokens.
    function approve(address spender_, uint256 amount_) external returns (bool);

    /// @notice Returns the amount of tokens owned by `account_`.
    function balanceOf(address account_) external view returns (uint256);

    /// @notice Returns the quantity of matured PTokens held by the given `account_`.
    function balanceOfMatured(address account_) external view returns (uint256);

    /// @notice Returns the number of decimals of the token. The Set use the same number of decimals, which also matches
    /// the number of decimals for the underlying asset of the Set.
    function decimals() external view returns (uint8);
}
