// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

contract CrimsonGalleon is Ownable(msg.sender), VRFConsumerBaseV2 {
    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords;
    }

    mapping(uint256 => RequestStatus) public s_requests; /* requestId --> requestStatus */

    VRFCoordinatorV2Interface COORDINATOR;
    uint64 s_subscriptionId;
    uint256[] public requestIds;
    uint256 public lastRequestId;
    bytes32 keyHash = 0x354d2f95da55398f44b7cff77da56283d9c6c829a4bdf1bbcaf2ad6a4d081f61;
    uint32 callbackGasLimit = 600000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 2;

    constructor(uint64 subscriptionId) VRFConsumerBaseV2(0x2eD832Ba664535e5886b75D64C46EB9a228C2610) {
        ownerAddress = msg.sender;

        COORDINATOR = VRFCoordinatorV2Interface(0x2eD832Ba664535e5886b75D64C46EB9a228C2610);
        s_subscriptionId = subscriptionId;

        lastCalled = block.timestamp - 14 minutes;
    }

    uint256 public lastCalled;

    uint256 wagerValue = 1000000 gwei;

    uint256 winValue = 900000 gwei;

    uint256 creatorValue = 10000 gwei;

    uint256 pickUpValue = 90000 gwei;

    uint256 availablePickups;

    string[] public unitsInGame;
    mapping(string => Unit) public units;

    address ownerAddress;

    mapping(address => uint256) playersBalance;

    uint256 treasuryBalance;

    uint256 creatorBalance;

    uint256 pickUpBalance;

    uint256 constant multiplier = 1e18;

    uint256 public currentMapId = 0;

    struct Map {
        uint256 requestId;
        uint256 randomSeed;
    }

    mapping(uint256 => Map) public allMaps;

    uint256 public lastRandomSeed;

    struct Unit {
        address payable playerAddress;
        uint8 unitType;
        bool unitReady;
        bool doesExist;
    }

    function requestRandomWords() private returns (uint256 requestId) {
        // Will revert if subscription is not set and funded.
        requestId =
            COORDINATOR.requestRandomWords(keyHash, s_subscriptionId, requestConfirmations, callbackGasLimit, numWords);
        s_requests[requestId] = RequestStatus({randomWords: new uint256[](0), exists: true, fulfilled: false});
        requestIds.push(requestId);
        lastRequestId = requestId;

        return requestId;
    }

    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;

        allMaps[currentMapId].randomSeed = _randomWords[0];

        lastRandomSeed = _randomWords[0];
    }

    function GetRandomWords(uint256 _requestId) public view returns (uint256) {
        return s_requests[_requestId].randomWords[0];
    }

    function startNewMap() public {
        //  require(
        //         block.timestamp >= lastCalled + 14 minutes,
        //         "Function can't be called more than once every 14 minutes."
        //     );

        lastCalled = block.timestamp;

        uint256 newMapId = currentMapId = currentMapId + 1;
        currentMapId = newMapId;

        uint256 reqId = requestRandomWords();

        Map memory map = Map(reqId, 0);

        allMaps[newMapId] = map;
    }

    function GetTimeSinceNewMap() public view returns (uint256) {
        return lastCalled;
    }

    function GetCurrentMapDetails() public view returns (uint256) {
        return allMaps[currentMapId].randomSeed;
    }

    function joinBattle(uint8 _unitType, string memory _unitId) public payable {
        require(msg.value > wagerValue, "Not enough money");

        bool hasJoined = false;
        if (units[_unitId].unitType == _unitType) {
            hasJoined = true;
        }
        require(hasJoined == false, "Already joined");

        Unit memory theUnit = units[_unitId];

        theUnit.playerAddress = (payable(msg.sender));
        theUnit.unitType = _unitType;
        theUnit.unitReady = false;
        theUnit.doesExist = true;

        units[_unitId] = theUnit;

        unitsInGame.push(_unitId);
    }

    function checkIfJoined(uint8 _unitType, string memory _unitId) public view returns (bool) {
        bool hasJoined = false;
        if (units[_unitId].unitType == _unitType) {
            hasJoined = true;
        }

        return hasJoined;
    }

    //Server
    function readyUnit(string memory _unitId) public onlyOwner {
        require(units[_unitId].unitType != 0, "Not joined");
        require(units[_unitId].unitReady == false, "Unit is already ready");

        units[_unitId].unitReady = true;
    }

    function checkIfReady(string memory _unitId) public view returns (uint256) {
        //req owner
        uint256 returnString = 0;
        if (units[_unitId].unitReady == true) {
            returnString = units[_unitId].unitType;
        }

        return returnString;
    }

    function getUnitType(string memory _unitId) public view returns (uint8) {
        uint8 unitType = units[_unitId].unitType;

        return unitType;
    }

    function returnUnit(string calldata _unitId) public onlyOwner {
        if (units[_unitId].doesExist == true) {
            playersBalance[units[_unitId].playerAddress] += wagerValue;
            RemoveUnit(_unitId);
        }
    }

    function shipSank(string memory _unitId1, string memory _unitId2) public onlyOwner {
        string memory winnderId;
        string memory loserId;
        uint8 player1Type = units[_unitId1].unitType;
        uint8 player2Type = units[_unitId2].unitType;

        if (player1Type == 1 && player2Type == 2) {
            winnderId = _unitId2;
            loserId = _unitId1;
        }
        if (player1Type == 2 && player2Type == 1) {
            winnderId = _unitId1;
            loserId = _unitId2;
        }
        if (player1Type == 2 && player2Type == 3) {
            winnderId = _unitId2;
            loserId = _unitId1;
        }
        if (player1Type == 3 && player2Type == 2) {
            winnderId = _unitId1;
            loserId = _unitId2;
        }
        if (player1Type == 1 && player2Type == 3) {
            winnderId = _unitId1;
            loserId = _unitId2;
        }
        if (player1Type == 3 && player2Type == 1) {
            winnderId = _unitId2;
            loserId = _unitId1;
        }

        RemoveUnit(loserId);

//Old
        //  uint wonValue = (((wagerValue * multiplier) / 100) *90) / multiplier;
        //        playersBalance[units[winnderId].playerAddress] = wonValue;

        //         uint leftOver = wagerValue - wonValue;

        //       creatorBalance +=  (((leftOver * multiplier) / 100) *90) / multiplier;

        //       treasuryBalance += leftOver - (((leftOver * multiplier) / 100) *90) / multiplier;

        playersBalance[units[winnderId].playerAddress] += winValue;

        creatorBalance += creatorValue;

        treasuryBalance += pickUpValue;

        availablePickups++;
    }

    function playerPickedUp(string calldata _unitId) public {
        require(availablePickups > 0, "Not enough pickups");
        playersBalance[units[_unitId].playerAddress] += pickUpValue;

        treasuryBalance -= pickUpValue;

        availablePickups--;
    }

    function withdrawPlayerFunds() public {
        require(playersBalance[msg.sender] > 0, "no player balance");

        uint256 amount = playersBalance[msg.sender];

        playersBalance[msg.sender] = 0;

        payable(msg.sender).transfer(amount);
    }

    function RemoveUnit(string memory _unitId) internal {
        uint256 index = 999999999;

        for (uint256 i = 0; i < unitsInGame.length; i++) {
            if (stringsEquals(unitsInGame[i], _unitId)) {
                index = i;
            }
        }

        for (uint256 i = index; i < unitsInGame.length - 1; i++) {
            unitsInGame[i] = unitsInGame[i + 1];
        }
        unitsInGame.pop();

        delete units[_unitId];
    }

    function returnFundsOfUnitsNotLostOrWon() public onlyOwner {
        string[] memory unitsinGame_local = unitsInGame;

        for (uint256 i = 0; i < 10; i++) {
            if (unitsinGame_local.length > i) {
                units[unitsinGame_local[i]].playerAddress.transfer(wagerValue);
                RemoveUnit(unitsinGame_local[i]);
            }
        }
    }

    function getPlayerBalance(address _address) public view returns (uint256) {
        return playersBalance[_address];
    }

    function getContractBalance() public view onlyOwner returns (uint256) {
        return address(this).balance;
    }

    function getCreatoralance() public view onlyOwner returns (uint256) {
        return creatorBalance;
    }

    function getPickUpBalance() public view onlyOwner returns (uint256) {
        return pickUpBalance;
    }

    function setWagerValue(uint256 _value) public onlyOwner {
        wagerValue = _value;
    }

    function getWagerValue() public view returns (uint256) {
        return wagerValue;
    }

    function getRandomNumber() internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
    }

    function stringsEquals(string memory s1, string memory s2) private pure returns (bool) {
        bytes memory b1 = bytes(s1);
        bytes memory b2 = bytes(s2);
        uint256 l1 = b1.length;
        if (l1 != b2.length) return false;
        for (uint256 i = 0; i < l1; i++) {
            if (b1[i] != b2[i]) return false;
        }
        return true;
    }

    function withdrawContractBalance() public onlyOwner {
        address payable creatorAddress = payable(ownerAddress);
        creatorAddress.transfer(address(this).balance);
    }

    function withdrawCreatorBalance() public onlyOwner {
        address payable creatorAddress = payable(ownerAddress);
        creatorAddress.transfer(creatorBalance);
    }

    function getAvailablePickups(string memory code) public view returns (uint256) {
        uint256 hasedCode = uint256(keccak256(abi.encodePacked(code)));

        return availablePickups;
    }

    function useAvailablePickup() public onlyOwner {
        availablePickups--;
    }

    //debug

    function getUnitsInGame() public view onlyOwner returns (string[] memory) {
        return unitsInGame;
    }

    function uint8ToString(uint8 value) public pure returns (string memory) {
        // Since uint8 is smaller than uint256, we don't need to worry about overflow here
        uint256 _value = uint256(value);
        if (_value == 0) {
            return "0";
        }
        uint256 temp = _value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        uint256 index = digits - 1;
        temp = _value;

        while (temp != 0) {
            buffer[index--] = bytes1(uint8(48 + temp % 10));
            temp /= 10;
        }
        return string(buffer);
    }
}
