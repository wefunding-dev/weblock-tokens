// scripts/10_create_asset_series_offering.cjs
const { ethers } = require("hardhat");

function requireEnv(name) {
    const v = process.env[name];
    if (!v) throw new Error(`Missing env: ${name}`);
    return v;
}

async function main() {
    const [deployer] = await ethers.getSigners();

    // ====== Your deployed addresses (Fuji) ======
    const USDR_ADDR = process.env.USDR_ADDR || "0xd5e04A32f7F8E35C8F7FE6F66793bd84453A689D";
    const FACTORY_ADDR = process.env.FACTORY_ADDR || "0xA6D728EE44D2887E78E1E71798D9FBB33bc66773";
    const SALE_ROUTER_ADDR = process.env.SALE_ROUTER_ADDR || "0x0121Cb6D579AE40CCDD686470e5d74cd1b105C77";

    // ====== Manual inputs you must decide ======
    // offeringId == productId policy
    const OFFERING_ID = BigInt(requireEnv("OFFERING_ID")); // 예: "1"

    // Treasury: define receiver wallet address for USDR proceeds
    // 빠른 테스트: deployer.address 사용 가능
    const TREASURY = process.env.TREASURY || deployer.address;

    // Asset meta
    const ASSET_NAME = process.env.ASSET_NAME || "WeBlock Asset #1";
    const ASSET_SYMBOL = process.env.ASSET_SYMBOL || "RBT-A1";
    const ASSET_LABEL = process.env.ASSET_LABEL || "WeBlock Property #1";

    // Series meta
    const SERIES_LABEL = process.env.SERIES_LABEL || "Series #1";

    // unitPrice: 1 USDR
    // 주의: USDR decimals가 18이라는 가정입니다.
    // 만약 USDR이 6 decimals라면 parseUnits("1", 6)으로 바꾸세요.
    const UNIT_PRICE_WEI = ethers.parseUnits("1", 18);

    // maxSupply: 10000 units
    const MAX_SUPPLY = 10000n;

    // offering remainingUnits: 보통 maxSupply와 동일
    const REMAINING_UNITS = 10000n;

    // start/end: 0이면 즉시 시작/무기한
    const START_AT = 0; // unix timestamp
    const END_AT = 0;   // unix timestamp

    console.log("Deployer  :", deployer.address);
    console.log("Treasury  :", TREASURY);
    console.log("USDR      :", USDR_ADDR);
    console.log("Factory   :", FACTORY_ADDR);
    console.log("SaleRouter:", SALE_ROUTER_ADDR);
    console.log("OfferingId:", OFFERING_ID.toString());

    // ====== 1) Create Asset (RBTPropertyToken clone) ======
    const factory = await ethers.getContractAt("RBTAssetFactory", FACTORY_ADDR);

    // createAsset(...) 시그니처는 당신의 컨트랙트 구현과 동일해야 합니다.
    // 만약 함수명이 다르면 factory ABI 기준으로 맞춰야 합니다.
    const tx1 = await factory.createAsset(
        ASSET_NAME,
        ASSET_SYMBOL,
        ASSET_LABEL,
        USDR_ADDR,
        deployer.address // admin (운영시 멀티시그 권장)
    );
    const rc1 = await tx1.wait();

    // Parse asset address from event logs
    let assetAddr;
    for (const log of rc1.logs) {
        try {
            const parsed = factory.interface.parseLog(log);
            // 이벤트 args에 asset/address가 있을 가능성이 큼
            if (parsed?.args?.asset) assetAddr = parsed.args.asset;
            if (!assetAddr && parsed?.args?.[0] && String(parsed.args[0]).startsWith("0x")) {
                assetAddr = parsed.args[0];
            }
        } catch {}
    }
    if (!assetAddr) {
        throw new Error("Failed to parse rbtAssetAddress from createAsset() receipt logs. Check factory events.");
    }
    console.log("rbtAssetAddress:", assetAddr);

    // ====== 2) Create Series (tokenId) ======
    const asset = await ethers.getContractAt("RBTPropertyToken", assetAddr);
    const tx2 = await asset.createSeries(SERIES_LABEL, UNIT_PRICE_WEI, MAX_SUPPLY);
    const rc2 = await tx2.wait();

    let seriesId;
    for (const log of rc2.logs) {
        try {
            const parsed = asset.interface.parseLog(log);
            if (parsed?.args?.tokenId !== undefined) seriesId = parsed.args.tokenId;
            if (seriesId === undefined && parsed?.args?.[0] !== undefined) seriesId = parsed.args[0];
        } catch {}
    }
    if (seriesId === undefined) {
        throw new Error("Failed to parse seriesId(tokenId) from createSeries() receipt logs. Check asset events.");
    }
    console.log("seriesId(tokenId):", seriesId.toString());

    // ====== 3) Grant ISSUER_ROLE to SaleRouter ======
    let issuerRole;
    try {
        issuerRole = await asset.ISSUER_ROLE();
    } catch {
        issuerRole = ethers.keccak256(ethers.toUtf8Bytes("ISSUER_ROLE"));
    }

    await (await asset.grantRole(issuerRole, SALE_ROUTER_ADDR)).wait();
    console.log("Granted ISSUER_ROLE to SaleRouter");

    // ====== 4) Register Offering in SaleRouter ======
    const saleRouter = await ethers.getContractAt("RBTPrimarySaleRouter", SALE_ROUTER_ADDR);

    await (await saleRouter.upsertOffering(
        OFFERING_ID,
        assetAddr,
        seriesId,
        UNIT_PRICE_WEI,
        REMAINING_UNITS,
        START_AT,
        END_AT,
        TREASURY,
        true
    )).wait();

    console.log("Offering upserted:", OFFERING_ID.toString());

    console.log(JSON.stringify({
        network: "fuji",
        usdr: USDR_ADDR,
        saleRouter: SALE_ROUTER_ADDR,
        rbtAssetAddress: assetAddr,
        seriesId: seriesId.toString(),
        offeringId: OFFERING_ID.toString(),
        unitPriceWei: UNIT_PRICE_WEI.toString(),
        maxSupply: MAX_SUPPLY.toString(),
        treasury: TREASURY
    }, null, 2));
}

main().catch((e) => {
    console.error(e);
    process.exitCode = 1;
});
