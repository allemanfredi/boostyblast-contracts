import { task } from "hardhat/config"

// Sha512 = 0x183b1772dfeaEC69A749bDb30Fd63D4461178AC4
// Ed25519_pow = 0x92043e95553ff00edbd0ccfeb1b2bf88efead816
// Blake3 = 0xc0d192b2a6a5d6de221c9d7d6ec4c698054d6b59
// Ed25519 = 0x1c6ce6b570cf27e77a3d5ce96d800451feb6b06d
// Promoty = 0x3ee3092c5212c798258b17243b61cda41a334ac2

task("Promoty:deploy")
  .addParam("idRegistry")
  .setAction(async (_args, _hre) => {
    console.log("Deploying Promoty...")
    const Promoty = await _hre.ethers.getContractFactory("Promoty", {
      libraries: {
        Blake3: "0xc0d192b2a6a5d6de221c9d7d6ec4c698054d6b59",
        Ed25519: "0x1c6ce6b570cf27e77a3d5ce96d800451feb6b06d",
      },
    })
    const promoty = await Promoty.deploy(_args.idRegistry)
    console.log("Promoty deployed to:", await promoty.getAddress())
  })
