const { expect } = require("chai");
const { ethers } = require("hardhat");

const increaseTime = async(time) => {
  await ethers.provider.send("evm_increaseTime", [time])
  await ethers.provider.send("evm_mine")
}

describe("Vault", function() {
    beforeEach(async function() {
        [owner, alice, bob, feeReceiver] = await ethers.getSigners();
        const Vault = await ethers.getContractFactory("Vault");
        vault = await Vault.deploy(3, 5, 10, 1000, 1000, feeReceiver.address);
    });
    
    it("Successful configure() execution", async() => {
        await vault.configure(5, 10, 15, 2000, 1500, bob.address);
        expect(await vault.fastTariffDuration()).to.equal(5);
        expect(await vault.averageTariffDuration()).to.equal(10);
        expect(await vault.slowTariffDuration()).to.equal(15);
        expect(await vault.percentagePerMinute()).to.equal(2000);
        expect(await vault.feePercentage()).to.equal(1500);
        expect(await vault.feeReceiver()).to.equal(bob.address);
    });
    
    it("Successful stake() execution", async() => {
        await expect(vault.stake(3, {value: ethers.utils.parseEther("1")})).to.be.reverted;
        await expect(vault.stake(2, {value: ethers.utils.parseEther("0")})).to.be.revertedWith("Vault: can not stake 0 TRX");
        await vault.stake(2, {value: ethers.utils.parseEther("1")});
        const deposit = await vault.deposits(owner.address);
        const block = await ethers.provider.getBlock();
        expect(deposit.owner).to.equal(owner.address);
        expect(deposit.amount).to.equal(ethers.utils.parseEther("0.9"));
        expect(deposit.creationTime).to.equal(block.timestamp);
        expect(deposit.completionTime).to.equal(block.timestamp + 600);
        expect(deposit.tariff).to.equal(2);
        expect(await vault.totalStakingBalance()).to.equal(ethers.utils.parseEther("0.9"));
        expect(await vault.getDepositor(0)).to.equal(owner.address);
        await expect(vault.stake(2, {value: ethers.utils.parseEther("1")})).to.be.revertedWith("Vault: user is already a staker");
    });
    
    it("Successful withdraw() execution", async() => {
        await expect(vault.withdraw()).to.be.revertedWith("Vault: user is not a staker");
        await vault.stake(2, {value: ethers.utils.parseEther("1")});
        await expect(vault.withdraw()).to.be.revertedWith("Vault: cannot withdraw before completion time");
        increaseTime(600);
        balanceBefore = await ethers.provider.getBalance(owner.address);
        await vault.withdraw();
        balanceAfter = await ethers.provider.getBalance(owner.address)
        console.log(`Difference: ${balanceAfter.sub(balanceBefore)}`);
        await owner.sendTransaction({
            to: vault.address,
            value: ethers.utils.parseEther("20")
        });
        await vault.stake(2, {value: ethers.utils.parseEther("1")});
        increaseTime(600);
        balanceBefore = await ethers.provider.getBalance(owner.address);
        await vault.withdraw();
        balanceAfter = await ethers.provider.getBalance(owner.address)
        console.log(`Difference: ${balanceAfter.sub(balanceBefore)}`);
        const deposit = await vault.deposits(owner.address);
        expect(deposit.owner).to.equal('0x0000000000000000000000000000000000000000');
        expect(deposit.amount).to.equal(0);
        expect(deposit.creationTime).to.equal(0);
        expect(deposit.completionTime).to.equal(0);
        expect(deposit.tariff).to.equal(0);
        expect(await vault.totalStakingBalance()).to.equal(0);
        await expect(vault.getDepositor(0)).to.be.revertedWith("Vault: empty set");
    });
    
    it("Successful getAmountOfDepositors() and getDepositor() execution", async() => {
        expect(await vault.getAmountOfDepositors()).to.equal(0);
        await expect(vault.getDepositor(0)).to.be.revertedWith("Vault: empty set");
        await vault.stake(2, {value: ethers.utils.parseEther("1")});
        await vault.connect(alice).stake(0, {value: ethers.utils.parseEther("2")});
        expect(await vault.getAmountOfDepositors()).to.equal(2);
        await expect(vault.getDepositor(2)).to.be.revertedWith("Vault: invalid index");
        expect(await vault.getDepositor(0)).to.equal(owner.address);
    });
    
    it("Successful calculateReward() execution", async() => {
        await expect(vault.calculateReward(0, 0)).to.be.revertedWith("Vault: invalid amount");
        await expect(vault.calculateReward(1000, 3)).to.be.reverted;
        expect(await vault.calculateReward(1000, 0)).to.equal(1300);
        expect(await vault.calculateReward(1000, 1)).to.equal(1500);
        expect(await vault.calculateReward(1000, 2)).to.equal(2000);
    });
    
    it("Successful getCompletionTime() execution", async() => {
        await expect(vault.getCompletionTime(3)).to.be.reverted;
        block = await ethers.provider.getBlock();
        expect(await vault.getCompletionTime(0)).to.equal(block.timestamp + 180);
        expect(await vault.getCompletionTime(1)).to.equal(block.timestamp + 300);
        expect(await vault.getCompletionTime(2)).to.equal(block.timestamp + 600);
    });
});
