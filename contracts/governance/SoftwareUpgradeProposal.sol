pragma solidity ^0.5.0;

import "./SafeMath.sol";
import "./Constants.sol";
import "./Governable.sol";
import "./Upgradability.sol";


contract SoftwareUpgradeProposalHandler {
    using SafeMath for uint256;

    struct VersionDescription {
        string version;
        address addr;
        bool unsafe;
        bool sealedVersion;
    }

    string[] availableVersions;
    Upgradability upgradableContract;
    mapping(string => VersionDescription) versions;

    function validateProposalRequest(string memory version) public {
        VersionDescription memory vDesc = versions[version];
        require(vDesc.addr != address(0), "this version is not yet present among available versions");
        require(vDesc.sealedVersion == false, "this version is sealed");
    }

    function addSoftwareVersion(string memory version, address addr) public {
        checkSoftwareContractIsValid(addr);
        VersionDescription memory vDesc;
        vDesc.version = version;
        vDesc.addr = addr;
        vDesc.unsafe = true;
        versions[version] = vDesc;
    }

    function resolveSoftwareUpgrade(string memory version) public {
        VersionDescription memory vDesc = versions[version];
        require(vDesc.addr != address(0), "this version is not yet present among available versions");
        require(vDesc.sealedVersion == false, "this version is sealed");
        upgradableContract.upgradeTo(versions[version].addr);
    }

    function checkSoftwareContractIsValid(address addr) public {
        require(isValidSoftwareContract(addr), "address does not belong to a contract");
    }

    function isValidSoftwareContract(address account) public view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(account) }
        return size > 0;
    }
}