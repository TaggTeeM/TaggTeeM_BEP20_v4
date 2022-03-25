/*
 * Copyright © 2022 TaggTeem. ALL RIGHTS RESERVED.
 */

pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicensed

import "./ABDKMathQuad.sol";

library Algorithms {
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