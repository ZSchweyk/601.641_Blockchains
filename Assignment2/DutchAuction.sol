// Written by Mingyuan (Jerome) Shen

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Assignment2.sol";

contract DutchAuction is IDutchAuction {
    address public seller;

    address public winner;
    // function winner() public view returns (address) {}

    uint256 public finalPrice;

    uint256 private initialPrice;
    uint256 private blockDecrement;
    uint256 private duration;

    uint256 private firstBlock;

    uint256 private highestBid;
    address private tempWinner;

    bool private auctionOver;

    // function finalPrice() public view returns (uint256) {}

    // Note: Contract creator should be the seller
    constructor(
        uint256 _initialPrice,
        uint256 _blockDecrement,
        uint256 _duration
    ) {
        initialPrice = _initialPrice;
        blockDecrement = _blockDecrement;
        duration = _duration;
        seller = msg.sender;
        auctionOver = false;
        firstBlock = block.number;
    }


    function bid() external payable override {
        uint256 time_passed = block.number - firstBlock;
        if (time_passed >= duration) {
            auctionOver = true;
        }
        require(!auctionOver, "auction is over, no more bid");

        // require(msg.value > highestBid, "the bid price is not the highest");
        if (msg.value > highestBid) {
            highestBid = msg.value;
            tempWinner = msg.sender;
        }

        

        uint256 currPrice = currentPrice();
        if (msg.value < currPrice) {
            revert("your bidding is too low");
        }

        if (currPrice <= highestBid) {
            winner = tempWinner;
            finalPrice = currPrice;
            auctionOver = true;

            if (highestBid > currPrice) {
                payable(msg.sender).transfer(highestBid - currPrice);
            }
        }

        
        
    }

    // Anyone can finalize the auction after the auction has ended
    function finalize() external override {
        uint256 time_passed = block.number - firstBlock;
        if (time_passed >= duration) {
            auctionOver = true;
        }
        require(auctionOver, "not over");
        payable(seller).transfer(finalPrice); //pay to the seller
    }

    function currentPrice() public view override returns (uint256) {
        uint256 time_passed = block.number - firstBlock;
        if (time_passed >= duration) {
            return initialPrice - blockDecrement * duration;
        }
        uint256 priceDecrese = time_passed * blockDecrement;
        return initialPrice - priceDecrese;
    }
}
