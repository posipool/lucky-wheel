// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

contract Lukywheel {
    address private owner;
    mapping(address => Player) private playerInfo; //may change to list due incapability of mapping interaction by index
    Prize[] private prizes;
    uint16 public ticketPrice;
    uint16 public spinCount = 0;

    struct Player {
        // bool spinning; //spining state will aways be true if the contract reverts
        uint16 tickets;
        uint16 balance;
        uint16 games;
        uint16 wins;
        bool blocked; //not using at now, working in progress
        address user; //stores user's Lukywheel_user contract address
    }
    struct Prize {
        string name;
        uint8 weight;
        uint8 posis;
        uint8 tickets;
    }

    event RewardLog(address indexed player, Prize prize);
    event ActionLog(string indexed action, address indexed player, uint256 timestamp, uint256 blocknumber);

    constructor(uint16 _ticketPrice) {
        owner = payable(msg.sender);
        ticketPrice = _ticketPrice;

        prizes.push(Prize("Lose", 100, 0, 0));
        prizes.push(Prize("1 Posi", 20, 1, 0));
        prizes.push(Prize("Lose", 100, 0, 0));
        prizes.push(Prize("2 Posi", 10, 2, 0));
        prizes.push(Prize("+1 Spin", 40, 0, 1));
        prizes.push(Prize("3 Posi", 5, 3, 0));
        prizes.push(Prize("Lose", 100, 0, 0));
        prizes.push(Prize("4 Posi", 2, 4, 0));
        prizes.push(Prize("+2 Spin", 20, 0, 2));
        prizes.push(Prize("8 Posi", 1, 8, 0));
    }

    event vrflog(address a, uint256 b); //temporary

    // BASE FUNCTIONS*******************************************************
    function spin() public {
        // require(playerInfo[msg.sender].tickets > 0, "No tickets left"); //temporary
        require(!playerInfo[msg.sender].blocked, "alan alert");
        if (playerInfo[msg.sender].user == address(0)) 
            playerInfo[msg.sender].user = address(new Lukywheel_user());

        uint256 vrf = Lukywheel_user(playerInfo[msg.sender].user).vrf();
        emit vrflog(playerInfo[msg.sender].user, vrf); //temporary
        giveReward(prizes[randomIndex(vrf)]);
        log("Spin");
    }

    function randomIndex(uint256 _vrf) private view returns (uint8) {
        uint16 sum = 0;
        for (uint8 i = 0; i < prizes.length; i++) 
            sum += prizes[i].weight;
        uint16 rnd = uint16(_vrf % sum);
        sum = 0;
        for (uint8 i = 0; i < prizes.length; i++) {
            sum += prizes[i].weight;
            if (rnd < sum) return i;
        }
        revert("Weighted random calculation failed");
    }

    function giveReward(Prize memory _prize) private {
        //uint type cannot be negative, doesnt make sense user tickets amount be negative anyway...
        if (playerInfo[msg.sender].tickets > 0)
            playerInfo[msg.sender].tickets--;
        playerInfo[msg.sender].games++;
        playerInfo[msg.sender].balance += _prize.posis;
        playerInfo[msg.sender].tickets += _prize.tickets;
        playerInfo[msg.sender].wins += _prize.posis > 0 ? 1 : 0;
        spinCount++;
        emit RewardLog(msg.sender, _prize);
    }

    function log(string memory _action) private {
        emit ActionLog(_action, msg.sender, block.timestamp, block.number);
    }
    //**********************************************************************

    // TRANSACTION FUNCTIONS************************************************
    function buyTickets(uint16 _numTickets) public payable {
        require(msg.value == _numTickets * ticketPrice, "Incorrect ticket price");
        playerInfo[msg.sender].tickets += _numTickets;
        log("buyTickets");
    }

    function withdraw(uint256 _amount) public {
        require(_amount <= address(this).balance, "Insufficient contract balance");
        if (msg.sender != owner) 
            require(_amount <= playerInfo[msg.sender].balance, "Insufficient user balance");
        payable(msg.sender).transfer(_amount);
        log("withdraw");
    }
    //**********************************************************************

    // ONLY OWNER FUNCTIONS*************************************************
    function getContractBalance() public view onlyOwner returns (uint256) {
        return address(this).balance;
    }

    function setTicketPrice(uint16 _newPrice) public onlyOwner {
        ticketPrice = _newPrice;
        log("setTicketPrice");
    }

    //this function can manipulate ucontract information outside contract
    //temporary by now due discution of fairness in the future, added for security reasons
    function setPlayerInfo(address _player, Player memory _info) public onlyOwner {
        playerInfo[_player] = _info;
    }

    function getPlayer(address _player) public view onlyOwner returns (Player memory) {
        return playerInfo[_player];
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    //**********************************************************************
}

// CONTRACT PER USER
contract Lukywheel_user {
    constructor() {}

    function vrf() public view returns (uint256 _result) {
        uint256[1] memory bn = [uint256(keccak256(abi.encodePacked(block.number, msg.sender)))];
        assembly {
            let memPtr := mload(0x40)
            if iszero(staticcall(not(0), 0xff, bn, 0x20, memPtr, 0x20)) {
                invalid()
            }
            _result := mload(memPtr)
        }
    }
}
