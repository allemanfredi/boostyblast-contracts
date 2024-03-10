import { module } from "@lens-protocol/metadata"

const main = async () => {
  const metadata = module({
    attributes: [],
    name: "PromoteReferenceModule",
    title: "Promote Reference Module",
    description: "This module is used to promote content on Lens Protocol",
    authors: ["alle.manfredi@gmail.com"],
    initializeCalldataABI: JSON.stringify([
      {
        type: "address[]",
        name: "assets",
      },
      {
        type: "uint256[]",
        name: "amounts",
      },
      {
        type: "uint256[]",
        name: "collectorProfileIds",
      },
      {
        type: "uint64[]",
        name: "durations",
      },
    ]),
    processCalldataABI: JSON.stringify([]),
  })

  console.log(metadata)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
