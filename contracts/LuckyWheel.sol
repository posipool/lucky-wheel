// SPDX-License-Identifier: UNLICENSED
pragma solidity >= 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Lukywheel is Ownable, ReentrancyGuard {
    uint public constant spinPrice = 1 ether;
    uint public constant maxSpins = 30;
    uint public constant maxPrize = 8;
    uint public totalSpins;
    bool public locked;
    Prize[] public prizes;
    mapping(address => uint) public playerSpins;
    struct Prize { string name; uint posis; uint spins; uint weight; }

    constructor() payable {
        require(msg.value > maxPrize * maxSpins, "!balance");
        prizes.push(Prize("LOSE", 0, 0, 32));
        prizes.push(Prize("0.5_POSI", 0.5 ether, 0, 32));
        prizes.push(Prize("1_SPIN", 0, 1, 20));
        prizes.push(Prize("2_POSI", 2 ether, 0, 10));
        prizes.push(Prize("4_POSI", 4 ether, 0, 3));
        prizes.push(Prize("6_POSI", 6 ether, 0, 2));
        prizes.push(Prize("8_POSI", maxPrize * 1 ether, 0, 1));
    }

    event spinEvent(address indexed, string[], uint);

    function spin(uint _spins) external payable nonReentrant priceCheck(_spins) {
        string[] memory result = new string[](_spins);
        Prize[] memory _prizes = prizes;
        Prize memory prize;
        (uint posisSum, uint spinsSum, uint vrf) = (0, 0, VRF());
        for (uint i = 0; i < _spins;) {
            prize = selectPrize(_prizes, vrf % 100);
            result[i] = prize.name;
            posisSum += prize.posis;
            spinsSum += prize.spins;
            vrf /= 100;
            unchecked { ++i; }
        }
        totalSpins += _spins;
        playerSpins[msg.sender] += spinsSum;
        if (posisSum > 0) payable(msg.sender).transfer(posisSum);
        emit spinEvent(msg.sender, result, block.timestamp);
    }

    function selectPrize(Prize[] memory _prizes, uint _vrf) internal pure returns (Prize memory) {
        (uint sum, uint len) = (0, _prizes.length);
        for (uint i = 0; i < len;) {
            sum += _prizes[i].weight;
            if (_vrf < sum) return _prizes[i];
            unchecked { ++i; }
        }
        revert("sum != 100");
    }

    function getPrice(address _player, uint _spins) public view returns (uint) {
        uint ps = playerSpins[_player];
        return (_spins > ps ? _spins - ps : 0) * spinPrice;
    }

    //https://docs.posichain.org/developers/dapps-development/posichain-vrf
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

    function giveSpins(address[] calldata _player, uint _spins) external onlyOwner {
        uint len = _player.length;
        for (uint i = 0; i < len;) {
            playerSpins[_player[i]] += _spins;
            unchecked { ++i; }
        }
    }

    function withdraw(uint _amount) external onlyOwner {
        require(address(this).balance >= _amount, "withdraw");
        payable(msg.sender).transfer(_amount);
    }

    function setLock(bool _enabled) external onlyOwner {
        locked = _enabled;
    }

    modifier priceCheck(uint _spins) {
        uint ps = playerSpins[msg.sender];
        uint price = (_spins > ps ? _spins - ps : 0) * spinPrice;
        require(address(this).balance > maxPrize * maxSpins, "!balance");
        require(_spins > 0 && _spins <= maxSpins, "!spins");
        require(!locked || _spins <= ps, "locked");
        require(msg.value == price, "!price");
        playerSpins[msg.sender] = _spins > ps ? 0 : ps - _spins;
        _;
    }
}
