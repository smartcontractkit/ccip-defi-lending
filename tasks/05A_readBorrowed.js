const { networks } = require("../networks")

task("read-borrowed", "reads the borrowing balance for the borrower")
  .addParam("protocol", "address of Protocol.sol")
  .setAction(async (taskArgs, hre) => {
    if (network.name === "hardhat") {
      throw Error("This command cannot be used on a local development chain.  Specify a valid network.")
    }
    if (network.name !== "sepolia") {
      throw Error("This task must be used on Sepolia.")
    }

    const [deployer] = await ethers.getSigners()

    const protocolFactory = await ethers.getContractFactory("Protocol")
    const protocolContract = await protocolFactory.attach(taskArgs.protocol)

    const [messageId, sourceChainSelector, senderContract, depositorEOA, transferredToken, amountTransferred] =
      await protocolContract.getLastReceivedMessageDetails()

    // Checking state on Protocol
    const deposit = await protocolContract.deposits(deployer.address, transferredToken)

    const borrowedToken = await protocolContract.usdcToken()
    const borrowings = await protocolContract.borrowings(deployer.address, borrowedToken)

    console.log(`Borrowing recorded on Protocol: 
    Depositor: ${deployer.address}, 
    Deposited Amount: ${deposit},
    Borrowing: ${borrowings}
    `)
  })
