pragma solidity ^0.5.0;

interface Governable {
    function softwareUpgradeTotalVoters() external view returns(uint256);
    function plainTextTotalVoters() external view returns(uint256);
    function immediateActionTotalVoters() external view returns(uint256);

    function softwareUpgradeVotingPower(address addr) external view returns(uint256, uint256, uint256);
    function plainTextVotingPower(address addr) external view returns(uint256, uint256, uint256);
    function immediateActionVotingPower(address addr) external view returns(uint256, uint256, uint256);
    function delegatedVotesTo(address addr) external view returns(address);
}
