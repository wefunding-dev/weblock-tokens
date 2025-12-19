// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * RBTMonthlyRevenueVault
 * - USDR를 예치해두고, "월 단위(에폭)"로 RBT 보유자에게 배당 지급
 * - 월 마감 스냅샷은 오프체인에서 계산, 온체인은 Merkle proof 기반 claim
 * - seriesId(tokenId) 별로 root를 분리해 1호/2호/3호 별 정산이 가능
 *
 * 운영 흐름:
 * 1) (월 마감) 오프체인에서 seriesId별 [account -> claimAmountUSDR] 계산
 * 2) (운영자) USDR를 vault로 입금 (fund)
 * 3) (운영자) epoch/seriesId별 merkleRoot 등록
 * 4) (유저) proof로 claim
 */
contract RBTMonthlyRevenueVault is AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    IERC20 public immutable usdr;

    // epoch = YYYYMM (예: 202601)
    // roots[epoch][seriesId] = merkle root
    mapping(uint256 => mapping(uint256 => bytes32)) public roots;

    // claimed[epoch][seriesId][account] = true
    mapping(uint256 => mapping(uint256 => mapping(address => bool))) public claimed;

    event Funded(address indexed from, uint256 amount);
    event RootSet(uint256 indexed epoch, uint256 indexed seriesId, bytes32 root);
    event Claimed(uint256 indexed epoch, uint256 indexed seriesId, address indexed account, uint256 amount);

    constructor(address usdrToken, address admin) {
        usdr = IERC20(usdrToken);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);
    }

    function pause() external onlyRole(OPERATOR_ROLE) { _pause(); }
    function unpause() external onlyRole(OPERATOR_ROLE) { _unpause(); }

    /**
     * 운영자: 월 배당 재원(USDR)을 vault로 입금
     */
    function fund(uint256 amount) external onlyRole(OPERATOR_ROLE) {
        require(amount > 0, "amount=0");
        require(usdr.transferFrom(msg.sender, address(this), amount), "transferFrom failed");
        emit Funded(msg.sender, amount);
    }

    /**
     * 운영자: 특정 월(epoch), 특정 상품(seriesId=tokenId)에 대한 정산 root 등록
     * root가 한번 등록된 후 바꾸지 않는 것을 권장(신뢰/감사).
     * 필요하면 "overrideRoot" 정책을 별도 프로세스로 추가하세요.
     */
    function setRoot(uint256 epoch, uint256 seriesId, bytes32 root) external onlyRole(OPERATOR_ROLE) {
        require(epoch >= 200001, "invalid epoch");
        require(root != bytes32(0), "root=0");
        require(roots[epoch][seriesId] == bytes32(0), "root already set");

        roots[epoch][seriesId] = root;
        emit RootSet(epoch, seriesId, root);
    }

    /**
     * leaf = keccak256(abi.encodePacked(account, amount))
     */
    function claim(
        uint256 epoch,
        uint256 seriesId,
        uint256 amount,
        bytes32[] calldata proof
    ) external nonReentrant whenNotPaused {
        require(!claimed[epoch][seriesId][msg.sender], "already claimed");
        bytes32 root = roots[epoch][seriesId];
        require(root != bytes32(0), "root not set");
        require(amount > 0, "amount=0");

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount));
        require(MerkleProof.verify(proof, root, leaf), "invalid proof");

        claimed[epoch][seriesId][msg.sender] = true;

        require(usdr.transfer(msg.sender, amount), "transfer failed");
        emit Claimed(epoch, seriesId, msg.sender, amount);
    }

    function isClaimed(uint256 epoch, uint256 seriesId, address account) external view returns (bool) {
        return claimed[epoch][seriesId][account];
    }
}
