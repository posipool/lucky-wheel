// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

contract Lukywheel {
    uint256 public spinPrice = 1;
    uint256 public spins = 0;

    address internal owner;
    mapping(address => Player) public playerInfo;
    Prize[] public prizes;

    struct Player {
        uint32 spins;
        uint32 games;
        uint32 wins;
        bool blocked;
        uint256 balance;
    }
    struct Prize {
        uint8 posis;
        uint8 spins;
        uint8 weight;
    }

    // [[0, 0, 23], [2, 0, 3], [0, 0, 23], [3, 0, 3], [0, 1, 15], [4, 0, 2], [0, 0, 23], [5, 0, 1], [0, 2, 6], [6, 0, 1]]

    constructor() {
        owner = msg.sender;
        Prize[] memory _prizes = new Prize[](10);
        _prizes[0] = Prize(0, 0, 23);
        _prizes[1] = Prize(2, 0, 3);
        _prizes[2] = Prize(0, 0, 23);
        _prizes[3] = Prize(3, 0, 3);
        _prizes[4] = Prize(0, 1, 15);
        _prizes[5] = Prize(4, 0, 2);
        _prizes[6] = Prize(0, 0, 23);
        _prizes[7] = Prize(5, 0, 1);
        _prizes[8] = Prize(0, 2, 6);
        _prizes[9] = Prize(6, 0, 1);
        setPrizes(_prizes);
    }

    event spinEvent(address indexed, uint8[], uint256, uint256);

    function spin(uint32 _spins) external payable securityCheck priceCheck(_spins) returns (uint8[] memory _indexes) {
        _indexes = new uint8[](_spins);
        uint256 vrf = VRF();
        uint256 div = vrf / _spins;
        Prize memory _prize;
        Player memory _player = playerInfo[msg.sender];
        for (uint8 i = 0; i < _spins; i++) {
            _indexes[i] = randomIndex(vrf);
            _prize = prizes[_indexes[i]];
            _player.games++;
            _player.spins += _prize.spins;
            _player.wins += _prize.posis > 0 ? 1 : 0;
            _player.balance += _prize.posis;
            spins++;
            vrf -= div;
        }
        playerInfo[msg.sender] = _player;
        userWithdraw();
        emit spinEvent(msg.sender, _indexes, block.number, block.timestamp);
    }

    modifier priceCheck(uint32 _spins) {
        require(_spins <= 50, "Too much spins");
        uint32 ps = playerInfo[msg.sender].spins;
        playerInfo[msg.sender].spins = _spins > ps ? 0 : ps - _spins;
        _spins = _spins > ps ? _spins - ps : 0;
        require(msg.value == _spins * spinPrice * 1 ether, "Incorrect spins price");
        _;
    }

    function randomIndex(uint256 _vrf) internal view returns (uint8) {
        uint256 rnd = _vrf % 100;
        uint256 sum = 0;
        for (uint8 i = 0; i < prizes.length; i++) {
            sum += prizes[i].weight;
            if (rnd < sum) return i;
        }
        revert("Weighted random calculation failed");
    }

    function VRF() internal view returns (uint256 _result) {
        uint256[1] memory bn = [block.number];
        assembly {
            let memPtr := mload(0x40)
            if iszero(staticcall(not(0), 0xff, bn, 0x20, memPtr, 0x20)) {
                invalid()
            }
            _result := mload(memPtr)
        }
        _result = uint256(keccak256(abi.encodePacked(msg.sender, _result)));
        // _result = uint256(keccak256(abi.encodePacked(block.timestamp))); //Remix's VM
    }

    function userWithdraw() private {
        uint256 balance = playerInfo[msg.sender].balance;
        if (balance <= 0) return;
        payable(msg.sender).transfer(balance * 1 ether);
        playerInfo[msg.sender].balance = 0;
    }

    event prizesUpdate(address indexed, Prize[], uint256, uint256);

    function setPrizes(Prize[] memory _prizes) public onlyOwner {
        delete prizes;
        uint256 sum = 0;
        for (uint8 i = 0; i < _prizes.length; i++) {
            sum += _prizes[i].weight;
            prizes.push(_prizes[i]);
        }
        require(sum == 100, "sum of weights must be 100");
        emit prizesUpdate(msg.sender, prizes, block.number, block.timestamp);
    }

    event ownerEvent(address indexed, string, uint256, uint256, uint256);

    function giveSpins(address[] memory _players, uint32 _spins) external onlyOwner {
        for (uint8 i = 0; i < _players.length; i++) playerInfo[_players[i]].spins += _spins;
        emit ownerEvent(msg.sender, "giveSpins", _players.length, block.number, block.timestamp);
    }

    function withdraw(uint256 _amount) external onlyOwner {
        require(address(this).balance / 1 ether >= _amount, "Insufficient contract balance");
        payable(msg.sender).transfer(_amount * 1 ether);
        emit ownerEvent(msg.sender, "withdraw", _amount, block.number, block.timestamp);
    }

    function setPrice(uint256 _newPrice) external onlyOwner {
        spinPrice = _newPrice;
        emit ownerEvent(msg.sender, "setPrice", _newPrice, block.number, block.timestamp);
    }

    function blockPlayers(address[] memory _players, bool _blocked) external onlyOwner {
        for (uint8 i = 0; i < _players.length; i++) playerInfo[_players[i]].blocked = _blocked;
        emit ownerEvent(msg.sender, "blockPlayers", _players.length, block.number, block.timestamp);
    }

    function setLock(bool _enabled) external onlyOwner {
        locked = _enabled;
        emit ownerEvent(msg.sender, "setLock", _enabled ? 1 : 0, block.number, block.timestamp);
    }

    function getBalance() external view onlyOwner returns (uint256) {
        return address(this).balance / 1 ether;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    bool private locked;
    modifier securityCheck() {
        require(!locked, "Locked");
        require(!playerInfo[msg.sender].blocked, "Blocked");
        locked = true;
        _;
        locked = false;
    }
}
