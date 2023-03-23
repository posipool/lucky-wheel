// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract Lukywheel {
    uint public spinPrice = 1 ether;
    uint public totalSpins;
    bool public locked;
    address public immutable owner = msg.sender;
    Prize[] public prizes;
    mapping(address => Player) public playerInfo;
    struct Player { uint spins; bool blocked; }
    struct Prize { string name; uint posis; uint spins; uint weight; }

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
        (uint posisSum, uint spinsSum, uint vrf) = (0, 0, VRF());
        unchecked {
            for (uint i = 0; i < _spins; ++i) {
                prize = selectPrize(_prizes, vrf % 100);
                result[i] = prize.name;
                posisSum += prize.posis;
                spinsSum += prize.spins;
                vrf /= 100;
            }
        }
        totalSpins += _spins;
        playerInfo[msg.sender].spins += spinsSum;
        if (posisSum > 0) payable(msg.sender).transfer(posisSum);
        emit spinEvent(msg.sender, result, block.timestamp);
    }

    function selectPrize(Prize[] memory _prizes, uint _vrf) internal pure returns (Prize memory) {
        unchecked {
            (uint sum, uint len) = (0, _prizes.length);
            for (uint i = 0; i < len; ++i) {
                sum += _prizes[i].weight;
                if (_vrf < sum) return _prizes[i];
            }
        }
        return Prize("", 0, 0, 0);
    }

    function getWeiPrice(address _player, uint _spins) public view returns (uint) {
        uint ps = playerInfo[_player].spins;
        return (_spins > ps ? _spins - ps : 0) * spinPrice;
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

    function setPrizes(Prize[] calldata _prizes) external onlyOwner returns (uint sum) {
        delete prizes;
        unchecked {
            uint len = _prizes.length;
            for (uint i = 0; i < len; ++i) {
                sum += _prizes[i].weight;
                prizes.push(_prizes[i]);
            }
        }
        require(sum == 100, "setPrizes");
    }

    function updatePlayer(address[] calldata _player, uint _spins, bool _blocked) external onlyOwner {
        unchecked {
            uint len = _player.length;
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

    function destroy() external onlyOwner {
        selfdestruct(payable(owner));
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "onlyOwner");
        _;
    }

    bool private reentrance;
    modifier securityCheck() {
        require(!reentrance, "reentrance");
        require(!playerInfo[msg.sender].blocked, "Blocked");
        reentrance = true;
        _;
        reentrance = false;
    }

    modifier priceCheck(uint _spins) {
        require(_spins > 0 && _spins <= 30, "!spins");
        uint ps = playerInfo[msg.sender].spins;
        require(!locked || _spins <= ps, "locked");
        uint price = (_spins > ps ? _spins - ps : 0) * spinPrice;
        require(msg.value == price, "!price");
        playerInfo[msg.sender].spins = _spins > ps ? 0 : ps - _spins;
        _;
    }
}
