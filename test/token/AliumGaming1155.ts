import chai from "chai";

import { ethers } from "hardhat";
import { Signer } from "ethers";
import { assert } from "chai";
import { solidity } from "ethereum-waffle";
const { constants } = ethers;
const { MaxUint256 } = constants;

chai.use(solidity);

describe("AliumGaming1155", function () {
    let accounts: Signer[];

    let OWNER_SIGNER: any;
    let MINTER_SIGNER: any;
    let ALICE_SIGNER: any;

    let OWNER: any;
    let MINTER: any;
    let ALICE: any;

    let nft: any;
    let AliumGaming1155: any;

    before("config", async () => {
        accounts = await ethers.getSigners();

        OWNER_SIGNER = accounts[0];
        MINTER_SIGNER = accounts[1];
        ALICE_SIGNER = accounts[2];

        OWNER = await OWNER_SIGNER.getAddress();
        MINTER = await MINTER_SIGNER.getAddress();
        ALICE = await ALICE_SIGNER.getAddress();

        AliumGaming1155 = await ethers.getContractFactory("AliumGaming1155");
    });

    beforeEach(async () => {
        const tokenApiUrl = "http://localhost:3000/api/";
        nft = await AliumGaming1155.deploy(tokenApiUrl);
        const MINTER_ROLE = String(await nft.MINTER_ROLE());
        await nft.grantRole(MINTER_ROLE, MINTER);
    });

    describe("immutable functions", () => {
        it("#supportsInterface", async () => {
            const royaltyInterface = "0xb7799584";
            assert.equal(await nft.supportsInterface(royaltyInterface), true, "Royalty lost");
        });
    });

    describe("mutable functions", () => {
        describe("in AliumGaming1155", () => {
            it("#mint", async () => {
                await nft.connect(MINTER_SIGNER).mint(ALICE, 1, 1, "0x");

                // mint the same token id
                await nft.connect(MINTER_SIGNER).mint(ALICE, 1, 1, "0x");

                // mint the other token id
                await nft.connect(MINTER_SIGNER).mint(ALICE, 2, 1, "0x");
            });

            it("#mintBatch", async () => {
                await nft.connect(MINTER_SIGNER).mintBatch(ALICE, [1, 2], [1, 1], "0x");
            });

            it("#burn", async () => {
                await nft.connect(MINTER_SIGNER).mint(ALICE, 1, 1, "0x");
                await nft.connect(ALICE_SIGNER).burn(1, 1);
            });

            it("#burnBatch", async () => {
                await nft.connect(MINTER_SIGNER).mintBatch(ALICE, [1, 2], [1, 1], "0x");
                await nft.connect(ALICE_SIGNER).burnBatch([1, 2], [1, 1]);
            });
        });

        // describe('in AccessControlToken', () => {
        //     //
        // })
        //
        // describe('in RoyaltyToken', () => {
        //     it('#saveRoyalties', async () => {
        //         //
        //     })
        //
        //     it('#saveRoyaltiesBatch', async () => {
        //         //
        //     })
        //
        //     it('#getRoyalties', async () => {
        //         //
        //     })
        //
        //     it('#updateAccount', async () => {
        //         //
        //     })
        // })
    });
});
