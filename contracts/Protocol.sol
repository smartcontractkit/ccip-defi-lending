// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/token/ERC20/IERC20.sol";
import {IERC165} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/utils/introspection/IERC165.sol";

import {IAny2EVMMessageReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol";
import {MockUSDC} from "./MockUSDC.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */

/// @title - A simple messenger contract for sending/receiving messages and tokens across chains.
/// Pay using LINK tokens
contract Protocol is CCIPReceiver, OwnerIsCreator {
  // Custom errors to provide more descriptive revert messages.
  error NoMessageReceived(); // Used when trying to access a message but no messages have been received.
  error IndexOutOfBound(uint256 providedIndex, uint256 maxIndex); // Used when the provided index is out of bounds.
  error MessageIdNotExist(bytes32 messageId); // Used when the provided message ID does not exist.
  error NotEnoughBalance(uint256, uint256);
  error NothingToWithdraw(); // Used when trying to withdraw Ether but there's nothing to withdraw.
  error FailedToWithdrawEth(address owner, uint256 value); // Used when the withdrawal of Ether fails.

  // Event emitted when a message is sent to another chain.
  event MessageSent(
    bytes32 indexed messageId, // The unique ID of the message.
    uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
    address receiver, // The address of the receiver on the destination chain.
    address borrower, // The borrower's EOA - would map to a depositor on the source chain.
    Client.EVMTokenAmount tokenAmount, // The token amount that was sent.
    uint256 fees // The fees paid for sending the message.
  );

  // Event emitted when a message is received from another chain.
  event MessageReceived(
    bytes32 indexed messageId, // The unique ID of the message.
    uint64 indexed sourceChainSelector, // The chain selector of the source chain.
    address sender, // The address of the sender from the source chain.
    address depositor, // The EOA of the depositor on the source chain
    Client.EVMTokenAmount tokenAmount // The token amount that was received.
  );

  // Struct to hold details of a message.
  struct MessageIn {
    uint64 sourceChainSelector; // The chain selector of the source chain.
    address sender; // The address of the sender.
    address depositor; // The content of the message.
    address token; // received token.
    uint256 amount; // received amount.
  }

  // Storage variables.
  bytes32[] public receivedMessages; // Array to keep track of the IDs of received messages.
  mapping(bytes32 => MessageIn) public messageDetail; // Mapping from message ID to MessageIn struct, storing details of each received message.
  mapping(address => mapping(address => uint256)) public deposits; // Depsitor Address => Deposited Token Address ==> amount
  mapping(address => mapping(address => uint256)) public borrowings; // Depsitor Address => Borrowed Token Address ==> amount

  MockUSDC public usdcToken;
  LinkTokenInterface linkToken;

  constructor(address _router, address link) CCIPReceiver(_router) {
    linkToken = LinkTokenInterface(link);
    usdcToken = new MockUSDC();
  }

  /// handle a received message
  function _ccipReceive(Client.Any2EVMMessage memory any2EvmMessage) internal override {
    bytes32 messageId = any2EvmMessage.messageId; // fetch the messageId
    uint64 sourceChainSelector = any2EvmMessage.sourceChainSelector; // fetch the source chain identifier (aka selector)
    address sender = abi.decode(any2EvmMessage.sender, (address)); // abi-decoding of the sender address
    address depositor = abi.decode(any2EvmMessage.data, (address)); // abi-decoding of the depositor's address

    // Collect tokens transferred. This increases this contract's balance for that Token.
    Client.EVMTokenAmount[] memory tokenAmounts = any2EvmMessage.destTokenAmounts;
    address token = tokenAmounts[0].token;
    uint256 amount = tokenAmounts[0].amount;

    receivedMessages.push(messageId);
    MessageIn memory detail = MessageIn(sourceChainSelector, sender, depositor, token, amount);
    messageDetail[messageId] = detail;

    emit MessageReceived(messageId, sourceChainSelector, sender, depositor, tokenAmounts[0]);

    // Store depositor data.
    deposits[depositor][token] += amount;
  }

  function borrowUSDC(bytes32 msgId) public returns (uint256) {
    uint256 borrowed = borrowings[msg.sender][address(usdcToken)];
    require(borrowed == 0, "Caller has already borrowed USDC");

    address transferredToken = messageDetail[msgId].token;
    require(transferredToken != address(0), "Caller has not transferred this token");

    uint256 deposited = deposits[msg.sender][transferredToken];
    uint256 borrowable = (deposited * 70) / 100; // 70% collaterization ratio.

    // In this example we treat BnM as though it has the same value SNX. This is because BnM tokens are dummy tokens that are not on Chainlink Pricefeeds.
    // And that the USD/USDC peg is a perfect 1:1
    // SNX/USD on Sepolia (https://sepolia.etherscan.io/address/0xc0F82A46033b8BdBA4Bb0B0e28Bc2006F64355bC)
    // Docs: https://docs.chain.link/data-feeds/price-feeds/addresses#Sepolia%20Testnet
    AggregatorV3Interface priceFeed = AggregatorV3Interface(0xc0F82A46033b8BdBA4Bb0B0e28Bc2006F64355bC);

    (, int256 price, , , ) = priceFeed.latestRoundData();
    uint256 price18decimals = uint256(price * (10 ** 10)); // make USD price 18 decimal places from 8 decimal places.

    uint256 borrowableInUSDC = borrowable * price18decimals;

    // MintUSDC
    usdcToken.mint(msg.sender, borrowableInUSDC);

    // Update state.
    borrowings[msg.sender][address(usdcToken)] = borrowableInUSDC;

    assert(borrowings[msg.sender][address(usdcToken)] == borrowableInUSDC);
    return borrowableInUSDC;
  }

  // Repay the Protocol. Transfer tokens back to source chain.
  // Assumes borrower has approved this contract to burn their borrowed token.
  // Assumes borrower has approved this contract to "spend" the transferred token so it can be transferred.
  function repayAndSendMessage(uint256 amount, uint64 destinationChain, address receiver, bytes32 msgId) public {
    require(amount >= borrowings[msg.sender][address(usdcToken)], "Repayment amount is less than amount borrowed");

    // Get the deposit details, so it can be transferred back.
    address transferredToken = messageDetail[msgId].token;
    uint256 deposited = deposits[msg.sender][transferredToken];

    uint256 mockUSDCBal = usdcToken.balanceOf(msg.sender);
    require(mockUSDCBal >= amount, "Caller's USDC token balance insufficient for repayment");

    if (usdcToken.allowance(msg.sender, address(this)) < borrowings[msg.sender][address(usdcToken)]) {
      revert("Protocol allowance is less than amount borrowed");
    }

    usdcToken.burnFrom(msg.sender, mockUSDCBal);

    borrowings[msg.sender][address(usdcToken)] = 0;
    // send transferred token and message back to Sepolia Sender contract
    sendMessage(destinationChain, receiver, transferredToken, deposited);
  }

  function sendMessage(
    uint64 destinationChainSelector,
    address receiver,
    address tokenToTransfer,
    uint256 transferAmount
  ) internal returns (bytes32 messageId) {
    address borrower = msg.sender;

    // Compose the EVMTokenAmountStruct. This struct describes the tokens being transferred using CCIP.
    Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);

    Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({token: tokenToTransfer, amount: transferAmount});
    tokenAmounts[0] = tokenAmount;

    Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
      receiver: abi.encode(receiver), // ABI-encoded receiver address
      data: abi.encode(borrower), // ABI-encoded string message
      tokenAmounts: tokenAmounts,
      extraArgs: Client._argsToBytes(
        Client.EVMExtraArgsV1({gasLimit: 200_000, strict: false}) // Additional arguments, setting gas limit and non-strict sequency mode
      ),
      feeToken: address(linkToken) // Setting feeToken to LinkToken address, indicating LINK will be used for fees
    });

    // Initialize a router client instance to interact with cross-chain
    IRouterClient router = IRouterClient(this.getRouter());

    // Get the fee required to send the message
    uint256 fees = router.getFee(destinationChainSelector, evm2AnyMessage);

    // approve the Router to send LINK tokens on contract's behalf. I will spend the fees in LINK
    linkToken.approve(address(router), fees);

    require(IERC20(tokenToTransfer).approve(address(router), transferAmount), "Failed to approve router");

    // Send the message through the router and store the returned message ID
    messageId = router.ccipSend(destinationChainSelector, evm2AnyMessage);

    // Emit an event with message details
    emit MessageSent(messageId, destinationChainSelector, receiver, borrower, tokenAmount, fees);

    deposits[borrower][tokenToTransfer] -= transferAmount;

    // Return the message ID
    return messageId;
  }

  function getNumberOfReceivedMessages() external view returns (uint256 number) {
    return receivedMessages.length;
  }

  function getReceivedMessageDetails(
    bytes32 messageId
  ) external view returns (uint64, address, address, address token, uint256 amount) {
    MessageIn memory detail = messageDetail[messageId];
    if (detail.sender == address(0)) revert MessageIdNotExist(messageId);
    return (detail.sourceChainSelector, detail.sender, detail.depositor, detail.token, detail.amount);
  }

  function getLastReceivedMessageDetails()
    external
    view
    returns (bytes32 messageId, uint64, address, address, address, uint256)
  {
    // Revert if no messages have been received
    if (receivedMessages.length == 0) revert NoMessageReceived();

    // Fetch the last received message ID
    messageId = receivedMessages[receivedMessages.length - 1];

    // Fetch the details of the last received message
    MessageIn memory detail = messageDetail[messageId];

    return (messageId, detail.sourceChainSelector, detail.sender, detail.depositor, detail.token, detail.amount);
  }

  function isChainSupported(uint64 destChainSelector) external view returns (bool supported) {
    return IRouterClient(this.getRouter()).isChainSupported(destChainSelector);
  }

  /// @notice Fallback function to allow the contract to receive Ether.
  /// @dev This function has no function body, making it a default function for receiving Ether.
  /// It is automatically called when Ether is sent to the contract without any data.
  receive() external payable {}

  /// @notice Allows the contract owner to withdraw the entire balance of Ether from the contract.
  /// @dev This function reverts if there are no funds to withdraw or if the transfer fails.
  /// It should only be callable by the owner of the contract.
  function withdraw() public onlyOwner {
    // Retrieve the balance of this contract
    uint256 amount = address(this).balance;

    // Attempt to send the funds, capturing the success status and discarding any return data
    (bool sent, ) = msg.sender.call{value: amount}("");

    // Revert if the send failed, with information about the attempted transfer
    if (!sent) revert FailedToWithdrawEth(msg.sender, amount);
  }

  /// @notice Allows the owner of the contract to withdraw all tokens of a specific ERC20 token.
  /// @dev This function reverts with a 'NothingToWithdraw' error if there are no tokens to withdraw.
  /// @param token The contract address of the ERC20 token to be withdrawn.
  function withdrawToken(address token) public onlyOwner {
    // Retrieve the balance of this contract
    uint256 amount = IERC20(token).balanceOf(address(this));
    IERC20(token).transfer(msg.sender, amount);
  }
}
