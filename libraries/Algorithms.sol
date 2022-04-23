/*
 * Copyright © 2022 TaggTeem. ALL RIGHTS RESERVED.
 */

pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicensed

import "./ABDKMathQuad.sol";

library Algorithms {
    function LogarithmicAlgoNaturalQuad(uint percentageOwned, uint _nonvolumetricSettingsDivisor, int _nonvolumetricA, int _nonvolumetricB, int _nonvolumetricK)
    internal
    pure
    returns (uint)
    {
        bytes16 quadDivisor = ABDKMathQuad.fromUInt(_nonvolumetricSettingsDivisor);

        // R = a * ln(O * k) + b
        bytes16 restrictedPercent = ABDKMathQuad.add(ABDKMathQuad.mul(ABDKMathQuad.div(ABDKMathQuad.fromInt(_nonvolumetricA), quadDivisor), ABDKMathQuad.ln(ABDKMathQuad.mul(ABDKMathQuad.fromUInt(percentageOwned), ABDKMathQuad.div(ABDKMathQuad.fromInt(_nonvolumetricK), quadDivisor)))), ABDKMathQuad.div(ABDKMathQuad.fromInt(_nonvolumetricB), quadDivisor));

        return ABDKMathQuad.toUInt(restrictedPercent);
    }
}