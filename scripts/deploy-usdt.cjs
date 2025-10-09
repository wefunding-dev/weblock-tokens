const { ethers, run } = require("hardhat");

async function main() {
    const name   = process.env.USDT_NAME   || "Tether USD (Test)";
    const symbol = process.env.USDT_SYMBOL || "USDT";
    const initialSupplyHuman = process.env.USDT_INITIAL_SUPPLY || "1000000"; // 6d
    const initialSupply = ethers.parseUnits(initialSupplyHuman, 6);

    const [deployer] = await ethers.getSigners();
    const admin = process.env.USDT_ADMIN || deployer.address;

    const USDT = await ethers.getContractFactory("USDT");
    const usdt = await USDT.deploy(name, symbol, initialSupply, admin);
    await usdt.waitForDeployment();

    const addr = await usdt.getAddress();
    console.log("USDT deployed to:", addr);
    console.log("Admin:", admin);

    if (process.env.SNOWTRACE_API_KEY) {
        try {
            await run("verify:verify", {
                address: addr,
                constructorArguments: [name, symbol, initialSupply, admin],
            });
            console.log("USDT verified!");
        } catch (e) { console.log("USDT verify failed:", e.message || e); }
    }
}
main().catch((e) => { console.error(e); process.exitCode = 1; });
