import eslint from "@eslint/js";
import tseslint from "@typescript-eslint/eslint-plugin";
import tsParser from "@typescript-eslint/parser";
import vuePlugin from "eslint-plugin-vue";
import vueParser from "vue-eslint-parser";
import unusedImports from "eslint-plugin-unused-imports";

export default [
  // Ignore build outputs, dependencies, and auto-generated Alva client code
  {
    ignores: ["dist/**", "node_modules/**", "../priv/**", "js/alva/**"]
  },

  // 1. Strict rules for application code (Vue components and TypeScript sources)
  {
    files: ["vue/**/*.ts", "vue/**/*.vue", "js/**/*.ts"],
    ignores: ["**/*.test.ts", "**/testing/**"],
    languageOptions: {
      parser: vueParser,
      parserOptions: {
        parser: tsParser,
        sourceType: "module",
        ecmaVersion: "latest"
      }
    },
    plugins: {
      "@typescript-eslint": tseslint,
      vue: vuePlugin,
      "unused-imports": unusedImports
    },
    rules: {
      // Vue 3 Recommended rules
      ...vuePlugin.configs["flat/recommended"].rules,

      // Ban unused imports and unused variables
      "unused-imports/no-unused-imports": "error",
      "@typescript-eslint/no-unused-vars": [
        "error",
        {
          argsIgnorePattern: "^_",
          varsIgnorePattern: "^_",
          caughtErrorsIgnorePattern: "^_"
        }
      ],

      // Ban 'any' type usage
      "@typescript-eslint/no-explicit-any": [
        "error",
        { fixToUnknown: false, ignoreRestArgs: false }
      ],

      // Ban 'as Type' type assertions
      "@typescript-eslint/consistent-type-assertions": [
        "error",
        {
          assertionStyle: "never"
        }
      ],

      // Vue specific relaxed defaults for custom styling
      "vue/multi-word-component-names": "off",
      "vue/singleline-html-element-content-newline": "off",
      "vue/max-attributes-per-line": "off",
      "vue/html-self-closing": "off"
    }
  },

  // 2. Relaxed rules for test files and test utilities
  {
    files: ["**/*.test.ts", "**/testing/**/*.ts"],
    languageOptions: {
      parser: tsParser,
      parserOptions: {
        sourceType: "module",
        ecmaVersion: "latest"
      }
    },
    plugins: {
      "@typescript-eslint": tseslint
    },
    rules: {
      "@typescript-eslint/no-explicit-any": "off",
      "@typescript-eslint/consistent-type-assertions": "off",
      "@typescript-eslint/no-unused-vars": "off"
    }
  }
];
