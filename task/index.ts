import { task } from "hardhat/config"

// Sha512 = 0x183b1772dfeaEC69A749bDb30Fd63D4461178AC4
// Ed25519_pow = 0x92043e95553ff00edbd0ccfeb1b2bf88efead816
// Blake3 = 0xc0d192b2a6a5d6de221c9d7d6ec4c698054d6b59
// Ed25519 = 0x1c6ce6b570cf27e77a3d5ce96d800451feb6b06d

task("RecastPromoter:deploy")
  .addParam("idRegistry")
  .setAction(async (_args, _hre) => {
    console.log("Deploying RecastPromoter...")
    const RecastPromoter = await _hre.ethers.getContractFactory("RecastPromoter", {
      libraries: {
        Blake3: "0xc0d192b2a6a5d6de221c9d7d6ec4c698054d6b59",
        Ed25519: "0x1c6ce6b570cf27e77a3d5ce96d800451feb6b06d",
      },
    })
    const recastPromoter = await RecastPromoter.deploy(_args.idRegistry, {
      gasLimit: 6000000,
    })
    console.log("RecastPromoter deployed to:", await recastPromoter.getAddress())
  })

task("PromoteReferenceModule:deploy")
  .addParam("hub")
  .addParam("moduleOwner")
  .setAction(async (_args, _hre) => {
    console.log("Deploying RecastPromoter...")
    const PromoteReferenceModule = await _hre.ethers.getContractFactory("PromoteReferenceModule")
    const promoteReferenceModule = await PromoteReferenceModule.deploy(_args.hub, _args.moduleOwner)
    console.log("PromoteReferenceModule deployed to:", await promoteReferenceModule.getAddress())
  })
