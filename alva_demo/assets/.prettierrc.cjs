/** @type {import("prettier").Config} */
module.exports = {
  // Core Prettier Formatting Rules
  semi: true,
  singleQuote: false,
  tabWidth: 2,
  trailingComma: "none",
  printWidth: 100,
  bracketSpacing: true,

  // Vue-specific Profile Optimization
  vueIndentScriptAndStyle: false,
  singleAttributePerLine: false,
  htmlWhitespaceSensitivity: "css",

  // Tailwind CSS Automatic Class Sorting Plugin
  plugins: ["prettier-plugin-tailwindcss"],
  tailwindConfig: "./tailwind.config.js",
  tailwindFunctions: ["cn", "cva", "clsx"]
};
