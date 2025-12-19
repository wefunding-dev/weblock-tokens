const { ethers } = require("hardhat");

async function main() {
    const factoryAddr = process.env.RBT_FACTORY;
    const usdrAddr = process.env.USDR;
    if (!factoryAddr || !usdrAddr) throw new Error("Missing RBT_FACTORY or USDR in .env");

    const [deployer] = await ethers.getSigners();
    const factory = await ethers.getContractAt("RBTAssetFactory", factoryAddr);

    const tx = await factory.createAsset(
        "Starbucks Yeoksam Store",
        "RBT-SB-YS",
        "스타벅스 역삼점",
        usdrAddr,
        deployer.address
    );

    const rc = await tx.wait();

    // AssetCreated(address asset, string assetName, string assetLabel, address settlementToken)
    const iface = factory.interface;
    let assetAddress = null;

    for (const log of rc.logs) {
        try {
            const parsed = iface.parseLog(log);
            if (parsed && parsed.name === "AssetCreated") {
                assetAddress = parsed.args.asset;
                break;
            }
        } catch (_) {}
    }

    console.log("tx:", tx.hash);
    console.log("asset:", assetAddress);
    if (!assetAddress) {
        console.log("Failed to parse AssetCreated. Check receipt logs manually.");
    }
}

main().catch((e) => {
    console.error(e);
    process.exitCode = 1;
});
