const { ethers } = require("hardhat");

async function main() {
    const vaultAddr = process.env.REVENUE_VAULT;
    const usdrAddr = process.env.USDR;
    const epoch = Number(process.env.EPOCH);      // 예: 202601
    const seriesId = Number(process.env.SERIES_ID || "1");
    const root = process.env.ROOT;
    const fundAmount = ethers.parseUnits(process.env.FUND_USDR || "1000", 18);

    if (!vaultAddr || !usdrAddr || !epoch || !root) throw new Error("Missing REVENUE_VAULT/USDR/EPOCH/ROOT");

    const [operator] = await ethers.getSigners();
    const vault = await ethers.getContractAt("RBTMonthlyRevenueVault", vaultAddr);
    const usdr = await ethers.getContractAt("USDRToken", usdrAddr);

    await (await usdr.approve(vaultAddr, fundAmount)).wait();
    await (await vault.fund(fundAmount)).wait();
    console.log("funded:", fundAmount.toString());

    await (await vault.setRoot(epoch, seriesId, root)).wait();
    console.log("root set:", { epoch, seriesId, root });
}

main().catch((e) => {
    console.error(e);
    process.exitCode = 1;
});
