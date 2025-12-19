const { ethers, upgrades } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deployer:", deployer.address);
    console.log("Balance :", (await ethers.provider.getBalance(deployer.address)).toString());

    // 1) USDR (UUPS Proxy)
    const USDR = await ethers.getContractFactory("USDRToken");
    const usdr = await upgrades.deployProxy(
        USDR,
        [deployer.address, "ipfs://USDR_DISCLOSURES_URI"],
        { kind: "uups" }
    );
    await usdr.waitForDeployment();
    const usdrAddr = await usdr.getAddress();
    console.log("USDR (proxy) :", usdrAddr);
    console.log("USDR (impl)  :", await upgrades.erc1967.getImplementationAddress(usdrAddr));

    // 2) RBTPropertyToken implementation (for clones)
    const RBTImplF = await ethers.getContractFactory("RBTPropertyToken");
    const rbtImpl = await RBTImplF.deploy();
    await rbtImpl.waitForDeployment();
    const rbtImplAddr = await rbtImpl.getAddress();
    console.log("RBT impl     :", rbtImplAddr);

    // 3) Factory
    const FactoryF = await ethers.getContractFactory("RBTAssetFactory");
    const factory = await FactoryF.deploy(rbtImplAddr);
    await factory.waitForDeployment();
    const factoryAddr = await factory.getAddress();
    console.log("RBT factory  :", factoryAddr);

    // 4) Revenue Vault
    const VaultF = await ethers.getContractFactory("RBTMonthlyRevenueVault");
    const vault = await VaultF.deploy(usdrAddr, deployer.address);
    await vault.waitForDeployment();
    const vaultAddr = await vault.getAddress();
    console.log("Vault        :", vaultAddr);

    // 5) WFT (UUPS Proxy)
    const WFT = await ethers.getContractFactory("WFTToken");
    const wft = await upgrades.deployProxy(
        WFT,
        [deployer.address, "ipfs://WFT_TERMS_URI"],
        { kind: "uups" }
    );
    await wft.waitForDeployment();
    const wftAddr = await wft.getAddress();
    console.log("WFT (proxy)  :", wftAddr);
    console.log("WFT (impl)   :", await upgrades.erc1967.getImplementationAddress(wftAddr));

    // 6) WFTStaking (rewardToken = USDR)
    const rewardToken = usdrAddr;
    const StakingF = await ethers.getContractFactory("WFTStaking");
    const staking = await StakingF.deploy(wftAddr, deployer.address, rewardToken);
    await staking.waitForDeployment();
    const stakingAddr = await staking.getAddress();
    console.log("Staking      :", stakingAddr);

    console.log("\nDONE");
    console.log(JSON.stringify({
        deployer: deployer.address,
        usdr: usdrAddr,
        usdrImpl: await upgrades.erc1967.getImplementationAddress(usdrAddr),
        rbtImpl: rbtImplAddr,
        rbtFactory: factoryAddr,
        revenueVault: vaultAddr,
        wft: wftAddr,
        wftImpl: await upgrades.erc1967.getImplementationAddress(wftAddr),
        wftStaking: stakingAddr,
        rewardToken
    }, null, 2));
}

main().catch((e) => {
    console.error(e);
    process.exitCode = 1;
});
