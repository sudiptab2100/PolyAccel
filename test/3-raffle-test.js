const { assert, expect } = require("chai")
const chai = require("chai")
chai.use(require('chai-as-promised'))

const PolCoin = artifacts.require("PolCoin")
const TestToken = artifacts.require("TestToken")
const Staker = artifacts.require("Staker")
const RaffleWrapTest = artifacts.require("RaffleWrapTest")

function timeout(s) {
    return new Promise(resolve => setTimeout(resolve, s * 1000))
}

contract("RaffleWrap", accounts => {

    var idoAmount = '10000000000000000000000' // 10000 Tokens
    var totalPrice = '10000000000000000000' // 0.001 * 10000 = 10 Eth

    let polCoin, testToken, staker, raffle
    beforeEach(async () => {
        polCoin = await PolCoin.new()
        testToken = await TestToken.new()

        staker = await Staker.new(polCoin.address)
        raffle = await RaffleWrapTest.new(
            staker.address,
            polCoin.address,
            testToken.address,
            idoAmount,
            totalPrice
        )

        // Transfer PolCoins to accounts
        await polCoin.transfer(accounts[1], '100000000000000000000', { from: accounts[0] })
        await polCoin.transfer(accounts[2], '100000000000000000000', { from: accounts[0] })
        await polCoin.transfer(accounts[3], '100000000000000000000', { from: accounts[0] })
        await polCoin.transfer(accounts[4], '100000000000000000000', { from: accounts[0] })
        await polCoin.transfer(accounts[5], '100000000000000000000', { from: accounts[0] })

        await staker.addIDO(raffle.address, { from: accounts[0] })
        await testToken.transfer(raffle.address, idoAmount, { from: accounts[0] })
    })

    it('Buy Test', async () => {
        var initTime = Math.floor(Date.now() / 1000) + 10
        await raffle.initialize(initTime)

        await polCoin.approve(raffle.address, '100000000000000000000', { from: accounts[0] })
        await raffle.buyTickets(5, { from: accounts[0] })
        var count1 = (await raffle.addressToTicketCount(accounts[0])).toNumber()
        assert.equal(count1, 5)
        
        await polCoin.approve(raffle.address, '100000000000000000000', { from: accounts[1] })
        await raffle.buyTickets(5, { from: accounts[1] })
        var count2 = (await raffle.addressToTicketCount(accounts[1])).toNumber()
        assert.equal(count2, 5)

        var sold = (await raffle.ticketsSold()).toNumber()
        assert.equal(sold, count1 + count2)
    })

    it('Rand Winner Test', async () => {
        var initTime = Math.floor(Date.now() / 1000) + 20
        await raffle.initialize(initTime)

        await polCoin.approve(raffle.address, '100000000000000000000', { from: accounts[0] })
        await polCoin.approve(raffle.address, '100000000000000000000', { from: accounts[1] })
        await polCoin.approve(raffle.address, '100000000000000000000', { from: accounts[2] })
        // await polCoin.approve(raffle.address, '100000000000000000000', { from: accounts[3] })

        await raffle.buyTickets(30, { from: accounts[0] })
        await raffle.buyTickets(30, { from: accounts[1] })
        await raffle.buyTickets(30, { from: accounts[2] })
        // await raffle.buyTickets(30, { from: accounts[3] })

        await timeout(20)
        await raffle.fulfillTest(
            '0x11784bfa961ea00360336b7dfda4504f3e5e01a6035d89a9464ccdf8c73ac1b0', 
            '77626901581511883625746798795701147174388658559238937904298300184740954966236'
        )

        var participants = ((await raffle.pools(2))['participants']).toNumber()
        assert.equal(participants, 1)
    })

})