// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract Roulette {
    address payable public owner;
    struct Player { uint16 tickets; uint16 amount; }
    mapping(address => Player) playerInfo;
    uint public ticketPrice;

    Prize[] public prizes;
    struct Prize { string name; uint16 weight; uint16 posis; uint16 tickets; }

    uint public spinCount;
    bool public isSpinning;

    event SpinResult(uint16 indexed prizeIndex, Prize prize);
    event ActionLog(string action, address indexed user, uint timestamp);
    event RewardLog(Player player, uint16 posis, uint16 tickets);

    constructor(uint _ticketPrice) {
        owner = payable(msg.sender);
        ticketPrice = _ticketPrice;
        spinCount = 0;
        isSpinning = false;

        prizes.push(Prize("Lose", 1600, 0, 0));
        prizes.push(Prize("1 Posi", 1200, 1, 0));
        prizes.push(Prize("Lose", 1600, 0, 0));
        prizes.push(Prize("2 Posi", 750, 2, 0));
        prizes.push(Prize("+1 Spin", 1100, 0, 1));
        prizes.push(Prize("3 Posi", 700, 3, 0));
        prizes.push(Prize("Lose", 1600, 0, 0));
        prizes.push(Prize("4 Posi", 600, 4, 0));
        prizes.push(Prize("+2 Spin", 500, 0, 2));
        prizes.push(Prize("8 Posi", 500, 8, 0));
    }

    function spin() public {
        require(playerInfo[msg.sender].tickets > 0, "No tickets left");
        require(!isSpinning, "Previous spin in progress");

        // consume one ticket
        playerInfo[msg.sender].tickets--;

        // run the roulette spin
        uint16 prizeIndex = _weightedRandom(prizes);

        Prize memory selectedPrize = prizes[prizeIndex];
        emit SpinResult(prizeIndex, selectedPrize);

        // give reward
        giveReward(selectedPrize.posis, selectedPrize.tickets);

        spinCount++;
        logAction("Spin");
    }

    function giveReward(uint16 _posis, uint16 _tickets) private {
        if (_posis > 0) {
            // give posi to player
        }
        playerInfo[msg.sender].tickets += _tickets;

        emit RewardLog(playerInfo[msg.sender], _posis, _tickets);
    }

    function logAction(string memory _action) private {
        emit ActionLog(_action, msg.sender, block.timestamp);
    }

    function buyTickets(uint16 numTickets) public payable {
        require(msg.value == numTickets * ticketPrice, "Incorrect ticket price");
        playerInfo[msg.sender].tickets += numTickets;
        logAction("buyTickets");
    }

    function vrf() public view returns (bytes32 result) {
        uint[1] memory bn;
        bn[0] = block.number;
        assembly {
            let memPtr := mload(0x40)
            if iszero(staticcall(not(0), 0xff, bn, 0x20, memPtr, 0x20)) {
                    invalid()
                }
            result := mload(memPtr)
        }
    }

    function _weightedRandom(Prize[] memory _weights) private view returns (uint16) {
        uint sum = 0;
        for (uint i = 0; i < _weights.length; i++) {
            sum += _weights[i].weight;
        }
        
        bytes32 randomNumber = vrf();
        uint rand = uint(randomNumber);
        rand = rand % sum;

        sum = 0;
        for (uint16 i = 0; i < _weights.length; i++) {
            sum += _weights[i].weight;
            if (rand < sum) {
                return i;
            }
        }
        
        revert("Weighted random calculation failed");
    }

    function withdraw(uint amount) public {
        require(msg.sender == owner, "Only owner can withdraw funds");
        require(amount <= address(this).balance, "Insufficient contract balance");
        owner.transfer(amount);
        logAction("withdraw");
    }

    function getContractBalance() public view returns (uint) {
        return address(this).balance;
    }

    function getPrizeByIndex(uint16 prizeIndex) public view returns (Prize memory) {
        require(prizeIndex >= 0 && prizeIndex < prizes.length, "Invalid prize index");
        return prizes[prizeIndex];
    }

    function setTicketPrice(uint _newPrice) public {
        require(msg.sender == owner, "Only owner can set ticket price");
        ticketPrice = _newPrice;
        logAction("setTicketPrice");
    }
}