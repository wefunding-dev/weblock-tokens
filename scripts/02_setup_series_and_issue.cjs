const { ethers } = require("hardhat");

async function main() {
    const asset = process.env.RBT_ASSET; // 01 실행 결과 asset 주소를 넣으세요
    if (!asset) throw new Error("Missing RBT_ASSET in env");

    // 예시 투자자 주소들
    const investors = (process.env.INVESTORS || "").split(",").map(s => s.trim()).filter(Boolean);
    if (investors.length === 0) throw new Error("Set INVESTORS=0x...,0x... in env");

    const [operator] = await ethers.getSigners();
    const rbt = await ethers.getContractAt("RBTPropertyToken", asset);

    // 1) whitelist
    for (const addr of investors) {
        const tx = await rbt.setWhitelist(addr, true);
        await tx.wait();
        console.log("whitelisted:", addr);
    }

    // 2) 시리즈 생성: 1호/2호/3호 (예: 각 2,000개 / 단가 1,000,000)
    const unitPrice = 1_000_000;
    const maxSupply = 2000;

    const tx1 = await rbt.createSeries("1호", unitPrice, maxSupply); await tx1.wait();
    const tx2 = await rbt.createSeries("2호", unitPrice, maxSupply); await tx2.wait();
    const tx3 = await rbt.createSeries("3호", unitPrice, maxSupply); await tx3.wait();

    console.log("series created. (tokenId starts from 1)");

    // 3) 발행(예시): 1호에 investors[0] 10개, investors[1] 20개
    const issue1 = await rbt.issue(1, investors[0], 10); await issue1.wait();
    if (investors[1]) { const issue2 = await rbt.issue(1, investors[1], 20); await issue2.wait(); }

    console.log("issued seriesId=1");
    console.log("done.");
}

main().catch((e) => {
    console.error(e);
    process.exitCode = 1;
});
