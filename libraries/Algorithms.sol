/*
 * Copyright © 2022 TaggTeem. ALL RIGHTS RESERVED.
 */

pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicensed

import "./ABDKMathQuad.sol";

library Algorithms {
    /*
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
    bytes32 public constant VOTING_ADMIN = keccak256("VOTING_ADMIN");
    */

    function LogarithmicAlgoNatural(uint balance, uint _nonvolumetricSettingsDivisor, int _nonvolumetricA, int _nonvolumetricB, int _nonvolumetricK)
    public
    pure
    returns (uint)
    {
        bytes16 quadDivisor = ABDKMathQuad.fromUInt(_nonvolumetricSettingsDivisor);

        bytes16 maximumSpend = ABDKMathQuad.add(ABDKMathQuad.mul(ABDKMathQuad.div(ABDKMathQuad.fromInt(_nonvolumetricA), quadDivisor), ABDKMathQuad.ln(ABDKMathQuad.mul(ABDKMathQuad.fromUInt(balance), ABDKMathQuad.div(ABDKMathQuad.fromInt(_nonvolumetricK), quadDivisor)))), ABDKMathQuad.div(ABDKMathQuad.fromInt(_nonvolumetricB), quadDivisor));

        return ABDKMathQuad.toUInt(maximumSpend);
    }
}