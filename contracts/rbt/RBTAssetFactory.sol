// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/Clones.sol";

interface IRBTPropertyToken {
    function initialize(
        string calldata assetName,
        string calldata assetSymbol,
        string calldata assetLabel,
        address settlementToken,
        address admin
    ) external;
}

contract RBTAssetFactory {
    using Clones for address;

    address public immutable implementation;
    address[] public allAssets;

    event AssetCreated(address indexed asset, string assetName, string assetLabel, address settlementToken);

    constructor(address _implementation) {
        implementation = _implementation;
    }

    function createAsset(
        string calldata assetName,      // "Starbucks Yeoksam Store"
        string calldata assetSymbol,    // "RBT-SB-YS"
        string calldata assetLabel,     // "스타벅스 역삼점"
        address settlementToken,        // USDR
        address admin
    ) external returns (address asset) {
        asset = implementation.clone();
        IRBTPropertyToken(asset).initialize(assetName, assetSymbol, assetLabel, settlementToken, admin);
        allAssets.push(asset);

        emit AssetCreated(asset, assetName, assetLabel, settlementToken);
    }

    function assetsLength() external view returns (uint256) {
        return allAssets.length;
    }
}
