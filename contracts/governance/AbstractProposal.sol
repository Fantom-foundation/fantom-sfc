pragma solidity ^0.5.0;

import "./SafeMath.sol";
import "./Constants.sol";
import "./Governable.sol";
import "./Upgradability.sol";


contract AbstractProposal {
    using SafeMath for uint256;

    struct ProposalTimeline {
        uint256 depositingStartTime;
        uint256 depositingEndTime;
        uint256 votingStartTime;
        uint256 votingEndTime;
        uint256 votingStartEpoch;
        uint256 votingEndEpoch;
    }

    bytes4 INTERFACE_ID;
    uint256 public id;
    uint256 public propType;
    uint256 public status; // status is a bitmask, check out "constants" for a further info
    uint256 public deposit;
    uint256 public requiredDeposit;
    uint256 public permissionsRequired; // might be a bitmask?
    uint256 public minVotesRequired;
    uint256 public totalVotes;
    bool public executable;
    mapping (uint256 => uint256) public choises;

    ProposalTimeline deadlines;

    string public title;
    string public description;
    // string[] public options;
    string public proposalName;
    bytes public proposalSpecialData;
    bool public votesCanBeCanceled;

    function validateProposal(bytes32) external;
    function execute(uint256 optionId) external;
    function getOptions() external returns (bytes32[] memory);

    function supportsInterface(bytes4 interfaceID) external view returns (bool) {
        return interfaceID == INTERFACE_ID;
    }
}