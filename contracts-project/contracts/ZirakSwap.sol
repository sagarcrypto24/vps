// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @notice Minimal ERC20 interface to talk to USDT/SHIB (and any BEP-20 token).
interface IERC20 {
    function balanceOf(address owner) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

/// @notice Safe wrappers for ERC20 calls — needed because some tokens (like USDT)
/// don't strictly return a bool from transfer/transferFrom.
library TransferHelper {
    function safeTransfer(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(bytes4(keccak256(bytes("transfer(address,uint256)"))), to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "ZirakSwap: TRANSFER_FAILED");
    }

    function safeTransferFrom(address token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(bytes4(keccak256(bytes("transferFrom(address,address,uint256)"))), from, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "ZirakSwap: TRANSFER_FROM_FAILED");
    }
}

library Math {
    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x < y ? x : y;
    }

    // babylonian method
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

/// @title ZirakSwap
/// @notice ONE single contract: a fixed USDT <-> SHIB liquidity pool with swap +
/// add/remove liquidity. Standard constant-product AMM (x*y=k), 0.3% trading fee.
/// No factory, no separate router, no admin who can pull user funds — every swap
/// is atomic: the user's input token comes in and their output token goes out in
/// the very same transaction, enforced by the contract's own math.
contract ZirakSwap {
    string public constant name = "ZirakSwap LP Token";
    string public constant symbol = "ZIRAK-LP";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    uint256 public constant MINIMUM_LIQUIDITY = 10**3;

    address public immutable tokenUSDT;
    address public immutable tokenSHIB;

    uint256 public reserveUSDT;
    uint256 public reserveSHIB;

    uint256 private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "ZirakSwap: LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    event Mint(address indexed provider, uint256 amountUSDT, uint256 amountSHIB, uint256 liquidity);
    event Burn(address indexed provider, uint256 amountUSDT, uint256 amountSHIB, uint256 liquidity);
    event Swap(address indexed user, address tokenIn, uint256 amountIn, address tokenOut, uint256 amountOut);
    event Sync(uint256 reserveUSDT, uint256 reserveSHIB);

    constructor(address _usdt, address _shib) {
        require(_usdt != address(0) && _shib != address(0), "ZirakSwap: ZERO_ADDRESS");
        tokenUSDT = _usdt;
        tokenSHIB = _shib;
    }

    // -----------------------------------------------------------------
    // Liquidity
    // -----------------------------------------------------------------

    /// @notice Deposit USDT + SHIB, receive LP shares representing your slice of the pool.
    function addLiquidity(
        uint256 amountUSDTDesired,
        uint256 amountSHIBDesired,
        uint256 amountUSDTMin,
        uint256 amountSHIBMin,
        uint256 deadline
    ) external lock returns (uint256 amountUSDT, uint256 amountSHIB, uint256 liquidity) {
        require(block.timestamp <= deadline, "ZirakSwap: EXPIRED");

        if (reserveUSDT == 0 && reserveSHIB == 0) {
            (amountUSDT, amountSHIB) = (amountUSDTDesired, amountSHIBDesired);
        } else {
            uint256 shibOptimal = (amountUSDTDesired * reserveSHIB) / reserveUSDT;
            if (shibOptimal <= amountSHIBDesired) {
                require(shibOptimal >= amountSHIBMin, "ZirakSwap: INSUFFICIENT_SHIB");
                (amountUSDT, amountSHIB) = (amountUSDTDesired, shibOptimal);
            } else {
                uint256 usdtOptimal = (amountSHIBDesired * reserveUSDT) / reserveSHIB;
                require(usdtOptimal >= amountUSDTMin, "ZirakSwap: INSUFFICIENT_USDT");
                (amountUSDT, amountSHIB) = (usdtOptimal, amountSHIBDesired);
            }
        }

        TransferHelper.safeTransferFrom(tokenUSDT, msg.sender, address(this), amountUSDT);
        TransferHelper.safeTransferFrom(tokenSHIB, msg.sender, address(this), amountSHIB);

        uint256 _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amountUSDT * amountSHIB) - MINIMUM_LIQUIDITY;
            _mint(address(0xdead), MINIMUM_LIQUIDITY); // permanently locked, prevents share-price manipulation
        } else {
            liquidity = Math.min((amountUSDT * _totalSupply) / reserveUSDT, (amountSHIB * _totalSupply) / reserveSHIB);
        }
        require(liquidity > 0, "ZirakSwap: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(msg.sender, liquidity);

        reserveUSDT += amountUSDT;
        reserveSHIB += amountSHIB;
        emit Mint(msg.sender, amountUSDT, amountSHIB, liquidity);
        emit Sync(reserveUSDT, reserveSHIB);
    }

    /// @notice Burn your LP shares, get back your proportional USDT + SHIB.
    function removeLiquidity(
        uint256 liquidity,
        uint256 amountUSDTMin,
        uint256 amountSHIBMin,
        uint256 deadline
    ) external lock returns (uint256 amountUSDT, uint256 amountSHIB) {
        require(block.timestamp <= deadline, "ZirakSwap: EXPIRED");
        uint256 _totalSupply = totalSupply;
        amountUSDT = (liquidity * reserveUSDT) / _totalSupply;
        amountSHIB = (liquidity * reserveSHIB) / _totalSupply;
        require(amountUSDT >= amountUSDTMin && amountSHIB >= amountSHIBMin, "ZirakSwap: INSUFFICIENT_OUTPUT");

        _burn(msg.sender, liquidity);
        reserveUSDT -= amountUSDT;
        reserveSHIB -= amountSHIB;

        TransferHelper.safeTransfer(tokenUSDT, msg.sender, amountUSDT);
        TransferHelper.safeTransfer(tokenSHIB, msg.sender, amountSHIB);

        emit Burn(msg.sender, amountUSDT, amountSHIB, liquidity);
        emit Sync(reserveUSDT, reserveSHIB);
    }

    // -----------------------------------------------------------------
    // Swap
    // -----------------------------------------------------------------

    /// @notice Swap an exact amount of USDT for SHIB. Reverts if the output would be
    /// less than `minShibOut` (your slippage protection).
    function swapUSDTForSHIB(uint256 usdtIn, uint256 minShibOut, uint256 deadline)
        external
        lock
        returns (uint256 shibOut)
    {
        require(block.timestamp <= deadline, "ZirakSwap: EXPIRED");
        require(usdtIn > 0, "ZirakSwap: ZERO_INPUT");

        shibOut = getAmountOut(usdtIn, reserveUSDT, reserveSHIB);
        require(shibOut >= minShibOut, "ZirakSwap: SLIPPAGE");
        require(shibOut < reserveSHIB, "ZirakSwap: INSUFFICIENT_LIQUIDITY");

        TransferHelper.safeTransferFrom(tokenUSDT, msg.sender, address(this), usdtIn);
        TransferHelper.safeTransfer(tokenSHIB, msg.sender, shibOut);

        reserveUSDT += usdtIn;
        reserveSHIB -= shibOut;

        emit Swap(msg.sender, tokenUSDT, usdtIn, tokenSHIB, shibOut);
        emit Sync(reserveUSDT, reserveSHIB);
    }

    /// @notice Swap an exact amount of SHIB for USDT.
    function swapSHIBForUSDT(uint256 shibIn, uint256 minUsdtOut, uint256 deadline)
        external
        lock
        returns (uint256 usdtOut)
    {
        require(block.timestamp <= deadline, "ZirakSwap: EXPIRED");
        require(shibIn > 0, "ZirakSwap: ZERO_INPUT");

        usdtOut = getAmountOut(shibIn, reserveSHIB, reserveUSDT);
        require(usdtOut >= minUsdtOut, "ZirakSwap: SLIPPAGE");
        require(usdtOut < reserveUSDT, "ZirakSwap: INSUFFICIENT_LIQUIDITY");

        TransferHelper.safeTransferFrom(tokenSHIB, msg.sender, address(this), shibIn);
        TransferHelper.safeTransfer(tokenUSDT, msg.sender, usdtOut);

        reserveSHIB += shibIn;
        reserveUSDT -= usdtOut;

        emit Swap(msg.sender, tokenSHIB, shibIn, tokenUSDT, usdtOut);
        emit Sync(reserveUSDT, reserveSHIB);
    }

    // -----------------------------------------------------------------
    // View helpers (frontend uses these to show live quotes before swapping)
    // -----------------------------------------------------------------

    /// @notice Constant-product formula with 0.3% fee baked in — same math PancakeSwap/Uniswap use.
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "ZirakSwap: ZERO_INPUT");
        require(reserveIn > 0 && reserveOut > 0, "ZirakSwap: NO_LIQUIDITY");
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function quoteUSDTToSHIB(uint256 usdtIn) external view returns (uint256) {
        return getAmountOut(usdtIn, reserveUSDT, reserveSHIB);
    }

    function quoteSHIBToUSDT(uint256 shibIn) external view returns (uint256) {
        return getAmountOut(shibIn, reserveSHIB, reserveUSDT);
    }

    // -----------------------------------------------------------------
    // LP token bookkeeping (kept inline — this IS the one contract)
    // -----------------------------------------------------------------

    function _mint(address to, uint256 value) private {
        totalSupply += value;
        balanceOf[to] += value;
    }

    function _burn(address from, uint256 value) private {
        balanceOf[from] -= value;
        totalSupply -= value;
    }
}
