// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "forge-std/Test.sol";

import "../IAminal.sol";
import "../Aminals.sol";
import "./VisualsRegistry.sol";

contract VisualsAuction is IAminal {
    Aminals public aminals;
    VisualsRegistry public vRegistry;

    constructor(address _aminals, address _registry) {
        // TODO: Replace with Aminals contract address
        aminals = Aminals(_aminals);
        vRegistry = VisualsRegistry(_registry);

        console.log(address(this));
    }

    // TODO: Maintain an index of pending Aminals based on breeding in progress
    mapping(uint256 auctionId => Auction auction) public auctions;
    uint256 public auctionCnt = 2; // assuming there are only 2 initially deployed aminals

    struct Auction {
        uint256 aminalIdOne;
        uint256 aminalIdTwo;
        uint256 totalLove;
        // Max of 10 trait options can be proposed per Aminal. 2 slots are used
        // by the Aminals' current trains, and the other 8 slots are used by
        // proposed traits.
        uint256[8][10] visualIds;
        uint256[8][10] visualIdVotes;
        // If 0, auction has not yet concluded
        // The auctionId will be used as the child Aminal's ID
        uint256 childAminalId;
        uint256[8] winnerId;
    }

    function getAuctionByID(uint256 auctionID) public view returns (Auction memory) {
        console.log("returning for auction ID = ", auctionID);
        return auctions[auctionID];
    }

    // TODO: Add return value of auction ID and also emit events
    function startAuction(uint256 aminalIdOne, uint256 aminalIdTwo) public returns (uint256) {
        // Set the breeding flag on each Aminal
        //aminals.addSkill();

        Visuals memory visualsOne;
        Visuals memory visualsTwo;

        console.log("Auction starting for pregnancy of ", aminalIdOne, " and ", aminalIdTwo);

        // Get only the Visuals struct from the mapping
        (,,,,, visualsOne) = aminals.aminals(aminalIdOne);
        (,,,,, visualsTwo) = aminals.aminals(aminalIdTwo);


        // Reset breedable variable to zero for both aminals
        aminals.disableBreedable(aminalIdOne, aminalIdTwo);

        // Set breeding flag via a setter
        aminals.setBreeding(aminalIdOne, true);
        aminals.setBreeding(aminalIdTwo, true);
        
        // initialize the new auction
        // Cannot realistically overflow
        unchecked {
            ++auctionCnt;
        }

         Auction storage auction = auctions[auctionCnt];
        //Auction storage auction;
        auction.aminalIdOne = aminalIdOne;
        auction.aminalIdTwo = aminalIdTwo;
        auction.totalLove = aminals.getAminalLoveTotal(aminalIdOne) + aminals.getAminalLoveTotal(aminalIdTwo);

        console.log("recording auctions at count ", auctionCnt, "with aminalIdOne = ", aminalIdOne);
        console.log("resulting in ", auctions[auctionCnt].aminalIdOne);

        // register the new auction into the global auction registry
        auction.childAminalId = auctionCnt;
        auctions[auction.childAminalId] = auction;

        // Loop through each current visual per Aminal and write it to the
        // struct. i.e. Index [N][0] is AminalIdOne's traits, Index [N][1] is
        // AminalIdTwo's traits.


        console.log("..................................... visuals: ", visualsOne.eyesId);

        auction.visualIds[0][0] = visualsOne.bodyId;
        auction.visualIds[0][1] = visualsTwo.bodyId;
        auction.visualIds[1][0] = visualsOne.hatId;
        auction.visualIds[1][1] = visualsTwo.hatId;
        auction.visualIds[2][0] = visualsOne.eyesId;
        auction.visualIds[2][1] = visualsTwo.eyesId;
        auction.visualIds[3][0] = visualsOne.mouthId;
        auction.visualIds[3][1] = visualsTwo.mouthId;
        auction.visualIds[4][0] = visualsOne.noseId;
        auction.visualIds[4][1] = visualsTwo.noseId;
        auction.visualIds[5][0] = visualsOne.limbsId;
        auction.visualIds[5][1] = visualsTwo.limbsId;
        auction.visualIds[6][0] = visualsOne.tailId;
        auction.visualIds[6][1] = visualsTwo.tailId;
        auction.visualIds[7][0] = visualsOne.miscId;
        auction.visualIds[7][1] = visualsTwo.miscId;

        console.log("____________________________ visuals::: ", auction.visualIds[2][0]);

        return auctionCnt;
    }

    function proposeVisual(uint256 auctionId, VisualsRegistry.VisualsCat catEnum, uint256 visualId) public payable {
        // anyone can propose new visuals, but the cost depends on how much they love you in order to avoid ppl from spamming the available slots.abi

        uint category = uint256(catEnum);

        Auction storage auction = auctions[auctionId];

        uint256 priceOne = aminals.loveDrivenPrice(auction.aminalIdOne, msg.sender);
        uint256 priceTwo = aminals.loveDrivenPrice(auction.aminalIdTwo, msg.sender);

        uint256 price = priceOne + priceTwo;

        console.log("required ether to submit new visual === ", price);

        require(msg.value >= price, "Not enough ether to propose a new Visual");

        // This starts at 2 because the first two array values are used by the Aminal's traits
        for (uint256 i = 2; i < 10; i++) {
            console.log("Iterating thourgh .... ", i, " . -- where auction.visualsIds cat = ", category);
            if (auction.visualIds[category][i] == 0) {
                auction.visualIds[category][i] = visualId;
                break;
            }
        }
    }

    function voteVisual(uint256 auctionId, uint256 category, uint256 i) public payable {
        Auction storage auction = auctions[auctionId];
        uint256 totallove = aminals.getAminalLoveByIdByUser(auction.aminalIdOne, msg.sender)
            + aminals.getAminalLoveByIdByUser(auction.aminalIdTwo, msg.sender);

        auction.visualIdVotes[category][i] += totallove;
    }

    function removeVisual(uint256 auctionId, uint256 visualId) public payable {
        // the loved ones can vote to remove a trait from the auction
    }

    function endAuction(uint256 auctionId) public {
        Auction storage auction = auctions[auctionId];

        // loop through all the Visuals and identify the winner;
        uint256[] memory maxVotes;
        uint256[8][10] memory arrVisuals;

        for (uint256 i = 0; i < 8; i++) {
            arrVisuals[i] = auction.visualIds[i];

            for (uint256 j = 0; j < arrVisuals.length; j++) {
                if (arrVisuals[i][j] > maxVotes[i]) {
                    maxVotes[i] = arrVisuals[i][j];
                    auction.winnerId[i] = j;
                }
            }
        }

        // Zero breeding flag via a setter
        aminals.setBreeding(auction.aminalIdOne, false);
        aminals.setBreeding(auction.aminalIdTwo, false);


    }
}
