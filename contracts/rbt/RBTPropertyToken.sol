// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * RBTPropertyToken
 * - 1 Asset = 1 Contract (e.g., "스타벅스 역삼점")
 * - Series/Tranche = tokenId (e.g., 1호/2호/3호)
 * - KYC whitelist-gated transfer
 * - Revenue distribution (USDR) per tokenId via cumulative-per-share accounting
 */
contract RBTPropertyToken is ERC1155Supply, AccessControl, Pausable, ReentrancyGuard {
    // ========== Roles ==========
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE"); // 운영/정산/분배
    bytes32 public constant ISSUER_ROLE   = keccak256("ISSUER_ROLE");   // 상품 생성/발행

    // ========== Asset Metadata ==========
    string public assetName;     // e.g., "Starbucks Yeoksam Store"
    string public assetSymbol;   // e.g., "RBT-SB-YS"
    string public assetLabel;    // e.g., "스타벅스 역삼점"

    IERC20 public settlementToken; // USDR

    // ========== Compliance ==========
    mapping(address => bool) public whitelisted; // KYC 완료 주소
    mapping(address => bool) public frozen;      // 전송/수령 금지
    mapping(address => bool) public blacklisted; // 영구 차단

    // ========== Series (tokenId) ==========
    struct Series {
        string label;       // "1호"
        uint256 unitPrice;  // 회계/정산 기준 단가 (예: 1,000,000)
        uint256 maxSupply;  // 발행 상한
        bool active;
    }

    uint256 public nextSeriesId;                 // tokenId auto-increment
    mapping(uint256 => Series) public series;    // tokenId => Series

    // ========== Revenue Distribution ==========
    // cumulativeRevenuePerToken[tokenId] scaled by 1e18
    mapping(uint256 => uint256) public cumulativeRevenuePerToken;
    // userRevenueCredited[tokenId][account] scaled by 1e18
    mapping(uint256 => mapping(address => uint256)) public userRevenueCredited;

    event WhitelistUpdated(address indexed account, bool allowed);
    event FrozenUpdated(address indexed account, bool frozen);
    event BlacklistUpdated(address indexed account, bool blacklisted);

    event SeriesCreated(uint256 indexed tokenId, string label, uint256 unitPrice, uint256 maxSupply);
    event SeriesStatusChanged(uint256 indexed tokenId, bool active);

    event Issued(uint256 indexed tokenId, address indexed to, uint256 amount);
    event RevenueDeposited(uint256 indexed tokenId, uint256 amount, uint256 newCumulativePerToken);
    event RevenueClaimed(uint256 indexed tokenId, address indexed account, uint256 amount);

    // ========== Init (for clone) ==========
    bool private _initialized;

    constructor() ERC1155("") {
        // implementation contract: do nothing
    }

    function initialize(
        string calldata _assetName,
        string calldata _assetSymbol,
        string calldata _assetLabel,
        address _settlementToken,
        address admin
    ) external {
        require(!_initialized, "already initialized");
        _initialized = true;

        assetName = _assetName;
        assetSymbol = _assetSymbol;
        assetLabel = _assetLabel;
        settlementToken = IERC20(_settlementToken);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);
        _grantRole(ISSUER_ROLE, admin);

        // 운영 편의상 admin 기본 whitelist
        whitelisted[admin] = true;

        nextSeriesId = 1;
    }

    // ========== Admin / Compliance ==========
    function setWhitelist(address account, bool allowed) external onlyRole(OPERATOR_ROLE) {
        whitelisted[account] = allowed;
        emit WhitelistUpdated(account, allowed);
    }

    function setFrozen(address account, bool _frozen) external onlyRole(OPERATOR_ROLE) {
        frozen[account] = _frozen;
        emit FrozenUpdated(account, _frozen);
    }

    function setBlacklisted(address account, bool _blacklisted) external onlyRole(OPERATOR_ROLE) {
        blacklisted[account] = _blacklisted;
        emit BlacklistUpdated(account, _blacklisted);
    }

    function pause() external onlyRole(OPERATOR_ROLE) { _pause(); }
    function unpause() external onlyRole(OPERATOR_ROLE) { _unpause(); }

    // ========== Series management ==========
    function createSeries(
        string calldata label,      // "1호"
        uint256 unitPrice,          // 1,000,000 (예: 원 단위)
        uint256 maxSupply
    ) external onlyRole(ISSUER_ROLE) returns (uint256 tokenId) {
        require(maxSupply > 0, "maxSupply=0");
        tokenId = nextSeriesId++;
        series[tokenId] = Series({
            label: label,
            unitPrice: unitPrice,
            maxSupply: maxSupply,
            active: true
        });
        emit SeriesCreated(tokenId, label, unitPrice, maxSupply);
    }

    function setSeriesActive(uint256 tokenId, bool active) external onlyRole(OPERATOR_ROLE) {
        require(bytes(series[tokenId].label).length != 0, "series not found");
        series[tokenId].active = active;
        emit SeriesStatusChanged(tokenId, active);
    }

    // ========== Issuance ==========
    function issue(
        uint256 tokenId,
        address to,
        uint256 amount
    ) external onlyRole(ISSUER_ROLE) {
        Series memory s = series[tokenId];
        require(bytes(s.label).length != 0, "series not found");
        require(s.active, "series inactive");
        require(totalSupply(tokenId) + amount <= s.maxSupply, "exceeds maxSupply");
        require(_canReceive(to), "receiver not allowed");

        _mint(to, tokenId, amount, "");
        emit Issued(tokenId, to, amount);
    }

    // ========== Revenue ==========
    /**
     * depositRevenue(tokenId, amount)
     * - OPERATOR가 USDR를 본 컨트랙트로 전송(approve 필요)
     * - tokenId별 총 공급량 기준으로 cumulativeRevenuePerToken 증가
     */
    function depositRevenue(uint256 tokenId, uint256 amount) external onlyRole(OPERATOR_ROLE) {
        require(amount > 0, "amount=0");
        require(totalSupply(tokenId) > 0, "no supply");
        require(bytes(series[tokenId].label).length != 0, "series not found");

        // pull tokens
        require(settlementToken.transferFrom(msg.sender, address(this), amount), "transferFrom failed");

        uint256 inc = (amount * 1e18) / totalSupply(tokenId);
        cumulativeRevenuePerToken[tokenId] += inc;

        emit RevenueDeposited(tokenId, amount, cumulativeRevenuePerToken[tokenId]);
    }

    function claimable(uint256 tokenId, address account) public view returns (uint256) {
        uint256 bal = balanceOf(account, tokenId);
        if (bal == 0) return 0;

        uint256 cumulative = cumulativeRevenuePerToken[tokenId];
        uint256 credited = userRevenueCredited[tokenId][account];
        if (cumulative <= credited) return 0;

        uint256 delta = cumulative - credited;
        return (bal * delta) / 1e18;
    }

    function claim(uint256 tokenId) external nonReentrant whenNotPaused {
        require(_canAct(msg.sender), "sender not allowed");

        uint256 amount = claimable(tokenId, msg.sender);
        require(amount > 0, "nothing to claim");

        // update credit first
        userRevenueCredited[tokenId][msg.sender] = cumulativeRevenuePerToken[tokenId];

        require(settlementToken.transfer(msg.sender, amount), "transfer failed");
        emit RevenueClaimed(tokenId, msg.sender, amount);
    }

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override(ERC1155Supply) whenNotPaused {
        // Mint
        if (from == address(0)) {
            require(_canReceive(to), "receiver not allowed");
            super._update(from, to, ids, values);
            return;
        }

        // Burn
        if (to == address(0)) {
            require(_canAct(from), "sender not allowed");
            super._update(from, to, ids, values);
            return;
        }

        // Transfer
        require(_canAct(from), "sender not allowed");
        require(_canReceive(to), "receiver not allowed");

        super._update(from, to, ids, values);
    }


    function _canAct(address a) internal view returns (bool) {
        if (blacklisted[a]) return false;
        if (frozen[a]) return false;
        if (!whitelisted[a]) return false;
        return true;
    }

    function _canReceive(address a) internal view returns (bool) {
        // same rules for receive in this model
        return _canAct(a);
    }

    // ========== Metadata ==========
    // 운영 시 tokenId별 URI를 별도 구성하려면 override해서 tokenId 기반 JSON으로 연결 가능
    function uri(uint256) public view override returns (string memory) {
        return ""; // 필요 시 "ipfs://.../{id}.json" 형태로 확장
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

}
