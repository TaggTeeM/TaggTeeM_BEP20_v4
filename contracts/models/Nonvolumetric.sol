/*
 * Copyright © 2022 TaggTeem. ALL RIGHTS RESERVED.
 */

pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicensed

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../../libraries/Constants.sol";
import "../../libraries/Algorithms.sol";

///
/// @title TaggTeeM (TTM) token NONVOLUMETRIC contract
///
/// @author John Daugherty
///
contract Nonvolumetric is AccessControl {
    using SafeMath for uint;

    // keep track of how much is in public supply
    uint private _totalPublicSupply;

    // whale settings
    uint private _whaleThreshold = 1; // 1%

    // for nonvolumetric calculations
    uint private _nonvolumetricSettingsDivisor = 100; // to divide a, b, and k by
    int private _nonvolumetricA = 4000; 
    int private _nonvolumetricB = 600;
    int private _nonvolumetricK = 170;

    /// @notice Checks if the amount provided exceeds the whale threshold.
    ///
    /// @dev If the whale threshold is set to 0, always return false, otherwise check total public supply.
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @param amount The amount of coin to check for whale threshold.
    /// @return Whether the amount exceeds the whale threshold.
    function isWhale(uint256 amount) 
    public 
    view 
    virtual
    returns (bool) {
        require (_totalPublicSupply > 0, "TTM: Error checking whale status - total coin supply not set");
        
        // whaleThreshold of 0 turns off whales
        if (_whaleThreshold == 0)
            return false;
        else
            return amount.mul(100).div(_totalPublicSupply) > _whaleThreshold;
    }


    /// @notice Updates the whale threshold.
    ///
    /// @dev Checks that the new threshold is between 0 and 100, then sets the whale threshold.
    ///
    /// Requirements:
    /// - Must have NONVOLUMETRIC_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param whaleThreshold The new whale threshold.
    /// @return Whether the whale threshold was successfully set.
    function setWhaleThreshold(uint whaleThreshold) 
    public
    onlyRole(Constants.NONVOLUMETRIC_ADMIN)
    returns (bool)
    {
        // require that requested threshold is >= 0 && <= 100 - 0 turns off whale checking
        require (whaleThreshold >= 0 && whaleThreshold <= 100, "TTM: Nonvolumetric threshold must be between 0% and 100%.");

        // update whale threshold
        _whaleThreshold = whaleThreshold;

        return true;
    }

    /// @notice Gets the current whale threshold.
    ///
    /// Requirements:
    /// - Must have NONVOLUMETRIC_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The current whale threshold.
    function getWhaleThreshold() 
    public
    view
    onlyRole(Constants.NONVOLUMETRIC_ADMIN)
    returns (uint)
    {
        return _whaleThreshold;
    }

    /// @notice Updates the total public supply.
    ///
    /// @dev Checks that the new supply amount is positive and less than the total supply, then sets the total public supply.
    ///
    /// Requirements:
    /// - Must have OWNER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param totalPublicSupply The new total public supply.
    /// @return Whether the total public supply was successfully set.
    function setTotalPublicSupply(uint totalPublicSupply)
    public
    virtual
    onlyRole(Constants.OWNER_ROLE)
    returns (bool)
    {
        require (totalPublicSupply >= 0, "TTM: Total public supply can't be negative.");

        _totalPublicSupply = totalPublicSupply;

        return true;
    }

    /// @notice Gets the total public supply.
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The current total public supply.
    function getTotalPublicSupply() 
    public
    view
    returns (uint)
    {
        return _totalPublicSupply;
    }

    /// @notice Updates the nonvolumetric parameters.
    ///
    /// @dev Checks that the settings divisor is positive, then sets the parameters.
    ///
    /// Requirements:
    /// - Must have OWNER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param NonvolumetricSettingsDivisor The new settings divisor.
    /// @param AParameter The new A parameter.
    /// @param BParameter The new B parameter.
    /// @param KParameter The new K parameter.
    /// @return Whether the parameters were successfully set.
    function setNonvolumetricParameters (uint NonvolumetricSettingsDivisor, int AParameter, int BParameter, int KParameter)
    public
    onlyRole(Constants.NONVOLUMETRIC_ADMIN)
    returns (bool)
    {
        require (NonvolumetricSettingsDivisor > 0, "TTM: Settings divisor must be greater than 0");

        _nonvolumetricSettingsDivisor = NonvolumetricSettingsDivisor;
        _nonvolumetricA = AParameter;
        _nonvolumetricB = BParameter;
        _nonvolumetricK = KParameter;

        return true;
    }

    /// @notice Gets all nonvolumetric parameters.
    ///
    /// Requirements:
    /// - Must have OWNER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return All of the nonvolumetric parameters.
    function getNonvolumetricParameters() 
    public
    view
    onlyRole(Constants.NONVOLUMETRIC_ADMIN)
    returns (uint, int, int, int)
    {
        return (_nonvolumetricSettingsDivisor, _nonvolumetricA, _nonvolumetricB, _nonvolumetricK);
    }

    /// @notice Gets the nonvolumetric maximum nonrestricted coins for the provided amount.
    ///
    /// @dev If the holder is a whale, applies the NonVolumetric algorithm to their current holdings (including restricted coins), and returns the
    /// @dev   number of restricted coins they currently have. For non-whales, the whole balance (no restrictions) is returned.
    /// @dev The current nonvolumetric algorithm is =>> "y = a * ln(x * k) + b"
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @param amount The amount to get the maximum for.
    /// @return The total number of unrestricted coins.
    function getNonvolumetricMaximum(uint amount)
    public
    view
    virtual
    returns (uint)
    {
        if (isWhale(amount))
        {
            uint logResult = Algorithms.LogarithmicAlgoNatural(amount, _nonvolumetricSettingsDivisor, _nonvolumetricA, _nonvolumetricB, _nonvolumetricK); //  * 10 ** decimals();

            return logResult < amount ? logResult : amount;
        }
        else
            return amount;
    }
}