/*
 * Copyright © 2022 TaggTeem. ALL RIGHTS RESERVED.
 */

pragma solidity 0.8.7;
// SPDX-License-Identifier: MIT

///
/// @title TaggTeeM (TTM) token ITAGGTEEM interface
///
/// @author John Daugherty
///
interface ITaggTeeM {
    /**
     * @dev Airdrops `amount` tokens from the caller's account to `to` with proper restrictions.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function presalesAirdrop(address to, uint256 amount) external returns (bool);

    /**
     * @dev Gets the total number of tradable tokens in `account`.
     *
     * Returns the total number of unrestricted tokens.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);
}