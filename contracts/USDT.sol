// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title USDT (Test)
 * @notice 6 decimals stable-like token (Mintable/Pausable/Permit/Burnable)
 */
contract USDT is ERC20, ERC20Burnable, ERC20Permit, ERC20Pausable, AccessControl {
    bytes32 public constant MINTER_ROLE  = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE  = keccak256("PAUSER_ROLE");

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply_, // 6 decimals
        address admin_
    ) ERC20(name_, symbol_) ERC20Permit(name_) {
        require(admin_ != address(0), "admin cannot be zero");
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(MINTER_ROLE, admin_);
        _grantRole(PAUSER_ROLE, admin_);
        if (initialSupply_ > 0) _mint(admin_, initialSupply_);
    }

    function decimals() public pure override returns (uint8) { return 6; }

    function pause() external onlyRole(PAUSER_ROLE) { _pause(); }
    function unpause() external onlyRole(PAUSER_ROLE) { _unpause(); }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function _update(address from, address to, uint256 value)
    internal
    override(ERC20, ERC20Pausable)
    {
        super._update(from, to, value);
    }
}
