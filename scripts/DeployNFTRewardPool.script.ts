import hre from "hardhat";
const ethers = hre.ethers;

async function main() {
    // Hardhat always runs the compile task when running scripts with its command
    // line interface.
    //
    // If this script is run directly using `node` you may want to call compile
    // manually to make sure everything is compiled
    // await hre.run('compile');

    // console.log(await ethers.getSigners())


    // We get the contract to deploy
    const NFTRewardPool = await hre.ethers.getContractFactory("NFTRewardPool");
    const AliumGaming1155 = await hre.ethers.getContractFactory("AliumGaming1155");


    const nftRewardPool = await NFTRewardPool.deploy();
    await nftRewardPool.deployed();
    // const nftRewardPool = await NFTRewardPool.attach('0x2EBd28de6de248a7C9fa712890951E245b9CD8Ce')

    const aliumGaming1155 = await AliumGaming1155.deploy("https://some-api.com/");
    await aliumGaming1155.deployed();

    const MINTER_ROLE = await aliumGaming1155.MINTER_ROLE()
    await aliumGaming1155.grantRole(MINTER_ROLE, aliumGaming1155.address)

    let SHP = '0x65533E342449dcC24062126A3aa17E670f1B762D'
    await nftRewardPool.initialize(aliumGaming1155.address, SHP)

    const [owner] = await ethers.getSigners();
    console.log(owner)

    let withdrawPositions = [];
    let rewards = [];

    let i = 100;
    while (i > 0) {
        withdrawPositions.push(i)
        rewards.push({
            rewards: [
                {
                    tokenId: 1,
                    amount: 1,
                },
            ],
        })
        i--;
    }

    console.log(withdrawPositions)
    console.log(rewards)

    await nftRewardPool.connect(owner).setRewards(withdrawPositions, rewards)

    // const MINTER_ROLE = await aliumGaming1155.connect(owner).MINTER_ROLE();
    // await aliumGaming1155.connect(owner).grantRole(MINTER_ROLE, nftRewardPool.address)

    // [100, 99, 98, 97, 96, 95, 94, 93, 92, 91],
    // [
    //     {
    //         rewards: [
    //             {
    //                 tokenId: 1,
    //                 amount: 1,
    //             },
    //         ],
    //     },
    //     {
    //         rewards: [
    //             {
    //                 tokenId: 1,
    //                 amount: 1,
    //             },
    //         ],
    //     },
    //     {
    //         rewards: [
    //             {
    //                 tokenId: 1,
    //                 amount: 1,
    //             },
    //         ],
    //     },
    //     {
    //         rewards: [
    //             {
    //                 tokenId: 1,
    //                 amount: 1,
    //             },
    //         ],
    //     },
    //     {
    //         rewards: [
    //             {
    //                 tokenId: 1,
    //                 amount: 1,
    //             },
    //         ],
    //     },
    //     {
    //         rewards: [
    //             {
    //                 tokenId: 1,
    //                 amount: 1,
    //             },
    //         ],
    //     },
    //     {
    //         rewards: [
    //             {
    //                 tokenId: 1,
    //                 amount: 1,
    //             },
    //         ],
    //     },
    //     {
    //         rewards: [
    //             {
    //                 tokenId: 1,
    //                 amount: 1,
    //             },
    //         ],
    //     },
    //     {
    //         rewards: [
    //             {
    //                 tokenId: 1,
    //                 amount: 1,
    //             },
    //         ],
    //     },
    //     {
    //         rewards: [
    //             {
    //                 tokenId: 1,
    //                 amount: 1,
    //             },
    //         ],
    //     },
    // ],
    // );
    //
    // const greeterAddress = nftRewardPool.address
    // console.log(await NFTRewardPool.attach(greeterAddress))

    console.log("AliumGaming1155 deployed to:", aliumGaming1155.address);
    console.log("NFTRewardPool deployed to:", nftRewardPool.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });