// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract MARIN is ERC20, ERC20Pausable, AccessControl, ERC20Permit {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant RESCUER_ROLE = keccak256("RESCUER_ROLE");
    uint256 public constant MAX_TOTAL_SUPPLY = 1000000000e18; // 1 billion total supply

    constructor(address defaultAdmin, address pauser, address minter)
        ERC20("MARIN", "MARIN")
        ERC20Permit("MARIN")
    {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(RESCUER_ROLE, msg.sender);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        require(amount + totalSupply() <= MAX_TOTAL_SUPPLY, "NAVIX: Max total supply exceeded");
        _mint(to, amount);
    }

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Pausable)
    {
        super._update(from, to, value);
    }

    function rescueTokens(
        IERC20 token,
        uint256 value
    ) external onlyRole(RESCUER_ROLE) {
        token.transfer(msg.sender, value);
    }

    function rescueNative() public onlyRole(RESCUER_ROLE) {
    address payable recipient = payable(msg.sender);
    recipient.transfer(address(this).balance);
}

}
