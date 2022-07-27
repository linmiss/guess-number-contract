// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Import this file to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract GuessNumber {
    event GameStarted(GameState state);

    enum GameState {
        WAITING_START,
        WAITING_GUESS,
        WAITING_RESULT,
        PLAYERS_WIN
    }

    bytes32 public nonceHash;
    bytes32 public nonceNumHash;
    uint256 public initValue;
    bytes32 private _nonce;
    uint256 private _number;

    address public host;
    address[] public playerAddresses;
    address[] public winnerPlayers;
    mapping(address => uint256) public players;
    GameState public gameState;

    modifier byHost() {
        require(msg.sender == host);

        _;
    }

    modifier byWinnerPlayer() {
        require(existAddress(msg.sender));

        _;
    }

    modifier validGameState(GameState expected) {
        require(getGameState() == expected);

        _;
    }

    modifier validEthValue(uint256 value) {
        require(value == initValue);

        _;
    }

    constructor(bytes32 nonce, uint256 number) {
        host = msg.sender;
        _nonce = nonce;
        _number = number;
        nonceHash = keccak256(abi.encode(nonce));
        nonceNumHash = keccak256(abi.encode(nonce, number));
    }

    function submitStartGame()
        public
        payable
        byHost
        validGameState(GameState.WAITING_START)
    {
        require(msg.value > 0);

        initValue = msg.value;
        setGameState(GameState.WAITING_GUESS);
    }

    function guess(uint256 _guessNum)
        public
        payable
        validGameState(GameState.WAITING_GUESS)
        validEthValue(msg.value)
    {
        require(isValidNumber(_guessNum));
        require(playerAddresses.length <= 2);
        require(!existAddress(msg.sender));

        playerAddresses.push(msg.sender);
        players[msg.sender] = _guessNum;

        if (playerAddresses.length == 2) {
            setGameState(GameState.WAITING_RESULT);
        }
    }

    function reveal(bytes32 nonce, uint16 number)
        public
        byHost
        validGameState(GameState.WAITING_RESULT)
    {
        require(playerAddresses.length <= 2);

        if (keccak256(abi.encode(nonce)) != nonceHash) {
            revert();
        }

        if (keccak256((abi.encode(nonce, number))) != nonceNumHash) {
            revert();
        }

        if (!isValidNumber(number)) {
            winnerPlayers = playerAddresses;
            return;
        }

        uint256 deltaPlayerOne = abs(players[playerAddresses[0]], initValue);
        uint256 deltaPlayerTwo = abs(players[playerAddresses[1]], initValue);

        if (deltaPlayerOne > deltaPlayerTwo) {
            winnerPlayers.push(playerAddresses[1]);
        } else if (deltaPlayerOne < deltaPlayerTwo) {
            winnerPlayers.push(playerAddresses[0]);
        } else {
            winnerPlayers = playerAddresses;
        }
    }

    function withdraw() public payable byWinnerPlayer {
        if (winnerPlayers.length == 1) {
            (bool success, ) = msg.sender.call{value: initValue * 3}("");
            require(success, "Withdraw failed!");

            gameState = GameState.WAITING_START;
        } else {
            uint256 bonus = (initValue * 3) / 2;
            for (uint256 index = 0; index < winnerPlayers.length; index++) {
                (bool success, ) = msg.sender.call{value: bonus * 3}("");
                require(success, "Withdraw failed!");

                delete winnerPlayers[index];
            }
        }
    }

    function setGameState(GameState _gameState) private {
        gameState = _gameState;
    }

    function getGameState() public view returns (GameState) {
        return gameState;
    }

    function existAddress(address player) private view returns (bool) {
        for (uint256 index = 0; index < playerAddresses.length; index++) {
            if (playerAddresses[index] == player) {
                return true;
            }
        }

        return false;
    }

    function isValidNumber(uint256 _guessNum) private pure returns (bool) {
        return _guessNum >= 0 && _guessNum < 1000;
    }

    function abs(uint256 a, uint256 b) public pure returns (uint256) {
        return a - b < 0 ? b - a : a - b;
    }
}
