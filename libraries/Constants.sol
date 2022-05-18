/*
 * Copyright © 2022 TaggTeem. ALL RIGHTS RESERVED.
 */

pragma solidity 0.8.7;
// SPDX-License-Identifier: MIT

library Constants {
    /**
    * @dev Lockbox structure.
    */
    struct Lockbox {
        uint lockboxId;
        uint balance;
        uint releaseTime;
        address beneficiary;
        address creator;
    }

    // roles
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant FOUNDER_ROLE = keccak256("FOUNDER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant SECURITY_ADMIN = keccak256("SECURITY_ADMIN");
    bytes32 public constant NONVOLUMETRIC_ADMIN = keccak256("NONVOLUMETRIC_ADMIN");
    bytes32 public constant AIRDROPPER_ROLE = keccak256("AIRDROPPER_ROLE");
    bytes32 public constant RESTRICTION_ADMIN = keccak256("RESTRICTION_ADMIN");
    bytes32 public constant TAX_ADMIN = keccak256("TAX_ADMIN");
    bytes32 public constant SALES_HISTORY_ADMIN = keccak256("SALES_HISTORY_ADMIN");
    bytes32 public constant LOCKBOX_ADMIN = keccak256("LOCKBOX_ADMIN");
}