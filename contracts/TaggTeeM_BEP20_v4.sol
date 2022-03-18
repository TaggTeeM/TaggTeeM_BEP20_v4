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

import "./Libraries/ABDKMathQuad.sol";

import "./Libraries/ExpirableTransactionsTracker.sol";

contract TaggTeeM_BEP20_v4 is ERC20, ERC20Burnable, Pausable, AccessControl, ERC20Permit, ERC20Votes, Ownable {
    using SafeMath for uint;

    // roles
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant FOUNDER_ROLE = keccak256("FOUNDER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant SECURITY_ADMIN = keccak256("SECURITY_ADMIN");
    bytes32 public constant WHALE_ADMIN = keccak256("WHALE_ADMIN");
    bytes32 public constant AIDROPPER_ROLE = keccak256("AIDROPPER_ROLE");
    bytes32 public constant RESTRICTION_ADMIN = keccak256("RESTRICTION_ADMIN");
    bytes32 public constant IFC_TAX_ADMIN = keccak256("IFC_TAX_ADMIN");
    bytes32 public constant SALES_HISTORY_ADMIN = keccak256("SALES_HISTORY_ADMIN");

    // whale settings
    uint private _whaleThreshold = 1; // 1%
    uint private _restrictionTimeline = 6 * 30 * 24 * 60 * 60; // 6 months
    uint private _salesTrackerTimeline = 24 * 60 * 60; // 24 hours

    // founder coins
    uint private _founderRestrictionPercentage = 75; // 75%
    uint private _founderRestrictionTimeline = 6 * 30 * 24 * 60 * 60; // 6 months
    uint private _founderBonusRestrictionPercentage = 1; // 1%
    uint private _founderBonusRestrictionTimeline = 24 * 60 * 60; // 24 hours

    int private settingsDivisor = 100;
    int private a = 4000;
    int private b = 600;
    int private k = 170;

    mapping (address => uint) private _totalFounderCoins;
    mapping (address => uint) private _founderCoinBalances;
    mapping (address => uint) private FounderBonusSalesExpirations;

    // token creator info
    //address private _tokenCreator;

    // Influencers For Change tax information
    address private _ifcTaxWallet = address(0);
    uint private _ifcTaxAmount = 1; // 1%

    ExpirableTransactionsTracker private _activeHolderRestrictions;
    ExpirableTransactionsTracker private _activeSales;

    constructor () ERC20("TaggTeeM", "TTM") ERC20Permit("TaggTeeM") {
        //_tokenCreator = _msgSender();

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(PAUSER_ROLE, _msgSender());
        _grantRole(MINTER_ROLE, _msgSender());
        _grantRole(OWNER_ROLE, _msgSender());

        _mint(_msgSender(), 100000000000 * 10 ** decimals());

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

    // The following functions are overrides required by Solidity.

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

        _activeSales.addTransaction(from, amount);
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
    /// @param value The amount of coin to send to the provided address.
    /// return Whether the transfer was a success.
    function _transfer(address from, address to, uint256 value)
    override
    internal
    whenNotPaused
    //returns (bool)
    {
        bool isFounderTransfer = false;
        uint balance = balanceOf(from);

        // check if holder is a founder and is selling bonus coins (lower 75% is governed by the active holder restrictions records)
        if (_founderCoinBalances[from] > 0 && _founderCoinBalances[from] >= _totalFounderCoins[from].mul(_founderRestrictionPercentage.div(100))) {
            // if founder bonus, restrict to 1% per day
            require (value.div(balance.add(_activeSales.getUnexpiredTransactions(from))).mul(100) < _founderBonusRestrictionPercentage);

            isFounderTransfer = true;
        } else 
            // check for whale trade cap unless we're selling founder coins
            require (value < getNonvolumetricMaximum(from), "TTM: Maximum daily trade cap reached for this wallet's staking tier");

        // check that we're not trying to transfer restricted coins
        if (_restrictionTimeline > 0 && _activeHolderRestrictions.hasTransactions(from)) // ActiveRestrictions[from]) // perform ActiveRestrictions check here to reduce gas by eliminating function call
            require (value < balance - _activeHolderRestrictions.getUnexpiredTransactions(from), "TTM: Attempt to transfer restricted coins");

        // IFC tax
        if (_ifcTaxAmount > 0 && _ifcTaxWallet != address(0)) {
            uint taxAmount = value.mul(_ifcTaxAmount.div(100));

            super._transfer(from, _ifcTaxWallet, taxAmount);

            value -= taxAmount;
        }

        // require that transaction completes successfully
        super._transfer(from, to, value);

        // record the founder coin transfer
        if (isFounderTransfer || _founderCoinBalances[from] > 0)
            _founderCoinBalances[from] = _founderCoinBalances[from] < value ? 0 : _founderCoinBalances[from] - value;
            //FounderBonusSalesExpirations[_msgSender()] = block.timestamp + _founderBonusRestrictionTimeline; 

        //return true;
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
    /// @param _to The address to airdrop to.
    /// @param _value The amount of coin to send to the proveded address.
    /// @return Whether the transfer was a success.
    function airdrop(address _to, uint256 _value)
    public
    whenNotPaused
    onlyRole(AIDROPPER_ROLE)
    returns (bool)
    {
        require(super.transfer(_to, _value));

        // add to restricted list
        _activeHolderRestrictions.addTransaction(_to, _value);

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
    /// @param _to The address to send founder coins to.
    /// @param _value The amount of coin to send to the proveded address.
    /// @return Whether the transfer was a success.
    function sendFounderCoins(address _to, uint256 _value)
    public
    onlyRole(OWNER_ROLE)
    returns (bool)
    {
        require(super.transfer(_to, _value));

        // mark 75% of coins as founder coins and add to restricted list using the founder restriction timeline
        _activeHolderRestrictions.addTransaction(_to, _value.mul(_founderRestrictionPercentage.div(100)), _founderRestrictionTimeline);
        _totalFounderCoins[_to] += _value;
        _founderCoinBalances[_to] += _value;

        return true;
    }

    /*
    * Returns the total number of restricted coins for the caller
    */
    function getTotalRestrictions()
    public
    returns (uint)
    {
        return _activeHolderRestrictions.getUnexpiredTransactions(_msgSender());
    }

    function getTotalFounderCoins()
    public
    view
    onlyRole(FOUNDER_ROLE)
    returns (uint)
    {
        return _totalFounderCoins[_msgSender()];
    }

    function isWhale(uint256 Amount) 
    public 
    view 
    returns (bool ConfirmWhale) {
        // whaleThreshold of 0 turns off whales
        if (_whaleThreshold == 0)
            return false;
        else
            return Amount.div(totalSupply()) > _whaleThreshold;
    }

    function isWhale(address Holder) 
    public 
    view 
    returns (bool ConfirmWhale) {
        return isWhale(balanceOf(Holder));
    }

    function changeWhaleThreshold(uint8 NewThreshold) 
    public
    onlyRole(WHALE_ADMIN)
    returns (bool success)
    {
        // require that requested threshold is >= 0 && <= 100 - 0 turns off whale checking
        require (NewThreshold >= 0 && NewThreshold <= 100, "TTM: Whale threshold must be between 0% and 100%");

        // update whale threshold
        _whaleThreshold = NewThreshold;

        success = true;
    }

    function changeRestrictionTimeline(uint NewRestriction) 
    public
    onlyRole(RESTRICTION_ADMIN)
    returns (bool success)
    {
        // require that the new restriction is positive, 0 turns off restrictions
        require (NewRestriction >= 0, "TTM: Restriction timeline must be positive");

        // update restriction timeline
        _restrictionTimeline = NewRestriction;

        _activeHolderRestrictions.setTimelineOffset(_restrictionTimeline);

        success = true;
    }

    function changeFounderRestrictionTimeline(uint NewRestriction) 
    public
    onlyRole(FOUNDER_ROLE)
    returns (bool success)
    {
        // require that the new restriction is positive, 0 turns off restrictions
        require (NewRestriction >= 0, "TTM: Founder restriction timeline must be positive");

        // update restriction timeline
        _founderRestrictionTimeline = NewRestriction;

        success = true;
    }

    function changeFounderBonusRestrictionPercentage(uint NewRestriction) 
    public
    onlyRole(FOUNDER_ROLE)
    returns (bool success)
    {
        // require that the new restriction is positive, 0 turns off restrictions
        require (NewRestriction >= 0 && NewRestriction <= 100, "TTM: Founder bonus restriction must be between 0% and 100%");

        // update restriction timeline
        _founderBonusRestrictionPercentage = NewRestriction;

        success = true;
    }

    function changeFounderBonusRestrictionTimeline(uint NewRestriction) 
    public
    onlyRole(FOUNDER_ROLE)
    returns (bool)
    {
        // require that the new restriction is positive, 0 turns off restrictions
        require (NewRestriction >= 0, "TTM: Founder Bonus restriction timeline must be a positive integer");

        // update restriction timeline
        _founderBonusRestrictionTimeline = NewRestriction;

        return true;
    }

    function changeIfcTaxWallet(address NewWallet)
    public
    onlyRole(IFC_TAX_ADMIN)
    returns (bool)
    {
        require (NewWallet != address(0), "TTM: Attempt to set IFC tax wallet to address: 0");

        _ifcTaxWallet = NewWallet;

        return true;
    }

    function changeIfcTaxAmount(uint NewAmount)
    public
    onlyRole(IFC_TAX_ADMIN)
    returns (bool)
    {
        require (NewAmount >= 0, "TTM: IFC tax amount must be positive or zero.");

        _ifcTaxAmount = NewAmount;

        return true;
    }

    function changeSalesTrackerTimeline(uint NewTimeline)
    public
    onlyRole(WHALE_ADMIN)
    returns (bool)
    {
        // require that the new restriction is positive, 0 turns off restrictions
        require (NewTimeline >= 0, "TTM: Sales tracker timeline must be positive");

        // update restriction timeline
        _salesTrackerTimeline = NewTimeline;

        _activeSales.setTimelineOffset(_salesTrackerTimeline);

        return true;
    }

    function setNonvolumetricParameters (int SettingsDivisor, int128 AParameter, int128 BParameter, int128 KParameter)
    public
    onlyRole(OWNER_ROLE)
    returns (bool)
    {
        // TODO: Do we need this function?

        settingsDivisor = SettingsDivisor;
        a = AParameter;
        b = BParameter;
        k = KParameter;

        return true;
    }

    /*
    * If the holder is a whale, applies the NonVolumetric algorithm to their current holdings (including restricted coins), and returns the
    *   number of restricted coins they currently have. For non-whales, the whole balance (no restrictions) is returned.
    *
    * The current nonvolumetric algorithm is =>> "y = a * log10(x * k) + b"
    */
    function getNonvolumetricMaximum(address Holder) 
    public 
    returns (uint) 
    {
        // TODO: turn off maximum for _tokenCreator and OWNER_ROLE?

        // add sales tracker to balance for whale/nonvolumetric checks
        uint balance = balanceOf(Holder) + _activeSales.getUnexpiredTransactions(Holder);

        if (!isWhale(balance))
            return balance;
        else
        {
            /*
            bytes16 quadBalance = ABDKMathQuad.fromUInt(balance);
            bytes16 quadDivisor = ABDKMathQuad.fromInt(settingsDivisor);
            bytes16 quadA = ABDKMathQuad.div(ABDKMathQuad.fromInt(a), quadDivisor);
            bytes16 quadB = ABDKMathQuad.div(ABDKMathQuad.fromInt(b), quadDivisor);
            bytes16 quadK = ABDKMathQuad.div(ABDKMathQuad.fromInt(k), quadDivisor);

            bytes16 loggerTarget = ABDKMathQuad.mul(quadBalance, quadK);
            bytes16 logged = ABDKMathQuad.ln(loggerTarget);

            bytes16 firstTerm = ABDKMathQuad.mul(quadA, logged);
            bytes16 lastTerm = ABDKMathQuad.add(firstTerm, quadB);
            */
            bytes16 quadDivisor = ABDKMathQuad.fromInt(settingsDivisor);

            bytes16 lastTerm = ABDKMathQuad.add(ABDKMathQuad.mul(ABDKMathQuad.div(ABDKMathQuad.fromInt(a), quadDivisor), ABDKMathQuad.ln(ABDKMathQuad.mul(ABDKMathQuad.fromUInt(balance), ABDKMathQuad.div(ABDKMathQuad.fromInt(k), quadDivisor)))), ABDKMathQuad.div(ABDKMathQuad.fromInt(b), quadDivisor));

            return ABDKMathQuad.toUInt(lastTerm);
        }
    }
}