import BN from "bn.js";
import chai from "chai";

import { ethers } from "hardhat";
import { Signer } from "ethers";
import { assert, expect } from "chai";
import { solidity } from "ethereum-waffle";

const {
    expectRevert, // Assertions for transactions that should fail
} = require('@openzeppelin/test-helpers');

const { constants } = ethers;
const { MaxUint256 } = constants;

chai.use(solidity);

function getDateNow() {
    return Math.floor(Date.now()/1000);
}

describe("StrongHolderPool", function() {
    let accounts: Signer[];

    let OWNER_SIGNER: any
    let ALICE_SIGNER: any
    let BOB_SIGNER: any

    let OWNER: any
    let ALICE: any
    let BOB: any

    let alm: any;
    let farm: any;
    let shp: any;

    before('config', async () => {
        accounts = await ethers.getSigners();

        OWNER_SIGNER = accounts[0];
        ALICE_SIGNER = accounts[1];
        BOB_SIGNER = accounts[2];

        OWNER = await OWNER_SIGNER.getAddress()
        ALICE = await ALICE_SIGNER.getAddress()
        BOB = await BOB_SIGNER.getAddress()

        const ERC20Mock = await ethers.getContractFactory("ERC20Mock");
        const FarmMock = await ethers.getContractFactory("FarmMock");
        const StrongHolderPool = await ethers.getContractFactory("StrongHolderPool");

        alm = await ERC20Mock.deploy('Mock Alium Token', 'ALM');
        shp = await StrongHolderPool.deploy(alm.address);
        farm = await FarmMock.deploy(alm.address, shp.address);

        await alm.mint(farm.address, '10000000000000000000')
    })

    describe('setters', () => {
        it('#setTrustedContract', async () => {})
    })

    describe('getters', () => {
        it('#percentFrom', async () => {})
        it('#getPoolWithdrawPosition', async () => {})
        it('#totalLockedPoolTokens', async () => {})
        it('#totalLockedPoolTokensFrom', async () => {})
    })

    describe('mutable functions, success tests', () => {
        before('mut tests', async () => {
            //
        })

        it('#lock', async () => {
            await farm.connect(ALICE_SIGNER).deposit(0, 100_000)

            //assert.equal(await shp.getPoolWithdrawPosition(0), 100, 'Wrong position')
            assert.equal((await shp.totalLockedPoolTokens(0)).toString(), 100_000, 'Wrong tokens locked')
            assert.equal((await shp.userLockedPoolTokens(0, ALICE)).toString(), 100_000, 'Wrong tokens locked by account 100K')
            assert.equal((await shp.currentPoolLength()).toString(), 1, 'Wrong pool length 1')

            await farm.connect(BOB_SIGNER).deposit(0, 100_000)

            assert.equal((await shp.totalLockedPoolTokens(0)).toString(), 200_000, 'Wrong tokens locked')
            assert.equal((await shp.userLockedPoolTokens(0, BOB)).toString(), 100_000, 'Wrong tokens locked by account 200K')
            assert.equal((await shp.currentPoolLength()).toString(), 2, 'Wrong pool length 2')

            await farm.connect(BOB_SIGNER).deposit(0, 100_000)

            assert.equal((await shp.totalLockedPoolTokens(0)).toString(), 300_000, 'Wrong tokens locked')
            assert.equal((await shp.userLockedPoolTokens(0, BOB)).toString(), 200_000, 'Wrong tokens locked by account 200K')
            assert.equal((await shp.currentPoolLength()).toString(), 2, 'Wrong pool length 2')
        })

        it.only('#lock mock', async () => {
            const SHPMock = await ethers.getContractFactory("SHPMock");
            const sphMock = await SHPMock.deploy(alm.address);

            assert.equal(await sphMock.poolLength(0), 100, 'Bed pool length')

            await alm.mint(ALICE, 100_000)

            await alm.connect(ALICE_SIGNER).approve(sphMock.address, MaxUint256)
            await sphMock.connect(ALICE_SIGNER).lock(ALICE, 100_000)

            assert.equal((await alm.balanceOf(sphMock.address)).toString(), 100_000, "Bed locked tokens")

            assert.equal((await sphMock.getCurrentPoolId()).toString(), 1)
            assert.equal((await sphMock.currentPoolLength()).toString(), 1)
            assert.equal((await sphMock.poolLength(0)).toString(), 100)
            assert.equal((await sphMock.poolLength(1)).toString(), 1)
            assert.equal((await sphMock.userLockedPoolTokens(1, ALICE)).toString(), 100_000)
            assert.equal((await sphMock.totalLockedPoolTokens(1)).toString(), 100_000)
            assert.equal((await sphMock.poolWithheld(1)).toString(), 0)
        })

        it('#totalLockedPoolTokensFrom', async () => {
            const SHPMock = await ethers.getContractFactory("SHPMock");
            const sphMock = await SHPMock.deploy(alm.address);

            assert.equal(await sphMock.poolLength(0), 100, 'Bed pool length')

            let countReqAlms = async () => {
                let result: number = 0;
                for (let i = 0; i < 100; i++) {
                    result += 100_000
                }
                return result;
            }

            const mintAmount = await countReqAlms();
            await alm.mint(sphMock.address, mintAmount.toString())

            assert.equal(
                (await alm.balanceOf(sphMock.address)).toString(),
                (await sphMock.totalLockedPoolTokens(0)).toString(),
                "Bed locked tokens"
            )

            const poolId = 0;
            let res = await sphMock.withdrawTo(poolId, await sphMock.getAddress(1))
            let events = (await res.wait()).events

            console.log('Withheld: ')
            console.log((await sphMock.poolWithheld(poolId)).toString())
            console.log('')

            events.map(({args, event}: any) => {
                if (event == 'Withdrawn') {
                    console.log(`Withdrawn:`)
                    console.log(args[0].toString())
                    console.log(args[1].toString())
                    console.log('')
                }
                if (event == 'Withheld') {
                    console.log(`Withheld:`)
                    console.log(args[0].toString())
                    console.log('')
                }
                if (event == 'Bonus') {
                    console.log(`Bonus:`)
                    console.log(args[0].toString())
                    console.log(args[1].toString())
                    console.log('')
                }
                if (event == 'Test2') {
                    console.log(`Test2:`)
                    console.log(args[0].toString())
                    console.log(args[1].toString())
                    console.log(args[2].toString())
                    console.log('')
                }
            })

            assert.equal((await sphMock.getPoolWithdrawPosition(0)).toString(), 99, 'Position not changed')

            let totalLocked = (await sphMock.totalLockedPoolTokens(0)).toString()
            let totalLockedFrom = (await sphMock.totalLockedPoolTokensFrom(0, 0)).toString()

            console.log('Locked')
            console.log(totalLocked)
            console.log(totalLockedFrom)

            assert.notEqual(totalLocked, '0', 'Zero lock 1')
            assert.notEqual(totalLockedFrom, '0', 'Zero lock 2')
            assert.equal(totalLocked, totalLockedFrom, 'Locked tokens wrong calculation')

            totalLocked = (await sphMock.totalLockedPoolTokens(0)).toString()
            totalLockedFrom = (await sphMock.totalLockedPoolTokensFrom(0, 1)).toString()

            console.log('Locked 1')
            console.log(totalLocked)
            console.log(totalLockedFrom)

            assert.isAbove(Number(totalLocked), Number(totalLockedFrom), 'Locked from not less then total locked')
        })

        it('#withdraw', async () => {
            const SHPMock = await ethers.getContractFactory("SHPMock");
            const sphMock = await SHPMock.deploy(alm.address);

            assert.equal(await sphMock.poolLength(0), 100, 'Bed pool length')

            let countReqAlms = async () => {
                let result: number = 0;
                for (let i = 0; i < 100; i++) {
                    // result += (i+1) * 100_000
                    result += 100_000
                }
                return result;
            }

            const mintAmount = await countReqAlms();
            // console.log(mintAmount)

            await alm.mint(sphMock.address, mintAmount.toString())
            // console.log(await sphMock.getAddress(1))

            assert.equal((await alm.balanceOf(sphMock.address)).toString(), (await sphMock.totalLockedPoolTokens(0)).toString(), "Bed locked tokens")

            let withdrawOrder = async (i: number) => {
                if (i > 100) {
                    return;
                }

                const poolId = 0;

                // await sphMock.withdraw(0)
                // let pool_length = await sphMock.currentPoolLength()
                // assert.equal(pool_length, 100, "Pool length broken")

                let res = await sphMock.withdrawTo(poolId, await sphMock.getAddress(i))
                let events = (await res.wait()).events

                console.log('Withheld: ')
                console.log((await sphMock.poolWithheld(poolId)).toString())
                console.log('')

                events.map(({args, event}: any) => {
                    if (event == 'Withdrawn') {
                        console.log(`Withdrawn: ${i}`)
                        console.log(args[0].toString())
                        console.log(args[1].toString())
                        console.log('')
                    }
                    if (event == 'Withheld') {
                        console.log(`Withheld: ${i}`)
                        console.log(args[0].toString())
                        console.log('')
                    }
                    if (event == 'Bonus') {
                        console.log(`Bonus: ${i}`)
                        console.log(args[0].toString())
                        console.log(args[1].toString())
                        console.log('')
                    }
                    if (event == 'Test2') {
                        console.log(`Test2: ${i}`)
                        console.log(args[0].toString())
                        console.log(args[1].toString())
                        console.log(args[2].toString())
                        console.log('')
                    }
                })

                let pool = await sphMock.pools(0)
                // let bonusesPaid = await sphMock.bonusesPaid(0)
                //
                // console.log('Total bonuses paid: ')
                // console.log(bonusesPaid[0].toString())
                // console.log(bonusesPaid[1].toString())
                // console.log(bonusesPaid[2].toString())
                // console.log(bonusesPaid[3].toString())
                // console.log('')

                // todo: if equal bug
                console.log((await sphMock.totalLockedPoolTokensFrom(0, 80)).toString())
                console.log((await sphMock.totalLockedPoolTokensFrom(0, 85)).toString())
                console.log((await sphMock.totalLockedPoolTokensFrom(0, 90)).toString())
                console.log((await sphMock.totalLockedPoolTokensFrom(0, 95)).toString())
                console.log('')


                if (100 === i) {
                    await expectRevert(sphMock.getPoolWithdrawPosition(0), "Pool is empty")
                } else {
                    assert.equal((await sphMock.getPoolWithdrawPosition(0)).toString(), 100 - i, 'Position not changed')
                }

                await withdrawOrder(i+1)
            }

            await withdrawOrder(1)
        })

        it('#totalLockedPoolTokens', async () => {
            const SHPMock = await ethers.getContractFactory("SHPMock");
            const sphMock = await SHPMock.deploy(alm.address);

            assert.equal(await sphMock.poolLength(0), 100, 'Bed pool length')

            let countReqAlms = () => {
                let result: number = 0;
                for (let i = 0; i < 100; i++) {
                    // result += (i+1) * 100_000
                    result += 100_000
                }
                return result;
            }

            const mintAmount = countReqAlms();
            // console.log(mintAmount)

            await alm.mint(sphMock.address, mintAmount.toString())
            // console.log(await sphMock.getAddress(1))

            assert.equal((await alm.balanceOf(sphMock.address)).toString(), (await sphMock.totalLockedPoolTokens(0)).toString(), "Bed locked tokens")

            let withdrawOrder = async (i: number) => {
                if (i > 100) {
                    return;
                }

                const poolId = 0;

                // await sphMock.withdraw(0)
                // let pool_length = await sphMock.currentPoolLength()
                // assert.equal(pool_length, 100, "Pool length broken")

                let res = await sphMock.withdrawTo(poolId, await sphMock.getAddress(i))
                let events = (await res.wait()).events

                console.log('Withheld: ')
                console.log((await sphMock.poolWithheld(poolId)).toString())
                console.log('')

                events.map(({args, event}: any) => {
                    if (event == 'Withdrawn') {
                        console.log(`Withdrawn: ${i}`)
                        console.log(args[0].toString())
                        console.log(args[1].toString())
                        console.log('')
                    }
                    if (event == 'Withheld') {
                        console.log(`Withheld: ${i}`)
                        console.log(args[0].toString())
                        console.log('')
                    }
                    if (event == 'Bonus') {
                        console.log(`Bonus: ${i}`)
                        console.log(args[0].toString())
                        console.log(args[1].toString())
                        console.log('')
                    }
                    if (event == 'Test2') {
                        console.log(`Test2: ${i}`)
                        console.log(args[0].toString())
                        console.log(args[1].toString())
                        console.log(args[2].toString())
                        console.log('')
                    }
                })

                let pool = await sphMock.pools(0)
                // let bonusesPaid = await sphMock.bonusesPaid(0)
                //
                // console.log('Total bonuses paid: ')
                // console.log(bonusesPaid[0].toString())
                // console.log(bonusesPaid[1].toString())
                // console.log(bonusesPaid[2].toString())
                // console.log(bonusesPaid[3].toString())
                // console.log('')

                // todo: if equal bug
                console.log((await sphMock.totalLockedPoolTokensFrom(0, 80)).toString())
                console.log((await sphMock.totalLockedPoolTokensFrom(0, 85)).toString())
                console.log((await sphMock.totalLockedPoolTokensFrom(0, 90)).toString())
                console.log((await sphMock.totalLockedPoolTokensFrom(0, 95)).toString())
                console.log('')


                if (100 === i) {
                    await expectRevert(sphMock.getPoolWithdrawPosition(0), "Pool is empty")
                } else {
                    assert.equal((await sphMock.getPoolWithdrawPosition(0)).toString(), 100 - i, 'Position not changed')
                }

                await withdrawOrder(i+1)
            }

            await withdrawOrder(1)

                // await sphMock.withdraw(0)
                // let res = await sphMock.withdrawTo(0, await sphMock.getAddress(i+1))
                //
                // let events = (await res.wait()).events
                // // console.log(events[1])
                // console.log(`Withdrawn: ${i}`)
                // console.log(events[1].args[0].toString())
                // console.log(events[1].args[1].toString())
                //
                // assert.equal((await sphMock.getPoolWithdrawPosition(0)).toString(), 100 - (i+1), 'Position not changed')

            // // await sphMock.withdraw(0)
            // let res = await sphMock.withdrawTo(0, await sphMock.getAddress(1))
            //
            // let events = (await res.wait()).events
            // console.log(events[1])
            // console.log(events[1].args[0].toString())
            // console.log(events[1].args[1].toString())
            //
            // assert.equal((await sphMock.getPoolWithdrawPosition(0)).toString(), 99, 'Position not changed')
            //
            // // await sphMock.withdraw(0)
            // res = await sphMock.withdrawTo(0, await sphMock.getAddress(1))
            //
            // events = (await res.wait()).events
            // console.log(events[1])
            // console.log(events[1].args[0].toString())
            // console.log(events[1].args[1].toString())
            //
            // assert.equal((await sphMock.getPoolWithdrawPosition(0)).toString(), 98, 'Position not changed')
        })
    })

    describe('mutable functions, fail tests', () => {
        it('#lock', async () => {})
        it('#withdraw', async () => {})
    })

});
