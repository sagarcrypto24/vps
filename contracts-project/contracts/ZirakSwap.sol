// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @notice Minimal ERC20 interface for USDT/SHIB.
interface IERC20 {
    function balanceOf(address owner) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

/// @notice The subset of PancakeSwap's Router02 interface we actually call.
interface IPancakeRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

/// @notice Safe wrappers for ERC20 calls — needed because some tokens (like USDT)
/// don't strictly return a bool.
library TransferHelper {
    function safeApprove(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(bytes4(keccak256(bytes("approve(address,uint256)"))), to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "ZirakSwap: APPROVE_FAILED");
    }

    function safeTransferFrom(address token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(bytes4(keccak256(bytes("transferFrom(address,address,uint256)"))), from, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "ZirakSwap: TRANSFER_FROM_FAILED");
    }
}

/// @title ZirakSwap (PancakeSwap-routed)
/// @notice This contract does NOT hold its own liquidity. Every swap the user
/// requests is forwarded, in the same transaction, to PancakeSwap's own Router —
/// which already has deep, real USDT/SHIB liquidity from thousands of independent
/// liquidity providers. You never need to fund a pool yourself.
///
/// Flow for one swap:
///   1. User approves THIS contract to spend their USDT (or SHIB) — only the exact amount.
///   2. User calls swapUSDTForSHIB(...).
///   3. This contract pulls that exact amount in, approves PancakeSwap's router for
///      that exact amount, and asks the router to send the output token straight
///      to the user's own wallet.
///   4. Nothing is ever left sitting in this contract, and no one — including the
///      contract owner — can move a user's funds outside of this one atomic flow.
contract ZirakSwap {
    IPancakeRouter public immutable pancakeRouter;
    address public immutable tokenUSDT;
    address public immutable tokenSHIB;

    event Swap(address indexed user, address tokenIn, uint256 amountIn, address tokenOut, uint256 amountOut);

    constructor(address _pancakeRouter, address _usdt, address _shib) {
        require(_pancakeRouter != address(0) && _usdt != address(0) && _shib != address(0), "ZirakSwap: ZERO_ADDRESS");
        pancakeRouter = IPancakeRouter(_pancakeRouter);
        tokenUSDT = _usdt;
        tokenSHIB = _shib;
    }

    /// @notice Swap an exact amount of USDT for SHIB, routed through PancakeSwap's liquidity.
    /// @param usdtIn Exact amount of USDT to spend (user must have approved this contract for this amount).
    /// @param minShibOut Your slippage protection — transaction reverts if you'd get less than this.
    /// @param deadline Unix timestamp after which the transaction is no longer valid.
    function swapUSDTForSHIB(uint256 usdtIn, uint256 minShibOut, uint256 deadline)
        external
        returns (uint256 shibOut)
    {
        require(usdtIn > 0, "ZirakSwap: ZERO_INPUT");

        // 1) Pull the exact input amount from the user into this contract.
        TransferHelper.safeTransferFrom(tokenUSDT, msg.sender, address(this), usdtIn);

        // 2) Approve PancakeSwap's router for exactly this amount (never more).
        TransferHelper.safeApprove(tokenUSDT, address(pancakeRouter), usdtIn);

        // 3) Ask PancakeSwap to do the actual swap, sending the output straight to the user.
        address[] memory path = new address[](2);
        path[0] = tokenUSDT;
        path[1] = tokenSHIB;

        uint256[] memory amounts =
            pancakeRouter.swapExactTokensForTokens(usdtIn, minShibOut, path, msg.sender, deadline);
        shibOut = amounts[amounts.length - 1];

        emit Swap(msg.sender, tokenUSDT, usdtIn, tokenSHIB, shibOut);
    }

    /// @notice Swap an exact amount of SHIB for USDT, routed through PancakeSwap's liquidity.
    function swapSHIBForUSDT(uint256 shibIn, uint256 minUsdtOut, uint256 deadline)
        external
        returns (uint256 usdtOut)
    {
        require(shibIn > 0, "ZirakSwap: ZERO_INPUT");

        TransferHelper.safeTransferFrom(tokenSHIB, msg.sender, address(this), shibIn);
        TransferHelper.safeApprove(tokenSHIB, address(pancakeRouter), shibIn);

        address[] memory path = new address[](2);
        path[0] = tokenSHIB;
        path[1] = tokenUSDT;

        uint256[] memory amounts =
            pancakeRouter.swapExactTokensForTokens(shibIn, minUsdtOut, path, msg.sender, deadline);
        usdtOut = amounts[amounts.length - 1];

        emit Swap(msg.sender, tokenSHIB, shibIn, tokenUSDT, usdtOut);
    }

    /// @notice Live quote — how much SHIB you'd get for a given USDT input, right now.
    function quoteUSDTToSHIB(uint256 usdtIn) external view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = tokenUSDT;
        path[1] = tokenSHIB;
        uint256[] memory amounts = pancakeRouter.getAmountsOut(usdtIn, path);
        return amounts[amounts.length - 1];
    }

    /// @notice Live quote — how much USDT you'd get for a given SHIB input, right now.
    function quoteSHIBToUSDT(uint256 shibIn) external view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = tokenSHIB;
        path[1] = tokenUSDT;
        uint256[] memory amounts = pancakeRouter.getAmountsOut(shibIn, path);
        return amounts[amounts.length - 1];
    }
}
