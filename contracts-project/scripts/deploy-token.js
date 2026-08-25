// Sirf tab chalayen jab aapke paas SHIB side ke liye pehle se koi real token address nahi hai.
// Agar pehle se token hai, to ye script skip karen aur seedha uski address deploy.js/frontend me use karen.
const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying token with account:", deployer.address);

  const NAME = "Zirak Shiba";
  const SYMBOL = "ZSHIB";
  const INITIAL_SUPPLY = 1_000_000_000; // 1 billion, jaisa memecoins me aam hota hai

  const Token = await hre.ethers.getContractFactory("ZirakToken");
  const token = await Token.deploy(NAME, SYMBOL, INITIAL_SUPPLY);
  await token.waitForDeployment();

  console.log("Token deployed:", await token.getAddress());
  console.log("Isse .env me SHIB_TOKEN_ADDRESS me daal dein.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
