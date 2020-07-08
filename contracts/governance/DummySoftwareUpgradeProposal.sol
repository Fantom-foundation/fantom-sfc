pragma solidity ^0.5.0;

import "./SafeMath.sol";
import "./Constants.sol";
import "./Governable.sol";
import "./Upgradability.sol";
import "./AbstractProposal.sol";


contract DummySoftwareUpgradeProposal is AbstractProposal {

    Upgradability upgradableContract;
    address newContractAddress;
    bytes32[] opts;

    event SoftwareUpgradeIsDone();

    constructor(address upgradableAddr, address _newContractAddr) public {
        upgradableContract = Upgradability(upgradableAddr);
        newContractAddress = _newContractAddr;

        bytes32 voteYes = "yes";
        bytes32 voteNo = "no";
        opts.push(voteYes);
        opts.push(voteNo);
    }

    function validateProposal(bytes32) public {

    }

    function getOptions() public returns (bytes32[] memory) {

        return opts;
    }

    function execute(uint256 optionId) public {
        emit SoftwareUpgradeIsDone();
    }
}