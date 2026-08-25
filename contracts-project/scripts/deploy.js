const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying with account:", deployer.address);
  console.log("Account balance:", (await hre.ethers.provider.getBalance(deployer.address)).toString());

  const WBNB_ADDRESS = process.env.WBNB_ADDRESS;
  if (!WBNB_ADDRESS) throw new Error("WBNB_ADDRESS .env me set nahi hai");

  // 1) Factory deploy — feeToSetter = deployer (aap baad me protocol fee on/off kar sakte hain)
  const Factory = await hre.ethers.getContractFactory("ZirakFactory");
  const factory = await Factory.deploy(deployer.address);
  await factory.waitForDeployment();
  console.log("ZirakFactory deployed:", await factory.getAddress());

  // 2) Router deploy — factory + WBNB address lega
  const Router = await hre.ethers.getContractFactory("ZirakRouter");
  const router = await Router.deploy(await factory.getAddress(), WBNB_ADDRESS);
  await router.waitForDeployment();
  console.log("ZirakRouter deployed:", await router.getAddress());

  console.log("\n===============================================");
  console.log("Deployment complete! Ye addresses frontend me daalen:");
  console.log("Factory:", await factory.getAddress());
  console.log("Router: ", await router.getAddress());
  console.log("WBNB:   ", WBNB_ADDRESS);
  console.log("===============================================\n");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
