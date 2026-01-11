// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IRBTPropertyTokenSale {
    function issue(uint256 tokenId, address to, uint256 amount) external;
    function settlementToken() external view returns (address);
    function whitelisted(address account) external view returns (bool);
}

contract RBTPrimarySaleRouter is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant SALE_MANAGER_ROLE = keccak256("SALE_MANAGER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    IERC20 public immutable usdr;

    struct Offering {
        address asset;          // RBTPropertyToken(clone) address
        uint256 seriesId;       // tokenId
        uint256 unitPrice;      // price per unit in USDR wei
        uint256 remainingUnits; // 0 means unlimited
        uint64 startAt;         // 0 means now
        uint64 endAt;           // 0 means no end
        address treasury;       // USDR receiver
        bool enabled;
    }

    mapping(uint256 => Offering) public offerings;

    event OfferingUpserted(
        uint256 indexed offeringId,
        address indexed asset,
        uint256 indexed seriesId,
        uint256 unitPrice,
        uint256 remainingUnits,
        uint64 startAt,
        uint64 endAt,
        address treasury,
        bool enabled
    );

    event Purchased(
        uint256 indexed offeringId,
        address indexed buyer,
        address indexed asset,
        uint256 seriesId,
        uint256 units,
        uint256 cost,
        address treasury
    );

    error InvalidAddress();
    error InvalidPrice();
    error NotEnabled();
    error NotInSaleTime();
    error InvalidUnits();
    error InsufficientRemaining();
    error SettlementTokenMismatch();
    error BuyerNotWhitelisted();
    error CostExceeded(uint256 cost, uint256 maxCost);

    constructor(address usdrToken, address admin) {
        if (usdrToken == address(0) || admin == address(0)) revert InvalidAddress();
        usdr = IERC20(usdrToken);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(SALE_MANAGER_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    function pause() external onlyRole(PAUSER_ROLE) { _pause(); }
    function unpause() external onlyRole(PAUSER_ROLE) { _unpause(); }

    function upsertOffering(
        uint256 offeringId,
        address asset,
        uint256 seriesId,
        uint256 unitPrice,
        uint256 remainingUnits,
        uint64 startAt,
        uint64 endAt,
        address treasury,
        bool enabled
    ) external onlyRole(SALE_MANAGER_ROLE) {
        if (asset == address(0) || treasury == address(0)) revert InvalidAddress();
        if (unitPrice == 0) revert InvalidPrice();
        if (endAt != 0 && endAt < startAt) revert NotInSaleTime();

        if (IRBTPropertyTokenSale(asset).settlementToken() != address(usdr)) {
            revert SettlementTokenMismatch();
        }

        offerings[offeringId] = Offering({
            asset: asset,
            seriesId: seriesId,
            unitPrice: unitPrice,
            remainingUnits: remainingUnits,
            startAt: startAt,
            endAt: endAt,
            treasury: treasury,
            enabled: enabled
        });

        emit OfferingUpserted(
            offeringId, asset, seriesId, unitPrice, remainingUnits, startAt, endAt, treasury, enabled
        );
    }

    function buy(uint256 offeringId, uint256 units, uint256 maxCost)
    external
    nonReentrant
    whenNotPaused
    {
        if (units == 0) revert InvalidUnits();

        Offering storage off = offerings[offeringId];
        if (!off.enabled) revert NotEnabled();

        uint64 nowTs = uint64(block.timestamp);
        if (off.startAt != 0 && nowTs < off.startAt) revert NotInSaleTime();
        if (off.endAt != 0 && nowTs > off.endAt) revert NotInSaleTime();

        if (off.remainingUnits != 0) {
            if (off.remainingUnits < units) revert InsufficientRemaining();
            off.remainingUnits -= units;
        }

        if (!IRBTPropertyTokenSale(off.asset).whitelisted(msg.sender)) {
            revert BuyerNotWhitelisted();
        }

        uint256 cost = units * off.unitPrice;
        if (cost > maxCost) revert CostExceeded(cost, maxCost);

        // 1) USDR 결제 -> treasury
        usdr.safeTransferFrom(msg.sender, off.treasury, cost);

        // 2) RBT 지급 (issue 호출)
        IRBTPropertyTokenSale(off.asset).issue(off.seriesId, msg.sender, units);

        emit Purchased(offeringId, msg.sender, off.asset, off.seriesId, units, cost, off.treasury);
    }

    function rescueERC20(address token, address to, uint256 amount)
    external
    onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (token == address(0) || to == address(0)) revert InvalidAddress();
        IERC20(token).safeTransfer(to, amount);
    }
}
