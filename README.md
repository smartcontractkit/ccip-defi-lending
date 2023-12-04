# Cross Chain DEFI Lending and Borrowing

> **Note**
>
> _This repository represents an example of using a Chainlink product or service. It is provided to help you understand how to interact with Chainlink’s systems so that you can integrate them into your own. This template is provided "AS IS" without warranties of any kind, has not been audited, and may be missing key checks or error handling to make the usage of the product more clear. Take everything in this repository as an example and not something to be copy pasted into a production ready service._

In this project you will deploy contracts on Sepolia and Avalanche Fuji, and send messages and tokens back and forth!

## What is Chainlink CCIP?

**Chainlink Cross-Chain Interoperability Protocol (CCIP)** provides a simple, elegant interface through which dApps and web3 entrepreneurs can securely meet achieve cross-chain communication and interoperability. This includes token transfers and arbitrary messaging between supported chains.

![basic-architecture](./img/basic-architecture.png)

With Chainlink CCIP, you can do one or both of the following:

- Transfer supported tokens
- Send messages (arbitrary data in bytes)

A CCIP receiver can be either:

- a Smart contract that implements `CCIPReceiver.sol`
- an EOA

**Note**: If you send a message and token(s) to EOA, only tokens will arrive

# Use Case Description

Our use case works off of two three smart contracts 
- a "Sender" Contract on Fuji (source chain)
- a "Protocol" contract on Sepolia (destination chain) and
- a Mock StableCoin contract (controlled by the Protocol)

A DEFI user deposits a token in Sender, and  then, using [Chainlink CCIP](https://docs.chain.link/ccip), transfers that token, along with some message data, to Protocol. The Protocol contract that accepts the deposit. Using that transferred token  as collateral, the user (i.e. depositor/borrower - the same EOA as on the source chain)  initiates a borrow operation which mints units of the mock stablecoin to lend to the depositor/borrower . 

Chainlink CCIP fees are paid using LINK tokens. They can also be paid in the [chain's native token](https://documentation-private-git-ccip-documentation-chainlinklabs.vercel.app/ccip/architecture#ccip-billing) but in this example we pay CCIP fees in LINK.

The borrowed amount is calculated using a [collateralization factor (Loan to Value Ratio)](https://crypto.ro/en/dictionary/collateral-factor/#:~:text=Collateral%20Factor%20or%20Loan%20to,well%20as%20traditional%20financial%20institutions)

The stablecoin in this example repo is a mocked USDC token and we use [Chainlink's price feeds](https://docs.chain.link/data-feeds/price-feeds) to calculate the exchange rate between the deposited token and the Mock USDC stablecoin that is being borrowed.

The borrowed token must then be repaid in full, following which the protocol contract will update the borrowers ledger balances and send a CCIP message back to the source chain.

![CCIP Use Case Diagram](/img/diagram.svg)

# Use Case Setup - Prerequisites

Please go through this section and complete the steps before you proceed with the rest of this README.

This project uses [Hardhat tasks](https://hardhat.org/hardhat-runner/docs/guides/tasks-and-scripts). Each task file is named with a sequential number prefix that is the order of steps to use this use case's code.

Clone the project and run `npm install` in the repo's root directory.

You need to fund your developer wallet EOA on the source chain as well as on the destination chain.

On the source chain Fuji (where `Sender.sol` is deployed you need):

- LINK tokens (learn how to get them for each chain [here](https://docs.chain.link/resources/link-token-contracts))
- CCIP-BnM Tokens (Burn & Mint Tokens) for that chain using the `drip()` function (see [here](https://docs.chain.link/ccip/test-tokens#mint-test-tokens))
- a little Fuji AVAX (go [here](https://faucets.chain.link/fuji))

On the destination chain chain Sepolia (where `Protocol.sol` is deployed you need):

- LINK tokens (use the same URL from before but switch networks and make sure you're interacting with the right LINK token contract)
- A little Sepolia Eth (go [here](https://faucets.chain.link/sepolia))

## Configuration

This repo has been written to make it easy for you to quickly run through its steps. It has favoured ease of use over flexibility, and so it assumes you will follow it without modification. This means the configuration is already done for you in the code. You just need to supply the environment variables in the next step and make sure your wallet is funded with the right tokens on each of the chains.

You can inspect the configuration details in the `./networks.js` file. This file exports config data that are used by the tasks in `./tasks`.

## Environment Variables.

For optimized security, we recommend that you do not store your environment variables in human readable form. This means we don't use a `.env` file. Instead we use the the [@chainlink/env-enc NPM package](https://www.npmjs.com/package/@chainlink/env-enc).

Before you proceed make sure you have the following environment variables handy. Note that the Avalanche [RPC HTTPS endpoints](https://docs.avax.network/apis/avalanchego/public-api-server) can be looked up here, but since they're public one has been included directly below.

```
PRIVATE_KEY  // your dev wallet private key.

SEPOLIA_RPC_URL // the JSON-RPC Url from Alchemy/Infura etc

AVALANCHE_FUJI_RPC_URL="https://api.avax-test.network/ext/bc/C/rpc"
```

By using the `env-enc` package, we encrypt our secrets "at rest", meanining that we do have a local `.env.enc` file but the secrets are recorded there in encrypted form. Since it's not human readable, even if you accidentally push it to a git repo, your secrets won't be compromised.

However the package encrypts your secrets with a password that you must supply - and remember - used for encrypting and decrypted.

Steps are to encrypt your secrets and store them in a local `env.enc` file in this project are found in the "Commands" section [here.](https://www.npmjs.com/package/@chainlink/env-enc)

Once you've encrypted your variables (check with `npx env-enc view`) they will automatically be decrypted and injected into your code at runtime. This is achieved my importing the package in `./hardhat.config.js` with:

`require("@chainlink/env-enc").config()`

If you have issues running the code, and you see error messages like "THIS HAS NOT BEEN SET" then it means that an environment variable has not been set. Re-check this step.

⚠️ **Note:** If you see an error like "Error HH18: You installed Hardhat with a corrupted lockfile due to the NPM bug #4828" simply run `npm install` again.

# Running the Usecase's Steps

Just to refresh your memory, in this use case we deploy the `Sender.sol` contract, which accepts user deposits on the source chain, to the Avalanche Fuji C Chain, which will be our source chain.

We then deploy the `Protocol.sol` contract to Sepolia, which will be our destination chain.

Each step is a Hardhat Task. Each Task is in separate,, sequentially numbered file in `./tasks`. Just follow the sequence and make a note of the console outputs

1. Deploy and fund Sender on Fuji
   `npx hardhat setup-sender --network fuji`

Look at your console output and make a note of this contract address. This step and step 2 also fund your contract, provided your environment variables are correctly setup.

2. Deploy & Fund Protocol on Sepolia
   `npx hardhat setup-protocol --network sepolia`

Make a note of this contract address.

Note also, that in our example `Protocol.sol` also creates and controls the MockUSDC ERC20 contract on Sepolia. This was done for design/convenience to reduce the number of steps in this example. The key point is that the Protocol controls the interaction with the MockUSDC stablecoin contract - specifically the minting and burning of MockUSDC.

3. Send tokens and data from Fuji to Sepolia (From `Sender.sol` to `Protocol.sol`). We send only 100 "wei" units - i.e. 0.0000000000000001 CCIP-BnM tokens.

Note that this step utilizes the chain selector for the destination chain as set out in the `networks.js`` file. Check for the latest chain selectors [here](https://docs.chain.link/ccip/supported-networks#ethereum-sepolia--polygon-mumbai-lane).

```
npx hardhat transfer-token \
--network fuji \
--amount 100 \                                      // 100 units of BnM
--sender <<Sender Contract Address on Fuji>> \
--protocol << Protocol Contract Address on Sepolia >> \
--dest-chain sepolia
```

Make a note of the Source Tx Hash that get's printed to your console. You will need this. You can also open the CCIP Explorer URL that gets printed to your console.

Due to the cross-chain nature of CCIP and the different block confirmation times, and the architecture of cryptographic security offered by Chainlink, sending tokens and data can take between 5 and 15 minutes. This is largely driven by the architecture and performance of the source chain.

4. Check the message has been received on the destination chain.

The [CCIP explorer page](https://ccip.chain.link) will show you the status of the CCIP transaction. It will go through a few stages, but you want to wait until it shows "Success".

When your message and token has been successfully sent to the destination chain, the CCIP explorer UI will look like this. You should make a note of the message Id.

![CCIP Explorer Image](/img/explorer%20UI-success.png)

We can also run the Hardhat task to check the content of the tokens and data received on `Protocol.sol` thanks to CCIP:

```
npx hardhat read-message \
--contract <<contract name: either "Sender" or "Protocol" >>  \
--address << contract address >>    \
--message-id <<message Id to read >>    \
--network << network >>
```

This should produce output in your console as follows (when reading from `Protocol`):
![read-message result in console](/img/console-read-message.png)

The output has named fields, but it's important to note the following:

- the `sourceChainSelector` is the chain selector for Fuji - the source chain in this example
- the depositor EOA should be your wallet address
- the transferred token is the contract address of the CCIP-BnM **on the destination chain** (Sepolia, in this example) not the source chain. During transmission, CCIP updates this value to point to the token's address on the destination chain, even though what you provided in the `transfer-token` step was the token address on the source chain. You can get the addresses for supported tokens [here](https://docs.chain.link/ccip/supported-networks).

The `Protocol` contract has a `deposits` mapping that stores the details of the token that got deposited into the Protocol. Those details are also printed out. Note that at this stage the `borrowings` mapping for the depositor address shows `0` as no borrowing has been made yet.

If you want to specifically check the BnM-CCIP token contract on Sep

5. Initiate the borrow/swap of the deposited token for the Mock USDC token.

`npx hardhat borrow --network sepolia --protocol <<Protocol Contract on Fuji>>  --message-id << message ID from the CCIP explorer/previous step output >>`

This will cause the Protocol contract to apply the Collateral Factor (70%) and then use Chainlink Price Feeds to calculate the swap rate for 70% of the deposited token. This gives us the amount of MockUSDC that can be borrowed, while keeping sufficient collateral to secure against fluctuations in value of the deposited token.

6. Check that your borrowing is recorded on the Protocol contract
   `npx hardhat read-borrowed --protocol <<Protocol Contract on Fuji>> --network sepolia`

This will print details about the borrower (your wallet address), the amount of the deposit (100 juels/wei in this example) and the amount of your borrowing (calculated after applying the Collateral Factor and getting the exchange rate from Chainlink Price Feeds)
![read borrowing result in console](/img/read-borrowing.png)

At this stage the borrower can use the borrowed tokens for other DEFI activity.

When they're ready they can...

7. Repay the borrowing

```
npx hardhat repay --message-id << message id from the fuji to sepolia CCIP call >> \
 --network sepolia \
 --protocol << your protocol.sol address >> \
 --sender << your sender.sol address >>
```

There are a few key steps to note here:

- You'll note that the repay task takes in the address of the `Sender.sol` contract on Fuji. This is because the repay logic in `Protocol.sol` is in `repayAndSendMessage()` which repays the borrowing. The repay step includes a CCIP message being sent from the Protocol to the Sender -- in the reverse direction as the original token transfer. This reverse communication can be used to communicate data to the `Sender.sol` contract for operations to take place on the original source chain (Fuji in our example).

- If you look at the code in `./tasks/06_repay.js` you'll note that are a few necessary prerequisites to this repay working. The borrower (your address) must approve `Protocol.sol` to spend/burn the Mock USDC token on the borrower's behalf. This is part of the[ ERC20 Token specification](https://eips.ethereum.org/EIPS/eip-20) which prescribes that an owner of tokens can authorize another address to be the "spender". In our example, the Protocol contract must be approved before the Protocol can burn the borrower's MockUSDC to show that the borrowed amount has been "returned" and the borrower no longer has those tokens.

Similarly, the borrower must also approve the `Protocol` contract as a "spender" of the's CCIP-BnM tokens borrowed. The `Protocol` then transfers those borrowed token to itself before authorizing the Router to transfer them back to Fuji.

8. Wait for the CCIP transaction to complete. The Sepolia to Fuji lane is slower because Sepolia is slower. The repay hardhat task triggers the `repayAndSendMessage()` function internall in `Protocol.sol`. Therefore there is no Tx hash that gets printed to your console. Instead go to the [Sepolia block explorer](https://sepolia.etherscan.io/) and paste in your `Protocol` address. Then click on the Events Tab and if the previous repay task succcessfully excecuted, you'd notice a very recent event. Topic 1 is the Message Id for the Sepolia - Fuji CCIP transaction. Copy that and paste it into the CCIP explorer and wait for "Success". Be warned-- Sepolia is slow so this can take as much as 20 minutes!

![CCIP Explorer Image](/img/topic%201.png)

9 Once the CCIP explorer indicates that your tokens and message have been sent back to `Sender`, you can now re-use the previous `read-message` Task to read the message received in `Sender.sol` - just be sure to put in the right contract address and network name (Fuji).

10. Use the utility functions to cleanup by withdrawing your tokens.

Withdraw your test tokens from the Sender contract with
`npx hardhat withdraw-sender-funds --network fuji --address <<Sender contract address on Fuji>>`

Withdraw your test tokens from the Protocol.sol with
`npx hardhat withdraw-protocol-funds  --network sepolia --address <<Protocol address on Sepolia>>`
