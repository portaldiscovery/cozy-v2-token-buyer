// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;

import 'forge-std/Test.sol';
import { SafeCast } from 'openzeppelin-contracts/contracts/utils/math/SafeCast.sol';
import { AggregatorV3Interface } from 'token-buyer/src/AggregatorV3Interface.sol';
import { TokenBuyer } from 'token-buyer/src/TokenBuyer.sol';
import { Payer } from 'token-buyer/src/Payer.sol';
import { TestChainlinkAggregator } from 'token-buyer/test/helpers/TestChainlinkAggregator.sol';
import { CozyMultiOraclePriceFeed } from 'src/CozyMultiOraclePriceFeed.sol';
import { TestCozySet } from 'test/helpers/TestCozySet.sol';
import { IPToken } from 'src/IPToken.sol';
import { ISet } from 'src/ISet.sol';

contract CozyMultiOraclePriceFeedTest is Test {
    uint256 constant STALE_AFTER = 42 hours;
    uint256 constant BID_PRICE = 2e16; // i.e. $2 per $100 of protection
    address owner;

    CozyMultiOraclePriceFeed feed;
    TestChainlinkAggregator chainlinkA;
    TestChainlinkAggregator chainlinkB;
    TestCozySet set;

    function setUp() public {
        owner = address(this);
        chainlinkA = new TestChainlinkAggregator(8);
        chainlinkB = new TestChainlinkAggregator(8);
        set = new TestCozySet();
        set.setDecimals(6);
        feed = new CozyMultiOraclePriceFeed(set, 0, chainlinkA, chainlinkB, STALE_AFTER, STALE_AFTER, BID_PRICE, owner);
    }

    function test_price_decimalsEqualWAD() public {
        set.setConvertToPTokens(100e6);
        chainlinkA.setDecimals(18);
        chainlinkA.setLatestRound(1000e18, block.timestamp);
        chainlinkB.setDecimals(18);
        chainlinkB.setLatestRound(1e18, block.timestamp);
        feed = new CozyMultiOraclePriceFeed(set, 0, chainlinkA, chainlinkB, STALE_AFTER, STALE_AFTER, BID_PRICE, owner);

        assertEq(feed.price(), 100e18);
    }

    function test_price_decimalsBelowWAD() public {
        set.setConvertToPTokens(100e6);
        chainlinkA.setDecimals(16);
        chainlinkA.setLatestRound(1000e16, block.timestamp);
        chainlinkB.setDecimals(16);
        chainlinkB.setLatestRound(1e16, block.timestamp);
        feed = new CozyMultiOraclePriceFeed(set, 0, chainlinkA, chainlinkB, STALE_AFTER, STALE_AFTER, BID_PRICE, owner);

        assertEq(feed.price(), 100e18);
    }

    function test_price_decimalsAboveWAD() public {
        set.setConvertToPTokens(100e6);
        chainlinkA.setDecimals(21);
        chainlinkA.setLatestRound(1000e21, block.timestamp);
        chainlinkB.setDecimals(21);
        chainlinkB.setLatestRound(1e21, block.timestamp);
        feed = new CozyMultiOraclePriceFeed(set, 0, chainlinkA, chainlinkB, STALE_AFTER, STALE_AFTER, BID_PRICE, owner);

        assertEq(feed.price(), 100e18);
    }

    function test_price_convertToPTokensZero() public {
        set.setConvertToPTokens(0);
        chainlinkA.setDecimals(8);
        chainlinkA.setLatestRound(1000e8, block.timestamp);
        chainlinkB.setDecimals(8);
        chainlinkB.setLatestRound(1e8, block.timestamp);
        feed = new CozyMultiOraclePriceFeed(set, 0, chainlinkA, chainlinkB, STALE_AFTER, STALE_AFTER, BID_PRICE, owner);

        assertEq(feed.price(), 0);
    }

    function test_price_convertToPTokensOne() public {
        // The PToken has the same decimals as the Set, and the underlying asset of the Set.
        // So here 1 == 0.000001e6 == 0.000001 PTokens
        set.setConvertToPTokens(1);
        chainlinkA.setDecimals(8);
        chainlinkA.setLatestRound(1000e8, block.timestamp);
        chainlinkB.setDecimals(8);
        chainlinkB.setLatestRound(1e8, block.timestamp);
        feed = new CozyMultiOraclePriceFeed(set, 0, chainlinkA, chainlinkB, STALE_AFTER, STALE_AFTER, BID_PRICE, owner);

        // e.g. If chainlinkA is ETH/USD, chainlinkB is USDC/USD, and USDC is pegged to $1 USD (1e8):
        // USD Price per 1 ETH / bid price percentage = Protection value of PTokens for 1 ETH
        // 1000 USD per 1 ETH * 1e18/0.02e18 = 50000 USD
        // 50000 USD of ETH is equal to 0.000001e6 PTokens
        assertEq(feed.price(), 0.000001e18);
    }

    function test_price_zeroChainlinkAPriceReverts() public {
        chainlinkA.setLatestRound(1234, block.timestamp);
        chainlinkB.setLatestRound(0, block.timestamp);
        vm.expectRevert(CozyMultiOraclePriceFeed.ChainlinkBPriceZero.selector);
        feed.price();
    }

    function test_price_zeroBidPriceWADReverts() public {
        chainlinkA.setLatestRound(1234, block.timestamp);
        chainlinkB.setLatestRound(1234, block.timestamp);
        feed.setBidPriceWAD(0);
        vm.expectRevert(CozyMultiOraclePriceFeed.BidPriceWADZero.selector);
        feed.price();
    }

    function test_price_negativePriceReverts() public {
        chainlinkA.setLatestRound(-1234, block.timestamp);
        chainlinkB.setLatestRound(1234, block.timestamp);
        vm.expectRevert('SafeCast: value must be positive');
        feed.price();

        chainlinkA.setLatestRound(1234, block.timestamp);
        chainlinkB.setLatestRound(-1234, block.timestamp);
        vm.expectRevert('SafeCast: value must be positive');
        feed.price();
    }

    function test_price_stalePriceReverts() public {
        uint256 staleTime_ = block.timestamp - STALE_AFTER - 1;

        chainlinkA.setLatestRound(1234, staleTime_);
        chainlinkB.setLatestRound(1234, block.timestamp);
        vm.expectRevert(abi.encodeWithSelector(CozyMultiOraclePriceFeed.StaleOracle.selector, address(chainlinkA), staleTime_));
        feed.price();

        chainlinkA.setLatestRound(1234, block.timestamp);
        chainlinkB.setLatestRound(1234, staleTime_);
        vm.expectRevert(abi.encodeWithSelector(CozyMultiOraclePriceFeed.StaleOracle.selector, address(chainlinkB), staleTime_));
        feed.price();
    }

    function test_setBidPriceWAD() public {
        feed.setBidPriceWAD(0.8e18);
        assertEq(feed.bidPriceWAD(), 0.8e18);
    }

    function testFuzz_setBidPriceWADRevertsUnauthorized(address caller_) public {
        vm.assume(caller_ != owner);
        vm.prank(caller_);
        vm.expectRevert('Ownable: caller is not the owner');
        feed.setBidPriceWAD(0.5e18);
    }
}

contract CozyMultiOraclePriceFeedForkTest is Test {
    // On Optimism, this would be the L1Proxy contract which proxies transactions submitted from L1
    address constant OWNER = address(0xBEEF);
    uint256 constant PROTECTION_AMOUNT_USD = 1_000_000;

    uint256 forkId;

    ISet set;
    IPToken ptoken;
    uint16 marketId;

    CozyMultiOraclePriceFeed feed;
    uint256 bidPriceWAD;

    AggregatorV3Interface ethUsdOracle;
    AggregatorV3Interface usdcUsdOracle;
    uint256 staleAfterA;
    uint256 staleAfterB;

    Payer payer;
    TokenBuyer tokenBuyer;

    function setUp() public {
        uint256 optimismForkBlock = 101_113_658; // The optimism block number at the time this test was written
        forkId = vm.createSelectFork(vm.envString("OPTIMISM_RPC_URL"), optimismForkBlock);

        ethUsdOracle = AggregatorV3Interface(0x13e3Ee699D1909E989722E753853AE30b17e08c5);
        usdcUsdOracle = AggregatorV3Interface(0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3);
        staleAfterA = 1200;
        staleAfterB = 86400;

        set = ISet(0x17705474203F7ff7ba8a940c433AB43D1F58E249); // Set with USDC underlying
        ptoken = IPToken(0x3b548fbADC2d926AdB7e5A5d44d824a1c7F3614d); // stETH Peg PToken contract from the Set
        marketId = 3; // stETH Peg protection market

        feed = new CozyMultiOraclePriceFeed(
            set,
            3, // marketId
            ethUsdOracle,
            usdcUsdOracle,
            staleAfterA, // staleness threshold for ETH/USD
            staleAfterB, // staleness threshold for USDC/USD
            0,
            OWNER // owner
        );

        vm.prank(OWNER);
        bidPriceWAD = 0.02e18; // 2% per unit of protection
        feed.setBidPriceWAD(bidPriceWAD);

        uint256 protectionAmountUsdc_ = PROTECTION_AMOUNT_USD * (10 ** set.decimals());
        uint256 ptokensForProtectionAmount_ = set.convertToPTokens(marketId, protectionAmountUsdc_);

        payer = new Payer(OWNER, address(ptoken));

        // Inspired by token-buyer/script/DeployUSDC.s.sol
        tokenBuyer = new TokenBuyer(
            feed,
            ptokensForProtectionAmount_, // baselinePaymentTokenAmount
            0, // minAdminBaselinePaymentTokenAmount
            2 * ptokensForProtectionAmount_, // maxAdminBaselinePaymentTokenAmount
            10, // botDiscountBPs
            0, // minAdminBotDiscountBPs
            150, // maxAdminBotDiscountBPs
            OWNER, // owner
            OWNER, // admin
            address(payer)
        );
    }

    function test_set_sanityChecks() public {
        (IPToken ptoken_, address trigger_, , , , , , , , ) = set.markets(marketId);
        assertEq(address(ptoken_), address(ptoken)); // Address of the stETH Peg PToken contract
        assertEq(trigger_, 0xDc3e70904e88198903FbeE6C81cf90d0490D32B4); // Address of the stETH Peg Trigger contract
        assertEq(address(set.asset()), 0x7F5c764cBc14f9669B88837ca1490cCa17c31607); // USDC on Optimism
        assertEq(ptoken_.decimals(), set.decimals());
        assertEq(ptoken_.decimals(), 6); // USDC decimals
    }

    function test_price() public {
        (, int256 ethUsdPrice_, , , ) = ethUsdOracle.latestRoundData();
        (, int256 usdcUsdPrice_, , , ) = usdcUsdOracle.latestRoundData();
        assertEq(uint256(ethUsdPrice_), 1792.75977963e8); // 1 ETH == $1,792.75977963 USD
        assertEq(usdcUsdPrice_, 0.99990000e8); // 1e6 USDC == $0.9999 USD

        uint256 feedPriceEth_ = feed.price();
        assertEq(feedPriceEth_, 92212.296256e18); // 1 ETH is priced at 92212.296256e6 PTokens

        uint256 ptokensProtectionValueUsdc_ = set.convertToProtection(marketId, feedPriceEth_ / 1e12);
        assertEq(ptokensProtectionValueUsdc_, 89646.953675e6);

        // USDC protection value of PTokens * bid price percentage
        assertEq(ptokensProtectionValueUsdc_ * bidPriceWAD / 1e18, 1792.939073e6);

        // Result from above converted to USD ~= ethUsdPrice_ (some slight precision error due to rounding)
        assertEq(1792.939073e6 * usdcUsdPrice_ / 1e6, 1792.75977909e8);
    }

    function test_integration() public {
        (, int256 ethUsdPrice_, , , ) = ethUsdOracle.latestRoundData();
        (, int256 usdcUsdPrice_, , , ) = usdcUsdOracle.latestRoundData();
        assertEq(uint256(ethUsdPrice_), 1792.75977963e8);
        assertEq(uint256(usdcUsdPrice_), 0.9999e8);

        uint256 initTokenBuyerBalance_ = 1 ether;
        vm.deal(address(tokenBuyer), initTokenBuyerBalance_);

        // An existing PToken holder on the fork
        address ptokenHolder_ = 0x10647fd7eB21F50D461FC9C939cf41e7fe457Bd7;
        assertEq(ptoken.balanceOf(ptokenHolder_), 60066.237623e6);
        assertEq(ptoken.balanceOfMatured(ptokenHolder_), 60066.237623e6);
        uint256 ptokenSellAmount_ = 100e6; // Sell 100 PTokens to TokenBuyer

        uint256 ptokensValueUsdc_ = set.convertToProtection(marketId, ptokenSellAmount_);
        assertEq(ptokensValueUsdc_, 97.218003e6);
        uint256 ptokensValueUsd_ = ptokensValueUsdc_ * uint256(usdcUsdPrice_) / 1e6;
        assertEq(ptokensValueUsd_, 97.20828119e8); // Approx $97.21 USD of protection was bought

        vm.startPrank(ptokenHolder_);
        ptoken.approve(address(tokenBuyer), 60066.237623e6);
        tokenBuyer.buyETH(ptokenSellAmount_);
        vm.stopPrank();

        uint256 ethPaid_ = initTokenBuyerBalance_ - address(tokenBuyer).balance;
        assertEq(ethPaid_, 0.001085539609839038e18);

        uint256 ethPaidInUsd_ = ethPaid_ * uint256(ethUsdPrice_) / 1e18;
        // Approx 2% paid for the PTokens (some slight precision error due to rounding)
        assertEq(ethPaidInUsd_ * 1e18 / ptokensValueUsd_, 0.020020020168818705e18);

        // Payer received the PTokens
        assertEq(ptoken.balanceOf(address(payer)), ptokenSellAmount_);
    }

    function test_integration_largeAmountPTokens() public {
        (, int256 ethUsdPrice_, , , ) = ethUsdOracle.latestRoundData();
        (, int256 usdcUsdPrice_, , , ) = usdcUsdOracle.latestRoundData();
        assertEq(uint256(ethUsdPrice_), 1792.75977963e8);
        assertEq(uint256(usdcUsdPrice_), 0.9999e8);

        uint256 initTokenBuyerBalance_ = 15 ether;
        vm.deal(address(tokenBuyer), initTokenBuyerBalance_);

        address ptokenHolder_ = address(0xBEEF);
        uint256 ptokenHolderBalance_ = 1_000_000e6; // 1 million ptokens
        deal(address(ptoken), ptokenHolder_, ptokenHolderBalance_);
        uint256 ptokenSellAmount_ = ptokenHolderBalance_; // Sell 1 million ptokens

        uint256 ptokensValueUsdc_ = set.convertToProtection(marketId, ptokenSellAmount_);
        assertEq(ptokensValueUsdc_, 972_180.037974e6);
        uint256 ptokensValueUsd_ = ptokensValueUsdc_ * uint256(usdcUsdPrice_) / 1e6;
        assertEq(ptokensValueUsd_, 972_082.81997020e8); // Approx $1_944_165 USD of protection

        vm.startPrank(ptokenHolder_);
        ptoken.approve(address(tokenBuyer), ptokenSellAmount_);
        tokenBuyer.buyETH(ptokenSellAmount_);
        vm.stopPrank();

        uint256 ethPaid_ = initTokenBuyerBalance_ - address(tokenBuyer).balance;
        assertEq(ethPaid_, 10.855396098390388195e18);

        uint256 ethPaidInUsd_ = ethPaid_ * uint256(ethUsdPrice_) / 1e18;
        // Approx 2% paid for the PTokens (some slight precision error due to rounding)
        assertEq(ethPaidInUsd_ * 1e18 / ptokensValueUsd_, 0.020020020020245390e18);

        // Payer received the PTokens
        assertEq(ptoken.balanceOf(address(payer)), ptokenSellAmount_);
    }

    function test_integration_ZeroPTokens() public {
        (, int256 ethUsdPrice_, , , ) = ethUsdOracle.latestRoundData();
        (, int256 usdcUsdPrice_, , , ) = usdcUsdOracle.latestRoundData();
        assertEq(uint256(ethUsdPrice_), 1792.75977963e8);
        assertEq(uint256(usdcUsdPrice_), 0.9999e8);

        uint256 initTokenBuyerBalance_ = 15 ether;
        vm.deal(address(tokenBuyer), initTokenBuyerBalance_);

        address ptokenHolder_ = address(0xBEEF);
        uint256 ptokenSellAmount_ = 0; // Sell 0 ptokens

        uint256 ptokensValueUsdc_ = set.convertToProtection(marketId, ptokenSellAmount_);
        assertEq(ptokensValueUsdc_, 0);
        uint256 ptokensValueUsd_ = ptokensValueUsdc_ * uint256(usdcUsdPrice_) / 1e6;
        assertEq(ptokensValueUsd_, 0); // $0 of protection

        vm.startPrank(ptokenHolder_);
        ptoken.approve(address(tokenBuyer), ptokenSellAmount_);
        tokenBuyer.buyETH(ptokenSellAmount_);
        vm.stopPrank();

        uint256 ethPaid_ = initTokenBuyerBalance_ - address(tokenBuyer).balance;
        assertEq(ethPaid_, 0);

        uint256 ethPaidInUsd_ = ethPaid_ * uint256(ethUsdPrice_) / 1e18;
        assertEq(ethPaidInUsd_, 0);

        assertEq(ptoken.balanceOf(address(payer)), 0);
    }

    function test_integration_multipleBuys() public {
        (, int256 ethUsdPrice_, , , ) = ethUsdOracle.latestRoundData();
        (, int256 usdcUsdPrice_, , , ) = usdcUsdOracle.latestRoundData();
        assertEq(uint256(ethUsdPrice_), 1792.75977963e8);
        assertEq(uint256(usdcUsdPrice_), 0.9999e8);

        uint256 initTokenBuyerBalance_ = 15 ether;
        vm.deal(address(tokenBuyer), initTokenBuyerBalance_);

        address ptokenHolder_ = address(0xBEEF);
        uint256 ptokenHolderBalance_ = 1_000_000e6; // 1 million ptokens
        deal(address(ptoken), ptokenHolder_, ptokenHolderBalance_);
        uint256 ptokenSellAmount_ = 1000e6; // Sell 1 thousand ptokens

        vm.startPrank(ptokenHolder_);
        ptoken.approve(address(tokenBuyer), ptokenSellAmount_);
        tokenBuyer.buyETH(ptokenSellAmount_);
        vm.stopPrank();

        uint256 newEthBalance_ = address(tokenBuyer).balance;
        uint256 ethPaid_ = initTokenBuyerBalance_ - newEthBalance_;
        assertEq(ethPaid_, 0.010855396098390388e18);

        // Sell the same amount again
        vm.startPrank(ptokenHolder_);
        ptoken.approve(address(tokenBuyer), ptokenSellAmount_);
        tokenBuyer.buyETH(ptokenSellAmount_);
        vm.stopPrank();

        ethPaid_ = newEthBalance_ - address(tokenBuyer).balance;
        assertEq(ethPaid_, 0.010855396098390388e18); // Same amount paid as the first token buy
        newEthBalance_ = address(tokenBuyer).balance;

        // Sell the 2x amount
        vm.startPrank(ptokenHolder_);
        ptoken.approve(address(tokenBuyer), 2 * ptokenSellAmount_);
        tokenBuyer.buyETH(2 * ptokenSellAmount_);
        vm.stopPrank();

        ethPaid_ = newEthBalance_ - address(tokenBuyer).balance;
        assertEq(ethPaid_, 2 * 0.010855396098390388e18); // Amount paid is equal to the sum of the two separate buys

        // Payer received the PTokens
        assertEq(ptoken.balanceOf(address(payer)), ptokenSellAmount_ * 4);
    }

    function test_integration_multipleOneTokenBuys() public {
        (, int256 ethUsdPrice_, , , ) = ethUsdOracle.latestRoundData();
        (, int256 usdcUsdPrice_, , , ) = usdcUsdOracle.latestRoundData();
        assertEq(uint256(ethUsdPrice_), 1792.75977963e8);
        assertEq(uint256(usdcUsdPrice_), 0.9999e8);

        uint256 initTokenBuyerBalance_ = 15 ether;
        vm.deal(address(tokenBuyer), initTokenBuyerBalance_);

        address ptokenHolder_ = address(0xBEEF);
        uint256 ptokenHolderBalance_ = 1_000_000e6; // 1 million ptokens
        deal(address(ptoken), ptokenHolder_, ptokenHolderBalance_);
        uint256 ptokenSellAmount_ = 1; // Sell 0.000001e6 ptokens

        vm.startPrank(ptokenHolder_);
        ptoken.approve(address(tokenBuyer), ptokenSellAmount_ * 10);
        for (uint256 i = 0; i < 10; i++) {
            tokenBuyer.buyETH(ptokenSellAmount_);
        }
        vm.stopPrank();

        uint256 newEthBalance_ = address(tokenBuyer).balance;
        uint256 ethPaid_ = initTokenBuyerBalance_ - newEthBalance_;
        assertEq(ethPaid_, 0.000000000108553960e18);

        // Payer received the PTokens
        assertEq(ptoken.balanceOf(address(payer)), 10 * ptokenSellAmount_);

        // Sell the same amount but in one go
        vm.startPrank(ptokenHolder_);
        ptoken.approve(address(tokenBuyer), ptokenSellAmount_ * 10);
        tokenBuyer.buyETH(10 * ptokenSellAmount_);
        vm.stopPrank();

        ethPaid_ = newEthBalance_ - address(tokenBuyer).balance;
        assertEq(ethPaid_, 0.000000000108553960e18); // Same amount paid

        // Payer received the PTokens
        assertEq(ptoken.balanceOf(address(payer)), 20 * ptokenSellAmount_);
    }

    function test_integration_setBidPriceGasCost() public {
        uint256 newBidPrice_ = 0.03e18;
        vm.prank(OWNER);
        uint256 gasLeftInit_ = gasleft();
        feed.setBidPriceWAD(newBidPrice_);
        assertEq(gasLeftInit_ - gasleft(), 13_751);
    }
}