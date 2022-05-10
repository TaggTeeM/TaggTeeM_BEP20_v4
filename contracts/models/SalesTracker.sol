/*
 * Copyright © 2022 TaggTeem. ALL RIGHTS RESERVED.
 */

pragma solidity 0.8.7;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";

import "../../libraries/Constants.sol";

///
/// @title TaggTeeM (TTM) token SALESTRACKER contract
///
/// @author John Daugherty
///
contract SalesTracker is AccessControl {
    // sales tracker settings
    uint private _salesTrackerTimeline = 24 * 60 * 60; // 24 hours

    mapping (address => uint) private _lastTransferDate;
    mapping (address => uint) private _transferTotals;

    IERC20 private _parentContract;

    constructor() 
    {
        _parentContract = IERC20(address(this));
    }

    /// @notice Gets the provided user's sales tracker total.
    ///
    /// @dev Gets the provided user's sales tracker total.
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @param from The address to get the sales tracker for.
    /// @return The current sales tracker total for the provided user.
    function salesTrackerTotal(address from)
    internal
    view
    returns (uint)
    {
        return _transferTotals[from];
    }

    /// @notice Reset the sales count every day at midnight.
    ///
    /// @dev Calculates midnight of the current day, checks to see if the provided
    /// @dev user has any records for the current day, and if so then reset to 0.
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @param from The address to reset the sales tracker for.
    /// @return The date/time calculated as the current date at midnight.
    function resetSalesTracker(address from)
    internal
    returns (uint)
    {
        uint lastMidnight = _salesTrackerTimeline == 0 ? block.timestamp : (block.timestamp / _salesTrackerTimeline) * _salesTrackerTimeline;

        // reset sales counts every day at midnight
        if (_lastTransferDate[from] < lastMidnight)
            _transferTotals[from] = 0;

        return lastMidnight;
    }

    /// @notice Record the sale for the provided user.
    ///
    /// @dev Checks that the amount is not 0, ensures the transfer date tracker is updated,
    /// @dev then adds the transfer amount to the sales tracker.
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @param from The address to record the transfer for.
    /// @param amount The amount of the transfer.
    /// @param lastMidnight The date to record for the transfer.
    /// @return Whether the sale was sucessfully recorded.
    function recordSale(address from, uint amount, uint lastMidnight)
    internal
    returns (bool)
    {
        // record the trade for this user
        if (amount != 0)
        {
            _lastTransferDate[from] = lastMidnight;
            _transferTotals[from] += amount;
        }

        return true;
    }

    /// @notice Updates the default sales tracker timeline.
    ///
    /// @dev Checks that the new timeline amount is positive, then sets the default sales tracker timeline.
    ///
    /// Requirements:
    /// - Must have SALES_HISTORY_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param salesTrackerTimeline The new default sales tracker timeline.
    /// @return Whether the default sales tracker timeline was successfully set.
    function setSalesTrackerTimeline(uint salesTrackerTimeline)
    public
    onlyRole(Constants.SALES_HISTORY_ADMIN)
    returns (bool)
    {
        // require that the new restriction is positive, 0 turns off restrictions
        require (salesTrackerTimeline >= 0, "TTM: Sales tracker timeline must be positive.");

        // update restriction timeline
        _salesTrackerTimeline = salesTrackerTimeline;

        return true;
    }

    /// @notice Gets the default sales tracker timeline.
    ///
    /// Requirements:
    /// - Must have SALES_HISTORY_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The current default sales tracker timeline.
    function getSalesTrackerTimeline() 
    public
    view
    onlyRole(Constants.SALES_HISTORY_ADMIN)
    returns (uint)
    {
        return _salesTrackerTimeline;
    }
}
