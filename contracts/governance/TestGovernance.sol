pragma solidity ^0.5.0;

import "./Governance.sol";

// this is a special implementation of a governance contract made for testing purposes.
// it is important that the ONLY difference with an original Governance is that it redeclares some of constant functions


contract TestGovernance is Governance {

    uint256 constant DEPOSITING_PERIOD = 5 seconds;
    uint256 constant VOTING_PERIOD = 10 seconds;
    uint256 fakeblock;
    // uint now;

    // struct FakeBlock {
    //     uint timestamp;
    // }
    // FakeBlock block;


    constructor(address _governableContract, address _proposalFactory) Governance(_governableContract, _proposalFactory) public {}


    function depositingPeriod() public view returns (uint256) {
        return DEPOSITING_PERIOD;
    }

    function votingPeriod() public view returns (uint256) {
        return VOTING_PERIOD;
    }


    function mine() public {
        fakeblock++;
    }
}