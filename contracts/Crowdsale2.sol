// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract Crowdsale is Ownable {

    struct InvestorInfor {
        uint256 totalDeposit;
        uint256 totalClaim;
        uint256 totalClaimed;
        bool isSecondTimeDepositUSDT; // default is false
    }

    using SafeMath for uint256;

    address tokenAddress;
    address usdtAddress;
    address payable fundingWallet;
    uint256 public constant decimals = 18;

    mapping(address => bool) public isInvestor;
    mapping(address => InvestorInfor) public investorInfor;

    uint256 public constant crowdsalePool = 10000000 * (10**18);
    uint256 public constant tokenPrice = 1 * 10**(-2) * (10**18);
    uint256 public constant minDeposit = 100 * (10**18);
    uint256 public constant maxDeposit = 500 * (10**18);

    uint256 public tokenRemaining = crowdsalePool;
    uint256 public totalFunding = 0;

    uint256 public openCrowdsale = 1660492000;
    uint256 public closeCrowdsale = 1660492120;
    uint256 public releaseTime = 1660492180;

    uint256 public constant cliffTime = 1 minutes;

    enum VestingStages {
        TGE,
        P2,
        P3,
        P4,
        P5
    }

    mapping(VestingStages => uint256) public unlockPercentage;
    mapping(VestingStages => uint256) public releaseDate;

    constructor(
        address payable _fundingWallet,
        address _tokenAddress,
        address _usdtAddress
    ) {
        fundingWallet = _fundingWallet;
        tokenAddress = _tokenAddress;
        usdtAddress = _usdtAddress;


        VestingPlan();
    }

    function VestingPlan() internal onlyOwner {

        uint256 firstListingDate = releaseTime;

        unlockPercentage[VestingStages.TGE] = 20;
        unlockPercentage[VestingStages.P2] = 40;
        unlockPercentage[VestingStages.P3] = 60;
        unlockPercentage[VestingStages.P4] = 80;
        unlockPercentage[VestingStages.P5] = 100;

        releaseDate[VestingStages.TGE] = firstListingDate;
        releaseDate[VestingStages.P2] = firstListingDate + 1 minutes;
        releaseDate[VestingStages.P3] = firstListingDate + 2 minutes;
        releaseDate[VestingStages.P4] = firstListingDate + 3 minutes;
        releaseDate[VestingStages.P5] = firstListingDate + 4 minutes; 
    }

    function addInvestors(address[] memory _addressArr) public onlyOwner {
        for (uint256 idx = 0; idx < _addressArr.length; ++idx) {
            address curAddress = _addressArr[idx];
            isInvestor[curAddress] = true;
        }
    }
    
    function depositUSDT(uint256 amountUSDT) public {
        if (investorInfor[msg.sender].isSecondTimeDepositUSDT == false) {
        uint256 pointTimestamp = block.timestamp;

        require(isOpenCrowdsale(pointTimestamp), "Crowdsale does not open.");

        require(isInvestor[msg.sender], "Invalid Investor");

        require(amountUSDT >= minDeposit, "less than");
        require(amountUSDT <= maxDeposit, "more than");

        uint256 totalTokenReceive = amountUSDT.div(tokenPrice).mul(10**18);
        require(totalTokenReceive <= tokenRemaining, "not enough");

        investorInfor[msg.sender].totalDeposit += amountUSDT;
        investorInfor[msg.sender].totalClaim += totalTokenReceive;

        tokenRemaining = tokenRemaining.sub(totalTokenReceive);
        totalFunding += amountUSDT;

        bool transferUSDTSuccess = ERC20(usdtAddress).transferFrom(msg.sender, fundingWallet, amountUSDT);
        require(transferUSDTSuccess, "Transfer failed");

        investorInfor[msg.sender].isSecondTimeDepositUSDT = true;
        }
    }


    function isOpenCrowdsale(uint256 pointTimestamp) public view returns (bool) {
        return (pointTimestamp > openCrowdsale) && (pointTimestamp < closeCrowdsale);
    }


    function claimTokens() public {
        uint256 pointTimestamp = block.timestamp;

        require(isClaimTiming(pointTimestamp), "Claim Timing does not open");

        require(isInvestor[msg.sender], "Invalid investor");

        uint256 availableTokenToClaim = getAvailableTokenToClaim(msg.sender);
        require(availableTokenToClaim > 0, "available token can be claimed is equal to 0");

        investorInfor[msg.sender].totalClaimed += availableTokenToClaim;

        bool transferTokenSuccess = ERC20(tokenAddress).transfer(msg.sender, availableTokenToClaim);
        require(transferTokenSuccess, "transfer token failed");
    }

    function isClaimTiming(uint256 pointTimestamp) public view returns (bool) {
        return pointTimestamp > releaseTime;
    }

    function getAvailableTokenToClaim(address _addressInvestor) public view returns (uint256) {
        uint256 amountUnlockedToken = getAmountUnlockedToken(_addressInvestor);

        return amountUnlockedToken - investorInfor[_addressInvestor].totalClaimed;
    }

    function getAmountUnlockedToken(address _addressInvestor) internal view returns (uint256) {
        uint256 vestingStageIndex = getVestingStageIndex();

        return vestingStageIndex == 100 ? 0 : investorInfor[_addressInvestor].totalClaim.mul(unlockPercentage[VestingStages(vestingStageIndex)]).div(100);
    } 

    function getVestingStageIndex() public view returns (uint256 index) {
        uint256 timestamp = block.timestamp;

        if (timestamp < releaseDate[VestingStages(0)]) {
            return 100;
        }

        for (uint256 i = 1; i < 5; ++i) {
            if (timestamp < releaseDate[VestingStages(i)]) {
                return i - 1;
            }
        }

        return 4;
    }

    //GET FUNCTION - INEVESTOR'S INFORMATION
    
    function getTotalDeposit(address _addressInvestor) public view returns (uint256) {
        return investorInfor[_addressInvestor].totalDeposit;
    }

    function getTotalClaim(address _addressInvestor) public view returns (uint256) {
        return investorInfor[_addressInvestor].totalClaim;
    }

    function getTotalClaimed(address _addressInvestor) public view returns (uint256) {
        return investorInfor[_addressInvestor].totalClaimed;
    }

    function getRemainingToken(address _addressInvestor) public view returns (uint256) {
        return investorInfor[_addressInvestor].totalClaim - investorInfor[_addressInvestor].totalClaimed;
    }

}