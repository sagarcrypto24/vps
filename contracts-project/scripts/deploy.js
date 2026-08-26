const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying with account:", deployer.address);
  console.log("Account balance:", (await hre.ethers.provider.getBalance(deployer.address)).toString());

  const PANCAKE_ROUTER = process.env.PANCAKE_ROUTER;
  const USDT_ADDRESS = process.env.USDT_ADDRESS;
  const SHIB_TOKEN_ADDRESS = process.env.SHIB_TOKEN_ADDRESS;
  if (!PANCAKE_ROUTER) throw new Error("PANCAKE_ROUTER .env me set nahi hai");
  if (!USDT_ADDRESS) throw new Error("USDT_ADDRESS .env me set nahi hai");
  if (!SHIB_TOKEN_ADDRESS) throw new Error("SHIB_TOKEN_ADDRESS .env me set nahi hai");

  // Sirf ek hi contract — apni liquidity nahi rakhta, PancakeSwap ke router ko forward karta hai
  const ZirakSwap = await hre.ethers.getContractFactory("ZirakSwap");
  const zirakSwap = await ZirakSwap.deploy(PANCAKE_ROUTER, USDT_ADDRESS, SHIB_TOKEN_ADDRESS);
  await zirakSwap.waitForDeployment();

  console.log("\n===============================================");
  console.log("Deployment complete!");
  console.log("ZirakSwap contract:", await zirakSwap.getAddress());
  console.log("PancakeSwap Router:", PANCAKE_ROUTER);
  console.log("USDT:", USDT_ADDRESS);
  console.log("SHIB:", SHIB_TOKEN_ADDRESS);
  console.log("===============================================\n");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});


