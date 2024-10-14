// Written by Zeyn Schweyk

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Assignment2.sol";

contract VickreyAuction is IVickreyAuction {
    uint256 public reservePrice;
    uint256 public bidDeposit;
    uint256 private numBiddingPeriodBlocks;
    uint256 private numRevealPeriodBlocks;
    address public seller;

    address public winner;
    // function winner() public view returns (address) {}
    uint256 public finalPrice;
    // function finalPrice() public view returns (uint256) {}

    uint256 private highestBid;
    address public highestBidder;
    // function highestBidder() public view returns (address) {}
    uint256 public secondHighestBid;
    // function secondHighestBid() public view returns (uint256) {}

    uint256 private auctionCreationBlock;
    bool private atLeastOneReveal;

    // Note: Contract creator should be the seller
    constructor(
        uint256 _reservePrice,
        uint256 _bidDeposit,
        uint256 _biddingPeriod,
        uint256 _revealPeriod
    ) {
        reservePrice = _reservePrice;
        bidDeposit = _bidDeposit;
        numBiddingPeriodBlocks = _biddingPeriod;
        numRevealPeriodBlocks = _revealPeriod;
        auctionCreationBlock = block.number;
        seller = msg.sender;
        highestBid = 0;
        secondHighestBid = _reservePrice;
        atLeastOneReveal = false;
    }

    // Can use mapping to store the commitment for each bidder
    mapping(address => bool) private bidSubmitted;
    mapping(address => bytes32) private bidCommitments;
    mapping(address => uint256) private bidDeposits;
    mapping(address => bool) private hasRevealed;

    // Record the player's bid commitment
    // Make sure at least bidDepositAmount is provided (for new bids)
    // Bidders can update their previous bid for free if desired.
    // Only allow commitments before biddingDeadline
    function commitBid(bytes32 bidCommitment) external payable override {
        require(block.number <= auctionCreationBlock + numBiddingPeriodBlocks - 1, "Bidding period is over");
        if (!bidSubmitted[msg.sender]) { // bidder has not already sent a commitment
            require(msg.value >= bidDeposit, "Bid deposit amount is too low");
            payable(msg.sender).transfer(msg.value - bidDeposit);
            bidDeposits[msg.sender] = bidDeposit;
            bidSubmitted[msg.sender] = true;
        } else { // bidder has already sent a commitment... this is an update
            payable(msg.sender).transfer(msg.value); // refund this deposit... they have already made a previous deposit
        }
        
        bidCommitments[msg.sender] = bidCommitment;
    }

    // Check that the bid (msg.value) matches the commitment
    // If the bid is below the minimum price, it is ignored but the deposit is returned.
    // If the bid is below the current highest known bid, the bid value and deposit are returned.
    // If the bid is the new highest known bid, the deposit is returned and the previous high bidder's bid is returned.
    function revealBid(bytes32 nonce) external payable override {
        require(block.number > auctionCreationBlock + numBiddingPeriodBlocks - 1 && block.number <= auctionCreationBlock + numBiddingPeriodBlocks - 1 + numRevealPeriodBlocks, "Not time to reveal commitment");
        require(bidSubmitted[msg.sender], "The user never submitted a bid commitment");
        bytes32 commitment = makeCommitment(msg.value, nonce);
        require(commitment == bidCommitments[msg.sender]); // ensure the exact bid is sent
        require(!hasRevealed[msg.sender], "Bidder has already revealed their bid before");

        hasRevealed[msg.sender] = true;
        if (msg.value < reservePrice) {
            payable(msg.sender).transfer(bidDeposits[msg.sender]);
            payable(msg.sender).transfer(msg.value);
            return;
        }

        atLeastOneReveal = true;
        if (msg.value <= highestBid) { // what to do when there is a tie
            // check if higher than second highest bid
            if (msg.value > secondHighestBid) {
                secondHighestBid = msg.value;
            }
            payable(msg.sender).transfer(msg.value + bidDeposits[msg.sender]);
        } else {
            payable(msg.sender).transfer(bidDeposits[msg.sender]);
            payable(highestBidder).transfer(highestBid);

            secondHighestBid = highestBid;
            // handle case where this is the first bid
            if (highestBid == 0) { // highestBid is initialized to 0, so basically checking if no other bid was made
                secondHighestBid = reservePrice; // change secondHighestBid from 0 to reserverPrice
            }
            highestBid = msg.value;
            highestBidder = msg.sender;
        }
    }

    // This function shows how to make a commitment
    function makeCommitment(
        uint256 bidValue,
        bytes32 nonce
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(bidValue, nonce));
    }

    // Anyone can finalize the auction after the reveal period has ended
    function finalize() external override {
        require(block.number > auctionCreationBlock + numBiddingPeriodBlocks - 1 + numRevealPeriodBlocks, "Not time to finalize auction");
        
        finalPrice = secondHighestBid;
        if (atLeastOneReveal) {
            winner = highestBidder;
            payable(winner).transfer(highestBid - finalPrice);
            payable(seller).transfer(finalPrice);
        }
        // if there is not at least one reveal, do nothing when finalizing the auction
        
    }
}
