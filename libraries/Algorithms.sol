/*
 * Copyright © 2022 TaggTeem. ALL RIGHTS RESERVED.
 */

pragma solidity 0.8.7;
// SPDX-License-Identifier: MIT

import "./ABDKMathQuad.sol";

library Algorithms {
    /// @notice Applies the nonvolumetric algorithm.
    ///
    /// @dev Uses the equation "R = a * ln(O * k) + b" on the percentage owned, and returns the percentage restricted based on own %.
    ///
    /// Requirements:
    /// - .
    ///
    /// Caveats:
    /// - .
    ///
    /// @param percentageOwned The percentage of the total public supply to apply to.
    /// @param _nonvolumetricSettingsDivisor The divisor to divide the A, B, and K parameters by.
    /// @param _nonvolumetricA The nonvolumetric A parameter.
    /// @param _nonvolumetricB The nonvolumetric B parameter.
    /// @param _nonvolumetricK The nonvolumetric K parameter.
    /// @return Restriction percentage.
    function LogarithmicAlgoNaturalQuad(uint percentageOwned, uint _nonvolumetricSettingsDivisor, int _nonvolumetricA, int _nonvolumetricB, int _nonvolumetricK)
    internal
    pure
    returns (uint)
    {
        // divisor is used more than once below, so calculate once and use many
        bytes16 quadDivisor = ABDKMathQuad.fromUInt(_nonvolumetricSettingsDivisor);

        // R = a * ln(O * k) + b
        bytes16 restrictedPercent = ABDKMathQuad.add(ABDKMathQuad.mul(ABDKMathQuad.div(ABDKMathQuad.fromInt(_nonvolumetricA), quadDivisor), ABDKMathQuad.ln(ABDKMathQuad.mul(ABDKMathQuad.fromUInt(percentageOwned), ABDKMathQuad.div(ABDKMathQuad.fromInt(_nonvolumetricK), quadDivisor)))), ABDKMathQuad.div(ABDKMathQuad.fromInt(_nonvolumetricB), quadDivisor));

        return ABDKMathQuad.toUInt(restrictedPercent);
    }
}