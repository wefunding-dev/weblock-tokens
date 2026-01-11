// contracts/rbt/RBTAssetFactory.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

interface IRBTPropertyToken {
    function initialize(
        string calldata assetName,
        string calldata assetSymbol,
        string calldata assetLabel,
        address settlementToken,
        address admin
    ) external;
}

contract RBTAssetFactory is AccessControl {
    using Clones for address;

    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");

    address public immutable implementation;
    address[] public allAssets;

    event AssetCreated(address indexed asset, string assetName, string assetLabel, address settlementToken);

    constructor(address _implementation, address admin) {
        implementation = _implementation;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CREATOR_ROLE, admin);
    }

    function createAsset(
        string calldata assetName,
        string calldata assetSymbol,
        string calldata assetLabel,
        address settlementToken,
        address admin
    ) external onlyRole(CREATOR_ROLE) returns (address asset) {
        asset = implementation.clone();
        IRBTPropertyToken(asset).initialize(assetName, assetSymbol, assetLabel, settlementToken, admin);
        allAssets.push(asset);
        emit AssetCreated(asset, assetName, assetLabel, settlementToken);
    }

    function assetsLength() external view returns (uint256) {
        return allAssets.length;
    }
}
