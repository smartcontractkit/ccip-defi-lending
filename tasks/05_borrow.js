task("borrow", "borrows mock USDC against the deposit")
  .addParam("protocol", "address of Protocol.sol")
  .addParam("messageId", "the messageId that correlates to the token transfer tx")
  .setAction(async (taskArgs, hre) => {
    if (network.name === "hardhat") {
      throw Error("This command cannot be used on a local development chain.  Specify a valid network.")
    }
    if (network.name !== "sepolia") {
      throw Error("This task must be used on Sepolia.")
    }

    const [borrower] = await ethers.getSigners()

    const protocolFactory = await ethers.getContractFactory("Protocol")
    const protocolContract = await protocolFactory.attach(taskArgs.protocol)

    const [messageId, sourceChainSelector, senderContract, depositorEOA, transferredToken, amountTransferred] =
      await protocolContract.getLastReceivedMessageDetails()

    if (depositorEOA !== borrower.address) {
      throw Error(`depositor '${depositorEOA}' is not the same as borrower '${borrower.address}'`)
    }

    const usdcTokenAddress = await protocolContract.usdcToken()

    const mockUsdcFactory = await ethers.getContractFactory("MockUSDC")
    const mockUsdcToken = await mockUsdcFactory.attach(usdcTokenAddress)

    const borrowerBalance = await protocolContract.borrowings(depositorEOA, usdcTokenAddress)

    const borrowTx = await protocolContract.borrowUSDC(taskArgs.messageId)
    await borrowTx.wait()
    console.log(`Borrow Tx: ${borrowTx.hash}`)

    const borrowings = await protocolContract.borrowings(depositorEOA, usdcTokenAddress)
    const borrowerTokenBal = await mockUsdcToken.balanceOf(borrower.address)

    const totalSupply = await mockUsdcToken.totalSupply()
    console.log(`
    Borrowing recorded on Protocol: '${borrowings}'.  
    Starting Borrower Balance: ${borrowerBalance}.
    Updated Borrower Balance: '${borrowerTokenBal}' 
    MockUSDC total supply: '${totalSupply}'`)
  })
