const fs = require("fs");
const path = require("path");
const keccak256 = require("keccak256");
const { MerkleTree } = require("merkletreejs");
const { ethers } = require("ethers");

function leaf(account, amountWeiStr) {
    return keccak256(ethers.solidityPacked(["address", "uint256"], [account, BigInt(amountWeiStr)]));
}

async function main() {
    const input = process.env.INPUT;
    if (!input) throw new Error("Set INPUT=data/epoch_202601_series1.json");

    const rows = JSON.parse(fs.readFileSync(path.resolve(input), "utf8"));

    const leaves = rows.map(r => leaf(r.account, r.amount));
    const tree = new MerkleTree(leaves, keccak256, { sortPairs: true });

    const root = tree.getHexRoot();
    console.log("root:", root);

    // proofs 저장
    const proofs = {};
    for (const r of rows) {
        const l = leaf(r.account, r.amount);
        proofs[r.account.toLowerCase()] = {
            amount: r.amount,
            proof: tree.getHexProof(l),
        };
    }

    const outPath = input.replace(".json", ".proofs.json");
    fs.writeFileSync(outPath, JSON.stringify({ root, proofs }, null, 2));
    console.log("proofs saved:", outPath);
}

main().catch((e) => {
    console.error(e);
    process.exit(1);
});
