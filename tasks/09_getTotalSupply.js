task("get-token-supply", "Proves that MockUSDC has been deployed on testnet")
  .addParam("protocolAddress", "Contract address for the protocol token")
  .setAction(async (taskArgs, hre) => {
    if (network.name != "fuji" && network.name != "sepolia") {
      throw Error("This command is intended to be used with either Fuji or Sepolia.")
    }

    const protocolContractFactory = await ethers.getContractFactory("DefiProtocol")
    const protocolContract = await protocolContractFactory.attach(taskArgs.protocolAddress)

    const tokenContractFactory = await ethers.getContractFactory("MockUSDC")
    const tokenContract = await tokenContractFactory.attach(await protocolContract.usdcToken())

    console.log(`MockUSDC token supply is ${await tokenContract.totalSupply()}`)
  })
