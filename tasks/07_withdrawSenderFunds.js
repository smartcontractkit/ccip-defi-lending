const { networks } = require("../networks")

task("withdraw-sender-funds", "withdraw ETH and LINK from Sender.sol")
  .addParam("address", "Sender.sol contract address")
  .setAction(async (taskArgs, hre) => {
    if (network.name === "hardhat") {
      throw Error('This command cannot be used on a local development chain.  Specify a valid network ".')
    }

    if (network.name !== "fuji") {
      throw Error("This task must be used on Fuji.")
    }

    const bnmToken = networks[network.name].bnmToken
    if (!bnmToken) {
      throw Error("Missing BNM Token Address")
    }

    const senderFactory = await ethers.getContractFactory("Sender")
    const senderContract = await senderFactory.attach(taskArgs.address)

    // Withdraw Native token, if any
    const withdrawEthTx = await senderContract.withdraw({ gasLimit: 500_000 })
    await withdrawEthTx.wait(2)

    // Withdraw BnM
    const withdrawBnMTokenTx = await senderContract.withdrawToken(bnmToken, {
      gasLimit: 500_000,
    })
    await withdrawBnMTokenTx.wait(2)

    // Withdraw LINK
    const withdrawLinkTx = await senderContract.withdrawToken(networks[network.name].linkToken, {
      gasLimit: 500_000,
    })
    await withdrawLinkTx.wait(2)

    // Fetch updated balances to confirm.
    const bnmTokenContract = await ethers.getContractAt(
      "ERC20",
      bnmToken
    )

    const linkTokenContract = await ethers.getContractAt("LinkTokenInterface", networks[network.name].linkToken)

    console.log(`
    Sender Contract's Link Token Balance  : ${await linkTokenContract.balanceOf(taskArgs.address)}
    Sender Contract's BnM Token Balance : ${await bnmTokenContract.balanceOf(taskArgs.address)}
    Sender Contract's native balance : ${await ethers.provider.getBalance(taskArgs.address)}˝)
    `)
  })
