pragma solidity ^0.5.0;

import "./SafeMath.sol";
import "./Constants.sol";
import "./Governable.sol";
import "./SoftwareUpgradeProposal.sol";
import "../common/ImplementationValidator.sol";


contract GovernanceSettings is Constants {
    uint256 ftm = 1e18;
    uint256 _minimumDeposit = 500000 * ftm; // minimum deposit
    uint256 _minimumStartingDeposit = 100000 * ftm;
    uint256 _minimumVotesRequiredNum = 20;
    uint256 _minimumVotesRequiredDenum = 100;
    uint256 _maximumlPossibleResistance = 4000;
    uint256 _maximumlPossibleDesignation = 4000;

    function minimumDeposit() public view returns(uint256) {
        return _minimumDeposit;
    }

    function minimumStartingDeposit() public view returns(uint256) {
        return _minimumStartingDeposit;
    }

    function minimumVotesRequired(uint256 totalVotersNum) public view returns(uint256) {
        return totalVotersNum * _minimumVotesRequiredNum / _minimumVotesRequiredDenum;
    }
}
