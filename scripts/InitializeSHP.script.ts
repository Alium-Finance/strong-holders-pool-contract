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

    const [owner] = await ethers.getSigners();
    console.log(owner)

    // We get the contract to deploy
    const StrongHolderPool = await hre.ethers.getContractFactory("StrongHolderPool");

    if (hre.network.name === 'bscMainnet') {
        const AliumToken = "0x7C38870e93A1f959cB6c533eB10bBc3e438AaC11"
        const shp = await StrongHolderPool.deploy(
            AliumToken
        );

        await shp.deployed();

        console.log("StrongHolderPool initialized!");
    }

    if (hre.network.name === 'bscTestnet') {
        const SHP_ADDRESS = '0x65533E342449dcC24062126A3aa17E670f1B762D'
        const shp = await StrongHolderPool.attach(SHP_ADDRESS)

        const NFTRewardPoolAddress = '0x746a6AfeC89B1FCC56ffdA04682c771d9270d072'
        await shp.setNftRewardPool(NFTRewardPoolAddress);

        console.log("StrongHolderPool initialized!");
    }

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });