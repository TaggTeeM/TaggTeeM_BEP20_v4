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
import "../interfaces/IPresaleSwapback.sol";

///
/// @title TaggTeeM (TTM) token SWAPBACKTOKEN contract
///
/// @author John Daugherty
///
contract SwapbackToken is AccessControl, Pausable, IPresaleSwapback {
    uint private _presalesRestrictionTimeline = 8 * 30 * 24 * 60 * 60; // 8 months
    uint private _presalesRestrictionPercentage = 75; // 75%

    // swapback settings
    address private _authorizedSwapbackCaller;

    IERC20 private _parentContract;

    event SwapbackApproval(uint amount);

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

    /// @notice Requests presale swapback approval, but the request MUST come from the authorized address.
    ///
    /// @dev Checks that the caller is the authorized swapback requester, then attempts to secure approval
    ///      for third-party allowance. At that point, the presale token will send the main token to the sender
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @param amount The exact amount to authorize swapback for.
    /// @return Whether the amount was approved.
    function requestSwapbackApproval(uint amount) 
    public
    override
    returns (bool)
    {
        require (_authorizedSwapbackCaller != address(0), "TTM: No authorized swapback caller address set.");
        require (_msgSender() == _authorizedSwapbackCaller, "TTM: Requester is not the authorized swapback caller.");




            // request allowance of TTM (authorization set on other end)
            //require (IPresaleSwapback(_swapbackTargetWallet).requestSwapbackApproval(amount), "TTP: Swapback not approved at this time.");

            // transfer exact amount of allowance
            //IERC20(_swapbackTargetWallet).transferFrom(Ownable(_swapbackTargetWallet).owner(), to, amount);










        IERC20(address(this)).approve(_authorizedSwapbackCaller, amount);
        IERC20(address(this)).transferFrom(Ownable(address(this)).owner(), _authorizedSwapbackCaller, amount);

        emit SwapbackApproval(amount);

        return true;
    }

    /// @notice Updates the authorized swapback caller.
    ///
    /// @dev Sets the authorized swapback caller.
    ///
    /// Requirements:
    /// - Must have SWAPBACK_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param authorizedSwapbackCaller The new authorized swapback caller.
    /// @return Whether the authorized swapback caller was successfully set.
    function setAuthorizedSwapbackCaller(address authorizedSwapbackCaller)
    public
    onlyRole(Constants.SWAPBACK_ADMIN)
    returns (bool)
    {
        _authorizedSwapbackCaller = authorizedSwapbackCaller;

        return true;
    }

    /// @notice Gets the authorized swapback caller.
    ///
    /// Requirements:
    /// - Must have SWAPBACK_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The current authorized swapback caller.
    function getAuthorizedSwapbackCaller() 
    public
    view
    onlyRole(Constants.SWAPBACK_ADMIN)
    returns (address)
    {
        return _authorizedSwapbackCaller;
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
