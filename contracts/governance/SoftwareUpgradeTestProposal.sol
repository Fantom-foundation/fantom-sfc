pragma solidity ^0.5.0;

import "./SafeMath.sol";
import "./Constants.sol";
import "./Governable.sol";
import "./Upgradability.sol";
import "./AbstractProposal.sol";

contract SoftwareUpgradeTestProposal is AbstractProposal {

    struct VersionDescription {
        string version;
        address addr;
        bool unsafe;
        bool sealedVersion;
    }

    constructor(address upgradableAddr, address _newContractAddr) {
        upgradableContract = Upgradability(addr);
        newContractAddress = _newContractAddr;
    }

    function validateProposal(bytes32) external {

    }

    function execute(uint256 optionId) external {
        upgradableContract.upgradeTo(newContractAddress);
    }
}