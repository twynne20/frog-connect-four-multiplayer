// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract Connect4 is Ownable {
    using SafeERC20 for IERC20;

    struct Game {
        address player1;
        address player2;
        uint256 betAmount;
        address betToken;
        uint8[6][7] board; // Corrected dimensions: 6 rows, 7 columns
        uint8 currentPlayer;
        bool completed;
        bool openToPublic;
    }

    mapping(uint256 => Game) public games;
    mapping(address => uint256[]) public playerGames;
    mapping(address => uint256) public playerWins;
    uint256 public gameCount;
    uint256 public constant FEE_PERCENTAGE = 3;
    address public constant DEGEN_TOKEN = 0x6160D0Ca6ad8AA9Cc68d143D01591d8050b7dD9f;
    uint256 public totalFees;

    event GameCreated(uint256 indexed gameId, address indexed player1, uint256 betAmount, address betToken, bool openToPublic);
    event GameJoined(uint256 indexed gameId, address indexed player2);
    event MoveMade(uint256 indexed gameId, address indexed player, uint8 column);
    event GameCompleted(uint256 indexed gameId, address indexed winner, uint256 prize);
    event FeesTransferred(address indexed owner, uint256 amount);

    function createGame(uint256 _betAmount, address _betToken, bool _openToPublic, address _specificAddress) public payable {
        require(_betToken == DEGEN_TOKEN || _betToken == address(0), "Invalid bet token");
        require(_betAmount > 0, "Bet amount must be greater than zero");

        if (_betToken == DEGEN_TOKEN) {
            IERC20(DEGEN_TOKEN).safeTransferFrom(msg.sender, address(this), _betAmount);
        } else {
            require(msg.value == _betAmount, "Bet amount mismatch");
        }

        gameCount++;
        games[gameCount] = Game(
            msg.sender,
            _openToPublic ? address(0) : _specificAddress,
            _betAmount,
            _betToken,
            [
                [0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0]
            ],
            1,
            false,
            _openToPublic

        );
        playerGames[msg.sender].push(gameCount);
        emit GameCreated(gameCount, msg.sender, _betAmount, _betToken, _openToPublic);
    }

    function joinGame(uint256 _gameId) public payable {
        Game storage game = games[_gameId];
        require(game.player1 != address(0), "Game does not exist");
        require(game.player2 == address(0) || game.player2 == msg.sender, "Game already joined or not open to public");
        require(!game.completed, "Game already completed");

        if (game.betToken == DEGEN_TOKEN) {
            IERC20(DEGEN_TOKEN).safeTransferFrom(msg.sender, address(this), game.betAmount);
        } else {
            require(msg.value == game.betAmount, "Bet amount mismatch");
        }

        game.player2 = msg.sender;
        playerGames[msg.sender].push(_gameId);
        emit GameJoined(_gameId, msg.sender);
    }

    function makeMove(uint256 _gameId, uint8 _column) public {
        Game storage game = games[_gameId];
        require(game.player1 != address(0), "Game does not exist");
        require(game.player2 != address(0), "Game not joined by second player");
        require(!game.completed, "Game already completed");
        require(msg.sender == game.player1 || msg.sender == game.player2, "Invalid player");
        require(game.currentPlayer == 1 ? msg.sender == game.player1 : msg.sender == game.player2, "Not your turn");
        require(_column < 7, "Invalid column");
        require(isValidMove(game.board, _column), "Invalid move");

        // Make the move
        for (uint8 i = 0; i < 6; i++) {
            if (game.board[_column][i] == 0) {
                game.board[_column][i] = game.currentPlayer;
                break;
            }
        }

        emit MoveMade(_gameId, msg.sender, _column);

        // Check for winner
        if (checkWinner(game.board, _column, game.currentPlayer)) {
            game.completed = true;
            uint256 prize = game.betAmount * 2;
            uint256 fee = (prize * FEE_PERCENTAGE) / 100;
            uint256 winnings = prize - fee;
            totalFees += fee;
            if (game.betToken == DEGEN_TOKEN) {
                IERC20(DEGEN_TOKEN).safeTransfer(msg.sender, winnings);
            } else {
                payable(msg.sender).transfer(winnings);
            }
            emit GameCompleted(_gameId, msg.sender, winnings);
            // Remove the completed game from playerGames mapping
            removeGameFromPlayerGames(game.player1, _gameId);
            removeGameFromPlayerGames(game.player2, _gameId);
            // Increment the winner's win count
            playerWins[msg.sender]++;
        } else {
            // Switch player
            game.currentPlayer = game.currentPlayer == 1 ? 2 : 1;
        }
    }

    function removeGameFromPlayerGames(address _player, uint256 _gameId) private {
        uint256[] storage games = playerGames[_player];
        for (uint256 i = 0; i < games.length; i++) {
            if (games[i] == _gameId) {
                games[i] = games[games.length - 1];
                games.pop();
                break;
            }
        }
    }

    event Log(string message, uint256 value);

    function isValidMove(uint8[6][7] memory _board, uint8 _column) private pure returns (bool) {
        return _board[_column][5] == 0;
    }

    function checkWinner(uint8[6][7] memory _board, uint8 _column, uint8 _player) private pure returns (bool) {
        uint8 row;
        // Find the row where the last chip was placed
        for (uint8 i = 5; i >= 0; i--) {
            if (_board[_column][i] == _player) {
                row = i;
                break;
            }
        }

        // Check horizontal
        uint8 count = 0;
        for (uint8 j = 0; j < 7; j++) {
            if (_board[j][row] == _player) {
                count++;
                if (count == 4) {
                    return true;
                }
            } else {
                count = 0;
            }
        }

        // Check vertical
        count = 0;
        for (uint8 i = 0; i < 6; i++) {
            if (_board[_column][i] == _player) {
                count++;
                if (count == 4) {
                    return true;
                }
            } else {
                count = 0;
            }
        }

        // Check diagonal (top-left to bottom-right)
        count = 0;
        int8 i = int8(row);
        int8 j = int8(_column);
        while (i >= 0 && j >= 0) {
            if (_board[uint8(j)][uint8(i)] == _player) {
                count++;
                if (count == 4) {
                    return true;
                }
            } else {
                count = 0;
            }
            i--;
            j--;
        }
        i = int8(row) + 1;
        j = int8(_column) + 1;
        while (i < 6 && j < 7) {
            if (_board[uint8(j)][uint8(i)] == _player) {
                count++;
                if (count == 4) {
                    return true;
                }
            } else {
                count = 0;
            }
            i++;
            j++;
        }

        // Check diagonal (bottom-left to top-right)
        count = 0;
        i = int8(row);
        j = int8(_column);
        while (i < 6 && j >= 0) {
            if (_board[uint8(j)][uint8(i)] == _player) {
                count++;
                if (count == 4) {
                    return true;
                }
            } else {
                count = 0;
            }
            i++;
            j--;
        }
        i = int8(row) - 1;
        j = int8(_column) + 1;
        while (i >= 0 && j < 7) {
            if (_board[uint8(j)][uint8(i)] == _player) {
                count++;
                if (count == 4) {
                    return true;
                }
            } else {
                count = 0;
            }
            i--;
            j++;
        }

        return false;
    }

    function getOpenGames() public view returns (uint256[] memory) {
        uint256[] memory openGames = new uint256[](gameCount);
        uint256 count = 0;

        for (uint256 i = 1; i <= gameCount; i++) {
            if ((games[i].player2 == address(0) || games[i].openToPublic) && !games[i].completed) {
                openGames[count] = i;
                count++;
            }
        }

        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = openGames[i];
        }

        return result;
    }

    function getGameState(uint256 _gameId) public view returns (address, address, uint256, address, uint8[6][7] memory, uint8, bool, bool) {
        Game storage game = games[_gameId];
        return (game.player1, game.player2, game.betAmount, game.betToken, game.board, game.currentPlayer, game.completed, game.openToPublic);
    }

    function getPlayerGames(address _player) public view returns (uint256[] memory) {
        return playerGames[_player];
    }

    function getPlayerGameState(address _player, uint256 _gameId) public view returns (uint8[6][7] memory, uint8, bool, bool) {
        Game storage game = games[_gameId];
        require(game.player1 == _player || game.player2 == _player, "Player not in the game");
        bool isPlayerTurn = (game.currentPlayer == 1 && game.player1 == _player) ||
                            (game.currentPlayer == 2 && game.player2 == _player);
        return (game.board, game.currentPlayer, game.completed, isPlayerTurn);
    }

    function withdrawFees() public onlyOwner {
        uint256 amount = totalFees;
        totalFees = 0;
        payable(owner()).transfer(amount);
        emit FeesTransferred(owner(), amount);
    }
}