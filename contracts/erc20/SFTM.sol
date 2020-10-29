pragma solidity ^0.5.0;

import "../common/Initializable.sol";
import "./base/ERC20.sol";
import "./base/ERC20Detailed.sol";
import "./base/ERC20Mintable.sol";
import "./base/ERC20Burnable.sol";
import "../ownership/Ownable.sol";
import "./base/WhitelistedRecipientRole.sol";
import "./base/WhitelistedSenderRole.sol";

/**
 * @dev Extension of {ERC20} that allows token holders to destroy both their own
 * tokens and those that they have an allowance for, in a way that can be
 * recognized off-chain (via event analysis).
 */
contract SFTM is ERC20, ERC20Detailed, ERC20Mintable, ERC20Burnable, Ownable, WhitelistedRecipientRole, WhitelistedSenderRole {

    /**
     * @dev Sets the values for `name`, `symbol`, and `decimals`. All three of
     * these values are immutable: they can only be set once during
     * initialization.
     */
    function initialize(address owner) public initializer {
        // initialize the token
        ERC20Detailed.initialize("Staked FTM", "SFTM", 18);

        // initialize the Ownable
        _transferOwnership(owner);
    }

    function addMinter(address account) external onlyOwner {
        _addMinter(account);
    }

    function removeMinter(address account) external onlyOwner {
        _removeMinter(account);
    }

    function addWhitelistedSender(address account) external onlyOwner {
        _addWhitelistedSender(account);
    }

    function removeWhitelistedSender(address account) external onlyOwner {
        _removeWhitelistedSender(account);
    }

    function addWhitelistedRecipient(address account) external onlyOwner {
        _addWhitelistedRecipient(account);
    }

    function removeWhitelistedRecipient(address account) external onlyOwner {
        _removeWhitelistedRecipient(account);
    }

    function isWhitelisted(address sender, address recipient) public view returns (bool) {
        return isWhitelistedSender(sender) || isWhitelistedRecipient(recipient);
    }

    function transfer(address to, uint256 value) public returns (bool) {
        require(isWhitelisted(msg.sender, to), "SFTM: not whitelisted");
        return ERC20.transfer(to, value);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        require(isWhitelisted(msg.sender, recipient), "SFTM: not whitelisted");
        return ERC20.transferFrom(sender, recipient, amount);
    }

    function approve(address spender, uint256 value) public returns (bool) {
        require(isWhitelisted(msg.sender, spender), "SFTM: not whitelisted");
        return ERC20.approve(spender, value);
    }

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        require(isWhitelisted(msg.sender, spender), "SFTM: not whitelisted");
        return ERC20.increaseAllowance(spender, addedValue);
    }
}
