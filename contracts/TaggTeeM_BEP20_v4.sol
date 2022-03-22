/*
 * Copyright © 2022 TaggTeem. ALL RIGHTS RESERVED.
 */

pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicensed

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./models/ExpirableTransactionsTracker.sol";
import "../libraries/Algorithms.sol";

///
/// @title TaggTeeM (TTM) token BEP20 contract
///
/// @author John Daugherty
///
contract TaggTeeM_BEP20_v4 is ERC20, ERC20Burnable, Pausable, AccessControl, ERC20Permit, ERC20Votes, Ownable {
    using SafeMath for uint;

    // roles
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant FOUNDER_ROLE = keccak256("FOUNDER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant SECURITY_ADMIN = keccak256("SECURITY_ADMIN");
    bytes32 public constant NONVOLUMETRIC_ADMIN = keccak256("NONVOLUMETRIC_ADMIN");
    bytes32 public constant AIDROPPER_ROLE = keccak256("AIDROPPER_ROLE");
    bytes32 public constant RESTRICTION_ADMIN = keccak256("RESTRICTION_ADMIN");
    bytes32 public constant IFC_TAX_ADMIN = keccak256("IFC_TAX_ADMIN");
    bytes32 public constant SALES_HISTORY_ADMIN = keccak256("SALES_HISTORY_ADMIN");

    // keep track of how much is in public supply
    uint private _totalPublicSupply;

    // whale settings
    uint private _whaleThreshold = 1; // 1%
    uint private _presalesRestrictionTimeline = 8 * 30 * 24 * 60 * 60; // 8 months
    uint private _restrictionTimeline = 6 * 30 * 24 * 60 * 60; // 6 months
    uint private _salesTrackerTimeline = 24 * 60 * 60; // 24 hours

    // founder coins
    uint private _founderRestrictionPercentage = 75; // 75%
    uint private _founderRestrictionTimeline = 6 * 30 * 24 * 60 * 60; // 6 months
    uint private _founderBonusRestrictionPercentage = 1; // 1%
    uint private _founderBonusRestrictionTimeline = 24 * 60 * 60; // 24 hours

    // for nonvolumetric calculations
    uint private _nonvolumetricSettingsDivisor = 100; // to divide a, b, and k by
    int private _nonvolumetricA = 4000; 
    int private _nonvolumetricB = 600;
    int private _nonvolumetricK = 170;

    // for keeping track of founder coins
    mapping (address => uint) private _founderCoinCounter;
    mapping (address => uint) private _founderCoinBalance;
    uint private _totalFounderCoinsIssued;

    // Influencers For Change tax information
    address private _ifcTaxWallet = address(0);
    uint private _ifcTaxAmount = 1; // 1%

    // restriction trackers
    ExpirableTransactionsTracker private _activeHolderRestrictions;
    ExpirableTransactionsTracker private _activeSales;

    constructor () ERC20("TaggTeeM_TEST02", "TTM2") ERC20Permit("TaggTeeM_TEST02") {
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
        setRoleAdmin(AIDROPPER_ROLE, SECURITY_ADMIN);
        setRoleAdmin(RESTRICTION_ADMIN, SECURITY_ADMIN);
        setRoleAdmin(IFC_TAX_ADMIN, SECURITY_ADMIN);
        setRoleAdmin(SALES_HISTORY_ADMIN, SECURITY_ADMIN);

        // mint 100b tokens
        _mint(_msgSender(), 100000000000 * 10 ** decimals());

        // start restriction trackers
        _activeHolderRestrictions = new ExpirableTransactionsTracker(_restrictionTimeline);
        _activeSales = new ExpirableTransactionsTracker(_salesTrackerTimeline);
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

    /// @notice Performs any actions necessary before a coin transfer.
    ///
    /// @dev Calls parent function.
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @param from The address to transfer from.
    /// @param to The address to transfer to.
    /// @param amount The amount of coin to send to the provided address.
    function _beforeTokenTransfer(address from, address to, uint256 amount)
    internal
    whenNotPaused
    override
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    /// @notice Performs any actions necessary after a coin transfer.
    ///
    /// @dev Calls parent function then records the transfer.
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @param from The address to transfer from.
    /// @param to The address to transfer to.
    /// @param amount The amount of coin to send to the provided address.
    function _afterTokenTransfer(address from, address to, uint256 amount)
    internal
    override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    /// @notice Mints new coins.
    ///
    /// @dev Calls parent minting function.
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @param to The address to transfer newly minted coins to.
    /// @param amount The amount of coin to send to the provided address.
    function _mint(address to, uint256 amount)
    internal
    override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    /// @notice Burns coins.
    ///
    /// @dev Calls parent burning function.
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @param account The address to burn coins from.
    /// @param amount The amount of coin to burn.
    function _burn(address account, uint256 amount)
    internal
    override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
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
        uint balance = balanceOf(from);

        // check if holder is a founder and is selling bonus coins (non-bonus coins are governed by active holder restrictions)
        if (_founderCoinBalance[from] > 0 && _founderBonusRestrictionPercentage > 0 && _founderCoinBalance[from] >= _founderCoinCounter[from].mul(_founderRestrictionPercentage.div(100))) {
            // if founder bonus coins, restrict sales per day
            require (amount.div(balance.add(_activeSales.getUnexpiredTransactions(from))).mul(100) < _founderBonusRestrictionPercentage);

            isFounderTransfer = true;
        } else 
            // check for whale trade cap unless we're selling founder coins
            require (amount < getNonvolumetricMaximum(from), "TTM: Maximum daily trade cap reached for this wallet's staking tier");

        // check that we're not trying to transfer restricted coins
        if (_restrictionTimeline > 0 && _activeHolderRestrictions.hasTransactions(from)) // ActiveRestrictions[from]) // perform ActiveRestrictions check here to reduce gas by eliminating function call
            require (amount < balance - _activeHolderRestrictions.getUnexpiredTransactions(from), "TTM: Attempt to transfer restricted coins");

        // IFC tax
        if (_ifcTaxAmount > 0 && _ifcTaxWallet != address(0)) {
            uint taxAmount = amount.mul(_ifcTaxAmount.div(100));

            super._transfer(from, _ifcTaxWallet, taxAmount);

            amount -= taxAmount;
        }

        // require that transaction completes successfully
        super._transfer(from, to, amount);

        if (isFounderTransfer || _founderCoinBalance[from] > 0)
        {
            // record founder coin transfer
            _founderCoinBalance[from] = _founderCoinBalance[from] < amount ? 0 : _founderCoinBalance[from] - amount;

            if (_founderBonusRestrictionTimeline > 0)
                _activeSales.addTransaction(from, amount, _founderBonusRestrictionTimeline);
        }
        else // record all other transfers
            _activeSales.addTransaction(from, amount);
    }

    /// @notice Transfers _value amount of coins to the provided address with appropriate holder restrictions.
    ///
    /// @dev First verifies transfer, then adds coins to the restricted list.
    ///
    /// Requirements:
    /// - Must have AIRDROPPER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param to The address to airdrop to.
    /// @param amount The amount of coin to send to the provided address.
    /// @return Whether the transfer was a success.
    function airdrop(address to, uint256 amount)
    public
    whenNotPaused
    onlyRole(AIDROPPER_ROLE)
    returns (bool)
    {
        require(super.transfer(to, amount));

        // add to restricted list
        _activeHolderRestrictions.addTransaction(to, amount);

        return true;
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
    /// @param to The address to presales airdrop to.
    /// @param amount The amount of coin to send to the provided address.
    /// @return Whether the transfer was a success.
    function presalesAirdrop(address to, uint256 amount)
    public
    whenNotPaused
    onlyRole(AIDROPPER_ROLE)
    returns (bool)
    {
        require(super.transfer(to, amount));

        // add to restricted list
        _activeHolderRestrictions.addTransaction(to, amount, _presalesRestrictionTimeline);

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
    onlyRole(OWNER_ROLE)
    returns (bool)
    {
        require(super.transfer(to, amount));

        // mark 75% of coins as founder coins and add to restricted list using the founder restriction timeline
        if (_founderRestrictionTimeline > 0)
            _activeHolderRestrictions.addTransaction(to, amount.mul(_founderRestrictionPercentage.div(100)), _founderRestrictionTimeline);

        // keep track of founder coins
        _founderCoinCounter[to] += amount;
        _founderCoinBalance[to] += amount;

        _totalFounderCoinsIssued += amount;

        return true;
    }

    /// @notice Returns the total number of restricted coins for the caller.
    ///
    /// @dev Removes expired coin restrictions and returns the total number of unrestricted coins.
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @return Total number of unrestricted coins.
    function getRestrictedCoinCount()
    public
    returns (uint)
    {
        return _activeHolderRestrictions.getUnexpiredTransactions(_msgSender());
    }

    /// @notice Returns the total number of founder coins for the caller.
    ///
    /// @dev Pulls count from found coin counter mapping based on message sender.
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
    onlyRole(FOUNDER_ROLE)
    returns (uint)
    {
        return getFounderCoinCount(_msgSender());
    }

    /// @notice Returns the total number of founder coins for the account specified.
    ///
    /// @dev Pulls count from found coin counter mapping based on provided account address.
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
    onlyRole(FOUNDER_ROLE)
    returns (uint)
    {
        return _founderCoinCounter[account];
    }

    /// @notice Returns the total number of founder coins issued.
    ///
    /// @dev Pulls count from found coin counter variable.
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
    onlyRole(FOUNDER_ROLE)
    returns (uint)
    {
        return _totalFounderCoinsIssued;
    }

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
    returns (bool) {
        // whaleThreshold of 0 turns off whales
        if (_whaleThreshold == 0)
            return false;
        else
            return amount.div(_totalPublicSupply) > _whaleThreshold;
    }

    /// @notice Checks if the balance of the address provided exceeds the whale threshold.
    ///
    /// @dev If the whale threshold is set to 0, always return false, otherwise check total public supply.
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @param account The balance of the address to check for whale threshold.
    /// @return Whether the balance of the address exceeds the whale threshold.
    function isWhale(address account) 
    public 
    view 
    returns (bool) {
        return isWhale(balanceOf(account));
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
    onlyRole(NONVOLUMETRIC_ADMIN)
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
    onlyRole(NONVOLUMETRIC_ADMIN)
    returns (uint)
    {
        return _whaleThreshold;
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
    /// @param restrictionTimeline The new restriction timeline.
    /// @return Whether the restriction timeline was successfully set.
    function setRestrictionTimeline(uint restrictionTimeline) 
    public
    onlyRole(RESTRICTION_ADMIN)
    returns (bool)
    {
        // require that the new restriction is positive, 0 turns off restrictions
        require (restrictionTimeline >= 0, "TTM: Restriction timeline must be positive.");

        // update restriction timeline
        _restrictionTimeline = restrictionTimeline;

        _activeHolderRestrictions.setTimelineOffset(_restrictionTimeline);

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
    onlyRole(RESTRICTION_ADMIN)
    returns (uint)
    {
        return _restrictionTimeline;
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
    onlyRole(RESTRICTION_ADMIN)
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
    onlyRole(FOUNDER_ROLE)
    returns (uint)
    {
        return _presalesRestrictionTimeline;
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
    /// @param founderRestrictionTimeline The new founder restriction timeline.
    /// @return Whether the founder restriction timeline was successfully set.
    function setFounderRestrictionTimeline(uint founderRestrictionTimeline) 
    public
    onlyRole(FOUNDER_ROLE)
    returns (bool)
    {
        // require that the new restriction is positive, 0 turns off restrictions
        require (founderRestrictionTimeline >= 0, "TTM: Founder restriction timeline must be positive");

        // update restriction timeline
        _founderRestrictionTimeline = founderRestrictionTimeline;

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
    onlyRole(FOUNDER_ROLE)
    returns (uint)
    {
        return _founderRestrictionTimeline;
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
    /// @param founderBonusRestrictionPercentage The new founder bonus restriction percentage.
    /// @return Whether the founder bonus restriction percentage was successfully set.
    function setFounderBonusRestrictionPercentage(uint founderBonusRestrictionPercentage) 
    public
    onlyRole(FOUNDER_ROLE)
    returns (bool)
    {
        // require that the new restriction is positive, 0 turns off restrictions
        require (founderBonusRestrictionPercentage >= 0 && founderBonusRestrictionPercentage <= 100, "TTM: Founder bonus restriction must be between 0% and 100%");

        // update restriction timeline
        _founderBonusRestrictionPercentage = founderBonusRestrictionPercentage;

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
    onlyRole(FOUNDER_ROLE)
    returns (uint)
    {
        return _founderBonusRestrictionPercentage;
    }

    /// @notice Updates the founder bonus restriction timeline.
    ///
    /// @dev Checks that the new percentage is positive, then sets the founder bonus restriction timeline.
    ///
    /// Requirements:
    /// - Must have FOUNDER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param founderBonusRestrictionTimeline The new founder bonus restriction timeline.
    /// @return Whether the founder bonus restriction timeline was successfully set.
    function setFounderBonusRestrictionTimeline(uint founderBonusRestrictionTimeline) 
    public
    onlyRole(FOUNDER_ROLE)
    returns (bool)
    {
        // require that the new restriction is positive, 0 turns off restrictions
        require (founderBonusRestrictionTimeline >= 0, "TTM: Founder Bonus restriction timeline must be a positive integer");

        // update restriction timeline
        _founderBonusRestrictionTimeline = founderBonusRestrictionTimeline;

        return true;
    }

    /// @notice Gets the current founder bonus restriction timeline.
    ///
    /// Requirements:
    /// - Must have FOUNDER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The current founder bonus restriction timeline.
    function getFounderBonusRestrictionTimeline() 
    public
    view
    onlyRole(FOUNDER_ROLE)
    returns (uint)
    {
        return _founderBonusRestrictionTimeline;
    }

    /// @notice Updates the IFC tax wallet address.
    ///
    /// @dev Checks that the new address is not 0, then sets the IFC tax wallet.
    ///
    /// Requirements:
    /// - Must have IFC_TAX_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param taxWalletAddress The new IFC tax wallet address.
    /// @return Whether the IFC tax wallet address was successfully set.
    function setIfcTaxWallet(address taxWalletAddress)
    public
    onlyRole(IFC_TAX_ADMIN)
    returns (bool)
    {
        require (taxWalletAddress != address(0), "TTM: Attempt to set IFC tax wallet to address: 0");

        _ifcTaxWallet = taxWalletAddress;

        return true;
    }

    /// @notice Gets the IFC tax wallet address.
    ///
    /// Requirements:
    /// - Must have IFC_TAX_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The current IFC tax wallet address.
    function getIfcTaxWallet() 
    public
    view
    onlyRole(IFC_TAX_ADMIN)
    returns (address)
    {
        return _ifcTaxWallet;
    }

    /// @notice Updates the IFC tax amount.
    ///
    /// @dev Checks that the new tax amount is positive, then sets the IFC tax amount.
    ///
    /// Requirements:
    /// - Must have IFC_TAX_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param taxAmount The new IFC tax amount.
    /// @return Whether the IFC tax amount was successfully set.
    function setIfcTaxAmount(uint taxAmount)
    public
    onlyRole(IFC_TAX_ADMIN)
    returns (bool)
    {
        require (taxAmount >= 0, "TTM: IFC tax amount must be positive or zero.");

        _ifcTaxAmount = taxAmount;

        return true;
    }

    /// @notice Gets the IFC tax amount.
    ///
    /// Requirements:
    /// - Must have IFC_TAX_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The current IFC tax amount.
    function getIfcTaxAmount() 
    public
    view
    onlyRole(IFC_TAX_ADMIN)
    returns (uint)
    {
        return _ifcTaxAmount;
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

        _activeSales.setTimelineOffset(_salesTrackerTimeline);

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
    onlyRole(OWNER_ROLE)
    returns (bool)
    {
        require (totalPublicSupply >= 0, "TTM: Total public supply can't be negative.");
        require (totalPublicSupply <= totalSupply(), "TTM: Total public supply can't be greater than the total coin supply.");

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
    onlyRole(OWNER_ROLE)
    returns (bool)
    {
        require (NonvolumetricSettingsDivisor > 0, "TTM: Settings divisor must be greater than 0");

        _nonvolumetricSettingsDivisor = NonvolumetricSettingsDivisor;
        _nonvolumetricA = AParameter;
        _nonvolumetricB = BParameter;
        _nonvolumetricK = KParameter;

        return true;
    }

    /// @notice Gets the nonvolumetric settings divisor parameter.
    ///
    /// Requirements:
    /// - Must have OWNER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The nonvolumetric settings divisor parameter.
    function getNonvolumetricSettingsDivisor() 
    public
    view
    onlyRole(OWNER_ROLE)
    returns (uint)
    {
        return _nonvolumetricSettingsDivisor;
    }

    /// @notice Gets the nonvolumetric A parameter.
    ///
    /// Requirements:
    /// - Must have OWNER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The nonvolumetric A parameter.
    function getNonvolumetricAParameter() 
    public
    view
    onlyRole(OWNER_ROLE)
    returns (int)
    {
        return _nonvolumetricA;
    }

    /// @notice Gets the nonvolumetric B parameter.
    ///
    /// Requirements:
    /// - Must have OWNER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The nonvolumetric B parameter.
    function getNonvolumetricBParameter() 
    public
    view
    onlyRole(OWNER_ROLE)
    returns (int)
    {
        return _nonvolumetricB;
    }

    /// @notice Gets the nonvolumetric K parameter.
    ///
    /// Requirements:
    /// - Must have OWNER_ROLE role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The nonvolumetric K parameter.
    function getNonvolumetricKParameter() 
    public
    view
    onlyRole(OWNER_ROLE)
    returns (int)
    {
        return _nonvolumetricK;
    }

    /// @notice Gets the nonvolumetric maximum nonrestricted coins for the provided address.
    ///
    /// @dev Calls the internal function to get the maximum nonrestricted coins.
    ///
    /// Requirements:
    /// - Must have NONVOLUMETRIC_ADMIN role.
    ///
    /// Caveats:
    /// - .
    ///
    /// @param account The address to get the maximum for.
    /// @return The total number of unrestricted coins.
    function getNonvolumetricMaximum(address account) 
    public 
    onlyRole(NONVOLUMETRIC_ADMIN)
    returns (uint) 
    {
        return _applyNonvolumetricAlgoTo(account);
    }

    /// @notice Gets the nonvolumetric maximum nonrestricted coins for the caller.
    ///
    /// @dev Calls the internal function to get the maximum nonrestricted coins for the message sender.
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @return The total number of unrestricted coins for the caller.
    function getNonvolumetricMaximum() 
    public 
    returns (uint) 
    {
        return _applyNonvolumetricAlgoTo(_msgSender());
    }

    /// @notice Gets the nonvolumetric maximum nonrestricted coins for the provided address.
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
    /// @param account The address to get the maximum for.
    /// @return The total number of unrestricted coins.
    function _applyNonvolumetricAlgoTo(address account)
    internal
    returns (uint)
    {
                // add sales tracker to balance for whale/nonvolumetric checks
        uint balance = balanceOf(account) + _activeSales.getUnexpiredTransactions(account);

        if (!isWhale(balance))
            return balance;
        else
        {
            /*
            bytes16 quadDivisor = ABDKMathQuad.fromUInt(_nonvolumetricSettingsDivisor);

            bytes16 maximumSpend = ABDKMathQuad.add(ABDKMathQuad.mul(ABDKMathQuad.div(ABDKMathQuad.fromInt(_nonvolumetricA), quadDivisor), ABDKMathQuad.ln(ABDKMathQuad.mul(ABDKMathQuad.fromUInt(balance), ABDKMathQuad.div(ABDKMathQuad.fromInt(_nonvolumetricK), quadDivisor)))), ABDKMathQuad.div(ABDKMathQuad.fromInt(_nonvolumetricB), quadDivisor));

            return ABDKMathQuad.toUInt(maximumSpend);
            */
            return Algorithms.LogarithmicAlgoNatural(balance, _nonvolumetricSettingsDivisor, _nonvolumetricA, _nonvolumetricB, _nonvolumetricK);
        }
    }
}