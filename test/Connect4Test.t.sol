// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ConnectFour.sol";
import "../src/TestToken.sol";

contract Connect4Test is Test {
    Connect4 public connect4;
    TestToken public token;

    address player1 = address(1);
    address player2 = address(2);
    address player3 = address(3);

    function setUp() public {
        connect4 = new Connect4();
        token = new TestToken();

        // Mint tokens to player1, player2, and player3
        token.transfer(player1, 1000);
        token.transfer(player2, 1000);
        token.transfer(player3, 1000);
    }

    function testCreateGame() public {
        vm.startPrank(player1);
        token.approve(address(connect4), 100);
        connect4.createGame(100, address(token), true, address(0));
        vm.stopPrank();

        (address p1, address p2, uint256 betAmount, address betToken, , , bool completed, bool openToPublic) = connect4.getGameState(1);

        assertEq(p1, player1, "Player 1 should be the creator");
        assertEq(p2, address(0), "Player 2 should be zero address");
        assertEq(betAmount, 100, "Bet amount should be 100");
        assertEq(betToken, address(token), "Bet token should be the TestToken");
        assertFalse(completed, "Game should not be completed");
        assertTrue(openToPublic, "Game should be open to public");
    }

    function testJoinGame() public {
        vm.startPrank(player1);
        token.approve(address(connect4), 100);
        connect4.createGame(100, address(token), true, address(0));
        vm.stopPrank();

        vm.startPrank(player2);
        token.approve(address(connect4), 100);
        connect4.joinGame(1);
        vm.stopPrank();

        (, address p2, , , , , , ) = connect4.getGameState(1);
        assertEq(p2, player2, "Player 2 should have joined the game");
    }

    function testMakeMove() public {
        vm.startPrank(player1);
        token.approve(address(connect4), 100);
        connect4.createGame(100, address(token), true, address(0));
        vm.stopPrank();

        vm.startPrank(player2);
        token.approve(address(connect4), 100);
        connect4.joinGame(1);
        vm.stopPrank();

        vm.prank(player1);
        connect4.makeMove(1, 3);

        (, , , , uint8[6][7] memory board, , , ) = connect4.getGameState(1);
        assertEq(board[3][0], 1, "Player 1 should have made a move in column 3");
    }

    function testInvalidMove() public {
        vm.startPrank(player1);
        token.approve(address(connect4), 100);
        connect4.createGame(100, address(token), true, address(0));
        vm.stopPrank();

        vm.startPrank(player2);
        token.approve(address(connect4), 100);
        connect4.joinGame(1);
        vm.stopPrank();

        // row 0
        vm.prank(player1);
        connect4.makeMove(1, 3);
        
        // row 1
        vm.prank(player2);
        connect4.makeMove(1, 3);

        // row 2
        vm.prank(player1);
        connect4.makeMove(1, 3);

        // row 3
        vm.prank(player2);
        connect4.makeMove(1, 3);

        // row 4
        vm.prank(player1);
        connect4.makeMove(1, 3);

        // row 5 
        vm.prank(player2);
        connect4.makeMove(1, 3);

        // invalid move 
        vm.prank(player1);
        vm.expectRevert("Invalid move");
        connect4.makeMove(1, 3);
    }

    function testNotPlayerTurn() public {
        vm.startPrank(player1);
        token.approve(address(connect4), 100);
        connect4.createGame(100, address(token), true, address(0));
        vm.stopPrank();

        vm.startPrank(player2);
        token.approve(address(connect4), 100);
        connect4.joinGame(1);
        vm.stopPrank();

        vm.prank(player1);
        connect4.makeMove(1, 3);

        vm.prank(player1);
        vm.expectRevert("Not your turn");
        connect4.makeMove(1, 4);
    }

    function testGameCompletion() public {
        vm.startPrank(player1);
        token.approve(address(connect4), 100);
        connect4.createGame(100, address(token), true, address(0));
        vm.stopPrank();

        vm.startPrank(player2);
        token.approve(address(connect4), 100);
        connect4.joinGame(1);
        vm.stopPrank();

        // Make winning moves for player1
        vm.prank(player1);
        connect4.makeMove(1, 0);
        vm.prank(player2);
        connect4.makeMove(1, 1);
        vm.prank(player1);
        connect4.makeMove(1, 0);
        vm.prank(player2);
        connect4.makeMove(1, 1);
        vm.prank(player1);
        connect4.makeMove(1, 0);
        vm.prank(player2);
        connect4.makeMove(1, 1);
        vm.prank(player1);
        connect4.makeMove(1, 0);

        (, , , , , , bool completed, ) = connect4.getGameState(1);
        assertTrue(completed, "Game should be completed");
    }

    function testWithdrawFees() public {
        vm.startPrank(player1);
        token.approve(address(connect4), 100);
        connect4.createGame(100, address(token), true, address(0));
        vm.stopPrank();

        vm.startPrank(player2);
        token.approve(address(connect4), 100);
        connect4.joinGame(1);
        vm.stopPrank();

        // Make winning moves for player1
        vm.prank(player1);
        connect4.makeMove(1, 0);
        vm.prank(player2);
        connect4.makeMove(1, 1);
        vm.prank(player1);
        connect4.makeMove(1, 0);
        vm.prank(player2);
        connect4.makeMove(1, 1);
        vm.prank(player1);
        connect4.makeMove(1, 0);
        vm.prank(player2);
        connect4.makeMove(1, 1);
        vm.prank(player1);
        connect4.makeMove(1, 0);

        uint256 initialBalance = token.balanceOf(address(this));
        connect4.withdrawFees();
        uint256 finalBalance = token.balanceOf(address(this));

        assertEq(finalBalance - initialBalance, 6, "Fees should be transferred to the owner");
    }

    function testGetOpenGames() public {
        vm.startPrank(player1);
        token.approve(address(connect4), 100);
        connect4.createGame(100, address(token), true, address(0));
        vm.stopPrank();

        vm.startPrank(player2);
        token.approve(address(connect4), 200);
        connect4.createGame(200, address(token), false, player3);
        vm.stopPrank();

        uint256[] memory openGames = connect4.getOpenGames();
        assertEq(openGames.length, 1, "There should be 1 open game");
        assertEq(openGames[0], 1, "Game 1 should be open");
    }

    function testGetPlayerGames() public {
        vm.startPrank(player1);
        token.approve(address(connect4), 100);
        connect4.createGame(100, address(token), true, address(0));
        vm.stopPrank();

        vm.startPrank(player2);
        token.approve(address(connect4), 200);
        connect4.createGame(200, address(token), false, player3);
        vm.stopPrank();

        uint256[] memory player1Games = connect4.getPlayerGames(player1);
        assertEq(player1Games.length, 1, "Player 1 should have 1 game");
        assertEq(player1Games[0], 1, "Game 1 should belong to player 1");

        uint256[] memory player2Games = connect4.getPlayerGames(player2);
        assertEq(player2Games.length, 1, "Player 2 should have 1 game");
        assertEq(player2Games[0], 2, "Game 2 should belong to player 2");
    }

    function testGetPlayerGameState() public {
        vm.startPrank(player1);
        token.approve(address(connect4), 100);
        connect4.createGame(100, address(token), true, address(0));
        vm.stopPrank();

        vm.startPrank(player2);
        token.approve(address(connect4), 100);
        connect4.joinGame(1);
        vm.stopPrank();

        (, uint8 currentPlayer, bool completed, bool isPlayerTurn) = connect4.getPlayerGameState(player1, 1);
        assertEq(currentPlayer, 1, "Current player should be player 1");
        assertFalse(completed, "Game should not be completed");
        assertTrue(isPlayerTurn, "It should be player 1's turn");
    }
}