pragma solidity ^0.5.0;

import "./SafeMath.sol";
import "./Constants.sol";
import "./Governable.sol";
import "./Proposal.sol";
import "./SoftwareUpgradeProposal.sol";
import "../common/ImplementationValidator.sol";


contract GovernanceSettings is Constants {
    uint256 _minimumDeposit = 1500; // minimum deposit
    uint256 _minimumStartingDeposit = 150;
    uint256 _minimumVotesRequiredNum = 67;
    uint256 _minimumVotesRequiredDenum = 100;

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