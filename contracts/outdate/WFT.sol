// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title WFT (WeFunding Token)
 * @notice 기본 ERC20 + Burnable + Permit(EIP-2612). 배포자는 초기물량 수령, 추후 mint는 owner만 가능.
 */
contract WFT is ERC20, ERC20Burnable, ERC20Permit, Ownable {
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply,          // 18 decimals 기준
        address owner_
    ) ERC20(name_, symbol_) ERC20Permit(name_) Ownable(owner_) {
        if (owner_ == address(0)) revert("owner cannot be zero");
        if (initialSupply > 0) _mint(owner_, initialSupply);
    }

    /// @notice 추가 발행 (owner만)
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
