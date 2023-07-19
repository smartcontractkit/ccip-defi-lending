task("balance-of", "gets the balance of a ERC20 token holder")
  .addParam("account", "the EOA to check")
  .addParam("token", "ERC20 token contract address")
  .setAction(async (taskArgs, hre) => {
    if (network.name != "fuji" && network.name != "sepolia") {
      throw Error("This command is intended to be used with either Fuji or Sepolia.")
    }

    const tokenContract = await ethers.getContractAt(
      "@chainlink/contracts/src/v0.4/interfaces/ERC20.sol:ERC20",
      taskArgs.token
    )
    console.log(`Balance of EOA '${taskArgs.account}':  ${await tokenContract.balanceOf(taskArgs.account)}`)
  })
