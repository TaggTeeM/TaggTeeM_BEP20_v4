/*
 * Copyright © 2022 TaggTeem. ALL RIGHTS RESERVED.
 */

pragma solidity 0.8.7;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./Depository.sol";
import "../../libraries/Constants.sol";

///
/// @title TaggTeeM (TTM) token SWAPBACKTOKEN contract
///
/// @author John Daugherty
///
contract PresaleRestrictionToken is AccessControl, Pausable {
    // presales restriction settings
    uint private _presalesRestrictionTimeline = 8 * 30 * 24 * 60 * 60; // 8 months
    uint private _presalesRestrictionPercentage = 75; // 75%

    IERC20 private _parentContract;

    constructor() 
    {
        _parentContract = IERC20(address(this));
    }

    function presalesRestrictionTimeline()
    internal
    view
    returns (uint)
    {
        return _presalesRestrictionTimeline;
    }
    
    /// @notice Transfers amount of coins to the provided address with appropriate preslaes restrictions.
    ///
    /// @dev First verifies transfer, then adds coins to the restricted list.
    ///
    /// Requirements:
    /// - Must have AIDROPPER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param to The address to presales presales to.
    /// @param amount The amount of coin to send to the provided address.
    /// @return Whether the transfer was a success.
    function presalesAirdrop(address to, uint256 amount)
    public
    whenNotPaused
    onlyRole(Constants.AIRDROPPER_ROLE)
    returns (bool)
    {
        require(_parentContract.transfer(to, amount));

        // add to restricted list
        Depository(address(this)).addLockbox(to, (amount * _presalesRestrictionPercentage) / 100, _presalesRestrictionTimeline);

        return true;
    }

    /// @notice Updates the presales restriction timeline.
    ///
    /// @dev Checks that the new timeline is positive, then sets the restriction timeline.
    ///
    /// Requirements:
    /// - Must have FOUNDER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param restrictionTimeline The new presales restriction timeline.
    /// @return Whether the presales restriction timeline was successfully set.
    function setPresalesRestrictionTimeline(uint restrictionTimeline) 
    public
    onlyRole(Constants.RESTRICTION_ADMIN)
    returns (bool)
    {
        // require that the new restriction is positive, 0 turns off restrictions
        require (restrictionTimeline >= 0, "TTM: Presales restriction timeline must be positive.");

        // update restriction timeline
        _presalesRestrictionTimeline = restrictionTimeline;

        return true;
    }

    /// @notice Gets the current presales restriction timeline.
    ///
    /// Requirements:
    /// - Must have FOUNDER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The current presales restriction timeline.
    function getPresalesRestrictionTimeline() 
    public
    view
    onlyRole(Constants.FOUNDER_ROLE)
    returns (uint)
    {
        return _presalesRestrictionTimeline;
    }

    /// @notice Updates the presales restriction percentage.
    ///
    /// @dev Checks that the new percentage is between 0 and 100, then sets the presales restriction percentage.
    ///
    /// Requirements:
    /// - Must have RESTRICTION_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param presalesRestrictionPercentage The new presales restriction percentage.
    /// @return Whether the presales restriction percentage was successfully set.
    function setPresalesRestrictionPercentage(uint presalesRestrictionPercentage) 
    public
    onlyRole(Constants.RESTRICTION_ADMIN)
    returns (bool)
    {
        // require that the new restriction is positive, 0 turns off restrictions
        require (presalesRestrictionPercentage >= 0 && presalesRestrictionPercentage <= 100, "TTM: Presales restriction must be between 0% and 100%");

        // update restriction percentage
        _presalesRestrictionPercentage = presalesRestrictionPercentage;

        return true;
    }

    /// @notice Gets the current presales restriction percentage.
    ///
    /// Requirements:
    /// - Must have RESTRICTION_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The current presales restriction percentage.
    function getPresalesRestrictionPercentage() 
    public
    view
    onlyRole(Constants.RESTRICTION_ADMIN)
    returns (uint)
    {
        return _presalesRestrictionPercentage;
    }
}
