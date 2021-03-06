// SPDX-License-Identifier: MIT
pragma solidity ^0.7.5;

import "./NRT.sol";
import "./libraries/ERC20.sol";
import "./types/Ownable.sol";

// *********************************
// Fair Launch pool
// *********************************
// cap increases gradually over time
// this allows a maximum number of participants and still fill the round

contract FairLaunchPool is Ownable {

    // the token address the cash is raised in
    // assume decimals is 18
    address public investToken;
    // the token to be launched
    address public launchToken;
    // proceeds go to treasury
    address public treasury;
    // the certificate
    NRT public nrt;
    // fixed single price
    uint256 public price = 1;
    // ratio quote in 1000
    uint256 public priceQuote = 1000;
    // the cap at the beginning
    uint256 public initialCap;
    // maximum cap
    uint256 public maxCap;
    // the total amount in stables to be raised
    uint256 public totalraiseCap;
    // how much was raised
    uint256 public totalraised;
    // how much was issued
    uint256 public totalissued;
    // how much was redeemed
    uint256 public totalredeem;
    // start of the sale
    uint256 public startTime;
    // total duration
    uint256 public duration;
    // length of each epoch
    uint256 public epochTime;
    // end of the sale
    uint256 public endTime;
    // sale has started
    bool public saleEnabled;
    // redeem is possible
    bool public redeemEnabled;
    // minimum amount
    uint256 public mininvest;
    uint256 public launchDecimals = 18;
    //
    uint256 public numWhitelisted = 0;
    //
    uint256 public numInvested = 0;

    event SaleEnabled(bool enabled, uint256 time);
    event RedeemEnabled(bool enabled, uint256 time);
    event Invest(address investor, uint256 amount);
    event Redeem(address investor, uint256 amount);

    struct InvestorInfo {
        uint256 amountInvested; // Amount deposited by user
        bool claimed; // has claimed MAG
    }

    // user is whitelisted
    mapping(address => bool) public whitelisted;

    mapping(address => InvestorInfo) public investorInfoMap;

    constructor(
        address _investToken,
        uint256 _startTime,
        uint256 _duration,
        uint256 _epochTime,
        uint256 _initialCap,
        uint256 _totalraiseCap,
        uint256 _minInvest,
        address _treasury
    ) {
        investToken = _investToken;
        startTime = _startTime;
        duration = _duration;
        epochTime = _epochTime;
        initialCap = _initialCap;
        totalraiseCap = _totalraiseCap;
        mininvest = _minInvest;
        treasury = _treasury;
        require(duration < 7 days, "duration too long");
        endTime = startTime + duration;
        nrt = new NRT("aSPHERE", 18);
        redeemEnabled = false;
        saleEnabled = false;
        maxCap = 4000 * 10 ** 18;
    }

    // adds an address to the whitelist
    function addWhitelist(address _address) external onlyOwner {
        require(!saleEnabled, "sale has already started");
        //require(!whitelisted[_address], "already whitelisted");
        if(!whitelisted[_address])
            numWhitelisted+=1;
        whitelisted[_address] = true;
    }

    // adds multiple addresses
    function addMultipleWhitelist(address[] calldata _addresses) external onlyOwner {
        require(!saleEnabled, "sale has already started");
        require(_addresses.length <= 1000, "too many addresses");
        for (uint256 i = 0; i < _addresses.length; i++) {
            if(!whitelisted[_addresses[i]])
                numWhitelisted+=1;
            whitelisted[_addresses[i]] = true;
        }
    }

    // removes a single address from the sale
    function removeWhitelist(address _address) external onlyOwner {
        require(!saleEnabled, "sale has already started");
        whitelisted[_address] = false;
    }

    function currentEpoch() public view returns (uint256){
        return (block.timestamp - startTime)/epochTime;
    }

    // the current cap. increases exponentially
    function currentCap() public view returns (uint256){
        uint256 epochs = currentEpoch();
        uint256 cap = initialCap * (2 ** epochs);
        if (cap > maxCap){
            return maxCap;
        } else {
            return cap;
        }
    }

    // invest up to current cap
    function invest(uint256 investAmount) public {
        require(block.timestamp >= startTime, "not started yet");
        require(endTime >= block.timestamp, "sale has ended");
        require(saleEnabled, "not enabled yet");
        require(whitelisted[msg.sender] == true, 'msg.sender is not whitelisted');
        require(totalraised + investAmount <= totalraiseCap, "over total raise");
        require(investAmount >= mininvest, "below minimum invest");

        uint256 xcap = currentCap();

        InvestorInfo storage investor = investorInfoMap[msg.sender];

        require(investor.amountInvested + investAmount <= xcap, "above cap");

        require(
            ERC20(investToken).transferFrom(
                msg.sender,
                address(this),
                investAmount
            ),
            "transfer failed"
        );

        uint256 issueAmount = investAmount * priceQuote;

        nrt.issue(msg.sender, issueAmount);

        totalraised += investAmount;
        totalissued += issueAmount;
        if (investor.amountInvested == 0){
            numInvested += 1;
        }
        investor.amountInvested += investAmount;

        emit Invest(msg.sender, investAmount);
    }

    // redeem all tokens
    function redeem() public {
        require(redeemEnabled, "redeem not enabled");
        //require(block.timestamp > endTime, "not redeemable yet");
        uint256 redeemAmount = nrt.balanceOf(msg.sender);
        require(redeemAmount > 0, "no amount issued");
        InvestorInfo storage investor = investorInfoMap[msg.sender];
        require(!investor.claimed, "already claimed");
        require(
            ERC20(launchToken).transfer(
                msg.sender,
                redeemAmount
            ),
            "transfer failed"
        );

        nrt.redeem(msg.sender, redeemAmount);

        totalredeem += redeemAmount;
        emit Redeem(msg.sender, redeemAmount);
        investor.claimed = true;
    }

    // -- admin functions --

    // define the launch token to be redeemed
    function setLaunchToken(address _launchToken) public onlyOwner {
        launchToken = _launchToken;
    }

    //change the datetime for when the launch happens
    function setstartTime(uint256 _startTime) public onlyOwner {
        require(block.timestamp <= startTime, "too late, sale has started");
        require(!saleEnabled, "sale has already started");
        startTime = _startTime;
        endTime = _startTime + duration;
    }

    function depositLaunchtoken(uint256 amount) public onlyOwner {
        require(
            ERC20(launchToken).transferFrom(msg.sender, address(this), amount),
            "transfer failed"
        );
    }

    // withdraw in case some tokens were not redeemed
    function withdrawLaunchtoken(uint256 amount) public onlyOwner {
        require(
            ERC20(launchToken).transfer(msg.sender, amount),
            "transfer failed"
        );
    }

    // withdraw funds to treasury
    function withdrawTreasury(uint256 amount) public onlyOwner {
        require(
            ERC20(investToken).transfer(treasury, amount),
            "transfer failed"
        );
    }

    function toggleSale() public onlyOwner {
        if(block.timestamp > endTime ) {
            saleEnabled = false;
            emit SaleEnabled(false, block.timestamp);
        } else {
            saleEnabled = true;
            emit SaleEnabled(true, block.timestamp);
        }
    }

    function enableRedeem() public onlyOwner {
        require(launchToken != address(0), "launch token not set");
        redeemEnabled = true;
        emit RedeemEnabled(true, block.timestamp);
    }
}