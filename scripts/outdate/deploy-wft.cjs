// CommonJS 버전 (".cjs")
// ESM import 금지! require 사용
const { ethers, run } = require("hardhat");

async function main() {
    const name = process.env.WFT_NAME || "WeBlock Foundation Token";
    const symbol = process.env.WFT_SYMBOL || "WFT";

    // 10억 개 (18 decimals)
    const initialSupplyHuman = process.env.WFT_INITIAL_SUPPLY || "1000000000";
    const initialSupply = ethers.parseUnits(initialSupplyHuman, 18);

    const [deployer] = await ethers.getSigners();
    const owner = process.env.WFT_OWNER || deployer.address;

    const WFT = await ethers.getContractFactory("WFT");
    const wft = await WFT.deploy(name, symbol, initialSupply, owner);
    await wft.waitForDeployment();

    const addr = await wft.getAddress();
    console.log("WFT deployed to:", addr);
    console.log("Owner:", owner);

    if (process.env.SNOWTRACE_API_KEY) {
        console.log("Verifying on Snowtrace...");
        try {
            await run("verify:verify", {
                address: addr,
                constructorArguments: [name, symbol, initialSupply, owner],
            });
            console.log("Verified!");
        } catch (e) {
            console.log("Verify failed (maybe already verified):", e.message || e);
        }
    }
}

main().catch((err) => {
    console.error(err);
    process.exitCode = 1;
});
