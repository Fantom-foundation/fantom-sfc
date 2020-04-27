pragma solidity ^0.5.0;


interface ProposalA {
    function createSpecialData(bytes32[] calldata dataValues) external returns(bytes32);
    function modifyInnerState(bytes32[] calldata dataValues) external returns(bytes32);
    function validateProposal(bytes32) external;
    function resolveProposal(bytes32) external;
    function proposalName() external returns(string memory);
}