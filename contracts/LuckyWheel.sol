// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

contract Lukywheel {
    uint public spinPrice = 1 ether;
    uint public totalSpins;
    address public immutable owner = msg.sender;
    mapping(address => Player) public playerInfo;
    Prize[] public prizes;

    struct Player {
        uint spins;
        bool blocked;
    }
    struct Prize {
        string name;
        uint posis;
        uint spins;
        uint weight;
    }

    constructor() {
        prizes.push(Prize("LOSE", 0, 0, 35));
        prizes.push(Prize("0.5_POSI", 0.5 ether, 0, 35));
        prizes.push(Prize("1_SPIN", 0, 1, 19));
        prizes.push(Prize("2_POSI", 2 ether, 0, 5));
        prizes.push(Prize("3_POSI", 3 ether, 0, 3));
        prizes.push(Prize("4_POSI", 4 ether, 0, 2));
        prizes.push(Prize("5_POSI", 5 ether, 0, 1));
    }

    event spinEvent(address indexed, string[], uint);

    function spin(uint _spins) external payable securityCheck priceCheck(_spins) {
        string[] memory result = new string[](_spins);
        Prize[] memory _prizes = prizes;
        Prize memory prize;
        uint earned_posi;
        uint earned_spins;
        uint vrf = VRF();
        unchecked {
            for (uint i = 0; i < _spins; ++i) {
                prize = selectPrize(_prizes, vrf % 100);
                result[i] = prize.name;
                earned_posi += prize.posis;
                earned_spins += prize.spins;
                vrf /= 100;
            }
        }
        totalSpins += _spins;
        playerInfo[msg.sender].spins += earned_spins;
        if(earned_posi > 0) payable(msg.sender).transfer(earned_posi);
        emit spinEvent(msg.sender, result, block.timestamp);
    }

    function selectPrize(Prize[] memory _prizes, uint _vrf) internal pure returns (Prize memory) {
        uint sum = 0;
        uint len = _prizes.length;
        unchecked {
            for (uint i = 0; i < len; ++i) {
                sum += _prizes[i].weight;
                if (_vrf < sum) return _prizes[i];
            }
        }
        return Prize("", 0, 0, 0);
    }

    function getWeiPrice(uint _spins) public  view returns (uint) {
        uint ps = playerInfo[msg.sender].spins;
        return (_spins > ps ? _spins - ps : 0) * spinPrice;
    }

    modifier priceCheck(uint _spins) {
        require(_spins <= 30, "!spins");
        uint ps = playerInfo[msg.sender].spins;
        playerInfo[msg.sender].spins = _spins > ps ? 0 : ps - _spins;
        _spins = _spins > ps ? _spins - ps : 0;
        require(msg.value == _spins * spinPrice, "!price");
        _;
    }

    function VRF() internal view returns (uint result) {
        uint[1] memory bn = [block.number];
        assembly {
            let memPtr := mload(0x40)
            if iszero(staticcall(not(0), 0xff, bn, 0x20, memPtr, 0x20)) {
                invalid()
            }
            result := mload(memPtr)
        }
        result = uint(keccak256(abi.encodePacked(msg.sender, result)));
    }

    function setPrizes(Prize[] memory _prizes) external onlyOwner {
        delete prizes;
        uint sum = 0;
        uint len = _prizes.length;
        unchecked {
            for (uint i = 0; i < len; ++i) {
                sum += _prizes[i].weight;
                prizes.push(_prizes[i]);   
            }
        }
        require(sum == 100, "setPrizes");
    }

    function updatePlayer(address[] calldata _player, uint _spins, bool _blocked) external onlyOwner {
        uint len = _player.length;
        unchecked {
            for (uint i = 0; i < len; ++i) {
                playerInfo[_player[i]].spins += _spins;
                playerInfo[_player[i]].blocked = _blocked;
            }
        }
    }

    function getWeiBalance() external view onlyOwner returns (uint) {
        return address(this).balance;
    }

    function withdrawWei(uint _amount) external onlyOwner {
        require(address(this).balance >= _amount, "withdraw");
        payable(msg.sender).transfer(_amount);
    }

    function setWeiPrice(uint _newPrice) external onlyOwner {
        spinPrice = _newPrice;
    }

    function setLock(bool _enabled) external onlyOwner {
        locked = _enabled;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "onlyOwner");
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
