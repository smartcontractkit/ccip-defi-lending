// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";

import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/token/ERC20/IERC20.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT AND IS NOT SECURITY AUDITED.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */

contract Sender is CCIPReceiver, OwnerIsCreator {
  error NoFundsLocked(address msgSender, bool locked);
  error NoMessageReceived(); // Used when trying to access a message but no messages have been received.
  error IndexOutOfBound(uint256 providedIndex, uint256 maxIndex); // Used when the provided index is out of bounds.
  error MessageIdNotExist(bytes32 messageId); // Used when the provided message ID does not exist.
  error NotEnoughBalance(uint256, uint256);
  error NothingToWithdraw(); // Used when trying to withdraw Ether but there's nothing to withdraw.
  error FailedToWithdrawEth(address owner, uint256 value); // Used when the withdrawal of Ether fails.

  // Data Structures
  struct MessageIn {
    uint64 sourceChainSelector; // The chain selector of the source chain.
    address sender; // The address of the sending contract on the source chain.
    address borrower; // The content of the message which will be the EOA of the person sending tokens.
    address token; // received token.
    uint256 amount; // received amount.
  }

  struct Deposit {
    uint256 amount;
    bool locked;
  }

  // Event emitted when a message is sent to another chain.
  event MessageSent(
    bytes32 indexed messageId, // The unique ID of the message.
    uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
    address receiver, // The address of the receiver contract on the destination chain.
    address depositor, // The message being sent - will be the EOA of the person sending tokens.
    Client.EVMTokenAmount tokenAmount, // The token amount that was sent.
    uint256 fees // The fees paid for sending the message.
  );

  // Event emitted when a message is received from another chain.
  event MessageReceived(
    bytes32 indexed messageId, // The unique ID of the message.
    uint64 indexed sourceChainSelector, // The chain selector of the source chain.
    address sender, // The address of the sender from the source chain.
    address borrower, // The borrower EOA. Should be a depositor.
    Client.EVMTokenAmount tokenAmount // The token amount that was sent.
  );

  // Storage variables.
  bytes32[] public receivedMessages; // Array to keep track of the IDs of received messages.
  mapping(bytes32 => MessageIn) public messageDetail; // Mapping from message ID to MessageIn struct, storing details of each received message.
  mapping(address => Deposit) public deposits;

  LinkTokenInterface linkToken;

  constructor(address _router, address link) CCIPReceiver(_router) {
    linkToken = LinkTokenInterface(link);
  }

  function sendMessage(
    uint64 destinationChainSelector,
    address receiver,
    address tokenToTransfer,
    uint256 transferAmount
  ) external returns (bytes32 messageId) {
    // Compose the EVMTokenAmountStruct. This struct describes the tokens being transferred using CCIP.
    Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({token: tokenToTransfer, amount: transferAmount});

    Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
    tokenAmounts[0] = tokenAmount;

    // encode the depositor's EOA as  data to be sent in the message.
    bytes memory data = abi.encode(msg.sender);

    Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
      receiver: abi.encode(receiver), // ABI-encoded receiver contract address
      data: data,
      tokenAmounts: tokenAmounts,
      extraArgs: Client._argsToBytes(
        Client.EVMExtraArgsV1({gasLimit: 200_000, strict: false}) // Additional arguments, setting gas limit and non-strict sequency mode
      ),
      feeToken: address(linkToken) // Setting feeToken to LinkToken address, indicating LINK will be used for fees
    });

    // Initialize a router client instance to interact with cross-chain router
    IRouterClient router = IRouterClient(this.getRouter());

    // Get the fee required to send the message. Fee paid in LINK.
    uint256 fees = router.getFee(destinationChainSelector, evm2AnyMessage);

    // Approve the Router to pay fees in LINK tokens on contract's behalf.
    linkToken.approve(address(router), fees);

    // Approve the Router to transfer the tokens on contract's behalf.
    IERC20(tokenToTransfer).approve(address(router), transferAmount);

    // Send the message through the router and store the returned message ID
    messageId = router.ccipSend(destinationChainSelector, evm2AnyMessage);

    // Emit an event with message details
    emit MessageSent(messageId, destinationChainSelector, receiver, msg.sender, tokenAmount, fees);

    // Return the message ID
    return messageId;
  }

  function _ccipReceive(Client.Any2EVMMessage memory any2EvmMessage) internal override {
    bytes32 messageId = any2EvmMessage.messageId; // fetch the messageId
    uint64 sourceChainSelector = any2EvmMessage.sourceChainSelector; // fetch the source chain identifier (aka selector)
    address sender = abi.decode(any2EvmMessage.sender, (address)); // abi-decoding of the sender address
    address borrower = abi.decode(any2EvmMessage.data, (address)); // abi-decoding of the borrower's address

    // Collect tokens transferred. This increases this contract's balance for that Token.
    Client.EVMTokenAmount[] memory tokenAmounts = any2EvmMessage.destTokenAmounts;

    address token = tokenAmounts[0].token;
    uint256 amount = tokenAmounts[0].amount;

    receivedMessages.push(messageId);

    MessageIn memory detail = MessageIn(sourceChainSelector, sender, borrower, token, amount);
    messageDetail[messageId] = detail;

    emit MessageReceived(messageId, sourceChainSelector, sender, borrower, tokenAmounts[0]);
  }

  function getNumberOfReceivedMessages() external view returns (uint256 number) {
    return receivedMessages.length;
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

    return (messageId, detail.sourceChainSelector, detail.sender, detail.borrower, detail.token, detail.amount);
  }

  function deposit() external payable {
    recordDeposit(msg.sender, msg.value);
  }

  function recordDeposit(address sender, uint256 amount) internal {
    deposits[sender].amount += amount;
    if (!deposits[sender].locked) {
      deposits[sender].locked = true;
    }
  }

  function isChainSupported(uint64 destChainSelector) external view returns (bool supported) {
    return IRouterClient(this.getRouter()).isChainSupported(destChainSelector);
  }

  function getSendFees(
    uint64 destinationChainSelector,
    address receiver
  ) public view returns (uint256 fees, Client.EVM2AnyMessage memory message) {
    message = Client.EVM2AnyMessage({
      receiver: abi.encode(receiver), // ABI-encoded receiver contract address
      data: abi.encode(msg.sender),
      tokenAmounts: new Client.EVMTokenAmount[](0),
      extraArgs: Client._argsToBytes(
        Client.EVMExtraArgsV1({gasLimit: 200_000, strict: false}) // Additional arguments, setting gas limit and non-strict sequency mode
      ),
      feeToken: address(0) // Setting feeToken to zero address, indicating native asset will be used for fees
    });

    // Get the fee required to send the message
    fees = IRouterClient(this.getRouter()).getFee(destinationChainSelector, message);
    return (fees, message);
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

  function withdrawToken(address token) public onlyOwner {
    // Retrieve the balance of this contract
    uint256 amount = IERC20(token).balanceOf(address(this));
    IERC20(token).transfer(msg.sender, amount);
  }
}
