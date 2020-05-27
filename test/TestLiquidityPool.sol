pragma solidity ^0.5.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Mintable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract TestLiquidityPool is ReentrancyGuard {
    using SafeMath for uint256;
    using Address for address;
    using SafeERC20 for ERC20;

    uint256 public lastDeposit;
    uint256 public sumDeposit;

    function deposit(uint256 _value_native) external payable {
        lastDeposit = _value_native;
        sumDeposit += _value_native;
    }

    function _resetSumDeposit() public {
        sumDeposit = 0;
    }
}
