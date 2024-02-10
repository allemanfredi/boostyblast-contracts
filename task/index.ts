import { task } from "hardhat/config"

// IdRegistry = 0x00000000fc6c5f01fc30151999387bb99a9f489b
// Sha512 = 0x1f9356c2b5029d517c9d96c3aa7f9917b1f03ca2
// Ed25519_pow = 0xd66f8f024fc5faced3cb58a0cff80756e028e142
// Blake3 = 0xb335df6c2ca705be09250e3b4ee01f8d163813da
// Ed25519 = 0x1f9356c2b5029d517c9d96c3aa7f9917b1f03ca2
// Promoty = 0xbaa601a6bb5db5c91c08377679184e3497d51f59

task("Promoty:deploy")
  .addParam("idRegistry")
  .setAction(async (_args, _hre) => {
    console.log("Deploying Promoty...")
    const Promoty = await _hre.ethers.getContractFactory("Promoty", {
      libraries: {
        Blake3: "0xb335df6c2ca705be09250e3b4ee01f8d163813da",
        Ed25519: "0x1f9356c2b5029d517c9d96c3aa7f9917b1f03ca2",
      },
    })
    const promoty = await Promoty.deploy(_args.idRegistry)
    console.log("Promoty deployed to:", await promoty.getAddress())
  })
