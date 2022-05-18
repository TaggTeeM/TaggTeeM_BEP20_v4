/*
 * Copyright © 2022 TaggTeem. ALL RIGHTS RESERVED.
 */

pragma solidity 0.8.7;
// SPDX-License-Identifier: MIT

import "../../libraries/Constants.sol";

///
/// @title TaggTeeM (TTM) token IDEPOSITORY interface
///
/// @author John Daugherty
///
interface IDepository {
    /**
    * @dev Add a new lockbox for the caller for the amount given, locked for the specified number of seconds.
    */
    function addLockbox(uint amount, uint lockLengthSeconds) external returns (Constants.Lockbox memory);

    /**
    * @dev Add a new lockbox for the beneficiary for the amount given, locked for the specified number of seconds.
    */
    function addLockbox(address beneficiary, uint amount, uint lockLengthSeconds) external returns (Constants.Lockbox memory);
}
