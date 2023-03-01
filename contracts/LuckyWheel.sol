// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

contract Lukywheel {
    address private owner;
    mapping(address => Player) private playerInfo; //may change to list due incapability of mapping interaction by index
    address[] private players; //possible solution for 'mapping cant interact by index's problem ↑
    Prize[] private prizes;
    uint8 public ticketPrice;
    uint32 public spins = 0;
    uint32 public debt = 0; //necessary for contract knows how much he needs to pay if all players cashout at same time
    // fixed public fee = 0.1; //open discussion on usage of contract fee or not

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
        // fixed32x8 weight;
        uint8 weight;
        uint8 posis;
        uint8 tickets;
    }

    event RewardLog(address indexed player, Prize prize);
    event ActionLog(string indexed action, address indexed player, uint256 timestamp, uint256 blocknumber);

    constructor(uint8 _ticketPrice) {
        owner = payable(msg.sender);
        ticketPrice = _ticketPrice;

        //change the weights to fixed, require lib
        prizes.push(Prize("Lose", 100, 0, 0));
        prizes.push(Prize("1 Posi", 20, 1, 0)); //doesnt make sense spend 1 posi to gain 1 posi
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
        // require(playerInfo[msg.sender].tickets > 0, "No tickets left"); //temporary, faster for testing
        require(!playerInfo[msg.sender].blocked, "alan alert");
        require(debt < address(this).balance, "contract limit"); //keep contract's debt on limit
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
        debt += _prize.posis;
        spins++;
        emit RewardLog(msg.sender, _prize);
    }

    function log(string memory _action) private {
        emit ActionLog(_action, msg.sender, block.timestamp, block.number);
    }
    //**********************************************************************

    // TRANSACTION FUNCTIONS************************************************
    function buyTickets(uint16 _numTickets) public payable {
        require(msg.value >= _numTickets * ticketPrice, "Incorrect ticket price");
        playerInfo[msg.sender].tickets += _numTickets;
        log("buyTickets");
    }

    //may change for only owner, must create a separate function 'userWithdraw' without paramters
    function withdraw(uint32 _amount) public {
        require(_amount <= address(this).balance, "Insufficient contract balance");
        if (msg.sender != owner) {
            require(_amount <= playerInfo[msg.sender].balance, "Insufficient user balance");
            debt -= _amount;
        }
        payable(msg.sender).transfer(_amount);
        log("withdraw");
    }
    //**********************************************************************

    // ONLY OWNER FUNCTIONS*************************************************
    function getContractBalance() public view onlyOwner returns (uint256) {
        return address(this).balance;
    }

    function setTicketPrice(uint8 _newPrice) public onlyOwner {
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
