// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract RBT is ERC20, ERC20Burnable, ERC20Permit, ERC20Pausable, AccessControl {
    bytes32 public constant MINTER_ROLE     = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE     = keccak256("PAUSER_ROLE");
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");

    bool public whitelistEnabled;
    mapping(address => bool) private _whitelist;

    event WhitelistEnabled(bool enabled);
    event WhitelistSet(address indexed account, bool allowed);

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply_, // 18 decimals
        address admin_
    ) ERC20(name_, symbol_) ERC20Permit(name_) {
        require(admin_ != address(0), "admin cannot be zero");
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(MINTER_ROLE, admin_);
        _grantRole(PAUSER_ROLE, admin_);
        _grantRole(COMPLIANCE_ROLE, admin_);
        if (initialSupply_ > 0) _mint(admin_, initialSupply_);
    }

    function pause() external onlyRole(PAUSER_ROLE) { _pause(); }
    function unpause() external onlyRole(PAUSER_ROLE) { _unpause(); }
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) { _mint(to, amount); }

    function setWhitelistEnabled(bool enabled) external onlyRole(COMPLIANCE_ROLE) {
        whitelistEnabled = enabled; emit WhitelistEnabled(enabled);
    }
    function setWhitelist(address account, bool allowed) public onlyRole(COMPLIANCE_ROLE) {
        _whitelist[account] = allowed; emit WhitelistSet(account, allowed);
    }
    function batchSetWhitelist(address[] calldata accounts, bool allowed) external onlyRole(COMPLIANCE_ROLE) {
        for (uint256 i = 0; i < accounts.length; i++) { _whitelist[accounts[i]] = allowed; emit WhitelistSet(accounts[i], allowed); }
    }
    function isWhitelisted(address account) external view returns (bool) { return _whitelist[account]; }

    function _update(address from, address to, uint256 value)
    internal
    override(ERC20, ERC20Pausable)
    {
        if (whitelistEnabled) {
            if (from != address(0)) require(_whitelist[from], "RBT: sender not whitelisted");
            if (to != address(0))   require(_whitelist[to],   "RBT: recipient not whitelisted");
        }
        super._update(from, to, value);
    }
}
