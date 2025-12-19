const { ethers, run } = require("hardhat");

async function main() {
    const name   = process.env.USDR_NAME   || "USDR";
    const symbol = process.env.USDR_SYMBOL || "USDR";
    const initialSupplyHuman = process.env.USDR_INITIAL_SUPPLY || "1000000"; // 6d
    const initialSupply = ethers.parseUnits(initialSupplyHuman, 6);

    const [deployer] = await ethers.getSigners();
    const admin = process.env.USDR_ADMIN || deployer.address;

    const USDR = await ethers.getContractFactory("USDR");
    const usdr = await USDR.deploy(name, symbol, initialSupply, admin);
    await usdr.waitForDeployment();

    const addr = await usdr.getAddress();
    console.log("USDR deployed to:", addr);
    console.log("Admin:", admin);

    if (process.env.SNOWTRACE_API_KEY) {
        try {
            await run("verify:verify", {
                address: addr,
                constructorArguments: [name, symbol, initialSupply, admin],
            });
            console.log("USDR verified!");
        } catch (e) { console.log("USDR verify failed:", e.message || e); }
    }
}
main().catch((e) => { console.error(e); process.exitCode = 1; });
