// Written by Zeyn Schweyk

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Assignment2.sol";

contract EnglishAuction is IEnglishAuction {
    uint256 public minIncrement;
    address public seller;

    address public winner;
    uint256 public initialPrice;
    uint256 public finalPrice;

    address public highestBidder;
    // function highestBidder() public view returns (address) {}
    uint256 public highestBid;
    // function highestBid() public view returns (uint256) {}

    uint256 public biddingPeriod;

    bool private auctionStarted;
    uint256 private lastBidBlock;


    // Note: Contract creator should be the seller
    constructor(
        uint256 _initialPrice,
        uint256 _minIncrement,
        uint256 _biddingPeriod
    ) {
        seller = msg.sender;
        // highestBid = _initialPrice;
        initialPrice = _initialPrice;
        minIncrement = _minIncrement;
        biddingPeriod = _biddingPeriod;

        lastBidBlock = block.number;
        auctionStarted = false;
    }

    function bid() external payable override {
        require(block.number < lastBidBlock + biddingPeriod, "Bidding period is over");
        if (!auctionStarted) {
            require(msg.value >= initialPrice, "Initial bid is less than initialPrice");            
            auctionStarted = true;
        } else {
            require(msg.value >= highestBid + minIncrement, "Follow up bid is not at least highestBid + minIncrement");
            payable(highestBidder).transfer(highestBid);            
        }

        highestBid = msg.value;
        highestBidder = msg.sender;
        lastBidBlock = block.number;   
    }

    // Anyone can finalize the auction after the bidding period has ended
    function finalize() external override {
        require(block.number >= lastBidBlock + biddingPeriod, "Auction still in progress");
        winner = highestBidder;
        finalPrice = highestBid;
        payable(seller).transfer(finalPrice);
    }
}
