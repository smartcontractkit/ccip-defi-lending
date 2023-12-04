const { networks } = require("../networks")

task("setup-protocol", "deploy Protocol.sol").setAction(async (taskArgs, hre) => {
  if (network.name === "hardhat") {
    throw Error("This command cannot be used on a local development chain.  Specify a valid network.")
  }

  if (network.name !== "sepolia") {
    throw Error("This task is intended to be executed on the Sepolia network.")
  }
  
  const bnmToken = networks[network.name].bnmToken
  if (!bnmToken) {
    throw Error("Missing BNM Token Address")
  }

  const ROUTER = networks[network.name].router
  const LINK = networks[network.name].linkToken
  const LINK_AMOUNT = "0.5"

  console.log("\n__Compiling Contracts__")
  await run("compile")

  console.log(`\nDeploying Protocol.sol to ${network.name}...`)
  const protocolFactory = await ethers.getContractFactory("Protocol")
  const protocolContract = await protocolFactory.deploy(ROUTER, LINK)
  await protocolContract.deployTransaction.wait(1)

  console.log(`\nProtocol contract is deployed to ${network.name} at ${protocolContract.address}`)

  const [deployer] = await ethers.getSigners()

  // Fund with LINK
  console.log(`\nFunding ${protocolContract.address} with ${LINK_AMOUNT} LINK `)
  const linkTokenContract = await ethers.getContractAt("LinkTokenInterface", networks[network.name].linkToken)

  // Transfer LINK tokens to the contract
  const linkTx = await linkTokenContract.transfer(protocolContract.address, ethers.utils.parseEther(LINK_AMOUNT))
  await linkTx.wait(1)

  const juelsBalance = await linkTokenContract.balanceOf(protocolContract.address)
  const linkBalance = ethers.utils.formatEther(juelsBalance.toString())
  console.log(`\nFunded ${protocolContract.address} with ${linkBalance} LINK`)

  // Get the MockUSDC Contract address.
  const usdcToken = await protocolContract.usdcToken()
  console.log(`\nMockUSDC contract is deployed to ${network.name} at ${usdcToken}`)
})
