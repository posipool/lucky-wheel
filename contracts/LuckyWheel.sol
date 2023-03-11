// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract Lukywheel {
    uint8 public ticketPrice;
    uint256 private debt = 0;
    uint256 public spins = 0;
    address private owner;
    mapping(address => Player) private playerInfo;
    Prize[] public prizes;

    struct Player {
        uint32 tickets;
        uint32 balance;
        uint32 games;
        uint32 wins;
        bool blocked;
    }
    struct Prize {
        string name;
        uint8 weight;
        uint8 posis;
        uint8 tickets;
    }

    constructor(uint8 _ticketPrice) {
        owner = payable(msg.sender);
        ticketPrice = _ticketPrice;

        prizes.push(Prize("Lose", 100, 0, 0));
        prizes.push(Prize("2 Posi", 30, 1, 0));
        prizes.push(Prize("Lose", 100, 0, 0));
        prizes.push(Prize("3 Posi", 10, 2, 0));
        prizes.push(Prize("+1 Spin", 70, 0, 1));
        prizes.push(Prize("4 Posi", 10, 3, 0));
        prizes.push(Prize("Lose", 100, 0, 0));
        prizes.push(Prize("5 Posi", 5, 4, 0));
        prizes.push(Prize("+2 Spin", 50, 0, 2));
        prizes.push(Prize("6 Posi", 5, 8, 0));
    }

    event spinEvent(address indexed, uint8, uint256, uint256);

    function spin() public checkUser returns (uint8 _index) {
        require(playerInfo[msg.sender].tickets > 0, "No tickets left");
        require(debt < address(this).balance, "contract limit");
        _index = randomIndex();
        giveReward(prizes[_index]);
        emit spinEvent(msg.sender, _index, block.number, block.timestamp);
    }

    function testSpin() public onlyOwner returns (uint8 _index) {
        _index = randomIndex();
        emit spinEvent(msg.sender, _index, block.number, block.timestamp);
    }

    function randomIndex() private view returns (uint8) {
        uint16 sum = 0;
        for (uint8 i = 0; i < prizes.length; i++) sum += prizes[i].weight;
        uint16 rnd = uint16(vrf() % sum);
        sum = 0;
        for (uint8 i = 0; i < prizes.length; i++) {
            sum += prizes[i].weight;
            if (rnd < sum) return i;
        }
        revert("Weighted random calculation failed");
    }

    function vrf() private view returns (uint256 _result) {
        uint256[1] memory bn = [block.number];
        assembly {
            let memPtr := mload(0x40)
            if iszero(staticcall(not(0), 0xff, bn, 0x20, memPtr, 0x20)) {
                invalid()
            }
            _result := mload(memPtr)
        }
        _result = uint256(keccak256(abi.encodePacked(msg.sender, _result)));
    }

    function giveReward(Prize memory _prize) private {
        if (playerInfo[msg.sender].tickets > 0) playerInfo[msg.sender].tickets--;
        playerInfo[msg.sender].games++;
        playerInfo[msg.sender].balance += _prize.posis;
        playerInfo[msg.sender].tickets += _prize.tickets;
        playerInfo[msg.sender].wins += _prize.posis > 0 ? 1 : 0;
        debt += _prize.posis;
        spins++;
    }

    event userEvent(address indexed, string, uint16, uint256, uint256);

    function buyTickets(uint16 _numTickets) public payable checkUser {
        require(msg.value >= _numTickets * ticketPrice, "Incorrect ticket price");
        playerInfo[msg.sender].tickets += _numTickets;
        emit userEvent(msg.sender, "buyTickets", _numTickets, block.number, block.timestamp);
    }

    function convertToTickets(uint16 _numTickets) public checkUser {
        uint32 price = _numTickets * ticketPrice;
        require(playerInfo[msg.sender].balance >= price, "Insufficient user balance");
        playerInfo[msg.sender].balance -= price;
        playerInfo[msg.sender].tickets += _numTickets;
        emit userEvent(msg.sender, "convertToTickets", _numTickets, block.number, block.timestamp);
    }

    function withdraw(uint16 _amount) public checkUser {
        require(address(this).balance >= _amount, "Insufficient contract balance");
        uint32 playerBalance = playerInfo[msg.sender].balance;
        require(msg.sender != owner && playerBalance >= _amount, "Insufficient user balance");
        playerInfo[msg.sender].balance -= playerBalance - _amount < 0 ? 0 : _amount;
        debt -= debt - _amount < 0 ? 0 : _amount;
        payable(msg.sender).transfer(_amount);
        emit userEvent(msg.sender, "withdraw", _amount, block.number, block.timestamp);
    }

    function getPlayerInfo(address _player) public view returns (Player memory) {
        return playerInfo[_player];
    }

    function getContractDebt() public view onlyOwner returns (uint256) {
        return debt;
    }

    function getContractBalance() public view onlyOwner returns (uint256) {
        return address(this).balance;
    }

    function setTicketPrice(uint8 _newPrice) public onlyOwner {
        ticketPrice = _newPrice;
        emit userEvent(msg.sender, "setTicketPrice", _newPrice, block.number, block.timestamp);
    }

    function alanAlert(address _player, bool blocked) public onlyOwner {
        playerInfo[_player].blocked = blocked;
        emit userEvent(msg.sender, "alanAlert", blocked ? 1 : 0, block.number, block.timestamp);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    bool internal locked;
    modifier checkUser() {
        require(!locked, "No re-entrancy");
        require(!playerInfo[msg.sender].blocked, "alan alert");
        locked = true;
        _;
        locked = false;
    }
}
