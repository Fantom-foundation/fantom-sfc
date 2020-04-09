
pragma solidity ^0.5.0;

import "./SafeMath.sol";


contract Constants {
    using SafeMath for uint256;
    uint256 constant TYPE_SOFTWARE_UPGRADE = 1; // software upgrade type
    uint256 constant TYPE_PLAIN_TEXT = 2; // plane text type
    uint256 constant TYPE_IMMEDIATE_ACTION = 3; // immediate action type

    function typeSoftwareUpgrade() public pure returns (uint256) {
        return TYPE_SOFTWARE_UPGRADE;
    }

    function typePlainText() public pure returns (uint256) {
        return TYPE_PLAIN_TEXT;
    }

    function typeImmediateAction() public pure returns (uint256) {
        return TYPE_IMMEDIATE_ACTION;
    }

    uint256 internal constant PROPOSAL_TYPE_TEXT = 0;
}