pragma solidity ^0.5.0;

import "./Staker.sol";
import "../erc20/IERC20.sol";
import "../common/Initializable.sol";

contract StakeTokenizer is Ownable, Initializable {
    Stakers internal sfc = Stakers(address(0xFC00FACE00000000000000000000000000000000));

    mapping(address => mapping(uint256 => uint256)) public outstandingSFTM;

    address public sFTMTokenAddress;

    function initialize() internal initializer {
        _transferOwnership(msg.sender);
    }

    function _updateSFTMTokenAddress(address addr) onlyOwner external {
        sFTMTokenAddress = addr;
    }

    function _mintSFTM_staker(address sfcAddr, uint256 stakerID) internal returns(uint256) {
        require(sfc.isStakeLockedUp(stakerID), "staker isn't locked up");
        require(_getStakerAmount(stakerID) > outstandingSFTM[sfcAddr][stakerID], "sFTM is already minted");

        uint256 diff = _getStakerAmount(stakerID) - outstandingSFTM[sfcAddr][stakerID];
        outstandingSFTM[sfcAddr][stakerID] = _getStakerAmount(stakerID);
        return diff;
    }

    function _mintSFTM_delegator(address delegator, uint256 toStakerID) internal returns(uint256) {
        require(sfc.isDelegationLockedUp(delegator, toStakerID), "delegation isn't locked up");
        require(_getDelegationAmount(delegator, toStakerID) > outstandingSFTM[delegator][toStakerID], "sFTM is already minted");

        uint256 diff = _getDelegationAmount(delegator, toStakerID) - outstandingSFTM[delegator][toStakerID];
        outstandingSFTM[delegator][toStakerID] = _getDelegationAmount(delegator, toStakerID);
        return diff;
    }

    function redeemSFTM(uint256 stakerID, uint256 amount) external {
        require(outstandingSFTM[msg.sender][stakerID] >= amount, "low outstanding sFTM balance");
        require(IERC20(sFTMTokenAddress).allowance(msg.sender, address(this)) >= amount, "insufficient allowance");
        outstandingSFTM[msg.sender][stakerID] -= amount;

        // It's important that we burn after updating outstandingSFTM (protection against Re-Entrancy)
        IERC20(sFTMTokenAddress).burnFrom(msg.sender, amount);
    }

    function mintSFTM(uint256 toStakerID) external {
        address delegator = msg.sender;
        uint256 diff;
        if (_getStakerSfcAddress(toStakerID) == delegator) {
            diff = _mintSFTM_staker(msg.sender, toStakerID);
        } else {
            diff = _mintSFTM_delegator(delegator, toStakerID);
        }

        // It's important that we mint after updating outstandingSFTM (protection against Re-Entrancy)
        require(IERC20(sFTMTokenAddress).mint(msg.sender, diff), "failed to mint sFTM");
    }

    function allowedToWithdrawStake(address sender, uint256 stakerID) public view returns(bool) {
        return outstandingSFTM[sender][stakerID] == 0;
    }

    function checkAllowedToWithdrawStake(address sender, uint256 stakerID) public view {
        require(allowedToWithdrawStake(sender, stakerID), "outstanding sFTM balance");
    }

    function _getDelegationAmount(address delegator, uint256 toStakerID) internal view returns(uint256) {
        (, , uint256 deactivatedEpoch, , uint256 amount, ,) = sfc.delegations(delegator, toStakerID);
        if (deactivatedEpoch != 0) {
            return 0;
        }
        return amount;
    }

    function _getStakerAmount(uint256 stakerID) internal view returns(uint256) {
        (uint256 status, , , uint256 deactivatedEpoch, , uint256 stakeAmount, , , , ) = sfc.stakers(stakerID);
        if (deactivatedEpoch != 0 || status != 0) {
            return 0;
        }
        return stakeAmount;
    }

    function _getStakerSfcAddress(uint256 stakerID) internal view returns(address) {
        (, , , , , , , , , address sfcAddress) = sfc.stakers(stakerID);
        return sfcAddress;
    }
}
