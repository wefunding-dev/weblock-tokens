const { ethers } = require("hardhat");

async function main() {
    const asset = process.env.RBT_ASSET;
    const usdrAddr = process.env.USDR;
    if (!asset || !usdrAddr) throw new Error("Missing RBT_ASSET or USDR");

    const [operator, investor] = await ethers.getSigners(); // investor는 로컬 테스트용
    const rbt = await ethers.getContractAt("RBTPropertyToken", asset);
    const usdr = await ethers.getContractAt("USDRToken", usdrAddr);

    // 운영자가 investor에게 USDR를 지급할 수 있게(테스트용) 민팅 권한이 있어야 합니다.
    // 실제 운영에서는 운영자가 보유한 USDR로 진행.
    // (선택) investor에게 미리 USDR 민팅:
    // await (await usdr.mint(investor.address, ethers.parseUnits("1000", 18))).wait();

    // 1) 운영자가 수익금(USDR)을 approve 후 depositRevenue
    const seriesId = Number(process.env.SERIES_ID || "1");
    const amount = ethers.parseUnits(process.env.REVENUE_USDR || "100", 18); // 100 USDR

    await (await usdr.approve(asset, amount)).wait();
    await (await rbt.depositRevenue(seriesId, amount)).wait();

    console.log("deposited revenue to seriesId:", seriesId);

    // 2) (예시) investor가 claim (실제 운영에서는 투자자 지갑에서 호출)
    // 여기서는 동일 signer로 claim 시연하려면 investor가 whitelist + RBT 보유자여야 함.
    const investorRbt = await ethers.getContractAt("RBTPropertyToken", asset, investor);
    const claimTx = await investorRbt.claim(seriesId);
    await claimTx.wait();

    console.log("claimed. tx:", claimTx.hash);
}

main().catch((e) => {
    console.error(e);
    process.exitCode = 1;
});
