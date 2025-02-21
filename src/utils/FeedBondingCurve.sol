// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.20;

contract FeedBondingCurve {
    // feed function uses a negative exponential bonding curve, that starts at 0 and asymptotically goes to 100

    // P(S) = C * (1 - e ** (-a * S)) where C = 100 (max value) and a = steepness (e.g. 2)

    // integral :  R(S) = C * (S + e**(-a*S)/a)

    // TODO: Check this new formula, especially the type conversions which were
    // generated by GPT-4! Switch to a fixed point library if this solution
    // doesn't work
    function feedBondingCurve(uint256 /* amount*/, uint256 energy) public pure returns (uint256) {
        //simulate 'e' with eN / eD
        uint256 eN = 271828 * 10 ** 18;

        uint256 C = 100; // maximum value that will never be reached
        uint256 a = 2; // steepness of the curve

        // Ensure that energy is non-negative, as it doesn't make sense to have negative energy in this context
        require(energy >= 0, "Energy must be non-negative");

        // Convert to unsigned integers for the calculation
        uint256 unsignedEnergy = uint256(energy);
        uint256 positiveExponent = a * unsignedEnergy;

        // Compute 1 / (e^x) using the fact that e^(-x) is 1 / e^x
        uint256 divisor = eN ** positiveExponent;
        require(divisor != 0, "Exponentiation resulted in zero");
        uint256 eToTheNegativeValue = 1e36 / divisor; // 1e36 is used for scaling, assuming 18 decimals for the representation of 1

        // Now use the result in your equation
        int256 newEnergy = int256(C * (unsignedEnergy + eToTheNegativeValue / a));
        return uint256(newEnergy);
    }
}
