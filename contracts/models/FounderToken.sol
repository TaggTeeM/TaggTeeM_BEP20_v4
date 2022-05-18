/*
 * Copyright © 2022 TaggTeem. ALL RIGHTS RESERVED.
 */

pragma solidity 0.8.7;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/AccessControl.sol";

import "../../libraries/Constants.sol";

///
/// @title TaggTeeM (TTM) token FOUNDERTOKEN contract
///
/// @author John Daugherty
///
contract FounderToken is AccessControl {
    // founder coins
    uint private _founderRestrictionPercentage = 75; // 75%
    uint private _founderRestrictionTimeline = 6 * 30 * 24 * 60 * 60; // 6 months
    uint private _founderBonusRestrictionPercentage = 1; // 1%

    // for keeping track of founder coins
    mapping (address => uint) private _founderCoinCounter;
    mapping (address => uint) private _founderCoinBalance;
    uint private _totalFounderCoinsIssued;

    function founderCoinBalance(address founderWallet)
    internal
    view
    returns (uint)
    {
        return _founderCoinBalance[founderWallet];
    }

    function founderCoinCounter(address founderWallet)
    internal
    view
    returns (uint)
    {
        return _founderCoinCounter[founderWallet];
    }

    function founderBonusRestrictionPercentage()
    internal
    view
    returns (uint)
    {
        return _founderBonusRestrictionPercentage;
    }

    function founderRestrictionPercentage()
    internal
    view
    returns (uint)
    {
        return _founderRestrictionPercentage;
    }

    function founderRestrictionTimeline()
    internal
    view
    returns (uint)
    {
        return _founderRestrictionTimeline;
    }

    function reduceFounderBalanceBy(address account, uint amount)
    internal
    returns (bool)
    {
        _founderCoinBalance[account] = _founderCoinBalance[account] < amount ? 0 : _founderCoinBalance[account] - amount;

        return true;
    }

    /// @notice Transfers _value amount of coins to the provided address with appropriate founder restrictions.
    ///
    /// @dev Verifies coin transfer, then adds coins to restriction list and total founder coin list.
    ///
    /// Requirements:
    /// - Must have OWNER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param to The address to send founder coins to.
    /// @param amount The amount of coin to send to the proveded address.
    /// @return Whether the transfer was a success.
    function sendFounderCoins(address to, uint256 amount)
    public
    virtual
    onlyRole(Constants.OWNER_ROLE)
    returns (bool)
    {
        // keep track of founder coins
        _founderCoinCounter[to] += amount;
        _founderCoinBalance[to] += amount;

        _totalFounderCoinsIssued += amount;

        return true;
    }

    /// @notice Returns the total number of founder coins for the caller.
    ///
    /// @dev Pulls count account found coin counter mapping based on message sender.
    ///
    /// Requirements:
    /// - Must have FOUNDER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return Total number of founder coins for the caller.
    function getFounderCoinCount()
    public
    view
    onlyRole(Constants.FOUNDER_ROLE)
    returns (uint)
    {
        return getFounderCoinCount(_msgSender());
    }

    /// @notice Returns the total number of founder coins for the account specified.
    ///
    /// @dev Pulls count account found coin counter mapping based on provided account address.
    ///
    /// Requirements:
    /// - Must have FOUNDER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param account The wallet address to find the founder coin count for.
    /// @return Total number of founder coins for the account.
    function getFounderCoinCount(address account)
    public
    view
    onlyRole(Constants.FOUNDER_ROLE)
    returns (uint)
    {
        return _founderCoinCounter[account];
    }

    /// @notice Returns the total number of founder coins issued.
    ///
    /// @dev Pulls count account found coin counter variable.
    ///
    /// Requirements:
    /// - Must have FOUNDER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return Total number of founder coins.
    function getTotalFounderCoinsIssued()
    public
    view
    onlyRole(Constants.FOUNDER_ROLE)
    returns (uint)
    {
        return _totalFounderCoinsIssued;
    }

    /// @notice Updates the founder restriction timeline.
    ///
    /// @dev Checks that the new timeline is positive, then sets the founder restriction timeline.
    ///
    /// Requirements:
    /// - Must have FOUNDER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param newFounderRestrictionTimeline The new founder restriction timeline.
    /// @return Whether the founder restriction timeline was successfully set.
    function setFounderRestrictionTimeline(uint newFounderRestrictionTimeline) 
    public
    onlyRole(Constants.FOUNDER_ROLE)
    returns (bool)
    {
        // require that the new restriction is positive, 0 turns off restrictions
        require (newFounderRestrictionTimeline >= 0, "TTM: Founder restriction timeline must be positive");

        // update restriction timeline
        _founderRestrictionTimeline = newFounderRestrictionTimeline;

        return true;
    }

    /// @notice Gets the current founder restriction timeline.
    ///
    /// Requirements:
    /// - Must have FOUNDER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The current founder restriction timeline.
    function getFounderRestrictionTimeline() 
    public
    view
    onlyRole(Constants.FOUNDER_ROLE)
    returns (uint)
    {
        return _founderRestrictionTimeline;
    }

    /// @notice Updates the founder restriction percentage.
    ///
    /// @dev Checks that the new percentage is between 0 and 100, then sets the founder restriction percentage.
    ///
    /// Requirements:
    /// - Must have FOUNDER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param newFounderRestrictionPercentage The new founder restriction percentage.
    /// @return Whether the founder restriction percentage was successfully set.
    function setFounderRestrictionPercentage(uint newFounderRestrictionPercentage) 
    public
    onlyRole(Constants.FOUNDER_ROLE)
    returns (bool)
    {
        // require that the new restriction is positive, 0 turns off restrictions
        require (newFounderRestrictionPercentage >= 0 && newFounderRestrictionPercentage <= 100, "TTM: Founder restriction must be between 0% and 100%");

        // update restriction timeline
        _founderRestrictionPercentage = newFounderRestrictionPercentage;

        return true;
    }

    /// @notice Gets the current founder restriction percentage.
    ///
    /// Requirements:
    /// - Must have FOUNDER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The current founder restriction percentage.
    function getFounderRestrictionPercentage() 
    public
    view
    onlyRole(Constants.FOUNDER_ROLE)
    returns (uint)
    {
        return founderRestrictionPercentage();
    }

    /// @notice Updates the founder bonus restriction percentage.
    ///
    /// @dev Checks that the new percentage is between 0 and 100, then sets the founder bonus restriction percentage.
    ///
    /// Requirements:
    /// - Must have FOUNDER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param newFounderBonusRestrictionPercentage The new founder bonus restriction percentage.
    /// @return Whether the founder bonus restriction percentage was successfully set.
    function setFounderBonusRestrictionPercentage(uint newFounderBonusRestrictionPercentage) 
    public
    onlyRole(Constants.FOUNDER_ROLE)
    returns (bool)
    {
        // require that the new restriction is positive, 0 turns off restrictions
        require (newFounderBonusRestrictionPercentage >= 0 && newFounderBonusRestrictionPercentage <= 100, "TTM: Founder bonus restriction must be between 0% and 100%");

        // update restriction percentage
        _founderBonusRestrictionPercentage = newFounderBonusRestrictionPercentage;

        return true;
    }

    /// @notice Gets the current founder bonus restriction percentage.
    ///
    /// Requirements:
    /// - Must have FOUNDER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The current founder bonus restriction percentage.
    function getFounderBonusRestrictionPercentage() 
    public
    view
    onlyRole(Constants.FOUNDER_ROLE)
    returns (uint)
    {
        return founderBonusRestrictionPercentage();
    }
}