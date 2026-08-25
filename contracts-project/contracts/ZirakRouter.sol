// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./interfaces/IERC20.sol";
import "./interfaces/IWBNB.sol";
import "./interfaces/IZirakFactory.sol";
import "./interfaces/IZirakPair.sol";
import "./libraries/ZirakLibrary.sol";
import "./libraries/TransferHelper.sol";

/// @notice The contract users/frontends actually call. Pulls the input token from the
/// caller, forwards it straight to the relevant pair, and asks the pair to send the
/// output token straight back to the caller — all inside one transaction. Nothing is
/// ever left "approved and sitting" for later withdrawal by anyone.
contract ZirakRouter {
    address public immutable factory;
    address public immutable WBNB;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "ZirakSwap: EXPIRED");
        _;
    }

    constructor(address _factory, address _WBNB) {
        factory = _factory;
        WBNB = _WBNB;
    }

    receive() external payable {
        assert(msg.sender == WBNB);
    }

    // ---------------------------------------------------------------
    // Liquidity
    // ---------------------------------------------------------------

    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal returns (uint256 amountA, uint256 amountB) {
        if (IZirakFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            IZirakFactory(factory).createPair(tokenA, tokenB);
        }
        (uint256 reserveA, uint256 reserveB) = ZirakLibrary.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = ZirakLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "ZirakSwap: INSUFFICIENT_B_AMOUNT");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = ZirakLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, "ZirakSwap: INSUFFICIENT_A_AMOUNT");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = ZirakLibrary.pairFor(factory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IZirakPair(pair).mint(to);
    }

    function addLiquidityBNB(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountBNBMin,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) returns (uint256 amountToken, uint256 amountBNB, uint256 liquidity) {
        (amountToken, amountBNB) =
            _addLiquidity(token, WBNB, amountTokenDesired, msg.value, amountTokenMin, amountBNBMin);
        address pair = ZirakLibrary.pairFor(factory, token, WBNB);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWBNB(WBNB).deposit{value: amountBNB}();
        require(IWBNB(WBNB).transfer(pair, amountBNB));
        liquidity = IZirakPair(pair).mint(to);
        if (msg.value > amountBNB) TransferHelper.safeTransferBNB(msg.sender, msg.value - amountBNB);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) public ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        address pair = ZirakLibrary.pairFor(factory, tokenA, tokenB);
        IZirakPair(pair).transferFrom(msg.sender, pair, liquidity);
        (uint256 amount0, uint256 amount1) = IZirakPair(pair).burn(to);
        (address token0, ) = ZirakLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, "ZirakSwap: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "ZirakSwap: INSUFFICIENT_B_AMOUNT");
    }

    // ---------------------------------------------------------------
    // Swaps
    // ---------------------------------------------------------------

    function _swap(uint256[] memory amounts, address[] memory path, address _to) internal {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = ZirakLibrary.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) =
                input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
            address to = i < path.length - 2 ? ZirakLibrary.pairFor(factory, output, path[i + 2]) : _to;
            IZirakPair(ZirakLibrary.pairFor(factory, input, output)).swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    /// @notice The main swap entry point: exact input amount in, minimum acceptable output enforced.
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        amounts = ZirakLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "ZirakSwap: INSUFFICIENT_OUTPUT_AMOUNT");
        TransferHelper.safeTransferFrom(path[0], msg.sender, ZirakLibrary.pairFor(factory, path[0], path[1]), amountIn);
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        amounts = ZirakLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, "ZirakSwap: EXCESSIVE_INPUT_AMOUNT");
        TransferHelper.safeTransferFrom(path[0], msg.sender, ZirakLibrary.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }

    function swapExactBNBForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        payable
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        require(path[0] == WBNB, "ZirakSwap: INVALID_PATH");
        amounts = ZirakLibrary.getAmountsOut(factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "ZirakSwap: INSUFFICIENT_OUTPUT_AMOUNT");
        IWBNB(WBNB).deposit{value: amounts[0]}();
        require(IWBNB(WBNB).transfer(ZirakLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
    }

    function swapExactTokensForBNB(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        require(path[path.length - 1] == WBNB, "ZirakSwap: INVALID_PATH");
        amounts = ZirakLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "ZirakSwap: INSUFFICIENT_OUTPUT_AMOUNT");
        TransferHelper.safeTransferFrom(path[0], msg.sender, ZirakLibrary.pairFor(factory, path[0], path[1]), amountIn);
        _swap(amounts, path, address(this));
        IWBNB(WBNB).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferBNB(to, amounts[amounts.length - 1]);
    }

    // ---------------------------------------------------------------
    // View helpers (handy for the frontend to show quotes before swapping)
    // ---------------------------------------------------------------

    function getAmountsOut(uint256 amountIn, address[] memory path) external view returns (uint256[] memory amounts) {
        return ZirakLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint256 amountOut, address[] memory path) external view returns (uint256[] memory amounts) {
        return ZirakLibrary.getAmountsIn(factory, amountOut, path);
    }
}
