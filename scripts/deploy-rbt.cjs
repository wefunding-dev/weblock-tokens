const { ethers, run } = require("hardhat");

async function main() {
    const name   = process.env.RBT_NAME   || "Real Estate Backed Token";
    const symbol = process.env.RBT_SYMBOL || "RBT";
    const initialSupplyHuman = process.env.RBT_INITIAL_SUPPLY || "100000000"; // 18d
    const initialSupply = ethers.parseUnits(initialSupplyHuman, 18);

    const [deployer] = await ethers.getSigners();
    const admin = process.env.RBT_ADMIN || deployer.address;

    const RBT = await ethers.getContractFactory("RBT");
    const rbt = await RBT.deploy(name, symbol, initialSupply, admin);
    await rbt.waitForDeployment();

    const addr = await rbt.getAddress();
    console.log("RBT deployed to:", addr);
    console.log("Admin:", admin);

    if (process.env.SNOWTRACE_API_KEY) {
        try {
            await run("verify:verify", {
                address: addr,
                constructorArguments: [name, symbol, initialSupply, admin],
            });
            console.log("RBT verified!");
        } catch (e) { console.log("RBT verify failed:", e.message || e); }
    }
}
main().catch((e) => { console.error(e); process.exitCode = 1; });
