pragma solidity ^0.5.0;

import "./SafeMath.sol";
import "./IProposalFactory.sol";
import "./PlainTextProposal.sol";
import "./DummySoftwareUpgradeProposal.sol";


contract TestProposalFactory is IProposalFactory {

    uint256 constant statusCreated = 0x01;
    uint256 constant statusConsidered = 0x02;

    address upgradableAddr;

    mapping(address => uint256) public proposalContracts;

    event PlainTextProposalCreated(address proposalAddress);
    event SoftwareUpgradeProposalCreated(address proposalAddress);

    constructor(address _upgradableAddr) public {
        upgradableAddr = _upgradableAddr;
    }

    function newPlainTextProposal(bytes32 title, bytes32 desc, bytes32[] memory options) public {
        address newProp = address(new PlainTextProposal(title, desc, options));
        proposalContracts[newProp] = statusCreated;

        emit PlainTextProposalCreated(newProp);
    }

    function newSoftwareUpgradeProposal(address newContractAddr) public {
        address newProp = address(new DummySoftwareUpgradeProposal(upgradableAddr, newContractAddr));
        proposalContracts[newProp] = statusCreated;

        emit SoftwareUpgradeProposalCreated(newProp);
    }

    function canVoteForProposal(address prop) public view returns(bool) {
        return proposalContracts[prop] == statusCreated;
    }

    function setProposalIsConsidered(address prop) public {
        proposalContracts[prop] == statusConsidered;
    }
}