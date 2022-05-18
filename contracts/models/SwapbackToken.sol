/*
 * Copyright © 2022 TaggTeem. ALL RIGHTS RESERVED.
 */

pragma solidity 0.8.7;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "../../libraries/Constants.sol";

///
/// @title TaggTeeM (TTM) token SWAPBACKTOKEN contract
///
/// @author John Daugherty
///
contract SwapbackToken is AccessControl {
    // settings for swapback
    address private _swapbackTargetWallet;
    bool private _swapbackEnabled = false;

    function swapbackTargetWallet()
    internal
    view
    returns (address)
    {
        return _swapbackTargetWallet;
    }

    function swapbackEnabled()
    internal
    view
    returns (bool)
    {
        return _swapbackEnabled;
    }

    /// @notice Updates the swapback wallet target address.
    ///
    /// @dev Checks that the new wallet address is not 0, then sets the wallet address.
    ///
    /// Requirements:
    /// - Must have SWAPBACK_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param newSwapbackTargetWallet The new wallet address.
    /// @return Whether the swapback target wallet was successfully set.
    function setSwapbackTargetWallet(address newSwapbackTargetWallet) 
    public
    onlyRole(Constants.SWAPBACK_ADMIN)
    returns (bool)
    {
        // require that the new target wallet is not 0
        require (newSwapbackTargetWallet != address(0), "TTP: Swapback address cannot be 0.");

        // update target wallet
        _swapbackTargetWallet = newSwapbackTargetWallet;

        return true;
    }

    /// @notice Gets the current active swapback target wallet.
    ///
    /// Requirements:
    /// - Must have SWAPBACK_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The current swapback target wallet.
    function getSwapbackTargetWallet() 
    public
    view
    onlyRole(Constants.SWAPBACK_ADMIN)
    returns (address)
    {
        return swapbackTargetWallet();
    }

    /// @notice Enables or disabled token swapback.
    ///
    /// @dev Sets the swapback enabled flag.
    ///
    /// Requirements:
    /// - Must have SWAPBACK_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param isSwapbackEnabled Whether swapback is enabled.
    /// @return Whether the swapback was successfully enabled/disabled.
    function setSwapbackEnabled(bool isSwapbackEnabled) 
    public
    onlyRole(Constants.SWAPBACK_ADMIN)
    returns (bool)
    {
        // update enabled
        _swapbackEnabled = isSwapbackEnabled;

        return true;
    }

    /// @notice Gets the current state of the swapback enable flag.
    ///
    /// Requirements:
    /// - Must have SWAPBACK_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The current swapback enable flag.
    function getSwapbackEnabled() 
    public
    view
    onlyRole(Constants.SWAPBACK_ADMIN)
    returns (bool)
    {
        return swapbackEnabled();
    }

    /// @notice Returns all swapback coins to the owner.
    ///
    /// Requirements:
    /// - Must have SWAPBACK_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param owner The address of the owner's wallet to return tokens to.
    /// @return Whether the coins were successfully returned.
    function returnSwapbackCoins(address owner) 
    public
    onlyRole(Constants.SWAPBACK_ADMIN)
    returns (bool)
    {
        // get this contract's balance
        uint contractBalance = IERC20(_swapbackTargetWallet).balanceOf(address(this));

        // return it back to the owner
        IERC20(_swapbackTargetWallet).transfer(owner, contractBalance);

        return true;
    }
}