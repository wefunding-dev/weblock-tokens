// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract USDRToken is
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant MINTER_ROLE      = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE      = keccak256("BURNER_ROLE");
    bytes32 public constant PAUSER_ROLE      = keccak256("PAUSER_ROLE");
    bytes32 public constant COMPLIANCE_ROLE  = keccak256("COMPLIANCE_ROLE");

    mapping(address => bool) public frozen;
    mapping(address => bool) public blacklisted;

    string public disclosuresURI; // 공시/정책 문서 (ipfs/https)

    event FrozenUpdated(address indexed account, bool frozen);
    event BlacklistUpdated(address indexed account, bool blacklisted);
    event DisclosuresURIUpdated(string uri);

    function initialize(address admin, string calldata _disclosuresURI) external initializer {
        __ERC20_init("WeBlock USD Settlement Token", "USDR");
        __ERC20Permit_init("WeBlock USD Settlement Token");
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(BURNER_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        _grantRole(COMPLIANCE_ROLE, admin);

        disclosuresURI = _disclosuresURI;
    }

    function setDisclosuresURI(string calldata uri) external onlyRole(DEFAULT_ADMIN_ROLE) {
        disclosuresURI = uri;
        emit DisclosuresURIUpdated(uri);
    }

    function pause() external onlyRole(PAUSER_ROLE) { _pause(); }
    function unpause() external onlyRole(PAUSER_ROLE) { _unpause(); }

    function setFrozen(address account, bool v) external onlyRole(COMPLIANCE_ROLE) {
        frozen[account] = v;
        emit FrozenUpdated(account, v);
    }

    function setBlacklisted(address account, bool v) external onlyRole(COMPLIANCE_ROLE) {
        blacklisted[account] = v;
        emit BlacklistUpdated(account, v);
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function burnFrom(address from, uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(from, amount);
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    function _update(address from, address to, uint256 value)
    internal
    override
    whenNotPaused
    {
        if (from != address(0)) {
            require(!blacklisted[from], "USDR: sender blacklisted");
            require(!frozen[from], "USDR: sender frozen");
        }
        if (to != address(0)) {
            require(!blacklisted[to], "USDR: receiver blacklisted");
            require(!frozen[to], "USDR: receiver frozen");
        }
        super._update(from, to, value);
    }
}
