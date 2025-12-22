const fs = require("fs");
const path = require("path");
const { ethers } = require("hardhat");

async function main() {
    const vaultAddr = process.env.REVENUE_VAULT;
    const epoch = Number(process.env.EPOCH);
    const seriesId = Number(process.env.SERIES_ID || "1");
    const proofsFile = process.env.PROOFS_FILE;

    if (!vaultAddr || !epoch || !proofsFile) throw new Error("Missing REVENUE_VAULT/EPOCH/PROOFS_FILE");

    const [claimer] = await ethers.getSigners();
    const vault = await ethers.getContractAt("RBTMonthlyRevenueVault", vaultAddr, claimer);

    const data = JSON.parse(fs.readFileSync(path.resolve(proofsFile), "utf8"));
    const entry = data.proofs[claimer.address.toLowerCase()];
    if (!entry) throw new Error("No proof for this address in proofs file");

    const amount = BigInt(entry.amount);
    const proof = entry.proof;

    const tx = await vault.claim(epoch, seriesId, amount, proof);
    await tx.wait();

    console.log("claimed:", { epoch, seriesId, claimer: claimer.address, amount: amount.toString(), tx: tx.hash });
}

main().catch((e) => {
    console.error(e);
    process.exitCode = 1;
});
