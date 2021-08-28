import chai from "chai";

import { ethers } from "hardhat";
import { Signer } from "ethers";
import { assert } from "chai";
import { solidity } from "ethereum-waffle";

const {
    expectRevert, // Assertions for transactions that should fail
} = require('@openzeppelin/test-helpers');

const { constants } = ethers;
const { MaxUint256 } = constants;

chai.use(solidity);

describe("AliumGaming1155", function() {
    let accounts: Signer[];

    let OWNER_SIGNER: any
    let ALICE_SIGNER: any

    let OWNER: any
    let ALICE: any

    let almGaming1155: any;

    before('config', async () => {
        accounts = await ethers.getSigners();

        OWNER_SIGNER = accounts[0];
        ALICE_SIGNER = accounts[1];

        OWNER = await OWNER_SIGNER.getAddress()
        ALICE = await ALICE_SIGNER.getAddress()

        const AliumGaming1155 = await ethers.getContractFactory("AliumGaming1155");
        const tokenApiUrl = 'http://localhost:3000/api/'
        almGaming1155 = await AliumGaming1155.deploy(tokenApiUrl);
    })

    describe.only('immutable functions', () => {
        it.only('#supportsInterface', async () => {
            const royaltyInterface = '0xb7799584'
            assert.equal(await almGaming1155.supportsInterface(royaltyInterface), true, "Royalty lost")
        })
    })

    describe('mutable functions', () => {
        describe('in AliumGaming1155', () => {
            it('#mint', async () => {
                //
            })

            it('#mintBatch', async () => {
                //
            })

            it('#burn', async () => {
                //
            })

            it('#burnBatch', async () => {
                //
            })
        })

        describe('in AccessControlToken', () => {

        })

        describe('in RoyaltyToken', () => {
            it('#saveRoyalties', async () => {
                //
            })

            it('#updateAccount', async () => {
                //
            })
        })

    })

});
