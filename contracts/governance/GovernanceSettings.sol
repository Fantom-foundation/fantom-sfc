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
    uint256 _minimumVotesRequired = 1500;

    function minimumDeposit() public pure returns(uint256) {
        return _minimumDeposit;
    }

    function minimumStartingDeposit() public pure returns(uint256) {
        return _minimumStartingDeposit;
    }

    function minimumVotesRequired() public pure returns(uint256) {
        return _minimumVotesRequired;
    }
}