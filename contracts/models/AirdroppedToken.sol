/*
 * Copyright © 2022 TaggTeem. ALL RIGHTS RESERVED.
 */

pragma solidity 0.8.7;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "../../libraries/Constants.sol";
import "../../libraries/Algorithms.sol";

///
/// @title TaggTeeM (TTM) token AIRDROPPEDTOKEN contract
///
/// @author John Daugherty
///
contract AirdroppedToken is AccessControl, Pausable {
    // restrictions settings
    uint private _restrictionTimeline = 6 * 30 * 24 * 60 * 60; // 6 months
    uint private _airdropRestrictionPercentage = 75; // 75%

    function restrictionTimeline()
    internal
    view
    returns (uint)
    {
        return _restrictionTimeline;
    }

    function airdropRestrictionPercentage()
    internal
    view
    returns (uint)
    {
        return _airdropRestrictionPercentage;
    }

    /// @notice Updates the active restriction timeline.
    ///
    /// @dev Checks that the new timeline is positive, then sets the restriction timeline.
    ///
    /// Requirements:
    /// - Must have RESTRICTION_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param newRestrictionTimeline The new restriction timeline.
    /// @return Whether the restriction timeline was successfully set.
    function setRestrictionTimeline(uint newRestrictionTimeline) 
    public
    onlyRole(Constants.RESTRICTION_ADMIN)
    returns (bool)
    {
        // require that the new restriction is positive, 0 turns off restrictions
        require (newRestrictionTimeline >= 0, "TTM: Restriction timeline must be positive.");

        // update restriction timeline
        _restrictionTimeline = newRestrictionTimeline;

        return true;
    }

    /// @notice Gets the current active restriction timeline.
    ///
    /// Requirements:
    /// - Must have RESTRICTION_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The current restriction timeline.
    function getRestrictionTimeline() 
    public
    view
    onlyRole(Constants.RESTRICTION_ADMIN)
    returns (uint)
    {
        return restrictionTimeline();
    }

    /// @notice Updates the airdrop restriction percentage.
    ///
    /// @dev Checks that the new percentage is between 0 and 100, then sets the airdrop restriction percentage.
    ///
    /// Requirements:
    /// - Must have RESTRICTION_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param newAirdropRestrictionPercentage The new airdrop restriction percentage.
    /// @return Whether the airdrop restriction percentage was successfully set.
    function setAirdropRestrictionPercentage(uint newAirdropRestrictionPercentage) 
    public
    onlyRole(Constants.RESTRICTION_ADMIN)
    returns (bool)
    {
        // require that the new restriction is positive, 0 turns off restrictions
        require (newAirdropRestrictionPercentage >= 0 && newAirdropRestrictionPercentage <= 100, "TTM: Airdrop restriction must be between 0% and 100%");

        // update restriction percentage
        _airdropRestrictionPercentage = newAirdropRestrictionPercentage;

        return true;
    }

    /// @notice Gets the current airdrop restriction percentage.
    ///
    /// Requirements:
    /// - Must have RESTRICTION_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The current airdrop restriction percentage.
    function getAirdropRestrictionPercentage() 
    public
    view
    onlyRole(Constants.RESTRICTION_ADMIN)
    returns (uint)
    {
        return airdropRestrictionPercentage();
    }
}