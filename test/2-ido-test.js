const { assert, expect } = require("chai")
const chai = require("chai")
chai.use(require('chai-as-promised'))

const PolCoin = artifacts.require("PolCoin")
const TestToken = artifacts.require("TestToken")
const Staker = artifacts.require("Staker")
const IDO = artifacts.require("IDO")

function timeout(s) {
    return new Promise(resolve => setTimeout(resolve, s * 1000));
}

contract("IDO", accounts => {

    var idoAmount = '10000000000000000000000' // 10000 Tokens
    var pricePerToken = '1000000000000000' // 0.001 Eth

    var poolMin = [
        '100000000000000000000', 
        '500000000000000000000', 
        '1000000000000000000000', 
        '2000000000000000000000', 
        '4000000000000000000000'
    ]

    let polCoin, testToken, staker, ido
    beforeEach(async () => {
        polCoin = await PolCoin.new()
        testToken = await TestToken.new()

        staker = await Staker.new(polCoin.address)
        ido = await IDO.new(
            staker.address,
            polCoin.address,
            testToken.address,
            idoAmount,
            pricePerToken
        )
        
        // Transfer PolCoins to accounts
        await polCoin.transfer(accounts[1], poolMin[0], { from: accounts[0] })
        await polCoin.transfer(accounts[2], poolMin[0], { from: accounts[0] })
        await polCoin.transfer(accounts[3], poolMin[1], { from: accounts[0] })
        await polCoin.transfer(accounts[4], poolMin[2], { from: accounts[0] })
        await polCoin.transfer(accounts[5], poolMin[3], { from: accounts[0] })
        await polCoin.transfer(accounts[6], poolMin[4], { from: accounts[0] })
        await polCoin.transfer(accounts[7], poolMin[4], { from: accounts[0] })

        // Approve Transfer to Staker ontract
        await polCoin.approve(staker.address, poolMin[0], { from: accounts[1] })
        await polCoin.approve(staker.address, poolMin[0], { from: accounts[2] })
        await polCoin.approve(staker.address, poolMin[1], { from: accounts[3] })
        await polCoin.approve(staker.address, poolMin[2], { from: accounts[4] })
        await polCoin.approve(staker.address, poolMin[3], { from: accounts[5] })
        await polCoin.approve(staker.address, poolMin[4], { from: accounts[6] })
        await polCoin.approve(staker.address, poolMin[4], { from: accounts[7] })
        
        // Accounts Stake in Staker 
        await staker.stake(poolMin[0], { from: accounts[1] })
        await staker.stake(poolMin[0], { from: accounts[2] })
        await staker.stake(poolMin[1], { from: accounts[3] })
        await staker.stake(poolMin[2], { from: accounts[4] })
        await staker.stake(poolMin[3], { from: accounts[5] })
        await staker.stake(poolMin[4], { from: accounts[6] })
        await staker.stake(poolMin[4], { from: accounts[7] })

        await staker.addIDO(ido.address, { from: accounts[0] })
        await testToken.transfer(ido.address, idoAmount, { from: accounts[0] })
    })

    describe('Testing IDO Without Initializing', () => {

        it('Pool No Test', async () => {
            const poolNo = (await ido.getPoolNo(accounts[1])).toNumber()
            // account 1 didn't register to any pool yet
            // so pool no should be 0
            assert.equal(poolNo, 0)
        })

        it('Registration(fail test)', async () => {
            await expect(
                ido.register(1, { from: accounts[0] })
            ).to.be.rejected
        })

        it('Buy(fail test)', async () => {
            await expect(
                ido.buyNow({ from: accounts[0] })
            ).to.be.rejected
        })
    })

    describe('Testing IDO Registration(While Initialized)', () => {

        beforeEach(async () => {
            var initTime = Math.floor(Date.now() / 1000) + 5
            await ido.initialize(initTime, { from: accounts[0] })
        })

        it('Registration before time fails', async () => {
            await expect(
                ido.register(1, { from: accounts[1] })
            ).to.be.rejected
        })

        it('Register in Registration period', async () => {
            await timeout(5) // wait 5s for registration to start

            await ido.register(1, { from: accounts[1] })
        })

        it('Registration after time fails', async () => {
            await timeout(5 + 48 + 2) // wait for registration to end

            await expect(
                ido.register(1, { from: accounts[1] })
            ).to.be.rejected
        })

        it('Multiple Registration And Unstake After Registration Fails', async () => {
            await timeout(5) // wait for registration to start

            // Expect registration in invalid pool to fail
            await expect(
                // account 1 does not have enough tokens
                // staked to participate in pool no 4
                ido.register(4, { from: accounts[3] })
            ).to.be.rejected

            await ido.register(2, { from: accounts[3] })

            // Expecting 2nd registration from same user to fail
            await expect(
                ido.register(1, { from: accounts[3] })
            ).to.be.rejected
            
            // expecting unstaking to fail as user is locked
            await expect(
                staker.unstake(poolMin[1], { from: accounts[3] })
            ).to.be.rejected
        })

    })

    describe('Testing IDO Purchase', async () => {

        let saleStartsAfter, initTime
        beforeEach(async () => {
            initTime = Math.floor(Date.now() / 1000) + 1
            await ido.initialize(initTime, { from: accounts[0] })
            saleStartsAfter = 48 + 24
            await timeout(1)

            await ido.register(1, { from: accounts[1] })
            await ido.register(1, { from: accounts[2] })
            await ido.register(2, { from: accounts[3] })
            await ido.register(3, { from: accounts[4] })
            await ido.register(4, { from: accounts[5] })
            await ido.register(5, { from: accounts[6] })
            await ido.register(5, { from: accounts[7] })
        })

        it('Pool No Test', async () => {
            const poolNo = (await ido.getPoolNo(accounts[4])).toNumber()
            // account 4 registered in poolNo 3
            assert.equal(poolNo, 3)
        })

        it('Purchase before time(fails)', async () => {
            const price = (await ido.tokensAndPrice(1))[1]
            await expect(
                ido.buyNow({ from: accounts[1], value: price })
            ).to.be.rejected
        })

        it('Purchase in Sale period', async () => {
            await timeout(saleStartsAfter)

            const price = (await ido.tokensAndPrice(1))[1]
            await ido.buyNow({ from: accounts[1], value: price })

            const usr = await ido.userlog(accounts[1])
            assert.equal(usr.isRegistered, true);
            assert.equal(usr.registeredPool.toNumber(), 1)
            assert.equal(usr.purchased, true)

            // Multiple Purchase Order expected to Fail
            await expect(
                ido.buyNow({ from: accounts[1], value: price })
            ).to.be.rejected
        })

        it('Purchase After Sale Period(fails)', async () => {
            await timeout(saleStartsAfter + 12 + 1)

            let price = (await ido.tokensAndPrice(1))[1]
            await expect(
                ido.buyNow({ from: accounts[1], value: price })
            ).to.be.rejected
        })
    })

    describe('Recover', async () => {
        let saleStartsAfter, initTime
        beforeEach(async () => {
            initTime = Math.floor(Date.now() / 1000) + 1
            await ido.initialize(initTime, { from: accounts[0] })
            saleStartsAfter = 48 + 24
            await timeout(1)

            await ido.register(1, { from: accounts[1] })
        })

        it('Recover ERC20', async () => {
            await ido.recoverERC20(polCoin.address, accounts[0], { from: accounts[0] })
        })

        it('Recover Eth', async () => {
            await timeout(saleStartsAfter) // Wait for sale to start

            let price = (await ido.tokensAndPrice(1))[1]
            await ido.buyNow({ 
                from: accounts[1],
                value: price
            }) // A participant buys tokens and eth added to contract

            await ido.recoverEth(accounts[0], { from: accounts[0] }) // Recover the Eth
        })
    })
})