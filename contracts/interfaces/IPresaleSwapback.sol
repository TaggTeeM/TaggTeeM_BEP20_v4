/*
 * Copyright © 2022 TaggTeem. ALL RIGHTS RESERVED.
 */

pragma solidity 0.8.7;
// SPDX-License-Identifier: MIT

interface IPresaleSwapback {
    /**
    * @dev Request swapback approval from the target contract.
    */
    function requestSwapbackApproval(uint amount) external returns (bool);
}
