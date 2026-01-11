// scripts/08_setup_sale_and_buy.cjs
const { ethers } = require("hardhat");

/**
 * Env required:
 * - USDR=0x...
 * - RBT_ASSET=0x...
 * - SALE_ROUTER=0x...
 * - TREASURY=0x... (optional, default: deployer)
 * - OFFERING_ID=1 (optional)
 * - SERIES_ID=1 (optional)
 * - PRICE_USDR=100 (optional, human)
 * - REMAINING_UNITS=0 (optional, 0 means unlimited)
 * - BUYER=0x... (optional; if not set, uses signer[1])
 * - BUY_UNITS=10 (optional)
 */
async function main() {
    const usdrAddr = process.env.USDR;
    const assetAddr = process.env.RBT_ASSET;
    const saleRouterAddr = process.env.SALE_ROUTER;
    if (!usdrAddr || !assetAddr || !saleRouterAddr) {
        throw new Error("Missing USDR, RBT_ASSET or SALE_ROUTER in env");
    }

    const [deployer, defaultBuyer] = await ethers.getSigners();
    const buyerAddr = process.env.BUYER || defaultBuyer.address;
    const treasury = process.env.TREASURY || deployer.address;

    const offeringId = BigInt(process.env.OFFERING_ID || "1");
    const seriesId = BigInt(process.env.SERIES_ID || "1");
    const remainingUnits = BigInt(process.env.REMAINING_UNITS || "0");
    const buyUnits = BigInt(process.env.BUY_UNITS || "10");

    const priceHuman = process.env.PRICE_USDR || "100";
    const unitPrice = ethers.parseUnits(priceHuman, 18);

    const usdr = await ethers.getContractAt("USDRToken", usdrAddr, deployer);
    const rbt = await ethers.getContractAt("RBTPropertyToken", assetAddr, deployer);
    const sale = await ethers.getContractAt("RBTPrimarySaleRouter", saleRouterAddr, deployer);

    const ISSUER_ROLE = await rbt.ISSUER_ROLE();
    const has = await rbt.hasRole(ISSUER_ROLE, saleRouterAddr);
    if (!has) {
        await (await rbt.grantRole(ISSUER_ROLE, saleRouterAddr)).wait();
    }

    if (!(await rbt.whitelisted(buyerAddr))) {
        await (await rbt.setWhitelist(buyerAddr, true)).wait();
    }

    await (await sale.upsertOffering(
        offeringId, assetAddr, seriesId, unitPrice, remainingUnits, 0, 0, treasury, true
    )).wait();

    const mintAmount = unitPrice * buyUnits;
    await (await usdr.mint(buyerAddr, mintAmount)).wait();

    const buyerSigner =
        buyerAddr.toLowerCase() === defaultBuyer.address.toLowerCase()
            ? defaultBuyer
            : await ethers.getImpersonatedSigner(buyerAddr);

    const usdrBuyer = await ethers.getContractAt("USDRToken", usdrAddr, buyerSigner);
    const saleBuyer = await ethers.getContractAt("RBTPrimarySaleRouter", saleRouterAddr, buyerSigner);

    await (await usdrBuyer.approve(saleRouterAddr, mintAmount)).wait();
    await (await saleBuyer.buy(offeringId, buyUnits, mintAmount)).wait();

    const bal = await rbt.balanceOf(buyerAddr, seriesId);
    console.log("Buyer RBT balance:", bal.toString());
}

main().catch((e) => {
    console.error(e);
    process.exitCode = 1;
});
