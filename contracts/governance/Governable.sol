pragma solidity ^0.5.0;

import "./GovernanceCallbacks.sol";

interface Governable {
    function getTotalVotes(uint256 propType) external view returns(uint256);
    function getVotingPower(address addr, uint256 propType) external view returns(uint256, uint256, uint256);
    function delegatedVotesTo(address addr) external view returns(address);
}
