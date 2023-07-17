task("get-token-supply", "Proves that MockUSDC has been deployed on testnet")
  .addParam("protocolAddress", "Contract address for the protocol token")
  .setAction(async (taskArgs, hre) => {
    if (network.name === "hardhat") {
      throw Error(
        'This command cannot be used on a local development chain.  Specify a valid network or simulate an Functions request locally with "npx hardhat functions-simulate".'
      )
    }

    const protocolContractFactory = await ethers.getContractFactory("DefiProtocol")
    const protocolContract = await protocolContractFactory.attach(taskArgs.protocolAddress)

    const tokenContractFactory = await ethers.getContractFactory("MockUSDC")
    const tokenContract = await tokenContractFactory.attach(await protocolContract.usdcToken())

    console.log(`MockUSDC token supply is ${await tokenContract.totalSupply()}`)
  })
