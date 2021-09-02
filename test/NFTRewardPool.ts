import chai from "chai";

import { ethers } from "hardhat";
import { Signer } from "ethers";
import { assert } from "chai";
import { solidity } from "ethereum-waffle";

chai.use(solidity);

describe("NFTRewardPool", function () {
    let accounts: Signer[];

    let OWNER_SIGNER: any;
    let ALICE_SIGNER: any;
    let SHP_SIGNER: any;

    let OWNER: any;
    let ALICE: any;
    let SHP: any;

    let almGaming1155: any;
    let nftPool: any;

    before("config", async () => {
        accounts = await ethers.getSigners();

        OWNER_SIGNER = accounts[0];
        ALICE_SIGNER = accounts[1];
        SHP_SIGNER = accounts[2];

        OWNER = await OWNER_SIGNER.getAddress();
        ALICE = await ALICE_SIGNER.getAddress();
        SHP = await SHP_SIGNER.getAddress();

        const ERC1155Mock = await ethers.getContractFactory("ERC1155Mock");
        almGaming1155 = await ERC1155Mock.deploy();
    });

    describe("mutable functions, success tests", () => {
        beforeEach(async () => {
            const NFTRewardPool = await ethers.getContractFactory("NFTRewardPool");
            nftPool = await NFTRewardPool.deploy();
        });

        describe("with OWNER permission", () => {
            it("#initialize", async () => {
                await nftPool.connect(OWNER_SIGNER).initialize(almGaming1155.address, SHP);

                assert.equal(await nftPool.rewardToken(), almGaming1155.address);
                assert.equal(await nftPool.shp(), SHP);
            });

            it("#setReward", async () => {
                await nftPool.connect(OWNER_SIGNER).initialize(almGaming1155.address, SHP);

                await nftPool.connect(OWNER_SIGNER).setReward(1, [
                    {
                        tokenId: 1,
                        amount: 1,
                    },
                ]);

                console.log(await nftPool.getReward(1));

                let rewardPool = await nftPool.getReward(1);

                assert.equal(rewardPool[0].tokenId, 1);
                assert.equal(rewardPool[0].amount, 1);

                await nftPool.connect(OWNER_SIGNER).setReward(2, [
                    {
                        tokenId: 2,
                        amount: 2,
                    },
                    {
                        tokenId: 3,
                        amount: 3,
                    },
                ]);

                rewardPool = await nftPool.getReward(2);

                assert.equal(rewardPool[0].tokenId, 2);
                assert.equal(rewardPool[0].amount, 2);

                assert.equal(rewardPool[1].tokenId, 3);
                assert.equal(rewardPool[1].amount, 3);

                // rewrite reward with position 1
                await nftPool.connect(OWNER_SIGNER).setReward(1, [
                    {
                        tokenId: 2,
                        amount: 2,
                    },
                ]);

                rewardPool = await nftPool.getReward(1);

                assert.equal(rewardPool[0].tokenId, 2);
                assert.equal(rewardPool[0].amount, 2);
            });

            it("#setRewards", async () => {
                await nftPool.connect(OWNER_SIGNER).initialize(almGaming1155.address, SHP);

                await nftPool.connect(OWNER_SIGNER).setRewards(
                    [1],
                    [
                        {
                            rewards: [
                                {
                                    tokenId: 1,
                                    amount: 1,
                                },
                            ],
                        },
                    ],
                );

                let rewardPool = await nftPool.getReward(1);

                assert.equal(rewardPool[0].tokenId, 1);
                assert.equal(rewardPool[0].amount, 1);

                await nftPool.connect(OWNER_SIGNER).setRewards(
                    [1],
                    [
                        {
                            rewards: [
                                {
                                    tokenId: 2,
                                    amount: 1,
                                },
                            ],
                        },
                    ],
                );

                rewardPool = await nftPool.getReward(1);

                assert.equal(rewardPool[0].tokenId, 2);
                assert.equal(rewardPool[0].amount, 1);
            });
        });

        describe("with SHP permission", () => {
            it("#log", async () => {
                await nftPool.connect(OWNER_SIGNER).initialize(almGaming1155.address, SHP);
                await nftPool.connect(SHP_SIGNER).log(ALICE, 100);

                assert.equal((await nftPool.getLog(ALICE, 100)).toString(), 1, "Wrong count");
                assert.equal((await nftPool.getLogs(ALICE))[100].toString(), 1, "Wrong count");
            });
        });

        describe("without permissions", () => {
            it("#claim", async () => {
                await nftPool.connect(OWNER_SIGNER).initialize(almGaming1155.address, SHP);
                await nftPool.connect(SHP_SIGNER).log(ALICE, 1);

                assert.equal((await nftPool.getLog(ALICE, 1)).toString(), 1, "Wrong count");
                assert.equal((await nftPool.getLogs(ALICE))[1].toString(), 1, "Wrong count");

                await nftPool.connect(ALICE_SIGNER).claim();

                assert.equal((await nftPool.getLog(ALICE, 1)).toString(), 0, "Wrong count");
                assert.equal((await nftPool.getLogs(ALICE))[1].toString(), 0, "Wrong count");

                await nftPool.connect(SHP_SIGNER).log(ALICE, 1);

                assert.equal((await nftPool.getLog(ALICE, 1)).toString(), 1, "Wrong count");
                assert.equal((await nftPool.getLogs(ALICE))[1].toString(), 1, "Wrong count");

                await nftPool.connect(OWNER_SIGNER).setReward(1, [
                    {
                        tokenId: 1,
                        amount: 100,
                    },
                ]);

                const rewardPool = await nftPool.getReward(1);

                assert.equal(rewardPool[0].tokenId.toString(), 1);
                assert.equal(rewardPool[0].amount.toString(), 100);

                const prevAliceBalance = Number(await almGaming1155.balanceOf(ALICE, 1));

                await nftPool.connect(ALICE_SIGNER).claim();

                assert.equal((await nftPool.getLog(ALICE, 1)).toString(), 0, "Wrong count");
                assert.equal((await nftPool.getLogs(ALICE))[1].toString(), 0, "Wrong count");
                assert.equal(
                    (await almGaming1155.balanceOf(ALICE, 1)).toString(),
                    prevAliceBalance + 100,
                    "Wrong count",
                );
            });

            it("#withdraw", async () => {
                const RewardPoolMock = await ethers.getContractFactory("RewardPoolMock");
                nftPool = await RewardPoolMock.deploy();

                await nftPool.connect(OWNER_SIGNER).initialize(almGaming1155.address, SHP);
                await nftPool.connect(OWNER_SIGNER).addBalance(ALICE, 1, 100);
                await almGaming1155.connect(OWNER_SIGNER).mint(nftPool.address, 1, 100, 0x00);

                assert.equal((await nftPool.getBalance(ALICE, 1)).toString(), 100);

                await nftPool.connect(ALICE_SIGNER).withdraw(1);

                assert.equal((await nftPool.getBalance(ALICE, 1)).toString(), 0);
            });
        });
    });
});
