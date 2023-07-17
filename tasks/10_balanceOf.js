task("balance-of", "gets the balance of a ERC20 token holder")
  .addParam("account", "the EOA to check")
  .addParam("token", "ERC20 token contract address")
  .setAction(async (taskArgs, hre) => {
    if (network.name === "hardhat") {
      throw Error(
        'This command cannot be used on a local development chain.  Specify a valid network or simulate an Functions request locally with "npx hardhat functions-simulate".'
      )
    }

    const tokenContract = await ethers.getContractAt("@chainlink/contracts/src/v0.4/interfaces/ERC20.sol:ERC20", taskArgs.token)
    console.log(`Balance of EOA '${taskArgs.account}':  ${await tokenContract.balanceOf(taskArgs.account)}`)
  })