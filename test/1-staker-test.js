const { assert, expect } = require("chai")
const chai = require("chai")
chai.use(require('chai-as-promised'))

const PolCoin = artifacts.require("PolCoin")
const Staker = artifacts.require("Staker")

contract("Staker", accounts => {

    var token, staker
    beforeEach(async () => {
        token = await PolCoin.new()
        staker = await Staker.new(token.address)
    })

    describe('Testing Staker', () => {
        let val = '100000000000000000000'
        beforeEach(async () => {
            await token.transfer(accounts[1], val, { from: accounts[0] })
            await token.transfer(accounts[2], val, { from: accounts[0] })

            await token.approve(staker.address, val, { from: accounts[1] })
            await staker.stake(val, { from: accounts[1] })

            await staker.addIDO(accounts[0], { from: accounts[0] })
        })

        it('Unstake', async () => {
            await staker.unstake(val, { from: accounts[1] }).then(function(res) {
                assert.equal(res.receipt.status, true, "unstake unsucessful")
            })
        })

        it('Stake When Halted(fail test) & nothalted', async () => {
            // Halt 
            await staker.halt(true, { from: accounts[0] })
            await token.approve(staker.address, val, { from: accounts[2] })
            await expect(
                staker.stake(val, { from: accounts[2] })
            ).to.be.rejected
            
            // unhalt
            await staker.halt(false, { from: accounts[0] })
            await staker.stake(val, { from: accounts[2] })
        })

        it('Unstake When Locked By IDO(fail test)', async () => {
            await staker.lock(accounts[1], Math.floor(Date.now()/1000) + 60 * 60, { from: accounts[0] })
            await expect( 
                staker.unstake(val, { from: accounts[1] }) 
            ).to.be.rejected
        })

        it('Usstaking test with user lock', async () => {
            let delay = 10000
            let now = Date.now()

            // Lock a account
            await staker.lock(accounts[1], Math.floor((now + delay) / 1000), { from: accounts[0] })

            // Wait for it to unlock
            function timeout(ms) {
                return new Promise(resolve => setTimeout(resolve, ms));
            }
            await timeout(delay);

            // Unstake now
            await staker.unstake(val, { from: accounts[1] })
        })

    })

})