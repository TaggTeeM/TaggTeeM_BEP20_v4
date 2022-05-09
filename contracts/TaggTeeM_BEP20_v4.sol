/*
 * Copyright © 2022 TaggTeem. ALL RIGHTS RESERVED.
 */

pragma solidity 0.8.7;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

import "./models/Depository.sol";
import "./models/Nonvolumetric.sol";
import "./models/SwapbackToken.sol";
import "./models/TaxableToken.sol";
import "./models/AirdroppedToken.sol";
import "./models/FounderToken.sol";
import "../libraries/Constants.sol";

///
/// @title TaggTeeM (TTM) token BEP20 contract
///
/// @author John Daugherty
///
contract TaggTeeM_BEP20_v4 is ERC20, ERC20Burnable, ERC20Permit, Ownable, Depository, Nonvolumetric, TaxableToken, SwapbackToken, AirdroppedToken, FounderToken {
    // roles
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant FOUNDER_ROLE = keccak256("FOUNDER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant SECURITY_ADMIN = keccak256("SECURITY_ADMIN");
    bytes32 public constant NONVOLUMETRIC_ADMIN = keccak256("NONVOLUMETRIC_ADMIN");
    bytes32 public constant AIRDROPPER_ROLE = keccak256("AIRDROPPER_ROLE");
    bytes32 public constant RESTRICTION_ADMIN = keccak256("RESTRICTION_ADMIN");
    bytes32 public constant IFC_TAX_ADMIN = keccak256("IFC_TAX_ADMIN");
    bytes32 public constant SALES_HISTORY_ADMIN = keccak256("SALES_HISTORY_ADMIN");
    bytes32 public constant LOCKBOX_ADMIN = keccak256("LOCKBOX_ADMIN");
    bytes32 public constant SWAPBACK_ADMIN = keccak256("SWAPBACK_ADMIN");

    uint private _salesTrackerTimeline = 24 * 60 * 60; // 24 hours

    // restriction trackers
    mapping (address => uint) private _lastTransferDate;
    mapping (address => uint) private _transferTotals;

    constructor () ERC20("TaggTeeM", "TTM") ERC20Permit("TaggTeeM") {
        // grant token creator some basic permissions
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        grantRole(MINTER_ROLE, _msgSender());
        grantRole(OWNER_ROLE, _msgSender());
        grantRole(PAUSER_ROLE, _msgSender());
        grantRole(SECURITY_ADMIN, _msgSender());

        // reassign admin role for all roles to SECURITY_ADMIN
        setRoleAdmin(OWNER_ROLE, SECURITY_ADMIN);
        setRoleAdmin(FOUNDER_ROLE, SECURITY_ADMIN);
        setRoleAdmin(PAUSER_ROLE, SECURITY_ADMIN);
        setRoleAdmin(MINTER_ROLE, SECURITY_ADMIN);
        setRoleAdmin(SECURITY_ADMIN, SECURITY_ADMIN);
        setRoleAdmin(NONVOLUMETRIC_ADMIN, SECURITY_ADMIN);
        setRoleAdmin(AIRDROPPER_ROLE, SECURITY_ADMIN);
        setRoleAdmin(RESTRICTION_ADMIN, SECURITY_ADMIN);
        setRoleAdmin(IFC_TAX_ADMIN, SECURITY_ADMIN);
        setRoleAdmin(SALES_HISTORY_ADMIN, SECURITY_ADMIN);
        setRoleAdmin(LOCKBOX_ADMIN, SECURITY_ADMIN);
        setRoleAdmin(SWAPBACK_ADMIN, SECURITY_ADMIN);

        // mint 100b tokens at 10^decimals() decimals
        _mint(_msgSender(), 100000000000 * 10 ** decimals());

        // default total public supply is 25% of total supply
        setTotalPublicSupply((totalSupply() * 25) / 100);
    }

    /// @notice Pauses coin trading.
    ///
    /// @dev Calls parent pause function.
    function pause() 
    public 
    onlyRole(PAUSER_ROLE) 
    {
        _pause();
    }

    /// @notice Unpauses coin trading.
    ///
    /// @dev Calls parent unpause function.
    function unpause() 
    public 
    onlyRole(PAUSER_ROLE) 
    {
        _unpause();
    }

    /// @notice Mints new coins.
    ///
    /// @dev Calls parent minting function.
    function mint(address to,  uint256 amount) 
    public 
    onlyRole(MINTER_ROLE) 
    {
        _mint(to, amount);
    }

    /// @notice Sets the admin role for a particular role. The admin role will have permissions to assign people to the role.
    ///           The DEFAULT_ADMIN_ROLE is the admin role for all roles by default.
    ///
    /// @dev Calls parent function.
    ///
    /// Requirements:
    /// - Must have DEFAULT_ADMIN_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param role The role to set the admin for.
    /// @param adminRole The admin role for the role specified.
    function setRoleAdmin(bytes32 role, bytes32 adminRole) 
    public
    onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setRoleAdmin(role, adminRole);
    }

    /// @notice Gets an account's currently tradable balance.
    ///
    /// @dev The currently tradable balance is the total balance of the account less all restricted tokens.
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @param account The address to get the balance for.
    /// @return The tradable balance
    function balanceOf(address account) 
    public 
    view 
    override 
    returns (uint256) {
        return super.balanceOf(account) - restrictedCoins(account);
    }

    /// @notice Gets an account's total balance.
    ///
    /// @dev The current total balance is the total balance of the account including restricted tokens.
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @param account The address to get the balance for.
    /// @return The total balance
    function totalBalanceOf(address account)
    public
    view
    returns (uint)
    {
        return super.balanceOf(account);
    }

    /// @notice Performs appropriate limitation checks and cleanup when transferring coins.
    ///
    /// @dev First checks founder and nonvolumetric restrictions, then checks time restrictions before taking IFC
    ///   tax and then verifying the transfer. Then, founder coins are reduced as necessary.
    ///
    /// Requirements:
    /// - Founder coins must follow restriction requirements.
    /// - Whales must follow restriction requirements.
    /// - Must not be selling restricted coins.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param from The address to transfer from.
    /// @param to The address to transfer to.
    /// @param amount The amount of coin to send to the provided address.
    function _transfer(address from, address to, uint256 amount)
    override
    internal
    whenNotPaused
    {
        bool isFounderTransfer = false;
        uint lastMidnight = _salesTrackerTimeline == 0 ? block.timestamp : (block.timestamp / _salesTrackerTimeline) * _salesTrackerTimeline;
        uint tradableBalance = balanceOf(from);

        // reset sales counts every day at midnight
        if (_lastTransferDate[from] < lastMidnight)
            _transferTotals[from] = 0;

        // check if holder is a founder and is selling bonus coins (non-bonus coins are governed by active holder restrictions)
        if (founderCoinBalance(from) > 0 && founderBonusRestrictionPercentage() > 0 && founderCoinBalance(from) >= (founderCoinCounter(from) * founderRestrictionPercentage()) / 100)
        {
            // if founder bonus coins, restrict sales per day
            require (((amount + _transferTotals[from]) * 100) / founderCoinCounter(from) < founderBonusRestrictionPercentage(), "TTM: Trade exceeds daily limit for founder bonus coins.");

            isFounderTransfer = true;
        } 
        else if (from != owner())
            // check for whale trade cap, ignoring caps for the owner
            require (amount < getNonvolumetricMaximum(tradableBalance), "TTM: Maximum daily trade cap reached for this wallet's staking tier.");

        // check that we're not trying to transfer restricted coins
        if ((restrictionTimeline() > 0 || presalesRestrictionTimeline() > 0) && restrictedCoins(from) > 0)
            require (amount <= tradableBalance, "TTM: Attempt to transfer restricted coins.");

        // IFC tax
        if (ifcTaxAmount() > 0 && ifcTaxWallet() != address(0)) 
        {
            uint taxAmount = (amount * ifcTaxAmount()) / 100;

            super._transfer(from, ifcTaxWallet(), taxAmount);

            amount -= taxAmount;
        }

        // do the transfer
        super._transfer(from, to, amount);

        // record founder coin transfer
        if (isFounderTransfer || founderCoinBalance(from) > 0)
            reduceFounderBalanceBy(from, amount);
        
        // record the trade for this user
        if (amount != 0)
        {
            _lastTransferDate[from] = lastMidnight;
            _transferTotals[from] += amount;
        }
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
    onlyRole(SALES_HISTORY_ADMIN)
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
    onlyRole(SALES_HISTORY_ADMIN)
    returns (uint)
    {
        return _salesTrackerTimeline;
    }
}