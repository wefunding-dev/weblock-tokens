// CommonJS (.cjs)
// 사용법 예)
// TOKEN=0xTokenAddr TO=0xRecipient AMOUNT=123.45 hardhat run --network fuji scripts/transfer-erc20.cjs
const { ethers } = require("hardhat");

const ERC20_ABI = [
    "function name() view returns (string)",
    "function symbol() view returns (string)",
    "function decimals() view returns (uint8)",
    "function balanceOf(address) view returns (uint256)",
    "function transfer(address to, uint256 amount) returns (bool)"
];

async function main() {
    const tokenAddr = process.env.TOKEN;
    const to = process.env.TO;
    const amountHuman = process.env.AMOUNT; // 문자열: "123.45" 등

    if (!tokenAddr || !to || !amountHuman) {
        throw new Error('환경변수 필요: TOKEN, TO, AMOUNT. 예) TOKEN=0x... TO=0x... AMOUNT=100');
    }

    const [signer] = await ethers.getSigners();
    const token = new ethers.Contract(tokenAddr, ERC20_ABI, signer);

    const [name, symbol, decimals] = await Promise.all([
        token.name(), token.symbol(), token.decimals()
    ]);

    const amount = ethers.parseUnits(amountHuman, decimals);

    const [fromBalBefore, toBalBefore] = await Promise.all([
        token.balanceOf(signer.address),
        token.balanceOf(to),
    ]);

    console.log(`Token: ${name} (${symbol}), decimals=${decimals}`);
    console.log(`From: ${signer.address}`);
    console.log(`To  : ${to}`);
    console.log(`Amount: ${amountHuman} ${symbol}`);

    const tx = await token.transfer(to, amount);
    console.log("Tx sent:", tx.hash);
    const rcpt = await tx.wait();
    console.log("Confirmed in block:", rcpt.blockNumber);

    const [fromBalAfter, toBalAfter] = await Promise.all([
        token.balanceOf(signer.address),
        token.balanceOf(to),
    ]);

    console.log(`Sender: ${ethers.formatUnits(fromBalBefore, decimals)} -> ${ethers.formatUnits(fromBalAfter, decimals)} ${symbol}`);
    console.log(`Recipient: ${ethers.formatUnits(toBalBefore, decimals)} -> ${ethers.formatUnits(toBalAfter, decimals)} ${symbol}`);
}

main().catch((e) => {
    console.error(e);
    process.exitCode = 1;
});
