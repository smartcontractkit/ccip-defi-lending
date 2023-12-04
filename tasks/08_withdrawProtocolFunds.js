const { networks } = require("../networks")

task("withdraw-protocol-funds", "withdraw ETH and LINK from Protocol.sol")
  .addParam("address", "Sender.sol contract address")
  .setAction(async (taskArgs, hre) => {
    if (network.name === "hardhat") {
      throw Error('This command cannot be used on a local development chain.  Specify a valid network ".')
    }
    if (network.name !== "sepolia") {
      throw Error("This task must be used on Sepolia.")
    }

    const bnmToken = networks[network.name].bnmToken
    if (!bnmToken) {
      throw Error("Missing BNM Token Address")
    }

    const protocolFactory = await ethers.getContractFactory("Protocol")
    const protocolContract = await protocolFactory.attach(taskArgs.address)

    // Withdraw BnM
    const withdrawBnMTokenTx = await protocolContract.withdrawToken(bnmToken, {
      gasLimit: 500_000,
    })
    await withdrawBnMTokenTx.wait()

    // Withdraw LINK
    const withdrawLinkTx = await protocolContract.withdrawToken(networks[network.name].linkToken, {
      gasLimit: 500_000,
    })
    await withdrawLinkTx.wait()

    // Withdraw Contract Eth, if any
    const withdrawEthTx = await protocolContract.withdraw({ gasLimit: 500_000 })
    await withdrawEthTx.wait()

    // Fetch updated balances to confirm.
    const bnmTokenContract = await ethers.getContractAt(
      "ERC20",
      bnmToken
    )

    const linkTokenContract = await ethers.getContractAt("LinkTokenInterface", networks[network.name].linkToken)

    console.log(`
   Protocol Contract's Link Token Balance  : ${await linkTokenContract.balanceOf(taskArgs.address)}
   Protocol Contract's BnM Token Balance : ${await bnmTokenContract.balanceOf(taskArgs.address)}
   Protocol Contract's Eth balance : ${await ethers.provider.getBalance(networks[network.name].linkToken)})
   `)
  })
