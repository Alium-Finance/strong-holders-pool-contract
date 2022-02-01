import chai, {expect} from "chai";

import { ethers } from "hardhat";
import { Signer } from "ethers";
import { assert } from "chai";
import { solidity } from "ethereum-waffle";

const { constants } = ethers;
const { MaxUint256 } = constants;

chai.use(solidity);

function shuffle(array: Array<number>) {
    let currentIndex = array.length,  randomIndex;

    // While there remain elements to shuffle...
    while (currentIndex != 0) {

        // Pick a remaining element...
        randomIndex = Math.floor(Math.random() * currentIndex);
        currentIndex--;

        // And swap it with the current element.
        [array[currentIndex], array[randomIndex]] = [
            array[randomIndex], array[currentIndex]];
    }

    return array;
}

function randomIntFromInterval(min: number, max: number) { // min and max included
    return Math.floor(Math.random() * (max - min + 1) + min)
}

function expectRevert(condition: any, message: string) {
    expect(condition).to.revertedWith(message);
}

describe("StrongHolderPool", function () {
    let accounts: Signer[];

    let OWNER_SIGNER: any;
    let ALICE_SIGNER: any;
    let BOB_SIGNER: any;

    let OWNER: any;
    let ALICE: any;
    let BOB: any;

    let alm: any;
    let farm: any;
    let shp: any;

    before("config", async () => {
        accounts = await ethers.getSigners();

        OWNER_SIGNER = accounts[0];
        ALICE_SIGNER = accounts[1];
        BOB_SIGNER = accounts[2];

        OWNER = await OWNER_SIGNER.getAddress();
        ALICE = await ALICE_SIGNER.getAddress();
        BOB = await BOB_SIGNER.getAddress();

        const ERC20Mock = await ethers.getContractFactory("ERC20Mock");
        const FarmMock = await ethers.getContractFactory("FarmMock");
        const StrongHolderPool = await ethers.getContractFactory("StrongHolderPool");

        alm = await ERC20Mock.deploy("Mock Alium Token", "ALM");
        shp = await StrongHolderPool.deploy(alm.address);
        farm = await FarmMock.deploy(alm.address, shp.address);

        await alm.mint(farm.address, "10000000000000000000");
    });

    describe("getters", () => {
        it("#percentFrom", async () => {
            assert.equal(await shp.percentFrom(10, 100), 10);
            assert.equal(await shp.percentFrom(20, 100), 20);
            assert.equal(await shp.percentFrom(35, 100), 35);
        });
        it("#getPoolWithdrawPosition", async () => {
            const SHPMock = await ethers.getContractFactory("SHPMock");
            const sphMock = await SHPMock.deploy(alm.address);

            expectRevert(sphMock.getPoolWithdrawPosition(0), "Only whole pool");

            await alm.mint(sphMock.address, 100_000 * 100);
            await sphMock.fastLock();

            assert.equal((await sphMock.getPoolWithdrawPosition(0)).toString(), 100);

            for (let i = 0; i < 100; i++) {
                const address = await sphMock.getAddress(i + 1);
                await sphMock.withdrawTo(0, address);
                if (i == 100 - 1) {
                    expectRevert(sphMock.getPoolWithdrawPosition(0), "Pool is empty");
                } else {
                    assert.equal((await sphMock.getPoolWithdrawPosition(0)).toString(), 100 - (i + 1));
                }
            }
        });
        it("#totalLockedPoolTokens", async () => {
            const SHPMock = await ethers.getContractFactory("SHPMock");
            const sphMock = await SHPMock.deploy(alm.address);

            assert.equal((await sphMock.totalLockedPoolTokens(0)).toString(), 0);

            await alm.mint(ALICE, 100_000);

            await alm.connect(ALICE_SIGNER).approve(sphMock.address, MaxUint256);
            await sphMock.connect(ALICE_SIGNER).lock(ALICE, 100_000);

            assert.equal((await sphMock.totalLockedPoolTokens(0)).toString(), 100_000);
        });
    });

    describe("mutable functions, success tests", () => {
        it("#lock", async () => {
            await farm.connect(ALICE_SIGNER).deposit(0, 100_000);

            //assert.equal(await shp.getPoolWithdrawPosition(0), 100, 'Wrong position')
            assert.equal((await shp.totalLockedPoolTokens(0)).toString(), 100_000, "Wrong tokens locked");
            assert.equal(
                (await shp.userLockedPoolTokens(0, ALICE)).toString(),
                100_000,
                "Wrong tokens locked by account 100K",
            );
            assert.equal((await shp.currentPoolLength()).toString(), 1, "Wrong pool length 1");

            await farm.connect(BOB_SIGNER).deposit(0, 100_000);

            assert.equal((await shp.totalLockedPoolTokens(0)).toString(), 200_000, "Wrong tokens locked");
            assert.equal(
                (await shp.userLockedPoolTokens(0, BOB)).toString(),
                100_000,
                "Wrong tokens locked by account 200K",
            );
            assert.equal((await shp.currentPoolLength()).toString(), 2, "Wrong pool length 2");

            await farm.connect(BOB_SIGNER).deposit(0, 100_000);

            assert.equal((await shp.totalLockedPoolTokens(0)).toString(), 300_000, "Wrong tokens locked");
            assert.equal(
                (await shp.userLockedPoolTokens(0, BOB)).toString(),
                200_000,
                "Wrong tokens locked by account 200K",
            );
            assert.equal((await shp.currentPoolLength()).toString(), 2, "Wrong pool length 2");
        });

        it("#lock mock", async () => {
            const SHPMock = await ethers.getContractFactory("SHPMock");
            const sphMock = await SHPMock.deploy(alm.address);

            await sphMock.fastLock();

            assert.equal(await sphMock.poolLength(0), 100, "Bed pool length");
            assert.equal(Number(await sphMock.getCurrentPoolId()), 1, "Wrong pool id not incremented");

            await alm.mint(ALICE, 100_000);

            await alm.connect(ALICE_SIGNER).approve(sphMock.address, MaxUint256);
            await sphMock.connect(ALICE_SIGNER).lock(ALICE, 100_000);

            assert.equal((await alm.balanceOf(sphMock.address)).toString(), 100_000, "Bed locked tokens");

            assert.equal((await sphMock.getCurrentPoolId()).toString(), 1);
            assert.equal((await sphMock.currentPoolLength()).toString(), 1);
            assert.equal((await sphMock.poolLength(0)).toString(), 100);
            assert.equal((await sphMock.poolLength(1)).toString(), 1);
            assert.equal((await sphMock.userLockedPoolTokens(1, ALICE)).toString(), 100_000);
            assert.equal((await sphMock.totalLockedPoolTokens(1)).toString(), 100_000);
            assert.equal((await sphMock.poolWithheld(1)).toString(), 0);
        });

        it("#totalLockedPoolTokensFrom", async () => {
            const SHPMock = await ethers.getContractFactory("SHPMock");
            const sphMock = await SHPMock.deploy(alm.address);

            await sphMock.fastLock();

            assert.equal(Number(await sphMock.poolLength(0)), 100, "Bed pool length");

            const countReqAlms = async () => {
                let result = 0;
                for (let i = 0; i < 100; i++) {
                    result += 100_000;
                }
                return result;
            };

            const mintAmount = await countReqAlms();
            await alm.mint(sphMock.address, mintAmount.toString());

            assert.equal(
                (await alm.balanceOf(sphMock.address)).toString(),
                (await sphMock.totalLockedPoolTokens(0)).toString(),
                "Bed locked tokens",
            );

            const poolId = 0;
            const res = await sphMock.withdrawTo(poolId, await sphMock.getAddress(1));
            const events = (await res.wait()).events;

            console.log("Withheld: ");
            console.log((await sphMock.poolWithheld(poolId)).toString());
            console.log("");

            events.map(({ args, event }: any) => {
                if (event == "Withdrawn") {
                    console.log(`Withdrawn:`);
                    console.log(args[0].toString());
                    console.log(args[1].toString());
                    console.log("");
                }
                if (event == "Withheld") {
                    console.log(`Withheld:`);
                    console.log(args[0].toString());
                    console.log("");
                }
                if (event == "Bonus") {
                    console.log(`Bonus:`);
                    console.log(args[0].toString());
                    console.log(args[1].toString());
                    console.log("");
                }
                if (event == "Test2") {
                    console.log(`Test2:`);
                    console.log(args[0].toString());
                    console.log(args[1].toString());
                    console.log(args[2].toString());
                    console.log("");
                }
            });

            assert.equal((await sphMock.getPoolWithdrawPosition(0)).toString(), 99, "Position not changed");

            let totalLocked = (await sphMock.totalLockedPoolTokens(0)).toString();
            let totalLockedFrom = (await sphMock.totalLockedPoolTokensFrom(0, 0)).toString();

            console.log("Locked");
            console.log(totalLocked);
            console.log(totalLockedFrom);

            assert.notEqual(totalLocked, "0", "Zero lock 1");
            assert.notEqual(totalLockedFrom, "0", "Zero lock 2");
            assert.equal(totalLocked, totalLockedFrom, "Locked tokens wrong calculation");

            totalLocked = (await sphMock.totalLockedPoolTokens(0)).toString();
            totalLockedFrom = (await sphMock.totalLockedPoolTokensFrom(0, 1)).toString();

            console.log("Locked 1");
            console.log(totalLocked);
            console.log(totalLockedFrom);

            assert.equal(Number(totalLocked), Number(totalLockedFrom), "not equal");
        });

        it("#withdraw with random left", async () => {
            const SHPMock = await ethers.getContractFactory("SHPMock");
            const sphMock = await SHPMock.deploy(alm.address);

            let fillNumericArray = (from: number, to: number) => {
                let result = [];
                for (let i = from; i <= to; i++) {
                    result.push(i);
                }
                return result;
            };

            const oneHundredUsers = fillNumericArray(1, 100)
            const oneHundredUsersSchuffled = shuffle(oneHundredUsers)

            console.log(oneHundredUsersSchuffled)

            const countReqAlms = async () => {
                let result = 0;
                for (let i = 0; i < 100; i++) {
                    let randDeposit = randomIntFromInterval(100_000, 1_000_000_000_000)
                    result += randDeposit;
                }
                return result;
            };

            const mintAmount = await countReqAlms();

            assert.equal(Number(await sphMock.poolLength(0)), 100, "Bed pool length");

            await alm.mint(sphMock.address, mintAmount.toString());

            assert.equal(
                (await alm.balanceOf(sphMock.address)).toString(),
                (await sphMock.totalLockedPoolTokens(0)).toString(),
                "Bed locked tokens",
            );

            const withdrawOrder = async (i: number) => {
                if (i > 100) {
                    return;
                }

                const poolId = 0;
                const accountId = oneHundredUsersSchuffled[i-1];
                const account = await sphMock.getAddress(accountId);

                console.log('Account address:')
                console.log(account)
                console.log("");

                console.log('Expected reward:')
                console.log((await sphMock.countReward(0, account)).toString())
                console.log("");

                console.log('total locked pool tokens from:')
                console.log((await sphMock.totalLockedPoolTokensFrom(0, i)).toString())
                console.log("");

                const res = await sphMock.withdrawTo(poolId, account);
                const events = (await res.wait()).events;

                console.log("Withheld: ");
                console.log((await sphMock.poolWithheld(poolId)).toString());
                console.log("");

                await withdrawOrder(i + 1);
            };

            await withdrawOrder(1);
        });

        it("#withdraw", async () => {
            const SHPMock = await ethers.getContractFactory("SHPMock");
            const sphMock = await SHPMock.deploy(alm.address);

            await sphMock.fastLock();

            assert.equal(await sphMock.poolLength(0), 100, "Bed pool length");

            const countReqAlms = async () => {
                let result = 0;
                for (let i = 0; i < 100; i++) {
                    result += 100_000;
                }
                return result;
            };

            const mintAmount = await countReqAlms();
            await alm.mint(sphMock.address, mintAmount.toString());

            assert.equal(
                (await alm.balanceOf(sphMock.address)).toString(),
                (await sphMock.totalLockedPoolTokens(0)).toString(),
                "Bed locked tokens",
            );

            const withdrawOrder = async (i: number) => {
                if (i > 100) {
                    return;
                }

                const poolId = 0;

                const account = await sphMock.getAddress(i);

                console.log('Expected reward:')

                let countedReward = await sphMock.countReward(0, account);
                console.log(countedReward.toString())
                console.log("");

                console.log('total locked pool tokens from:')
                console.log((await sphMock.totalLockedPoolTokensFrom(0, i)).toString())
                console.log("");

                const res = await sphMock.withdrawTo(poolId, account);
                const events = (await res.wait()).events;

                console.log("Withheld: ");
                console.log((await sphMock.poolWithheld(poolId)).toString());
                console.log("");

                var totalWithdraw = 0;
                await events.map(({ args, event }: any) => {
                    if (event == "Withdrawn") {
                        console.log(`Withdrawn: ${i}`);
                        console.log(`poolId: ${args[0].toString()}`);
                        console.log(`position: ${args[1].toString()}`);
                        console.log(`account: ${args[2].toString()}`);
                        console.log(`amount: ${args[3].toString()}`);
                        console.log("");

                        totalWithdraw += Number(args[3]);
                    }
                    if (event == "Withheld") {
                        console.log(`Withheld: ${i}`);
                        console.log(args[0].toString());
                        console.log("");
                    }
                    if (event == "Bonus") {
                        console.log(`Bonus: ${i}`);
                        console.log(args[0].toString());
                        console.log(args[1].toString());
                        console.log("");
                    }
                    if (event == "Test2") {
                        console.log(`Test2: ${i}`);
                        console.log(args[0].toString());
                        console.log(args[1].toString());
                        console.log(args[2].toString());
                        console.log("");
                    }
                });

                await new Promise<number>((resolve, reject) => {
                    setTimeout(() => {
                        if (totalWithdraw != 0) {
                            resolve(totalWithdraw)
                        } else {
                            reject(0)
                        }
                    }, 100)
                })

                assert.equal(Number(countedReward), totalWithdraw, `Reward issue on ${i}`)

                console.log(`Reward in ${i} (%):`)
                console.log(totalWithdraw / 100000 * 100)

                console.log("Locked pool tokens in range [0...4]");
                console.log((await sphMock.totalLockedPoolTokensFrom(0, 81)).toString());
                console.log((await sphMock.totalLockedPoolTokensFrom(0, 86)).toString());
                console.log((await sphMock.totalLockedPoolTokensFrom(0, 91)).toString());
                console.log((await sphMock.totalLockedPoolTokensFrom(0, 96)).toString());
                console.log("");

                if (100 === i) {
                    await expectRevert(sphMock.getPoolWithdrawPosition(0), "Pool is empty");
                } else {
                    assert.equal(
                        (await sphMock.getPoolWithdrawPosition(0)).toString(),
                        100 - i,
                        "Position not changed",
                    );
                }

                await withdrawOrder(i + 1);
            };

            await withdrawOrder(1);
        });

        it("#totalLockedPoolTokens", async () => {
            const SHPMock = await ethers.getContractFactory("SHPMock");
            const sphMock = await SHPMock.deploy(alm.address);

            await sphMock.fastLock();

            assert.equal(Number(await sphMock.poolLength(0)), 100, "Bed pool length");

            const countReqAlms = () => {
                let result = 0;
                for (let i = 0; i < 100; i++) {
                    result += 100_000;
                }
                return result;
            };

            const mintAmount = countReqAlms();
            await alm.mint(sphMock.address, mintAmount.toString());

            assert.equal(
                (await alm.balanceOf(sphMock.address)).toString(),
                (await sphMock.totalLockedPoolTokens(0)).toString(),
                "Bed locked tokens",
            );

            const withdrawOrder = async (i: number) => {
                if (i > 100) {
                    return;
                }

                const poolId = 0;

                const res = await sphMock.withdrawTo(poolId, await sphMock.getAddress(i));
                const events = (await res.wait()).events;

                console.log("Withheld: ");
                console.log((await sphMock.poolWithheld(poolId)).toString());
                console.log("");

                events.map(({ args, event }: any) => {
                    if (event == "Withdrawn") {
                        console.log(`Withdrawn: ${i}`);
                        console.log(args[0].toString());
                        console.log(args[1].toString());
                        console.log("");
                    }
                    if (event == "Withheld") {
                        console.log(`Withheld: ${i}`);
                        console.log(args[0].toString());
                        console.log("");
                    }
                    if (event == "Bonus") {
                        console.log(`Bonus: ${i}`);
                        console.log(args[0].toString());
                        console.log(args[1].toString());
                        console.log("");
                    }
                    if (event == "Test2") {
                        console.log(`Test2: ${i}`);
                        console.log(args[0].toString());
                        console.log(args[1].toString());
                        console.log(args[2].toString());
                        console.log("");
                    }
                });

                // const bonusesPaid = await sphMock.bonusesPaid(0);
                //
                // console.log("Total bonuses paid: ");
                // console.log(bonusesPaid[0].toString());
                // console.log(bonusesPaid[1].toString());
                // console.log(bonusesPaid[2].toString());
                // console.log(bonusesPaid[3].toString());
                // console.log("");

                // todo: if equal bug
                console.log((await sphMock.totalLockedPoolTokensFrom(0, 80)).toString());
                console.log((await sphMock.totalLockedPoolTokensFrom(0, 85)).toString());
                console.log((await sphMock.totalLockedPoolTokensFrom(0, 90)).toString());
                console.log((await sphMock.totalLockedPoolTokensFrom(0, 95)).toString());
                console.log("");

                if (100 === i) {
                    await expectRevert(sphMock.getPoolWithdrawPosition(0), "Pool is empty");
                } else {
                    assert.equal(
                        (await sphMock.getPoolWithdrawPosition(0)).toString(),
                        100 - i,
                        "Position not changed",
                    );
                }

                await withdrawOrder(i + 1);
            };

            await withdrawOrder(1);
        });
    });

    describe("mutable functions, fail tests", () => {
        it("#lock", async () => {
            const SHPMock = await ethers.getContractFactory("SHPMock");
            const sphMock = await SHPMock.deploy(alm.address);

            assert.equal((await sphMock.totalLockedPoolTokens(0)).toString(), 0);

            const MIN_DEPOSIT = 100_000;

            // lock with less balance
            expectRevert(sphMock.connect(ALICE_SIGNER).lock(ALICE, MIN_DEPOSIT - 1), "Not enough for participate");

            // lock without approve
            expectRevert(
                sphMock.connect(ALICE_SIGNER).lock(ALICE, MIN_DEPOSIT),
                "ERC20: transfer amount exceeds balance",
            );
        });

        it("#withdraw", async () => {
            const SHPMock = await ethers.getContractFactory("SHPMock");
            const sphMock = await SHPMock.deploy(alm.address);

            expectRevert(sphMock.connect(ALICE_SIGNER).withdraw(0), "Only whole pool");

            // make pool-0 whole
            await sphMock.connect(ALICE_SIGNER).fastLock();

            // call from not participant account
            expectRevert(sphMock.connect(ALICE_SIGNER).withdraw(0), "User not found");

            await alm.connect(OWNER_SIGNER).mint(sphMock.address, 100000);
            await sphMock.connect(ALICE_SIGNER).withdrawTo(0, "0x0000000000000000000000000000000000000001");

            expectRevert(sphMock.connect(ALICE_SIGNER).withdrawTo(0, "0x0000000000000000000000000000000000000001"), "Reward already received");
        });
    });
});
