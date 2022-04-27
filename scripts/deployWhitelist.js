
// Use to deploy Whitelist contract

const hre = require("hardhat");
require("dotenv").config();

const daiTokenAddress = '0xDA1430f5F3d9E6DC3232211532026bF101Daf83F'; 
const startTime = ethers.BigNumber.from(1651097100); // Calc the start time // 15:05 today
const saleDuration = ethers.BigNumber.from(360000); // ASK 
const epochLength = ethers.BigNumber.from(900);; // 15 min is 900 seconds 
const initialCap = ethers.BigNumber.from(500); // Initial DAI investment cap of 500 
const globalHardCap = ethers.BigNumber.from(1.25e6); // THIS NEEDS TO BE IN THE CORRECT DECIMALS Hard cap 1.25 Mil DAI
const maxInvestorCap = ethers.BigNumber.from(4000); // 4000 DAI investor cap
const minInvest = ethers.BigNumber.from(50); // 50 DAI Min investment
const presalePrice = ethers.BigNumber.from(1); // Price $1
const treasury = '0x0b2A7d5f0D2C9c96f4E751a4922BB4a3Bc31a8FB'; // Void treasury address
const voidTokenAddress = '0xb6D812F90E2384eE10a3477533cDA50306e5180C'; 


async function main() {
  [owner] = await ethers.getSigners();
  console.log(`Owner: ${owner.address}`);
  const contractName = 'Whitelist';
  await hre.run("compile");
  const smartContract = await hre.ethers.getContractFactory(contractName);
  console.log('Contract Factory Built')
  const contract = await smartContract.deploy(
    daiTokenAddress,
    startTime,
    saleDuration,
    epochLength,
    initialCap,
    globalHardCap,
    maxInvestorCap,
    minInvest,
    presalePrice,
    treasury,
    voidTokenAddress
  );
  await contract.deployed();
  console.log(`${contractName} deployed to: ${contract.address}`); 
}


main()

