pragma solidity ^0.5.0;

interface GovernanceCallbacks {
    function refreshVoterData(address voter) external;
}
