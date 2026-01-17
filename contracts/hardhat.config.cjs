require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config({ path: "../.env.local" });
const path = require("path");

module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  paths: {
    sources: ".",
    artifacts: "./artifacts",
    cache: "./cache",
  },
  resolve: {
    modules: ["node_modules", path.resolve(__dirname, "../node_modules")],
  },
  networks: {
    "base-sepolia": {
      url: "https://sepolia.base.org",
      accounts: process.env.ADMIN_PRIVATE_KEY ? [process.env.ADMIN_PRIVATE_KEY] : [],
      chainId: 84532,
    },
  },
};
