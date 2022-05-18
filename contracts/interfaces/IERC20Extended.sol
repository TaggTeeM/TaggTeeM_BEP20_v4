/*
 * Copyright © 2022 TaggTeem. ALL RIGHTS RESERVED.
 */

pragma solidity 0.8.7;
// SPDX-License-Identifier: MIT

///
/// @title TaggTeeM (TTM) token IERC20EXTENDED interface
///
/// @author John Daugherty
///
interface IERC20Extended {
    /**
    * @dev Add a new lockbox for the beneficiary for the amount given, locked for the specified number of seconds.
    */
    function specialTransfer(address from, address to, uint amount) external returns (bool);
}
