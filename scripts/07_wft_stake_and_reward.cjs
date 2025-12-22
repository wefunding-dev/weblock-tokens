const { ethers } = require("hardhat");

async function main() {
    const wftAddr = process.env.WFT;
    const stakingAddr = process.env.WFT_STAKING;
    const usdrAddr = process.env.USDR;
    if (!wftAddr || !stakingAddr || !usdrAddr) throw new Error("Missing WFT/WFT_STAKING/USDR");

    const [operator, user] = await ethers.getSigners();
    const wft = await ethers.getContractAt("WFTToken", wftAddr);
    const usdr = await ethers.getContractAt("USDRToken", usdrAddr);

    const stakingAsOp = await ethers.getContractAt("WFTStaking", stakingAddr, operator);
    const stakingAsUser = await ethers.getContractAt("WFTStaking", stakingAddr, user);

    // 테스트용: user에게 WFT 민팅(운영자만 가능)
    const mintAmt = ethers.parseUnits("1000", 18);
    await (await wft.mint(user.address, mintAmt)).wait();

    // user stake
    const stakeAmt = ethers.parseUnits("100", 18);
    await (await wft.connect(user).approve(stakingAddr, stakeAmt)).wait();
    await (await stakingAsUser.stake(stakeAmt)).wait();
    console.log("staked:", stakeAmt.toString());

    // 운영자가 보상(USDR) 적립
    const rewardAmt = ethers.parseUnits("50", 18);
    await (await usdr.approve(stakingAddr, rewardAmt)).wait();
    await (await stakingAsOp.depositReward(rewardAmt)).wait();
    console.log("reward deposited:", rewardAmt.toString());

    // user claim
    await (await stakingAsUser.claim()).wait();
    console.log("claimed reward");

    // user unstake
    await (await stakingAsUser.unstake(stakeAmt)).wait();
    console.log("unstaked");
}

main().catch((e) => {
    console.error(e);
    process.exitCode = 1;
});
