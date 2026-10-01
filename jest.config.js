const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");

module.exports = {
  ...jestConfig,
  modulePathIgnorePatterns: ["<rootDir>/.localdevserver"],
  coverageThreshold: {
    global: { branches: 80, functions: 80, lines: 85, statements: 85 }
  }
};
